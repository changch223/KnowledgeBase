//
//  ArticleCorrectionCoordinator.swift
//  KnowledgeTree
//
//  spec 096 — 本文の見直し→確認→確定→知識作り直し を 1 つの段階フローで継続実行する。
//  ① beginReview: 指示(任意)→用語集レビューを背景実行し、本文は触らず「候補」を作る。
//     先に走行中の抽出を停止して ANE を見直しに譲る (旧本文への抽出は破棄される無駄なため)。
//  ② awaitingConfirmation: 完了をバナーで通知 → ユーザーが確認 (レポート + 直接編集) する。
//  ③ confirm: 確定した本文を反映し、知識 (概念・タグ・要点) を 1 回だけ作り直す。
//  状態は stages[articleID] に持ち、ArticleDetailView が監視して表示する。シートを閉じても継続。
//

import SwiftUI
import SwiftData
import os

@MainActor
@Observable
final class ArticleCorrectionCoordinator {
    private static let logger = Logger(subsystem: "app.KnowledgeTree", category: "correction")

    /// 記事ごとの段階状態。
    enum Stage: Sendable {
        case reviewing(current: Int, total: Int)         // 見直し中 (背景)
        case awaitingConfirmation(PendingCorrection)     // 見直し完了、ユーザー確認待ち
        case committing                                  // 確定後、知識を作り直し中
        case done(CorrectionResult)                      // 完了、結果レポート表示
        case customizeDone                               // 生成カスタマイズ完了 (本文不変)
    }

    private(set) var stages: [UUID: Stage] = [:]

    /// 見直しが完了して確認待ちの記事 (どの画面からでも通知バナーを出すため)。
    private(set) var awaitingReview: [UUID: Article] = [:]

    /// いずれかの記事が確認待ちなら、その記事 (アプリ全体の通知バナー / 確認シート用)。
    var anyAwaitingReview: Article? { awaitingReview.first?.value }

    // MARK: - 読み取り

    func stage(for article: Article) -> Stage? { stages[article.id] }

    /// 見直し中 or 作り直し中 (新たな見直しを始められない)。
    func isBusy(_ article: Article) -> Bool {
        switch stages[article.id] {
        case .reviewing, .committing: return true
        default: return false
        }
    }

    func pendingConfirmation(for article: Article) -> PendingCorrection? {
        if case .awaitingConfirmation(let p) = stages[article.id] { return p }
        return nil
    }

    func result(for article: Article) -> CorrectionResult? {
        if case .done(let r) = stages[article.id] { return r }
        return nil
    }

    // MARK: - 操作

    /// 結果レポート / 確認待ち / カスタマイズ完了を閉じる (処理中は閉じない)。
    func clearStage(_ article: Article) {
        switch stages[article.id] {
        case .done, .awaitingConfirmation, .customizeDone:
            stages[article.id] = nil
            awaitingReview[article.id] = nil
        default:
            break
        }
    }

    /// 見直し候補を破棄 (本文は未変更なので何も反映しない)。
    /// 停止した抽出は次回 backfill で resume されるため、ここでは何もしない。
    func discardReview(_ article: Article) {
        if case .awaitingConfirmation = stages[article.id] { stages[article.id] = nil }
        awaitingReview[article.id] = nil
    }

    /// ① 見直し開始。指示(任意)→用語集レビューを連続で 1 回に。本文・知識は触らない。
    /// 先に走行中の抽出を停止してから見直す (旧本文への抽出は無駄 + ANE 競合回避)。
    func beginReview(
        article: Article,
        instruction: String,
        corrector: TranscriptCorrecting,
        knowledgeService: KnowledgeExtractionServiceProtocol?,
        modelContext: ModelContext
    ) {
        let id = article.id
        guard !isBusy(article), let (_, _, original) = bodyText(of: article) else { return }
        let inst = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        let glossary = TranscriptGlossaryBuilder.build(context: modelContext)
        stages[id] = .reviewing(current: 0, total: 1)
        Self.logger.info("""
            review begin: article=\(id, privacy: .public) bodyChars=\(original.count) \
            instruction=\(inst.isEmpty ? "(none)" : inst, privacy: .public) glossary=\(glossary.count)語
            """)
        Task { @MainActor in
            // 走行中の抽出を停止 (旧本文への処理は破棄予定。ANE を見直しに譲り高速化)。
            await knowledgeService?.cancelInFlight(article: article)

            let report: @Sendable (Int, Int) async -> Void = { current, total in
                await MainActor.run {
                    if case .reviewing = self.stages[id] {
                        self.stages[id] = .reviewing(current: current, total: total)
                    }
                }
            }

            var candidate = original
            if !inst.isEmpty {
                candidate = await corrector.applyInstruction(candidate, instruction: inst, onWindow: report)
            }
            candidate = await corrector.correct(candidate, glossary: glossary, onWindow: report)

            let changed = candidate != original
            let diff = changed ? CorrectionDiff.analyze(from: original, to: candidate) : .none
            Self.logger.info("review done: article=\(id, privacy: .public) changed=\(changed) changes=\(diff.total)")

            if changed {
                self.stages[id] = .awaitingConfirmation(
                    PendingCorrection(original: original, candidate: candidate, diff: diff)
                )
                // どの画面に居ても通知できるよう、確認待ちの記事を登録。
                self.awaitingReview[id] = article
            } else {
                // 変更なし → 確認不要、そのまま「変更なし」レポート。
                self.stages[id] = .done(CorrectionResult(
                    articleID: id, kind: .review, changed: false,
                    originalCount: original.count, correctedCount: candidate.count,
                    detailAvailable: true, total: 0, changes: []
                ))
            }
        }
    }

    /// ③ 確定。finalText (確認/編集後の本文) を反映し、知識を 1 回だけ作り直す。
    func confirm(
        article: Article,
        finalText: String,
        knowledgeService: KnowledgeExtractionServiceProtocol?,
        modelContext: ModelContext,
        refresh: RefreshTrigger
    ) {
        let id = article.id
        guard let (_, body, original) = bodyText(of: article) else { return }
        let edited = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !edited.isEmpty else { return }

        let changed = edited != original
        let diff = changed ? CorrectionDiff.analyze(from: original, to: edited) : .none
        let result = CorrectionResult(
            articleID: id, kind: .review, changed: changed,
            originalCount: original.count, correctedCount: edited.count,
            detailAvailable: diff.detailAvailable, total: diff.total, changes: diff.changes
        )

        guard changed else {
            Self.logger.info("confirm: no change for article=\(id, privacy: .public) → done")
            stages[id] = .done(result)
            return
        }

        stages[id] = .committing
        awaitingReview[id] = nil
        Self.logger.info("confirm commit: article=\(id, privacy: .public) \(original.count)字→\(edited.count)字 changes=\(diff.total)")
        Task { @MainActor in
            defer { refresh.bump() }

            // 走行中の抽出を停止して unwind を待つ (delete する知識グラフを安全にする)。
            await knowledgeService?.cancelInFlight(article: article)

            body.extractedText = edited

            // 訂正前の知識を clear (誤認識由来の概念・タグを残さない)。
            if let ek = article.extractedKnowledge {
                article.extractedKnowledge = nil
                modelContext.delete(ek)
                Self.logger.info("confirm: cleared ExtractedKnowledge")
            }
            let removed = deleteSoleSourceConcepts(of: article, in: modelContext)
            Self.logger.info("confirm: deleted \(removed) sole-source concept page(s)")
            try? modelContext.save()

            // 確定した本文で知識を再生成。
            Self.logger.info("confirm: re-extracting knowledge…")
            await knowledgeService?.extract(article: article)
            Self.logger.info("confirm: re-extraction finished article=\(id, privacy: .public)")

            self.stages[id] = .done(result)
        }
    }

    /// spec 096: カスタマイズ抽出。本文は変えず、抽出の方向性 (guidance) を指定して知識を作り直す。
    /// guidance 空 = 既定の抽出に戻す。
    func customizeExtraction(
        article: Article,
        guidance: String,
        knowledgeService: KnowledgeExtractionServiceProtocol?,
        modelContext: ModelContext,
        refresh: RefreshTrigger
    ) {
        let id = article.id
        guard !isBusy(article), bodyText(of: article) != nil else { return }
        let g = guidance.trimmingCharacters(in: .whitespacesAndNewlines)
        stages[id] = .committing
        Self.logger.info("customize extraction: article=\(id, privacy: .public) guidance=\(g.isEmpty ? "(cleared)" : g, privacy: .public)")
        Task { @MainActor in
            defer { refresh.bump() }

            // 走行中の抽出を停止 (delete を安全に + ANE を解放)。
            await knowledgeService?.cancelInFlight(article: article)

            article.extractionGuidance = g.isEmpty ? nil : g

            if let ek = article.extractedKnowledge {
                article.extractedKnowledge = nil
                modelContext.delete(ek)
            }
            let removed = deleteSoleSourceConcepts(of: article, in: modelContext)
            Self.logger.info("customize: cleared knowledge, deleted \(removed) sole-source concept(s)")
            try? modelContext.save()

            // 指定の方向性で知識を作り直す。
            await knowledgeService?.extract(article: article)
            Self.logger.info("customize: re-extraction finished article=\(id, privacy: .public)")

            // 完了を画面で知らせる (ユーザーが閉じるまで表示)。
            self.stages[id] = .customizeDone
        }
    }

    // MARK: - 共通処理

    /// article.body.extractedText を取り出す。本文なし / 空なら nil。
    private func bodyText(of article: Article) -> (id: UUID, body: ArticleBody, text: String)? {
        let id = article.id
        guard let body = article.body,
              let text = body.extractedText,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return (id, body, text)
    }

    /// この記事だけが source の概念ページを削除 (複数記事が紐づくものは残す)。削除件数を返す。
    /// article.relatedConcepts inverse を使い O(k) スキャン (k = この記事に紐づく概念数)。
    @discardableResult
    private func deleteSoleSourceConcepts(of article: Article, in context: ModelContext) -> Int {
        let candidates = article.relatedConcepts ?? []
        var removed = 0
        for page in candidates {
            let related = page.relatedArticles ?? []
            if related.count == 1, related.first?.id == article.id {
                context.delete(page)
                removed += 1
            }
        }
        return removed
    }
}

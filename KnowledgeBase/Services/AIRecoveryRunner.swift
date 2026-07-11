//
//  AIRecoveryRunner.swift
//  KnowledgeTree
//
//  AI 復旧機能 — Apple Intelligence 不可時に skip / 劣化生成された知識抽出・概念まとめ・
//  Wiki 本文を、AI 復活検知で自動的に裏で再生成する。
//
//  トリガ (KnowledgeTreeApp bootstrap が配線):
//    (a) AIAvailabilityMonitor の unavailable → available 遷移
//    (b) アプリ起動時、既に available なら一度 (起動をまたいだ復旧)
//
//  やること (availability 可のときのみ):
//    1. 過去分の一回限りの救済 (retroactive backfill): fallback 署名に一致する既存 ConceptPage に
//       synthesizedWithoutAI = true を付ける (BackfillFlagStore で 1 回だけ)
//    2. synthesizedWithoutAI == true の ConceptPage を isStale = true にマークし、
//       既存 ConceptSynthesisService.resynthesizeAllStale() (呼び出し 1 回あたり上位 5 件しか
//       処理しない) を、劣化ページが尽きるまで反復呼び出しする (有界ループ)。
//       - 継続条件: synthesizedWithoutAI == true かつ isStale == true のページが残っている
//       - 各イテレーション前に availability を再確認し、復旧中に AI が落ちたら中断する
//         (残りは次回の復活検知で再開される)
//       - 安全上限 30 イテレーション (最大 150 ページ) で無限ループを防止
//       - 直前のイテレーションで残数が減らなかったら中断 (合成が失敗し続けるケースで空回りしない)
//    3. knowledgeService.backfillAll() を呼ぶ。skipped な知識抽出は
//       ArticleKnowledgeStore.fetchPendingArticles の対象に含まれているので自然に再試行される
//       (AI がまだ不可なら extract() 冒頭の availability guard が再び skipped を書くだけの
//       安全な no-op ループになる)。
//
//  多重起動ガード: 実行中は再入しない (isRunning フラグ)。
//

import Foundation
import SwiftData
import os

@MainActor
protocol AIRecoveryRunnerProtocol: AnyObject {
    /// AI 復活検知時 (unavailable → available 遷移 / 起動時) に呼ばれる。
    /// availability 不可なら no-op、既に実行中なら再入しない。
    func runIfNeeded() async
}

@MainActor
final class DefaultAIRecoveryRunner: AIRecoveryRunnerProtocol {
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "ai-recovery")

    private let context: ModelContext
    private let knowledgeService: KnowledgeExtractionServiceProtocol
    private let conceptSynthesisService: ConceptSynthesisServiceProtocol
    private let availabilityChecker: AvailabilityChecker
    private let processingMonitor: ProcessingMonitor?
    private let refreshTrigger: RefreshTrigger?
    private let retroactiveFlagStore: BackfillFlagStore

    private var isRunning = false

    /// processingMonitor 表示用の固定 UUID (spec 013 AutoTagBackfillRunner.backfillProcessingID と同パターン)。
    static let recoveryProcessingID = UUID(
        uuidString: "00000000-0000-0000-0000-A19EC0BEBABE"
    )!

    /// resynthesizeAllStale() の反復呼び出し安全上限 (1 回あたり上位 5 件 × 30 = 最大 150 ページ)。
    /// 無限ループ防止。上限到達時点で残っている分は次回の復活検知トリガで再開される。
    static let maxRecoveryIterations = 30

    init(
        context: ModelContext,
        knowledgeService: KnowledgeExtractionServiceProtocol,
        conceptSynthesisService: ConceptSynthesisServiceProtocol,
        availabilityChecker: AvailabilityChecker = SystemLanguageModelAvailabilityChecker(),
        processingMonitor: ProcessingMonitor? = nil,
        refreshTrigger: RefreshTrigger? = nil,
        retroactiveFlagStore: BackfillFlagStore = UserDefaultsBackfillFlagStore(key: "ai_recovery_retroactive_v1_done")
    ) {
        self.context = context
        self.knowledgeService = knowledgeService
        self.conceptSynthesisService = conceptSynthesisService
        self.availabilityChecker = availabilityChecker
        self.processingMonitor = processingMonitor
        self.refreshTrigger = refreshTrigger
        self.retroactiveFlagStore = retroactiveFlagStore
    }

    func runIfNeeded() async {
        guard availabilityChecker.isAvailable else { return }
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        // 1. 過去分 (列追加前に劣化生成されたページ) の一回限りの救済。
        performRetroactiveBackfillIfNeeded()

        // 2. 劣化生成された概念ページを再合成対象にし、尽きるまで反復合成する (有界ループ)。
        let degradedPages = fetchDegradedConceptPages()
        if !degradedPages.isEmpty {
            logger.notice("ai recovery: marking \(degradedPages.count) degraded concept page(s) stale for resynthesis")
            processingMonitor?.start(
                .aiRecovering,
                articleID: Self.recoveryProcessingID,
                title: "AI 復旧: 概念まとめを再生成中"
            )
            // 堅牢化: 将来 early return/throw を追加しても phase 表示が残留しないよう defer で解除する。
            defer { processingMonitor?.finish(articleID: Self.recoveryProcessingID) }
            for page in degradedPages {
                page.isStale = true
            }
            try? context.save()
            refreshTrigger?.bump()

            var remaining = degradedPages.count
            var remainingAllStale = fetchAllStaleConceptPages().count
            var iteration = 0
            while remaining > 0 && iteration < Self.maxRecoveryIterations {
                guard availabilityChecker.isAvailable else {
                    logger.notice("ai recovery: availability lost mid-loop at iteration \(iteration), suspending (\(remaining) page(s) remain for next trigger)")
                    break
                }
                await conceptSynthesisService.resynthesizeAllStale()
                iteration += 1

                let nowRemaining = fetchDegradedStaleConceptPages().count
                let nowRemainingAllStale = fetchAllStaleConceptPages().count
                // 進捗判定: 劣化 stale 残数 または 全 stale 残数のどちらかが減っていれば継続する。
                // resynthesizeAllStale は最新記事優先で上位 5 件しか処理しないため、非劣化 stale
                // ページが top-5 を占有した回は劣化残数だけ見ると変化なしに見える (誤って無進捗と判定しない)。
                if nowRemaining == remaining && nowRemainingAllStale == remainingAllStale {
                    logger.notice("ai recovery: no progress after iteration \(iteration), stopping (\(nowRemaining) page(s) remain)")
                    break
                }
                remaining = nowRemaining
                remainingAllStale = nowRemainingAllStale
            }
            if iteration >= Self.maxRecoveryIterations && remaining > 0 {
                logger.notice("ai recovery: reached max iteration cap (\(Self.maxRecoveryIterations)), \(remaining) page(s) remain for next trigger")
            }
        }

        // 3. skipped な知識抽出を再試行 (再抽出自体の進捗は既存 .knowledge phase が表示する)。
        await knowledgeService.backfillAll()
    }

    // MARK: - Private

    private func fetchDegradedConceptPages() -> [ConceptPage] {
        let descriptor = FetchDescriptor<ConceptPage>(
            predicate: #Predicate { $0.synthesizedWithoutAI == true }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 復旧ループの継続判定用: マーク済み劣化ページのうち、まだ再合成されていない (isStale のまま) 件数。
    private func fetchDegradedStaleConceptPages() -> [ConceptPage] {
        let descriptor = FetchDescriptor<ConceptPage>(
            predicate: #Predicate { $0.synthesizedWithoutAI == true && $0.isStale == true }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 復旧ループの継続判定用: 劣化/非劣化を問わず isStale のままの全 ConceptPage。
    /// resynthesizeAllStale は最新記事優先で上位 5 件しか処理しないため、非劣化 stale ページが
    /// 先に消化された回でも「進捗あり」と判定できるよう、劣化件数と合わせて参照する。
    private func fetchAllStaleConceptPages() -> [ConceptPage] {
        let descriptor = FetchDescriptor<ConceptPage>(
            predicate: #Predicate { $0.isStale == true }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 過去分 (synthesizedWithoutAI 列追加前に劣化生成されたページ) を一回限り救済する。
    /// fallback 署名 (① bodyMarkdown が summary のコピー、② summary が空、
    /// ③ summary はあるが bodyMarkdown が空〔Fallback 経路は bodyMarkdown を書かないため、
    /// これが最も劣化した essence-list summary の署名〕) のいずれかに一致し、
    /// ユーザーが本文を訂正済 (bodyEditedByUser) でないページに synthesizedWithoutAI = true を付ける。
    private func performRetroactiveBackfillIfNeeded() {
        guard !retroactiveFlagStore.isCompleted() else { return }

        let allPages = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
        var changed = false
        for page in allPages {
            guard !page.bodyEditedByUser, !page.synthesizedWithoutAI else { continue }
            let looksFallback = (!page.bodyMarkdown.isEmpty && page.bodyMarkdown == page.summary)
                || page.summary.isEmpty
                || (!page.summary.isEmpty && page.bodyMarkdown.isEmpty)
            if looksFallback {
                page.synthesizedWithoutAI = true
                changed = true
            }
        }
        if changed {
            try? context.save()
            refreshTrigger?.bump()
        }
        retroactiveFlagStore.markCompleted()
        logger.notice("ai recovery: retroactive backfill completed (\(allPages.count) page(s) scanned)")
    }
}

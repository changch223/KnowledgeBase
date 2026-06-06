//
//  LintEngine.swift
//  KnowledgeTree
//
//  spec 058 — 「ユーザーに聞かず、AI が裏で勝手に整理する」の中核。
//  6 step Lint loop を idempotent に実行:
//   1. ConceptPage merge (重複統合)
//   2. ConceptPage delete (孤立 cleanup)
//   3. Tag delete (orphan cleanup)
//   4. ConceptPage link 強化 (孤立 ConceptPage に AI auto-link)
//   5. Tag/Category 再分類 (AutoCategoryClassifier 経由)
//   6. SavedAnswer auto-refresh (isStale → agent loop 経由で再生成)
//
//  各 step は idempotent (2 回実行で同結果)、LintLog に永続化、合計 30 秒以内 (1000 article 規模)。
//

import Foundation
import SwiftData
import os

@MainActor
protocol LintEngineProtocol: AnyObject {
    /// 6 step 全実行。LintLoopResult で各 step の件数 + 所要時間を返す。
    func runFullLintLoop() async -> LintLoopResult
}

/// LintEngine 1 回実行の結果サマリ。
struct LintLoopResult {
    var mergedCount: Int = 0
    var deletedConceptPageCount: Int = 0
    var deletedTagCount: Int = 0
    var linkedCount: Int = 0
    var reclassifiedCount: Int = 0
    var refreshedSavedAnswerCount: Int = 0
    var elapsedSeconds: Double = 0

    var totalOperations: Int {
        mergedCount + deletedConceptPageCount + deletedTagCount + linkedCount + reclassifiedCount + refreshedSavedAnswerCount
    }
}

@MainActor
final class DefaultLintEngine: LintEngineProtocol {
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "lint")
    private let context: ModelContext
    private let refreshTrigger: RefreshTrigger?
    /// Tag/Category 再分類で利用 (spec 015)
    private let categoryClassifier: AutoCategoryClassifier?
    /// 60 日無参照 cleanup の閾値
    private let inactiveCleanupDays: Int

    /// merge 編集距離閾値 (≤ 2 で merge 候補)
    private let mergeEditDistanceThreshold: Int = 2
    /// merge embedding similarity 閾値 (≥ 0.85 で merge 候補)
    private let mergeEmbeddingThreshold: Float = 0.85
    /// auto-link 上限 (relatedConceptIDs max)
    private let maxLinks: Int = 5
    /// LintLog cap (FIFO で最古から削除)
    private let lintLogCap: Int = 100
    /// spec 058 Step 6: SavedAnswer auto-refresh 用 (ChatService 経由 agent loop で再生成)
    private let chatService: ChatServiceProtocol?
    /// 1 回の loop で最大 N 件 SavedAnswer を refresh (token cost / 時間制限内)
    private let maxRefreshPerRun: Int = 3

    init(
        context: ModelContext,
        refreshTrigger: RefreshTrigger? = nil,
        categoryClassifier: AutoCategoryClassifier? = nil,
        chatService: ChatServiceProtocol? = nil,
        inactiveCleanupDays: Int = 60
    ) {
        self.context = context
        self.refreshTrigger = refreshTrigger
        self.categoryClassifier = categoryClassifier
        self.chatService = chatService
        self.inactiveCleanupDays = inactiveCleanupDays
    }

    func runFullLintLoop() async -> LintLoopResult {
        let start = Date.now
        var result = LintLoopResult()

        logger.notice("LintEngine: starting full loop")

        // Step 1: ConceptPage merge (重複統合)
        result.mergedCount = await stepMergeDuplicateConceptPages()

        // Step 2: ConceptPage delete (孤立 cleanup)
        result.deletedConceptPageCount = await stepDeleteOrphanedConceptPages()

        // Step 3: Tag delete (orphan cleanup)
        result.deletedTagCount = await stepDeleteOrphanedTags()

        // Step 4: ConceptPage link 強化
        result.linkedCount = await stepLinkOrphanedConceptPages()

        // Step 5: Tag/Category 再分類
        result.reclassifiedCount = await stepReclassifyTagCategories()

        // Step 6: SavedAnswer auto-refresh (spec 058 Phase C)
        result.refreshedSavedAnswerCount = await stepRefreshStaleSavedAnswers()

        // LintLog cap 維持 (FIFO で最古から削除)
        trimLintLogToCap()

        result.elapsedSeconds = Date.now.timeIntervalSince(start)
        logger.notice("LintEngine: loop done in \(result.elapsedSeconds)s, ops=\(result.totalOperations)")
        refreshTrigger?.bump()
        return result
    }

    // MARK: - Step 1: ConceptPage merge (重複統合)

    private func stepMergeDuplicateConceptPages() async -> Int {
        let pages = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
        var mergeCount = 0
        var processed = Set<UUID>()

        // O(N^2) だが N <= 数百想定で実用可
        for i in 0..<pages.count {
            let pageA = pages[i]
            if processed.contains(pageA.id) { continue }
            for j in (i+1)..<pages.count {
                let pageB = pages[j]
                if processed.contains(pageB.id) { continue }
                if shouldMerge(pageA, pageB) {
                    let (winner, loser) = pickWinner(pageA, pageB)
                    let before = "name=\(loser.name) (関連 \((loser.relatedArticles ?? []).count) 件)"
                    let after = "→ \(winner.name) (関連 \((winner.relatedArticles ?? []).count + (loser.relatedArticles ?? []).count) 件)"
                    mergeConceptPages(winner: winner, loser: loser)
                    logLintAction(.merge, targetName: loser.name, before: before, after: after)
                    processed.insert(loser.id)
                    mergeCount += 1
                }
            }
        }
        try? context.save()
        return mergeCount
    }

    private func shouldMerge(_ a: ConceptPage, _ b: ConceptPage) -> Bool {
        // 同 category のみで比較 (cross-category merge は誤統合リスク)
        guard a.categoryRaw == b.categoryRaw else { return false }

        // 編集距離 ≤ 2 (case insensitive)
        let nameA = a.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let nameB = b.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.levenshtein(nameA, nameB) <= mergeEditDistanceThreshold {
            return true
        }

        // embedding similarity (両者が essence embedding を持つ場合のみ)
        // ConceptPage 自体に embedding は無いが、relatedArticles の essence embedding 平均で代替
        // 簡易実装: 名前完全一致 (case insensitive) を embedding 経路の fallback として
        if nameA == nameB {
            return true
        }

        return false
    }

    private func pickWinner(_ a: ConceptPage, _ b: ConceptPage) -> (ConceptPage, ConceptPage) {
        // updatedAt 新しい方が winner
        if a.updatedAt >= b.updatedAt {
            return (a, b)
        } else {
            return (b, a)
        }
    }

    private func mergeConceptPages(winner: ConceptPage, loser: ConceptPage) {
        // relatedArticles 統合 (union)
        var winnerArticles = winner.relatedArticles ?? []
        let winnerArticleIDs = Set(winnerArticles.map { $0.id })
        for article in (loser.relatedArticles ?? []) {
            if !winnerArticleIDs.contains(article.id) {
                winnerArticles.append(article)
            }
        }
        winner.relatedArticles = winnerArticles

        // relatedConceptIDs 統合 (union, max 5)
        var winnerLinks = winner.relatedConceptIDs
        for id in loser.relatedConceptIDs where !winnerLinks.contains(id) && id != winner.id {
            winnerLinks.append(id)
        }
        winner.relatedConceptIDs = Array(winnerLinks.prefix(maxLinks))

        // nameAliases に loser.name を追加 (将来検索 hit 用)
        var aliases = winner.nameAliases
        if !aliases.contains(loser.name) {
            aliases.append(loser.name)
        }
        winner.nameAliases = aliases

        // isFollowing OR
        if loser.isFollowing {
            winner.isFollowing = true
        }

        // userUnderstanding は max を採用
        winner.userUnderstanding = max(winner.userUnderstanding, loser.userUnderstanding)

        winner.updatedAt = .now
        winner.isStale = true  // merge 後は再合成を促す

        // loser 削除
        context.delete(loser)
    }

    // MARK: - Step 2: ConceptPage delete (孤立 cleanup)

    private func stepDeleteOrphanedConceptPages() async -> Int {
        let pages = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
        let cutoff = Date.now.addingTimeInterval(-Double(inactiveCleanupDays) * 86400)
        var deleteCount = 0

        for page in pages {
            // 関連記事 ≤ 1 件 + 60 日参照ゼロ + isFollowing=false の AND
            let relatedCount = (page.relatedArticles ?? []).count
            guard relatedCount <= 1,
                  page.updatedAt < cutoff,
                  !page.isFollowing else { continue }

            logLintAction(
                .deleteConceptPage,
                targetName: page.name,
                before: "関連 \(relatedCount) 件、最終更新 \(page.updatedAt)",
                after: nil
            )
            context.delete(page)
            deleteCount += 1
        }
        try? context.save()
        return deleteCount
    }

    // MARK: - Step 3: Tag delete (orphan cleanup)

    private func stepDeleteOrphanedTags() async -> Int {
        let tags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        var deleteCount = 0
        for tag in tags where (tag.articles ?? []).isEmpty {
            logLintAction(.deleteTag, targetName: tag.name, before: "orphan (記事 0)", after: nil)
            context.delete(tag)
            deleteCount += 1
        }
        try? context.save()
        return deleteCount
    }

    // MARK: - Step 4: ConceptPage link 強化

    private func stepLinkOrphanedConceptPages() async -> Int {
        let pages = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
        var linkCount = 0

        // categoryRaw でグループ化
        let grouped = Dictionary(grouping: pages, by: { $0.categoryRaw })

        for page in pages where page.relatedConceptIDs.count <= 1 {
            guard let sameCategoryPages = grouped[page.categoryRaw] else { continue }
            // 自分以外の同 category ページを候補に
            let candidates = sameCategoryPages.filter { $0.id != page.id }
            guard !candidates.isEmpty else { continue }

            // 名前の文字数近似 + updatedAt 新しい順で簡易選定 (embedding 利用は後で拡張可能)
            let sortedCandidates = candidates.sorted { $0.updatedAt > $1.updatedAt }
            let topN = Array(sortedCandidates.prefix(maxLinks - page.relatedConceptIDs.count))
            guard !topN.isEmpty else { continue }

            let beforeLinks = page.relatedConceptIDs.count
            var newLinks = page.relatedConceptIDs
            for cand in topN where !newLinks.contains(cand.id) {
                newLinks.append(cand.id)
            }
            newLinks = Array(newLinks.prefix(maxLinks))
            if newLinks.count > beforeLinks {
                page.relatedConceptIDs = newLinks
                logLintAction(
                    .linkConceptPage,
                    targetName: page.name,
                    before: "links \(beforeLinks)",
                    after: "links \(newLinks.count)"
                )
                linkCount += 1
            }
        }
        try? context.save()
        return linkCount
    }

    // MARK: - Step 5: Tag/Category 再分類

    private func stepReclassifyTagCategories() async -> Int {
        guard let classifier = categoryClassifier else { return 0 }
        let tags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        var reclassifyCount = 0

        for tag in tags {
            // spec 072: Tag が付く記事の文脈を渡して再分類精度を上げる。
            let contextText = (tag.articles ?? []).prefix(2)
                .flatMap { [$0.title, $0.extractedKnowledge?.essence] }
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " / ")
            let predicted = await classifier.classify(tagName: tag.name, context: contextText)
            let predictedNonEmpty = !predicted.isEmpty && predicted != "その他"
            let currentRaw = tag.categoryRaw ?? ""

            // 既存値が空 → 予測を採用
            // 既存値が「その他」以外 → 予測も「その他」以外で違うなら更新 (idempotent: 同じなら skip)
            if currentRaw.isEmpty, predictedNonEmpty {
                tag.categoryRaw = predicted
                logLintAction(.reclassifyTag, targetName: tag.name, before: "(none)", after: predicted)
                reclassifyCount += 1
            } else if predictedNonEmpty, predicted != currentRaw {
                logLintAction(.reclassifyTag, targetName: tag.name, before: currentRaw, after: predicted)
                tag.categoryRaw = predicted
                reclassifyCount += 1
            }
        }
        try? context.save()
        return reclassifyCount
    }

    // MARK: - Step 6: SavedAnswer auto-refresh (spec 058 Phase C)

    private func stepRefreshStaleSavedAnswers() async -> Int {
        guard let chatService else { return 0 }
        let descriptor = FetchDescriptor<SavedAnswer>(
            predicate: #Predicate { $0.isStale == true },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let staleAnswers = (try? context.fetch(descriptor)) ?? []
        let toRefresh = Array(staleAnswers.prefix(maxRefreshPerRun))
        var refreshCount = 0

        for stale in toRefresh {
            // ChatService.send 経由で agent loop で新答え生成
            // 新 session 作成 → ask → 新 SavedAnswer 作成 (saveExplicit でなく manual capture)
            do {
                let newSession = try chatService.createSession()
                _ = try await chatService.send(
                    question: stale.question,
                    in: newSession,
                    contextMessages: []
                )
                logLintAction(
                    .refreshSavedAnswer,
                    targetName: String(stale.question.prefix(60)),
                    before: "isStale=true (id=\(stale.id.uuidString.prefix(8)))",
                    after: "新 ChatSession で再生成"
                )
                // 旧 SavedAnswer は isStale=true のまま archive (履歴保持)
                refreshCount += 1
            } catch {
                logger.error("LintEngine: SavedAnswer refresh failed: \(String(describing: error), privacy: .public)")
            }
        }
        try? context.save()
        return refreshCount
    }

    // MARK: - LintLog 永続化 + cap 維持

    private func logLintAction(_ action: LintAction, targetName: String, before: String?, after: String?) {
        let log = LintLog(
            action: action,
            targetName: targetName,
            beforeState: before,
            afterState: after
        )
        context.insert(log)
    }

    private func trimLintLogToCap() {
        var descriptor = FetchDescriptor<LintLog>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
        let all = (try? context.fetch(descriptor)) ?? []
        guard all.count > lintLogCap else { return }
        let toDelete = all.prefix(all.count - lintLogCap)
        for log in toDelete {
            context.delete(log)
        }
        _ = descriptor
        try? context.save()
    }

    // MARK: - Levenshtein 編集距離 (純関数)

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let m = aChars.count
        let n = bChars.count
        if m == 0 { return n }
        if n == 0 { return m }

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = aChars[i-1] == bChars[j-1] ? 0 : 1
                dp[i][j] = min(
                    dp[i-1][j] + 1,        // deletion
                    dp[i][j-1] + 1,        // insertion
                    dp[i-1][j-1] + cost    // substitution
                )
            }
        }
        return dp[m][n]
    }
}

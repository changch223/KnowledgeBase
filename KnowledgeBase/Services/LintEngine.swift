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
    /// 1 周 (全タグ) を完走するまで batch を回す。週 1 BGTask / ボタン「今すぐ整理」用。
    /// resumable: 途中で中断されても、次回呼び出しは前回の続き (未処理タグ) から再開する。
    func runFullLintLoop() async -> LintLoopResult

    /// spec 076: 1 バッチだけ進める (起動時の軽い整理 / ボタンの逐次反映用)。
    /// 新周回なら速い step1-4 を 1 回実行 + 周回マーカー設定。step5 は lastLintedAt 古い順 maxTags 件。
    func runBatch(maxTags: Int) async -> LintLoopResult
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
    /// spec 076: この batch で 1 周 (全タグ) を完走したか。
    var loopComplete: Bool = false
    /// spec 076: 今周回でまだ整理していないタグ数 (進捗表示用、batch 後の残り)。
    var remainingTags: Int = 0

    var totalOperations: Int {
        mergedCount + deletedConceptPageCount + deletedTagCount + linkedCount + reclassifiedCount + refreshedSavedAnswerCount
    }
}

// MARK: - spec 076: 周回マーカー (resumable 整理ループ用)

/// 「今の整理周回の開始日時」を保持。Tag.lastLintedAt がこれより古い/nil なら今周回の未処理。
/// 周回完了で nil に戻し、次 batch が新周回を開始する。
@MainActor
protocol LintLoopMarkerStoring: AnyObject {
    var loopStartedAt: Date? { get set }
}

/// UserDefaults 永続化 (アプリ再起動を跨いで周回を継続)。
@MainActor
final class UserDefaultsLintLoopMarker: LintLoopMarkerStoring {
    private let key = "lint.loopStartedAt.v1"
    private let defaults: UserDefaults
    nonisolated init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    var loopStartedAt: Date? {
        get { defaults.object(forKey: key) as? Date }
        set {
            if let newValue { defaults.set(newValue, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
    }
}

/// テスト用 in-memory マーカー。
@MainActor
final class InMemoryLintLoopMarker: LintLoopMarkerStoring {
    var loopStartedAt: Date?
    init(loopStartedAt: Date? = nil) { self.loopStartedAt = loopStartedAt }
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
    /// spec 078: merge embedding similarity 閾値 (同 kind + 同 category で cosine ≥ これ なら意味的重複として統合)
    private let mergeEmbeddingThreshold: Float = 0.88
    /// auto-link 上限 (relatedConceptIDs max)
    private let maxLinks: Int = 5
    /// LintLog cap (FIFO で最古から削除)
    private let lintLogCap: Int = 100
    /// spec 058 Step 6: SavedAnswer auto-refresh 用 (ChatService 経由 agent loop で再生成)
    private let chatService: ChatServiceProtocol?
    /// 1 回の loop で最大 N 件 SavedAnswer を refresh (token cost / 時間制限内)
    private let maxRefreshPerRun: Int = 3
    /// spec 076: 周回マーカー (resumable)
    private let loopMarker: LintLoopMarkerStoring
    /// spec 076: 1 batch で再分類するタグ数の既定
    private let defaultBatchSize: Int
    /// spec 077: 新カテゴリ昇格の AI 命名用 (nil でステップ skip)
    private let session: LanguageModelSessionProtocol?
    /// spec 077: 動的カテゴリ追加用レジストリ (nil でステップ skip)
    private let categoryRegistry: CategoryRegistry?
    /// spec 077: 昇格クラスタの最小件数 (これ未満は昇格しない)
    private let promoteMinClusterSize: Int = 5
    /// spec 077: 昇格クラスタの cosine 類似度しきい値
    private let promoteClusterThreshold: Float = 0.55

    init(
        context: ModelContext,
        refreshTrigger: RefreshTrigger? = nil,
        categoryClassifier: AutoCategoryClassifier? = nil,
        chatService: ChatServiceProtocol? = nil,
        inactiveCleanupDays: Int = 60,
        loopMarker: LintLoopMarkerStoring = UserDefaultsLintLoopMarker(),
        defaultBatchSize: Int = 15,
        session: LanguageModelSessionProtocol? = nil,
        categoryRegistry: CategoryRegistry? = nil,
        correctionStore: CategoryCorrectionStore? = nil
    ) {
        self.context = context
        self.refreshTrigger = refreshTrigger
        self.categoryClassifier = categoryClassifier
        self.chatService = chatService
        self.inactiveCleanupDays = inactiveCleanupDays
        self.loopMarker = loopMarker
        self.defaultBatchSize = defaultBatchSize
        self.session = session
        self.categoryRegistry = categoryRegistry
        self.correctionStore = correctionStore
    }

    /// spec 097 Phase 2: 学習ストア (ユーザー修正の few-shot 供給)。nil で例なし (Phase 1 相当)。
    private let correctionStore: CategoryCorrectionStore?

    /// 1 周完走するまで batch を回す。resumable (中断後は続きから)。週1 BGTask / ボタン用。
    func runFullLintLoop() async -> LintLoopResult {
        let start = Date.now
        var total = LintLoopResult()
        logger.notice("LintEngine: starting full loop (resumable batches)")

        var guardCount = 0
        while true {
            if Task.isCancelled { break }
            let batch = await runBatch(maxTags: defaultBatchSize)
            total.mergedCount += batch.mergedCount
            total.deletedConceptPageCount += batch.deletedConceptPageCount
            total.deletedTagCount += batch.deletedTagCount
            total.linkedCount += batch.linkedCount
            total.reclassifiedCount += batch.reclassifiedCount
            total.refreshedSavedAnswerCount += batch.refreshedSavedAnswerCount
            total.remainingTags = batch.remainingTags
            guardCount += 1
            if batch.loopComplete { total.loopComplete = true; break }
            if guardCount > 1000 { break }  // 暴走 backstop
        }

        total.elapsedSeconds = Date.now.timeIntervalSince(start)
        logger.notice("LintEngine: full loop done in \(total.elapsedSeconds)s, ops=\(total.totalOperations), complete=\(total.loopComplete)")
        return total
    }

    /// spec 076: 1 batch だけ進める。新周回なら速い step1-4 + マーカー設定、step5 を古い順 maxTags 件。
    /// remainingTags=0 で 1 周完走 → マーカー clear (次 batch が新周回)。
    func runBatch(maxTags: Int) async -> LintLoopResult {
        let start = Date.now
        var result = LintLoopResult()

        // 新周回の開始: マーカー未設定なら今を開始時刻に + 速い純DB step を 1 回だけ回す。
        let isNewLoop = (loopMarker.loopStartedAt == nil)
        if isNewLoop {
            loopMarker.loopStartedAt = .now
            logger.notice("LintEngine: new lint loop started")
            result.mergedCount = await stepMergeDuplicateConceptPages()
            result.deletedConceptPageCount = await stepDeleteOrphanedConceptPages()
            result.deletedTagCount = await stepDeleteOrphanedTags()
            result.linkedCount = await stepLinkOrphanedConceptPages()
            // i18n Phase B: 言語切替で CategoryRegistry に残った foreign シード名の categoryRaw を
            // 現在言語へ heal (「テクノロジー」と「科技」が別分野として並ぶバグの修正)。
            await stepHealCategoryLanguage()
            // spec 077: その他 概念の凝集クラスタを 1 つ新カテゴリに昇格 (週1 + 整理ボタンの新周回で 1 回)
            await stepPromoteCategories()
        }
        let loopStart = loopMarker.loopStartedAt ?? .now

        // Step 5 (batched): lastLintedAt が nil or < loopStart のタグを古い順 maxTags 件
        let (reclassified, remaining) = await reclassifyTagBatch(maxTags: maxTags, loopStart: loopStart)
        result.reclassifiedCount = reclassified
        result.remainingTags = remaining

        // Step 6: SavedAnswer auto-refresh (周回中に少しずつ、既存 cap)
        result.refreshedSavedAnswerCount = await stepRefreshStaleSavedAnswers()

        // 1 周完走: マーカーを clear → 次 batch が新周回を始める (NEVER STOP)
        if remaining == 0 {
            loopMarker.loopStartedAt = nil
            result.loopComplete = true
            trimLintLogToCap()
            logger.notice("LintEngine: lint loop complete (全タグ整理済)")
        }

        result.elapsedSeconds = Date.now.timeIntervalSince(start)
        refreshTrigger?.bump()  // 各 batch で UI 反映
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
            var pageADeleted = false
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
                    // pageA が loser として削除された場合、内側ループを抜ける。
                    // 削除済みオブジェクトに続けてアクセスすると "backing data detached" クラッシュになる。
                    if loser.id == pageA.id {
                        pageADeleted = true
                        break
                    }
                }
            }
            if pageADeleted { continue }
        }
        try? context.save()
        return mergeCount
    }

    private func shouldMerge(_ a: ConceptPage, _ b: ConceptPage) -> Bool {
        // 同 category のみで比較 (cross-category merge は誤統合リスク)
        guard a.categoryRaw == b.categoryRaw else { return false }

        // spec 078: canonical 名 (全角半角/かな/case/空白 正規化) で語彙的近接を判定。
        // 完全一致 (表記ゆれ含む) + 編集距離 ≤ 2 (OpenAI/Open AI 等)。
        let nameA = ConceptNameNormalizer.canonical(a.name)
        let nameB = ConceptNameNormalizer.canonical(b.name)
        if nameA == nameB { return true }
        if Self.levenshtein(nameA, nameB) <= mergeEditDistanceThreshold {
            return true
        }

        // spec 078: 意味的重複 (Apple/Apple Inc、生成AI/LLM 等、語は違うが同じもの) を embedding で統合。
        // 過剰統合ガード: 同 kind (人物/概念/プロジェクト) + 両者 embedding 有り + 次元一致 +
        // cosine ≥ mergeEmbeddingThreshold(0.88) のときだけ。embedding nil (未合成) はスキップ → 合成後の周回で再評価。
        if a.kind == b.kind,
           let da = a.embedding?.asFloatArray, let db = b.embedding?.asFloatArray,
           !da.isEmpty, da.count == db.count,
           EmbeddingService.cosineSimilarity(da, db) >= mergeEmbeddingThreshold {
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

    // MARK: - i18n Phase B: 言語混在バグの heal (「テクノロジー」/「科技」が別分野に割れる問題の修正)

    /// foreign シード名 (`CategorySeed.foreignSeedNames(excluding:)`) → 現在言語の対応シード名。
    /// `CategorySeed.allSeeds(for:)` は全言語で同数 (10)・同順 (index == order) の前提で、
    /// index 対応で張り替え先を決める。マッチしない名前は含まれない。純関数、テスト容易。
    static func categoryLanguageHealMapping(currentLanguage: PipelineLanguage) -> [String: String] {
        let foreignNames = CategorySeed.foreignSeedNames(excluding: currentLanguage)
        guard !foreignNames.isEmpty else { return [:] }
        let localSeeds = CategorySeed.allSeeds(for: currentLanguage)
        var mapping: [String: String] = [:]
        for language in PipelineLanguage.allCases where language != currentLanguage {
            let seeds = CategorySeed.allSeeds(for: language)
            for (index, seed) in seeds.enumerated() where foreignNames.contains(seed.name) {
                guard index < localSeeds.count else { continue }
                mapping[seed.name] = localSeeds[index].name
            }
        }
        return mapping
    }

    /// 端末の言語切替 (ja ⇔ zh) で Tag.categoryRaw / ConceptPage.categoryRaw に前の言語の seed 名が
    /// 残った状態 (例: 「テクノロジー」と「科技」が別分野として並ぶ) を修復する。
    /// 対象の Tag / ConceptPage の categoryRaw を index 対応で現在言語の名前に張り替える。
    ///
    /// CategoryDefinition (レジストリ側の定義行) は一切変更しない。`CategoryRegistry.activeCategories()`
    /// が現在言語に対して foreign な **seed** 定義を読み出し時に動的除外するため、レジストリ側の非表示化は
    /// 不要 (かつ言語を再度切り替えても un-hide する経路が無く、候補が言語往復のたびに欠落していくバグの
    /// 原因だった)。ユーザーの手動非表示 (spec 075) と衝突する非可逆な副作用も避けられる。
    private func stepHealCategoryLanguage() async {
        let mapping = Self.categoryLanguageHealMapping(currentLanguage: .current)
        guard !mapping.isEmpty else { return }

        // spec heal-fix Minor 2: foreign シード名を持つ CategoryDefinition が registry に
        // 1 件も無ければ heal 対象は存在しない → Tag/ConceptPage の全件 fetch を回避する
        // (純 ja 端末で言語切替を経験していない場合、定義 fetch 1 回だけで終わる)。
        let defs = (try? context.fetch(FetchDescriptor<CategoryDefinition>())) ?? []
        guard defs.contains(where: { mapping.keys.contains($0.name) }) else { return }

        var healedCount = 0

        let tags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        for tag in tags {
            guard let raw = tag.categoryRaw, let localized = mapping[raw] else { continue }
            logLintAction(.healCategoryLanguage, targetName: tag.name, before: raw, after: localized)
            tag.categoryRaw = localized
            healedCount += 1
        }

        let pages = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
        for page in pages {
            guard let localized = mapping[page.categoryRaw] else { continue }
            logLintAction(.healCategoryLanguage, targetName: page.name, before: page.categoryRaw, after: localized)
            page.categoryRaw = localized
            healedCount += 1
        }

        guard healedCount > 0 else { return }
        try? context.save()
        logger.notice("LintEngine: healed \(healedCount, privacy: .public) category-language mismatches")
    }

    // MARK: - Step 5: Tag/Category 再分類

    /// spec 076: 今周回の未処理タグ (lastLintedAt が nil or < loopStart) を古い順 maxTags 件だけ再分類。
    /// 戻り値: (今回再分類で変化した件数, この batch 後に残っている未処理タグ数)。
    private func reclassifyTagBatch(maxTags: Int, loopStart: Date) async -> (reclassified: Int, remaining: Int) {
        guard let classifier = categoryClassifier else { return (0, 0) }
        let allTags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []

        // 今周回の未処理 = lastLintedAt が nil または loopStart より前
        // spec 097 Phase 2: 確信度が低い (Low/Medium) or その他 のタグを優先して再訪する
        // (精度向上ループ: 不確実なものから直す)。同優先度内は lastLintedAt 古い順。
        let other = CategorySeed.otherCategory.name
        func isUncertain(_ t: Tag) -> Bool {
            let conf = t.categoryConfidence
            return conf == ClassificationConfidence.low.rawValue
                || conf == ClassificationConfidence.medium.rawValue
                || (t.categoryRaw ?? "") == other
        }
        let pending = allTags
            .filter { ($0.lastLintedAt ?? .distantPast) < loopStart }
            .sorted { a, b in
                let ua = isUncertain(a), ub = isUncertain(b)
                if ua != ub { return ua }  // 不確実を先に
                return (a.lastLintedAt ?? .distantPast) < (b.lastLintedAt ?? .distantPast)
            }
        let batch = Array(pending.prefix(maxTags))
        var reclassifyCount = 0

        for tag in batch {
            // spec 072: Tag が付く記事の文脈を渡して再分類精度を上げる。
            let contextText = (tag.articles ?? []).prefix(2)
                .flatMap { [$0.title, $0.extractedKnowledge?.essence] }
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " / ")
            // spec 097 Phase 2: 学習例 (ユーザー修正) を few-shot として渡し、第2段の再分類精度を上げる。
            let examples = correctionStore?.fewShot(for: tag.name) ?? []
            let result = await classifier.classifyDetailed(tagName: tag.name, context: contextText, examples: examples)
            let predicted = result.category
            let predictedNonEmpty = !predicted.isEmpty && predicted != "その他"
            let currentRaw = tag.categoryRaw ?? ""

            if currentRaw.isEmpty, predictedNonEmpty {
                tag.categoryRaw = predicted
                tag.categoryConfidence = result.confidence.rawValue
                logLintAction(.reclassifyTag, targetName: tag.name, before: "(none)", after: predicted)
                reclassifyCount += 1
            } else if predictedNonEmpty, predicted != currentRaw {
                logLintAction(.reclassifyTag, targetName: tag.name, before: currentRaw, after: predicted)
                tag.categoryRaw = predicted
                tag.categoryConfidence = result.confidence.rawValue
                reclassifyCount += 1
            } else {
                // 分類が変わらなくても確信度は更新 (Low/Medium の再訪対象判定に使う)。
                tag.categoryConfidence = result.confidence.rawValue
            }
            // 分類が変わらなくても「処理済」マーク (周回が前進する)。
            tag.lastLintedAt = .now
        }
        try? context.save()

        // spec 077: 再分類でカテゴリが確定したタグに紐づく [その他] 概念を再ヒール (AI 不要)。
        // → 「今すぐ整理」で再分類だけでなく概念カテゴリも実カテゴリに直る。
        for tag in batch {
            ConceptSynthesisCommon.healConcepts(forTag: tag, context: context, refreshTrigger: refreshTrigger)
        }

        let remaining = max(0, pending.count - batch.count)
        return (reclassifyCount, remaining)
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

    // MARK: - spec 077: 新カテゴリ自動昇格 (その他 クラスタ → AI 命名 → 動的追加 → 再割当)

    /// `その他` 概念を embedding で貪欲クラスタリングし、最大クラスタが minClusterSize 以上なら
    /// generateTopicName で命名 → CategoryRegistry に動的追加 → クラスタ概念 + その その他/空タグを新名へ。
    /// 1 周回 (= 1 整理) で最大 1 昇格。session/registry が nil、availability/失敗時は skip (graceful)。
    private func stepPromoteCategories() async {
        guard let session, let categoryRegistry else { return }
        let other = CategorySeed.otherCategory.name

        // その他 かつ embedding 有りの ConceptPage (非表示除外)
        let vectors: [(page: ConceptPage, vec: [Float])] = ((try? context.fetch(FetchDescriptor<ConceptPage>())) ?? [])
            .filter { !$0.isHidden && $0.categoryRaw == other }
            .compactMap { page in
                guard let v = page.embedding?.asFloatArray, !v.isEmpty else { return nil }
                return (page, v)
            }
        guard vectors.count >= promoteMinClusterSize else { return }

        // 貪欲クラスタリング: 各 seed 中心に threshold 以上を集め、最大クラスタを採用。
        var best: [(page: ConceptPage, vec: [Float])] = []
        for seed in vectors {
            let cluster = vectors.filter {
                $0.vec.count == seed.vec.count
                    && EmbeddingService.cosineSimilarity(seed.vec, $0.vec) >= promoteClusterThreshold
            }
            if cluster.count > best.count { best = cluster }
        }
        guard best.count >= promoteMinClusterSize else { return }

        // AI 命名 (generateTopicName 流用、小出力 = token 安全)
        // i18n Phase B: 出力言語 + 既存カテゴリー一覧・例語は PipelineLanguage.current に追従する。
        let language = PipelineLanguage.current
        let existingCategoryNames = (categoryRegistry.activeCategories()?.map(\.name) ?? CategorySeed.allSeeds.map(\.name))
            .joined(separator: " / ")
        let domainExampleHint: String
        switch language {
        case .ja: domainExampleHint = "不動産, 法律, 料理"
        case .zhHans: domainExampleHint = "房地产, 法律, 烹饪"
        case .zhHant: domainExampleHint = "不動產, 法律, 烹飪"
        }
        let memberNames = best.map { $0.page.name }
        let prompt = """
            次の概念グループに共通する「分野・カテゴリー名」を 1 つ、2〜6 字の短い\(language.endonym)で命名してください。
            具体的すぎず、分野レベルの名詞にすること (例: \(domainExampleHint))。
            既存カテゴリー (\(existingCategoryNames)) と同じものは避けてください。

            # 概念グループ
            \(memberNames.prefix(12).joined(separator: "、"))
            """
        let candidateName: String
        do {
            let out = try await session.generateTopicName(prompt: prompt)
            candidateName = out.name.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            logger.error("LintEngine: category naming failed: \(String(describing: error), privacy: .public)")
            return
        }
        guard !candidateName.isEmpty, candidateName != other,
              !categoryRegistry.categoryExists(name: candidateName) else { return }

        // 動的追加 (idempotent)
        let definition = "自動検出された分野。例: " + memberNames.prefix(4).joined(separator: ", ")
        guard categoryRegistry.insertCategory(name: candidateName, definition: definition) else { return }

        // クラスタ概念 + その記事の その他/空タグを新カテゴリへ (concept だけ移すと heal で その他 に戻るため tag も移す)
        for member in best {
            member.page.categoryRaw = candidateName
            for article in (member.page.relatedArticles ?? []) {
                for tag in (article.tags ?? []) {
                    let raw = tag.categoryRaw ?? ""
                    if raw.isEmpty || raw == other { tag.categoryRaw = candidateName }
                }
            }
        }
        try? context.save()
        logLintAction(
            .promoteCategory,
            targetName: candidateName,
            before: "その他 クラスタ \(best.count) 概念",
            after: "新カテゴリ『\(candidateName)』に昇格"
        )
        refreshTrigger?.bump()
        logger.notice("LintEngine: promoted category '\(candidateName, privacy: .public)' from \(best.count) その他 concepts")
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

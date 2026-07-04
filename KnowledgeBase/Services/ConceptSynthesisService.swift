//
//  ConceptSynthesisService.swift
//  KnowledgeTree
//
//  spec 042 — ConceptPage の自動生成 / 再合成パイプライン。
//
//  - protocol ConceptSynthesisServiceProtocol — KnowledgeExtractionService 経由 + BGTask 経由で呼ばれる
//  - FoundationModelsConceptSynthesisService — Apple Foundation Models 経由、4 件以下 = 1-shot、
//    5+ 件 = hierarchical (chunk_size=4) + meta-summary
//  - FallbackConceptSynthesisService — Apple Intelligence 不可時の essence 並べ簡易
//
//  Service は throw しない (silent fail + Logger)。calm UX (Constitution V) 原則。
//
//  contracts/concept-synthesis-service.md 準拠。
//

import Foundation
import SwiftData
import os

// MARK: - 概念合成の直列化ゲート (再入安全)

/// 概念合成 (ConceptPage の upsert / 再合成) を **プロセス全体で 1 本ずつ直列化**する gate。
///
/// 背景: KnowledgeExtractionService の extract hook は記事ごとに `Task { ingestArticle }` を
/// fire-and-forget する。通常運用では問題ないが、全記事一括再処理 (DebugReprocessButton) で
/// 数十件の hook が同時発火すると、各 Task が共有 ModelContext 上で ConceptPage の
/// fetch / mutate / delete を競合し、"backing data was detached from a context" クラッシュを起こす。
///
/// 対策: 別タスク同士は semaphore(1) で直列化。ただし `ingestArticle → processConceptHierarchy
/// → resynthesizeAllStale → resynthesize → fallback.resynthesize` と同一タスク内で多段再入する
/// ため、`@TaskLocal isHeld` で「既にこのタスクチェーンが gate を保持中」を検知し、再取得を
/// スキップする (= deadlock 回避)。`Task {}` 越しには isHeld は伝播するが、hook は gate の外で
/// 生成されるので各 hook は isHeld=false で開始し、確実に直列化される。
enum ConceptSynthesisGate {
    static let semaphore = AsyncSemaphore(1)

    @TaskLocal static var isHeld = false

    /// gate 配下で `operation` を実行。同一タスクチェーンで既に保持中なら再取得しない。
    @MainActor
    static func run<T>(_ operation: () async -> T) async -> T {
        if isHeld {
            return await operation()
        }
        await semaphore.acquire()
        let result = await $isHeld.withValue(true) {
            await operation()
        }
        await semaphore.release()
        return result
    }
}

// MARK: - Protocol

@MainActor
protocol ConceptSynthesisServiceProtocol: AnyObject {
    /// 新規記事 ingest 時 (KnowledgeExtractionService.extract 末尾) に呼ばれる。
    /// 記事内 entity を見て、2+ Article に同名登場した entity について:
    /// - 既存 ConceptPage あり → isStale = true で再合成予約
    /// - 既存 ConceptPage なし → 新規生成 (isStale = true、relatedArticles に過去 + 今回 = 2 件)
    /// silent fire-and-forget、例外を throw しない。
    func processNewArticle(article: Article) async

    /// spec 074: 記事 ingest の主経路。AI で概念階層を抽出 → processConceptHierarchy。
    /// AI 不可 / 失敗時は entity 共起の従来パス (processNewArticle) に degrade。
    /// KnowledgeExtractionService の hook はこれを呼ぶ。
    func ingestArticle(_ article: Article) async

    /// spec 074: 抽出済みの概念階層 (広い概念 + 具体概念) を ConceptPage に upsert。
    /// broad ページ (level=broad) + specific ページ (level=specific, parent=broad.id) を作成/更新し、
    /// 記事を両者に link、isStale=true → 同セッションで再合成。silent fire-and-forget。
    func processConceptHierarchy(article: Article, hierarchy: ConceptHierarchyOutput) async

    /// 単一 ConceptPage を再合成 (Foundation 経路 or Fallback 経路)。
    func resynthesize(_ conceptPage: ConceptPage) async

    /// 全 stale ConceptPage を順次再合成 (BGTask から呼ばれる、fetchLimit=5)。
    func resynthesizeAllStale() async

    /// 既存全 Article から ConceptPage 群を初期 backfill (UserDefaults flag で 1 回限り)。
    func backfillFromExistingArticles() async
}

// MARK: - Fallback 実装

/// Apple Intelligence 利用不可時の簡易実装。
/// essence を並べた summary + 各 essence 冒頭文を bullet 化した crossSourceInsights を生成。
@MainActor
final class FallbackConceptSynthesisService: ConceptSynthesisServiceProtocol {
    private let context: ModelContext
    private let refreshTrigger: RefreshTrigger?
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "concept-fallback")

    /// V1 リリース後 1 回限り backfill を実行するためのフラグキー。
    static let backfillFlagKey = "ConceptPage.backfillCompleted"

    init(context: ModelContext, refreshTrigger: RefreshTrigger? = nil) {
        self.context = context
        self.refreshTrigger = refreshTrigger
    }

    func processNewArticle(article: Article) async {
        await ConceptSynthesisGate.run {
            ConceptSynthesisCommon.processNewArticle(
                article: article,
                context: context,
                refreshTrigger: refreshTrigger,
                logger: logger
            )
            // spec 042 fix: 同セッション内で summary を生成 (BGTask 待たない)
            // fetchLimit=5 で bounded、Fallback 経路は AI 不使用なので軽量
            await resynthesizeAllStale()
        }
    }

    func processConceptHierarchy(article: Article, hierarchy: ConceptHierarchyOutput) async {
        await ConceptSynthesisGate.run {
            ConceptSynthesisCommon.processConceptHierarchy(
                article: article,
                hierarchy: hierarchy,
                context: context,
                refreshTrigger: refreshTrigger,
                logger: logger
            )
            await resynthesizeAllStale()
        }
    }

    func ingestArticle(_ article: Article) async {
        // Fallback (AI 不可) は階層抽出できないので entity 共起の従来パスに degrade。
        await processNewArticle(article: article)
    }

    func resynthesize(_ conceptPage: ConceptPage) async {
        await ConceptSynthesisGate.run { await self._resynthesize(conceptPage) }
    }

    private func _resynthesize(_ conceptPage: ConceptPage) async {
        let articles = (conceptPage.relatedArticles ?? []).sorted { $0.savedAt > $1.savedAt }
        // ① 自己修復: categoryRaw を relatedArticles から再計算。
        ConceptSynthesisCommon.healCategory(conceptPage, articles: articles)
        let essences = articles.compactMap { $0.extractedKnowledge?.essence }.filter { !$0.isEmpty }

        if essences.isEmpty {
            conceptPage.summary = "「\(conceptPage.name)」に関する保存記事は \(articles.count) 件ありますが、本文要点がまだ整っていません。"
            conceptPage.crossSourceInsights = []
            conceptPage.insightSourceArticleIDs = []
        } else {
            let joined = essences.prefix(3).joined(separator: "\n\n")
            conceptPage.summary = String(joined.prefix(400))
            // spec 089: fallback の要点は各記事の essence 先頭文 → 元記事を直接対応付け (index 整合)。
            let withEssence = articles.filter { !($0.extractedKnowledge?.essence ?? "").isEmpty }
            let pairs: [(insight: String, sourceID: String)] = Array(withEssence.prefix(3)).compactMap { article in
                guard let essence = article.extractedKnowledge?.essence,
                      let firstSentence = essence.split(whereSeparator: { $0 == "。" || $0 == "!" || $0 == "?" }).first
                else { return nil }
                return (String(firstSentence), article.id.uuidString)
            }
            conceptPage.crossSourceInsights = pairs.map { $0.insight }
            conceptPage.insightSourceArticleIDs = pairs.map { $0.sourceID }
        }

        conceptPage.isStale = false
        conceptPage.updatedAt = .now
        try? context.save()
        refreshTrigger?.bump()
    }

    func resynthesizeAllStale() async {
        await ConceptSynthesisGate.run {
            // spec 058 polish: 最新優先 (関連 Article の最新 savedAt で sort)
            // 新しい記事に紐付く概念から先に summary 生成、ユーザーは保存後すぐ概要を見られる。
            let allDescriptor = FetchDescriptor<ConceptPage>(
                predicate: #Predicate { $0.isStale == true }
            )
            guard let allStale = try? context.fetch(allDescriptor), !allStale.isEmpty else { return }

            let sorted = allStale.sorted { lhs, rhs in
                let lhsLatest = (lhs.relatedArticles ?? []).map(\.savedAt).max() ?? .distantPast
                let rhsLatest = (rhs.relatedArticles ?? []).map(\.savedAt).max() ?? .distantPast
                return lhsLatest > rhsLatest
            }
            for page in sorted.prefix(5) {
                // spec 082: チャット応答中は次の概念合成を開始せず待機 (ANE をチャットに最優先で譲る)
                await AIPriorityCoordinator.shared.waitWhileChatActive()
                await _resynthesize(page)
            }
        }
    }

    func backfillFromExistingArticles() async {
        guard !UserDefaults.standard.bool(forKey: Self.backfillFlagKey) else { return }

        let descriptor = FetchDescriptor<Article>(sortBy: [SortDescriptor(\.savedAt)])
        guard let articles = (try? context.fetch(descriptor)), !articles.isEmpty else {
            UserDefaults.standard.set(true, forKey: Self.backfillFlagKey)
            return
        }

        for article in articles {
            await processNewArticle(article: article)
        }
        UserDefaults.standard.set(true, forKey: Self.backfillFlagKey)
    }
}

// MARK: - Foundation Models 実装

@MainActor
final class FoundationModelsConceptSynthesisService: ConceptSynthesisServiceProtocol {
    private let session: LanguageModelSessionProtocol
    private let availability: AvailabilityChecker
    private let fallback: ConceptSynthesisServiceProtocol
    private let embeddingService: EmbeddingService?
    private let context: ModelContext
    private let refreshTrigger: RefreshTrigger?
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "concept")

    /// hierarchical パスに切り替える関連記事数閾値 (3+ 件で chunked パス)。
    /// 実機ログ (2026-05-23) で 4 件 article + 長い essence/KeyFact が 4090 token に達して
    /// Foundation Models の 4096 制限を overflow したため、5→3 に下げて安全側に。
    /// spec 042 brushup で 5 → 3、spec 051 spike で再確認 (維持)。
    /// 3 件以上で hierarchical 経路、各 chunk は chunkSize=1 (1 article ずつ) で安全側に振る。
    static let hierarchicalThreshold = 3
    /// hierarchical の chunk size (research.md R5)。
    /// spec 042 brushup で 4 → 2、spec 051 spike で 2 → 1 に再縮小。
    /// hierarchical 経路 = 1 article ずつ chunk 化 + meta-summary で統合。
    /// @Generable schema + FM overhead で 3000+ tokens 消費するため、user 入力余地 ~1000 tokens に圧縮必須。
    static let chunkSize = 1
    /// 各 article の essence を prompt に含める最大文字数。
    /// 強化 (2026-06-11): 真因は token でなく記事並列のランタイム逼迫と判明 → 直列化で解消。
    /// 実測でプロンプトは窓に余裕 → 80→200 (essence は元々 ~200 字なので全文活用)。
    static let perArticleEssenceMaxChars = 200
    /// 各 article から prompt に含める KeyFact 件数。強化 (2026-06-11): 1→3。
    static let perArticleKeyFactCount = 3
    /// 1 件あたり KeyFact 文字数上限。強化 (2026-06-11): 30→80。
    static let perKeyFactMaxChars = 80
    /// 各 article の title 上限。強化 (2026-06-11): 50→80。
    static let perArticleTitleMaxChars = 80
    /// spec 064 (LLM Wiki): embedding 近傍で relatedConceptIDs に補完する上限。
    static let relatedConceptLimit = 8
    /// spec 064: cosine 類似度の下限 (これ未満は無関係として除外)。
    static let relatedConceptThreshold: Float = 0.5
    /// spec 064: 本文 AI リンク候補の上限。
    static let linkCandidateLimit = 8

    init(
        session: LanguageModelSessionProtocol,
        availability: AvailabilityChecker = SystemLanguageModelAvailabilityChecker(),
        fallback: ConceptSynthesisServiceProtocol,
        embeddingService: EmbeddingService? = nil,
        context: ModelContext,
        refreshTrigger: RefreshTrigger? = nil
    ) {
        self.session = session
        self.availability = availability
        self.fallback = fallback
        self.embeddingService = embeddingService
        self.context = context
        self.refreshTrigger = refreshTrigger
    }

    func processNewArticle(article: Article) async {
        await ConceptSynthesisGate.run {
            // entity スキャン + ConceptPage 生成 / isStale toggle は availability に依存しない (DB 操作のみ)。
            ConceptSynthesisCommon.processNewArticle(
                article: article,
                context: context,
                refreshTrigger: refreshTrigger,
                logger: logger
            )
            // spec 042 fix: 同セッション内で summary を生成 (BGTask 待たない、UI に「整理中…」が残らない)
            // fetchLimit=5 で bounded、availability=false → fallback 経路で軽量 essence 並べ summary
            await resynthesizeAllStale()
        }
    }

    func processConceptHierarchy(article: Article, hierarchy: ConceptHierarchyOutput) async {
        await ConceptSynthesisGate.run {
            // upsert は DB 操作のみで availability 非依存。
            ConceptSynthesisCommon.processConceptHierarchy(
                article: article,
                hierarchy: hierarchy,
                context: context,
                refreshTrigger: refreshTrigger,
                logger: logger
            )
            await resynthesizeAllStale()
        }
    }

    func ingestArticle(_ article: Article) async {
        await ConceptSynthesisGate.run {
            // AI 不可 → entity 共起の従来パスに degrade。
            guard availability.isAvailable else {
                await processNewArticle(article: article)
                return
            }
            do {
                let prompt = buildConceptHierarchyPrompt(article: article)
                let hierarchy = try await session.generateConceptHierarchy(prompt: prompt)
                let broad = hierarchy.broadConcept.trimmingCharacters(in: .whitespacesAndNewlines)
                guard broad.count >= ConceptSynthesisCommon.minEntityNameLength else {
                    // AI が広い概念を出せなかった → 従来パスに degrade
                    logger.notice("concept hierarchy empty broad for article, fallback to entity path")
                    await processNewArticle(article: article)
                    return
                }
                await processConceptHierarchy(article: article, hierarchy: hierarchy)
            } catch {
                logger.error("concept hierarchy extraction failed: \(String(describing: error), privacy: .public)")
                await processNewArticle(article: article)
            }
        }
    }

    /// spec 074: 概念階層抽出 prompt。出力が小さい (broad + ≤4 specific) ので入力に余裕がある
    /// (essence 300 字まで許容、token 安全)。広い概念候補シード + schema ルールを embed。
    private func buildConceptHierarchyPrompt(article: Article) -> String {
        let title = Self.truncate(article.title, max: 80)
        let essence = Self.truncate(article.extractedKnowledge?.essence ?? "", max: 300)
        let keyFacts = (article.extractedKnowledge?.keyFacts ?? [])
            .sorted { $0.order < $1.order }
            .prefix(3)
            .map { Self.truncate($0.statement, max: 60) }
            .joined(separator: "、")
        let categoryRaw = ConceptSynthesisCommon.resolveCategoryRaw(for: article)
        let categoryDisplay = CategorySeed.category(for: categoryRaw).name
        let seedHint = BroadConceptSeed.promptHint(for: categoryRaw)
        let seedBlock = seedHint.isEmpty
            ? ""
            : "\n\n# 広い概念の候補 (この中から最も合うものを優先。無ければ簡潔に命名)\n\(seedHint)"
        let rules = SchemaLoader.shared.section(named: "概念階層抽出ルール") ?? Self.defaultHierarchyRules

        return """
        次の記事を 2 階層の概念に整理してください。
        - 広い概念 (broadConcept): この記事が属する最も広い概念を 1 つ。分野の代表概念。
        - 具体概念 (specificConcepts): その広い概念の下で、この記事が実際に論じている具体トピックを 2〜4 個。

        \(rules)\(seedBlock)

        # 記事
        カテゴリー: \(categoryDisplay)
        タイトル: \(title)
        要点: \(essence)
        事実: \(keyFacts.isEmpty ? "(なし)" : keyFacts)
        """
    }

    /// schema.md 不在時の概念階層抽出ルール (production 安全 fallback)。
    static let defaultHierarchyRules = """
    # ルール
    - 記事に明示されている概念のみ。推測・一般知識での補強は禁止。
    - 広い概念は「生成AI」「データエンジニアリング」のような分野レベルの短い名詞。
    - 具体概念は「Text-to-SQL」「RAG」のような記事が論じる個別トピックの短い名詞。
    - ★体言で書く: 概念名は短い名詞・専門用語のみ。文・説明句・動詞句は禁止。
      NG「顧客企業に深く入り込むエンジニア」「金融機関の共同出資による新会社設立」→ OK「現場常駐エンジニア」「合弁会社」。
    - 一般語・代名詞・地名 (男性 / ユーザー / 企業 / 彼女 / 東京駅 等) は概念にしない。
    - 広い概念と具体概念に同じ名前を入れない。
    """

    func resynthesize(_ conceptPage: ConceptPage) async {
        await ConceptSynthesisGate.run { await self._resynthesize(conceptPage) }
    }

    private func _resynthesize(_ conceptPage: ConceptPage) async {
        guard availability.isAvailable else {
            await fallback.resynthesize(conceptPage)
            return
        }

        let articles = conceptPage.relatedArticles ?? []
        // ① 自己修復: categoryRaw を relatedArticles から再計算 (その他 → 実カテゴリ に直る)。
        ConceptSynthesisCommon.healCategory(conceptPage, articles: articles)
        guard !articles.isEmpty else {
            // 関連記事 0 件 → 何もせず stale 解除 (孤立 ConceptPage、Wikilint で別 spec)
            conceptPage.isStale = false
            conceptPage.updatedAt = .now
            try? context.save()
            refreshTrigger?.bump()
            return
        }

        do {
            logger.notice("concept synthesis start for \(conceptPage.name, privacy: .public) [\(conceptPage.categoryRaw, privacy: .public)]: articles=\(articles.count) hierarchical=\(articles.count >= Self.hierarchicalThreshold)")
            // spec 080拡張: overflow なら 1 回だけ小型スキーマで再試行 (essence-list fallback より良い)。
            let output = try await synthesizeWithAdaptiveRetry(conceptPage: conceptPage, articles: articles)

            // post-process: 500 chars 超 trim、insights 7 件超 truncate
            let trimmedSummary: String
            if output.summary.count > 500 {
                trimmedSummary = String(output.summary.prefix(497)) + "…"
            } else {
                trimmedSummary = output.summary
            }
            // 防御: AI が空 summary を返した時、既存 summary を保持 (再合成失敗で見える内容を消さない)
            let preserveExisting = trimmedSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !conceptPage.summary.isEmpty
            if !preserveExisting {
                conceptPage.summary = trimmedSummary
                conceptPage.crossSourceInsights = Array(output.crossSourceInsights.prefix(5))
                // spec 089: 各要点を最も関連する元記事に照合し出典 ID を保存。
                conceptPage.insightSourceArticleIDs = ConceptSynthesisCommon.matchInsightSources(
                    insights: conceptPage.crossSourceInsights,
                    articles: conceptPage.relatedArticles ?? [],
                    embeddingService: embeddingService
                )
            }

            // embedding 再生成 (summary が更新されたので)
            if let embeddingService, embeddingService.isAvailable,
               !trimmedSummary.isEmpty,
               let vector = embeddingService.embed(trimmedSummary) {
                conceptPage.embedding = vector.asEmbeddingData
            }

            // spec 064 (LLM Wiki): embedding 近傍で relatedConceptIDs を補完 (AI 呼び出しゼロ)。
            // 既存 (LintEngine/merge 由来) と union で保全。bodyMarkdown 生成の前に置き候補を共有。
            let neighborIDs = nearestConceptIDs(for: conceptPage, in: context)
            if !neighborIDs.isEmpty {
                conceptPage.relatedConceptIDs = Array(Set(conceptPage.relatedConceptIDs + neighborIDs))
            }

            // spec 063 (LLM Wiki): kind 自動判定 + bodyMarkdown 生成
            await generateBodyMarkdown(for: conceptPage, articles: articles)

            conceptPage.isStale = false
            conceptPage.updatedAt = .now
            try? context.save()
            refreshTrigger?.bump()
            logger.notice("concept synthesis succeeded for \(conceptPage.name, privacy: .public) [\(conceptPage.categoryRaw, privacy: .public)]: articles=\(articles.count) summaryChars=\(conceptPage.summary.count) insights=\(conceptPage.crossSourceInsights.count) preserved=\(preserveExisting)")
        } catch {
            logger.error("concept synthesis failed for \(conceptPage.name, privacy: .public): \(String(describing: error), privacy: .public)")
            // safety net: Foundation 失敗 (context overflow / ANE error 等) → Fallback service に委譲
            // これで isStale が永遠に true のまま残るループを防ぐ。Fallback は essence 並べた簡易 summary を生成し isStale=false にする
            logger.notice("concept synthesis falling back to essence-list for \(conceptPage.name, privacy: .public)")
            await fallback.resynthesize(conceptPage)
        }
    }

    // MARK: - spec 064 (LLM Wiki) 関係発見 (embedding 近傍)

    /// embedding cosine 類似で近い ConceptPage の id を返す (AI 呼び出しゼロ)。
    /// self / isHidden / embedding なしは除外。threshold 未満は無関係として除外、上限 relatedConceptLimit。
    func nearestConceptIDs(for page: ConceptPage, in context: ModelContext) -> [UUID] {
        guard let data = page.embedding else { return [] }
        let target = data.asFloatArray
        guard !target.isEmpty else { return [] }

        let all: [ConceptPage] = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
        var scored: [(id: UUID, sim: Float)] = []
        for other in all {
            guard other.id != page.id, !other.isHidden, let od = other.embedding else { continue }
            let vec = od.asFloatArray
            guard vec.count == target.count else { continue }
            let sim = EmbeddingService.cosineSimilarity(target, vec)
            if sim >= Self.relatedConceptThreshold {
                scored.append((other.id, sim))
            }
        }
        return scored.sorted { $0.sim > $1.sim }
            .prefix(Self.relatedConceptLimit)
            .map(\.id)
    }

    /// relatedConceptIDs を (name, id) 候補に解決 (本文 AI リンク用)。非表示は除外。
    func resolveLinkCandidates(for page: ConceptPage) -> [(name: String, id: UUID)] {
        guard !page.relatedConceptIDs.isEmpty else { return [] }
        let ids = Set(page.relatedConceptIDs)
        let all: [ConceptPage] = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
        return all
            .filter { ids.contains($0.id) && !$0.isHidden && $0.id != page.id }
            .prefix(Self.linkCandidateLimit)
            .map { (name: $0.name, id: $0.id) }
    }

    // MARK: - spec 063 (LLM Wiki) bodyMarkdown 生成 + kind 判定

    /// Wiki 本文を plain string で生成 (token 超過回避)。kind も自動判定。
    /// ユーザー訂正済 (bodyEditedByUser) は本文生成をスキップして保護する。
    private func generateBodyMarkdown(for conceptPage: ConceptPage, articles: [Article]) async {
        // kind 自動判定 (記事の entity から推定、誤りはユーザーが Picker で訂正可)
        if let inferred = Self.inferKind(from: articles) {
            conceptPage.kind = inferred
        }

        // ユーザーが本文を訂正済なら自動再生成しない (FR-007)
        guard !conceptPage.bodyEditedByUser else { return }

        // Apple Intelligence 不可 → summary を本文に流用 (fallback)
        guard availability.isAvailable else {
            if conceptPage.bodyMarkdown.isEmpty && !conceptPage.summary.isEmpty {
                conceptPage.bodyMarkdown = conceptPage.summary
            }
            return
        }

        // spec 064: relatedConceptIDs (Phase 1 で補完済) を相互リンク候補に解決
        let linkCandidates = resolveLinkCandidates(for: conceptPage)
        let validIDs = Set(linkCandidates.map(\.id))

        let prompt = Self.buildWikiBodyPrompt(
            conceptPage: conceptPage,
            articles: articles,
            linkCandidates: linkCandidates
        )
        do {
            let body = try await session.generateWikiBody(prompt: prompt)
            var trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            // spec 064: 捏造/候補外の concept-id:// リンクをプレーン化 (dead link 防止)
            trimmed = Self.sanitizeConceptLinks(in: trimmed, validIDs: validIDs)
            // spec 079: AI が「関連ページ候補」指示ブロックを本文へ丸写しした漏れ (生 concept-id 等) を除去
            trimmed = WikiBodySanitizer.sanitize(trimmed)
            // LLM Best Practices P1-3: plain string 生成の品質下限を担保。
            // sanitize 後の本文が妥当なら採用、不合格 (短すぎ/スキャフォールド残り) なら
            // summary から fallback (既存本文が空のときのみ上書き、良い既存本文は保持)。
            if WikiBodySanitizer.isValid(trimmed) {
                conceptPage.bodyMarkdown = trimmed
            } else if conceptPage.bodyMarkdown.isEmpty && !conceptPage.summary.isEmpty {
                logger.notice("wiki body invalid for \(conceptPage.name, privacy: .public) → summary fallback")
                conceptPage.bodyMarkdown = conceptPage.summary
            }
            // 不合格 & 既存本文あり → 既存を保持 (防御)
        } catch {
            logger.error("wiki body generation failed for \(conceptPage.name, privacy: .public): \(String(describing: error), privacy: .public)")
            if conceptPage.bodyMarkdown.isEmpty && !conceptPage.summary.isEmpty {
                conceptPage.bodyMarkdown = conceptPage.summary
            }
        }
    }

    /// relatedArticles の KnowledgeEntity.typeRaw を集計して種別を推定。
    /// person/organization 優勢 → .person、それ以外 → .concept。entity ゼロ → nil (kind 据え置き)。
    static func inferKind(from articles: [Article]) -> WikiPageKind? {
        var personish = 0
        var other = 0
        for article in articles {
            for entity in (article.extractedKnowledge?.entities ?? []) {
                switch entity.typeRaw {
                case "person", "organization": personish += 1
                default: other += 1
                }
            }
        }
        if personish == 0 && other == 0 { return nil }
        return personish > other ? .person : .concept
    }

    /// Wiki 本文生成 prompt。summary + 圧縮した記事 essence + schema.md ルールを連結。
    /// plain string 出力 (schema コストゼロ) で token 内に収める。
    /// spec 064: linkCandidates があれば相互リンク候補を埋める (本文生成 AI 呼び出し回数は不変)。
    static func buildWikiBodyPrompt(
        conceptPage: ConceptPage,
        articles: [Article],
        linkCandidates: [(name: String, id: UUID)] = []
    ) -> String {
        let rule = SchemaLoader.shared.section(named: "Wiki 本文生成ルール") ?? """
        ## 概要 → ## 詳細 (箇条書き中心) の構成。300-800 字。推測禁止。日本語。
        """
        let essences = articles.prefix(5).compactMap { article -> String? in
            guard let e = article.extractedKnowledge?.essence, !e.isEmpty else { return nil }
            return "- " + Self.truncate(e, max: Self.perArticleEssenceMaxChars)
        }.joined(separator: "\n")

        // spec 064: 相互リンク候補 (name + ID)。name は 30 字 truncate、最大 linkCandidateLimit 件。
        let candidatesBlock: String
        if linkCandidates.isEmpty {
            candidatesBlock = ""
        } else {
            let lines = linkCandidates.prefix(Self.linkCandidateLimit).map {
                "- \(Self.truncate($0.name, max: 30)) → concept-id://\($0.id.uuidString)"
            }.joined(separator: "\n")
            candidatesBlock = """


            # 相互リンクの参考表 (★この表・見出し・UUID 自体は本文に出力しない)
            本文中に下記の名前が自然に登場したときだけ、その語を `[名前](concept-id://UUID)` のインラインリンクにする。
            「関連ページ候補」などの見出しや UUID の羅列を本文に書いてはいけない。候補外にリンクしない。UUID は創作しない。
            \(lines)
            """
        }

        return """
        「\(conceptPage.name)」についての Wiki ページ本文を Markdown で書いてください。

        # ルール
        \(rule)

        # 現在の要約
        \(conceptPage.summary)

        # 関連記事の要点
        \(essences)\(candidatesBlock)
        """
    }

    /// spec 064: AI が書いた本文中の concept-id:// リンクのうち、実在しない UUID をプレーン化する。
    /// validIDs に含まれない UUID のリンクは `[名前](concept-id://...)` → `名前` に剥がし、dead link を防ぐ。
    static func sanitizeConceptLinks(in markdown: String, validIDs: Set<UUID>) -> String {
        let pattern = #"\[([^\]]+)\]\(concept-id://([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return markdown }
        let ns = markdown as NSString
        var result = markdown
        let matches = regex.matches(in: markdown, range: NSRange(location: 0, length: ns.length))
        // 後ろから置換 (range ずれ防止)
        for match in matches.reversed() {
            let name = ns.substring(with: match.range(at: 1))
            let uuidString = ns.substring(with: match.range(at: 2))
            let isValid = UUID(uuidString: uuidString).map { validIDs.contains($0) } ?? false
            if !isValid {
                let full = ns.substring(with: match.range)
                if let r = result.range(of: full) {
                    result.replaceSubrange(r, with: name)
                }
            }
        }
        return result
    }

    func resynthesizeAllStale() async {
        await ConceptSynthesisGate.run {
            // spec 058 polish: 最新優先 (関連 Article の最新 savedAt で sort)
            // 新しい記事に紐付く概念から先に summary 生成、ユーザーは保存後すぐ概要を見られる。
            let allDescriptor = FetchDescriptor<ConceptPage>(
                predicate: #Predicate { $0.isStale == true }
            )
            guard let allStale = try? context.fetch(allDescriptor), !allStale.isEmpty else { return }

            let sorted = allStale.sorted { lhs, rhs in
                let lhsLatest = (lhs.relatedArticles ?? []).map(\.savedAt).max() ?? .distantPast
                let rhsLatest = (rhs.relatedArticles ?? []).map(\.savedAt).max() ?? .distantPast
                return lhsLatest > rhsLatest
            }
            for page in sorted.prefix(5) {
                // spec 082: チャット応答中は次の概念合成を開始せず待機 (ANE をチャットに最優先で譲る)
                await AIPriorityCoordinator.shared.waitWhileChatActive()
                await _resynthesize(page)
            }
        }
    }

    func backfillFromExistingArticles() async {
        guard !UserDefaults.standard.bool(forKey: FallbackConceptSynthesisService.backfillFlagKey) else { return }

        let descriptor = FetchDescriptor<Article>(sortBy: [SortDescriptor(\.savedAt)])
        guard let articles = (try? context.fetch(descriptor)), !articles.isEmpty else {
            UserDefaults.standard.set(true, forKey: FallbackConceptSynthesisService.backfillFlagKey)
            return
        }

        for article in articles {
            await processNewArticle(article: article)
        }
        UserDefaults.standard.set(true, forKey: FallbackConceptSynthesisService.backfillFlagKey)
    }

    // MARK: - Private synthesis

    /// 1-shot prompt (4 件以下、context window 内に収まる)。
    private func synthesizeOneShot(
        conceptPage: ConceptPage,
        articles: [Article],
        compact: Bool = false
    ) async throws -> ConceptSynthesisOutput {
        let prompt = buildOneShotPrompt(conceptPage: conceptPage, articles: articles)
        return try await runSynthesis(prompt: prompt, compact: compact)
    }

    /// spec 080拡張: compact=true は小型スキーマ (出力予約小) で生成し ConceptSynthesisOutput に map。
    /// overflow 時の 1 回再試行で使う (大概念だけ要点≤2 に落として窓内に収める)。
    private func runSynthesis(prompt: String, compact: Bool) async throws -> ConceptSynthesisOutput {
        if compact {
            let out = try await session.generateConceptSynthesisCompact(prompt: prompt)
            return ConceptSynthesisOutput(summary: out.summary, crossSourceInsights: out.crossSourceInsights)
        }
        return try await session.generateConceptSynthesis(prompt: prompt)
    }

    /// spec 080拡張: 概念合成を実行。overflow (exceededContextWindowSize) を検知したら
    /// 1 回だけ compact (小型スキーマ) で再試行する。compact も失敗 / 別エラーは rethrow → 上位で fallback。
    /// decodingFailure (LM が不完全 JSON を出力) の場合は JSON 修復を試みる。
    private func synthesizeWithAdaptiveRetry(
        conceptPage: ConceptPage,
        articles: [Article]
    ) async throws -> ConceptSynthesisOutput {
        func run(compact: Bool) async throws -> ConceptSynthesisOutput {
            if conceptPage.isBroadConcept {
                return try await synthesizeBroadConcept(conceptPage: conceptPage, articles: articles, compact: compact)
            } else if articles.count >= Self.hierarchicalThreshold {
                return try await synthesizeHierarchical(conceptPage: conceptPage, articles: articles, compact: compact)
            } else {
                return try await synthesizeOneShot(conceptPage: conceptPage, articles: articles, compact: compact)
            }
        }
        do {
            return try await run(compact: false)
        } catch {
            if Self.isContextOverflow(error) {
                logger.notice("concept synthesis overflow for \(conceptPage.name, privacy: .public) → compact retry (要点≤2)")
                return try await run(compact: true)
            }
            // decodingFailure: LM が 「」等の日本語引用符を含む文字列の閉じ " を忘れた場合に発生。
            // エラーテキストから部分 JSON を抽出して修復を試みる。修復失敗は rethrow → essence-list fallback。
            if let partial = Self.extractPartialOutput(from: error) {
                logger.notice("concept synthesis decodingFailure for \(conceptPage.name, privacy: .public) → repaired partial JSON")
                return partial
            }
            throw error
        }
    }

    /// 窓超過エラーか (実 overflow `exceededContextWindowSize` + P2-1 preflight
    /// `wouldExceedContextWindowSize` の両方を検出)。型 import 不要で頑健に文字列判定。
    static func isContextOverflow(_ error: Error) -> Bool {
        let s = String(describing: error)
        return s.contains("exceededContextWindowSize") || s.contains("wouldExceedContextWindowSize")
    }

    /// decodingFailure エラーのテキストから部分的に有効な ConceptSynthesisOutput を抽出する。
    /// LM が文字列の閉じ " を忘れた / 末尾ゴミがある場合をカバー。
    static func extractPartialOutput(from error: Error) -> ConceptSynthesisOutput? {
        let desc = String(describing: error)
        guard desc.contains("decodingFailure") else { return nil }
        guard let textRange = desc.range(of: "Text: ") else {
            // "Text: " が見つからない = Apple がエラー format を変更した可能性。
            // 修復を試みず rethrow させる。フォーマット変更の検出ログを残す。
            Logger(subsystem: "app.KnowledgeTree", category: "concept")
                .warning("concept synthesis decodingFailure: 'Text: ' prefix not found in error description — Apple may have changed the format")
            return nil
        }
        let jsonCandidate = String(desc[textRange.upperBound...])
        return repairAndDecode(jsonCandidate)
    }

    /// 不完全 JSON を修復してデコードを試みる。
    /// 戦略: JSON オブジェクトの開始 `{` を探し、最後に出現する `}` で切り取る。
    /// それでも失敗したら summary だけ取り出す。
    static func repairAndDecode(_ text: String) -> ConceptSynthesisOutput? {
        // まず `{` から最後の `}` までを試す
        guard let start = text.firstIndex(of: "{"),
              let end   = text.lastIndex(of: "}") else { return nil }
        let slice = String(text[start...end])

        if let data = slice.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let summary  = obj["summary"] as? String ?? ""
            let insights = obj["crossSourceInsights"] as? [String] ?? []
            if !summary.isEmpty { return ConceptSynthesisOutput(summary: summary, crossSourceInsights: insights) }
        }

        // `}` 切り取りでも失敗 → summary フィールドだけ正規表現で取り出す
        if let match = slice.range(of: "\"summary\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
            let raw = String(slice[match])
            if let valStart = raw.firstIndex(of: ":"),
               let q1 = raw[raw.index(after: valStart)...].firstIndex(of: "\""),
               let q2 = raw[raw.index(after: q1)...].firstIndex(of: "\"") {
                let summary = String(raw[raw.index(after: q1)..<q2])
                if !summary.isEmpty { return ConceptSynthesisOutput(summary: summary, crossSourceInsights: []) }
            }
        }
        return nil
    }

    /// hierarchical + meta-summary (5+ 件、chunk_size=4 で分割 → 各 chunk 要約 → meta prompt で最終合成)。
    private func synthesizeHierarchical(
        conceptPage: ConceptPage,
        articles: [Article],
        compact: Bool = false
    ) async throws -> ConceptSynthesisOutput {
        let sortedArticles = articles.sorted { $0.savedAt > $1.savedAt }
        let chunks = stride(from: 0, to: sortedArticles.count, by: Self.chunkSize).map {
            Array(sortedArticles[$0..<min($0 + Self.chunkSize, sortedArticles.count)])
        }

        var chunkSummaries: [String] = []
        for (index, chunk) in chunks.enumerated() {
            let chunkPrompt = buildChunkPrompt(
                conceptPage: conceptPage,
                articles: chunk,
                chunkIndex: index,
                totalChunks: chunks.count
            )
            do {
                let chunkOutput = try await session.generateConceptSummaryChunk(prompt: chunkPrompt)
                if !chunkOutput.chunkSummary.isEmpty {
                    chunkSummaries.append(chunkOutput.chunkSummary)
                }
            } catch {
                logger.error("concept chunk \(index + 1)/\(chunks.count) failed for \(conceptPage.name, privacy: .public): \(String(describing: error), privacy: .public)")
                // chunk 失敗時は skip、他 chunk で続行
            }
        }

        let metaPrompt = buildMetaPrompt(conceptPage: conceptPage, chunkSummaries: chunkSummaries, totalArticles: articles.count)
        return try await runSynthesis(prompt: metaPrompt, compact: compact)
    }

    /// spec 074: 広い概念 (L1) の synth。子トピック名 + 自身の関連記事要点を俯瞰して統合。
    /// 入力は子名リスト + 記事 essence 4 件 (capped) = token 安全。
    private func synthesizeBroadConcept(
        conceptPage: ConceptPage,
        articles: [Article],
        compact: Bool = false
    ) async throws -> ConceptSynthesisOutput {
        let allPages = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
        let childNames = allPages
            .filter { $0.parentConceptID == conceptPage.id && !$0.isHidden }
            .map(\.name)
        let prompt = buildBroadConceptPrompt(conceptPage: conceptPage, childNames: childNames, articles: articles)
        return try await runSynthesis(prompt: prompt, compact: compact)
    }

    private func buildBroadConceptPrompt(
        conceptPage: ConceptPage,
        childNames: [String],
        articles: [Article]
    ) -> String {
        let categoryDisplay = CategorySeed.category(for: conceptPage.categoryRaw).name
        let childText = childNames.isEmpty ? "(まだなし)" : childNames.prefix(12).joined(separator: "、")
        let essences = articles.sorted { $0.savedAt > $1.savedAt }.prefix(4).compactMap { a -> String? in
            guard let e = a.extractedKnowledge?.essence, !e.isEmpty else { return nil }
            return "- " + Self.truncate(e, max: Self.perArticleEssenceMaxChars)
        }
        let essenceText = essences.isEmpty ? "(なし)" : essences.joined(separator: "\n")

        return """
        あなたは「\(conceptPage.name)」という広い分野概念について「今わかっていること」を統合する役割です。

        ## 概念 (広い概念)
        名前: \(conceptPage.name)
        カテゴリー: \(categoryDisplay)

        ## この概念に含まれる具体トピック
        \(childText)

        ## 関連記事の要点
        \(essenceText)
        \(CategoryPrompts.block(forCategoryRaw: conceptPage.categoryRaw))
        ## 出力要件
        - summary: 120〜180 字、上記の具体トピックと要点を俯瞰した分野全体像、推測禁止、断定調
        - crossSourceInsights (要点): 最大 5 件、各 60 字以内、この分野で最も大事な要点・結論を重要度順
        """
    }

    // MARK: - Prompt builders

    private func buildOneShotPrompt(conceptPage: ConceptPage, articles: [Article]) -> String {
        let aliasesText = conceptPage.nameAliases.isEmpty ? "(なし)" : conceptPage.nameAliases.joined(separator: "、")
        let categoryDisplay = CategorySeed.category(for: conceptPage.categoryRaw).name
        let lines = articles.enumerated().map { idx, article -> String in
            let title = Self.truncate(article.title, max: Self.perArticleTitleMaxChars)
            let rawEssence = article.extractedKnowledge?.essence ?? "(要点未生成)"
            let essence = Self.truncate(rawEssence, max: Self.perArticleEssenceMaxChars)
            let keyFacts = (article.extractedKnowledge?.keyFacts ?? [])
                .sorted { $0.order < $1.order }
                .prefix(Self.perArticleKeyFactCount)
                .map { Self.truncate($0.statement, max: Self.perKeyFactMaxChars) }
                .joined(separator: "、")
            return """
            - [\(idx + 1)] \(title) (保存: \(formattedDate(article.savedAt)))
              essence: \(essence)
              KeyFact: \(keyFacts.isEmpty ? "(なし)" : keyFacts)
            """
        }.joined(separator: "\n")

        return """
        あなたは複数の保存記事から「\(conceptPage.name)」について「今わかっていること」を統合する役割です。

        ## 概念
        名前: \(conceptPage.name)
        別名: \(aliasesText)
        カテゴリー: \(categoryDisplay)

        ## 元記事 (essence + KeyFact)
        \(lines)
        \(CategoryPrompts.block(forCategoryRaw: conceptPage.categoryRaw))
        ## 出力要件
        - summary: 120〜180 字、原文に明示された内容のみ統合、断定調 (である / する / だ)
        - crossSourceInsights (要点): 最大 5 件、各 60 字以内、この概念で最も大事な要点・結論を重要度順
        - 推測 / 一般知識からの補強禁止
        """
    }

    private func buildChunkPrompt(
        conceptPage: ConceptPage,
        articles: [Article],
        chunkIndex: Int,
        totalChunks: Int
    ) -> String {
        let categoryDisplay = CategorySeed.category(for: conceptPage.categoryRaw).name
        let lines = articles.enumerated().map { idx, article -> String in
            let title = Self.truncate(article.title, max: Self.perArticleTitleMaxChars)
            let rawEssence = article.extractedKnowledge?.essence ?? "(要点未生成)"
            let essence = Self.truncate(rawEssence, max: Self.perArticleEssenceMaxChars)
            let keyFacts = (article.extractedKnowledge?.keyFacts ?? [])
                .sorted { $0.order < $1.order }
                .prefix(Self.perArticleKeyFactCount)
                .map { Self.truncate($0.statement, max: Self.perKeyFactMaxChars) }
                .joined(separator: "、")
            return """
            - [\(idx + 1)] \(title) (\(formattedDate(article.savedAt)))
              essence: \(essence)
              KeyFact: \(keyFacts.isEmpty ? "(なし)" : keyFacts)
            """
        }.joined(separator: "\n")

        return """
        あなたは保存記事のチャンクを要約する役割です。

        ## 概念
        名前: \(conceptPage.name)
        カテゴリー: \(categoryDisplay)

        ## 記事チャンク (\(chunkIndex + 1)/\(totalChunks))
        \(lines)

        ## 出力要件
        - chunkSummary: 80〜140 字、原文に明示された内容のみ、断定調
        """
    }

    private func buildMetaPrompt(
        conceptPage: ConceptPage,
        chunkSummaries: [String],
        totalArticles: Int
    ) -> String {
        let aliasesText = conceptPage.nameAliases.isEmpty ? "(なし)" : conceptPage.nameAliases.joined(separator: "、")
        let categoryDisplay = CategorySeed.category(for: conceptPage.categoryRaw).name

        // 強化 (2026-06-11): 真因は token でなく記事並列のランタイム逼迫と判明 → 直列化で解消。
        // meta 入力に余裕ができたので 4件×90字 → 6件×150字 (元記事多数の概念を richer に統合)。
        let cappedChunks = chunkSummaries.prefix(6).map { String($0.prefix(150)) }
        let chunkText = cappedChunks.isEmpty
            ? "(中間要約が生成できませんでした)"
            : cappedChunks.enumerated().map { idx, summary in "## チャンク \(idx + 1)\n\(summary)" }.joined(separator: "\n\n")

        return """
        あなたは複数の記事チャンク要約を統合して「\(conceptPage.name)」について「今わかっていること」を書く役割です。

        ## 概念
        名前: \(conceptPage.name)
        別名: \(aliasesText)
        カテゴリー: \(categoryDisplay)

        ## 記事チャンク要約 (元 \(totalArticles) 件記事、上位 \(cappedChunks.count) チャンク)
        \(chunkText)
        \(CategoryPrompts.block(forCategoryRaw: conceptPage.categoryRaw))
        ## 出力要件
        - summary: 120〜180 字、チャンク要約のみから統合、推測禁止、断定調
        - crossSourceInsights (要点): 最大 5 件、各 60 字以内、この概念で最も大事な要点・結論を重要度順
        """
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// 文字列を max 字以内に切り詰める。超過時は末尾に「…」を付与。
    /// Foundation Models の 4096 token 制限を回避するため per-article 内容を bound する。
    fileprivate static func truncate(_ text: String, max: Int) -> String {
        guard text.count > max else { return text }
        return String(text.prefix(max - 1)) + "…"
    }
}

// MARK: - 共通 processNewArticle ロジック

/// processNewArticle の DB 操作部分は Foundation 経路 / Fallback 経路で共通。
/// (entity スキャン + ConceptPage 生成 / isStale toggle は availability に依存しない)
@MainActor
enum ConceptSynthesisCommon {

    /// entity 名は 2 文字未満 (例: "AI" は 2 文字なので含まれる、1 文字は除外) で ambiguous なので skip。
    static let minEntityNameLength = 2

    // MARK: - spec 089: 要点 → 元記事 の出典照合

    /// 各 insight を最も関連する relatedArticle に照合し、id 文字列 (該当なしは "") を同 index で返す。
    /// embedding 可なら insight × article.essenceEmbedding の cosine、不可なら keyword overlap。
    /// AI/LM 呼び出しゼロ (embedding のみ、合成時に 1 回計算して保存)。
    static func matchInsightSources(
        insights: [String],
        articles: [Article],
        embeddingService: EmbeddingService?
    ) -> [String] {
        guard !insights.isEmpty, !articles.isEmpty else { return [] }
        return insights.map { insight in
            bestSourceArticleID(for: insight, articles: articles, embeddingService: embeddingService) ?? ""
        }
    }

    private static func bestSourceArticleID(
        for insight: String,
        articles: [Article],
        embeddingService: EmbeddingService?
    ) -> String? {
        // embedding 経路 (日本語も意味照合できる主経路)
        if let es = embeddingService, es.isAvailable, let query = es.embed(insight) {
            var best: (id: String, sim: Float)?
            for article in articles {
                guard let data = article.essenceEmbedding else { continue }
                let vector = data.asFloatArray
                guard vector.count == query.count else { continue }
                let sim = EmbeddingService.cosineSimilarity(query, vector)
                if best == nil || sim > best!.sim { best = (article.id.uuidString, sim) }
            }
            if let best, best.sim >= 0.3 { return best.id }
        }
        // keyword fallback (embedding 不可 / essenceEmbedding 無し時)
        return bestSourceByKeyword(insight: insight, articles: articles)
    }

    private static func bestSourceByKeyword(insight: String, articles: [Article]) -> String? {
        let tokens = Set(
            insight.lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
                .filter { $0.count >= 2 }
        )
        guard !tokens.isEmpty else { return nil }
        var best: (id: String, score: Int)?
        for article in articles {
            let facts = (article.extractedKnowledge?.keyFacts ?? []).map { $0.statement }.joined(separator: " ")
            let hay = (article.title + " " + (article.extractedKnowledge?.essence ?? "") + " " + facts).lowercased()
            let score = tokens.reduce(0) { $0 + (hay.contains($1) ? 1 : 0) }
            if score > 0, best == nil || score > best!.score { best = (article.id.uuidString, score) }
        }
        return best?.id
    }

    static func processNewArticle(
        article: Article,
        context: ModelContext,
        refreshTrigger: RefreshTrigger?,
        logger: Logger
    ) {
        guard let entities = article.extractedKnowledge?.entities, !entities.isEmpty else { return }

        // article の categoryRaw を解決 (Tag 経由、最頻出 1 つ、tags なしは「その他」)
        let articleCategoryRaw = resolveCategoryRaw(for: article)

        // 全 Article fetch (entity 出現件数カウント用)
        let allArticles: [Article] = (try? context.fetch(FetchDescriptor<Article>())) ?? []
        let allConceptPages: [ConceptPage] = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []

        // entity 名の重複除外 (同 article 内で同名 entity が複数 entry なら 1 回だけ処理)
        var processedNames = Set<String>()

        for entity in entities {
            let name = entity.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.count >= minEntityNameLength else { continue }
            let lowercased = name.lowercased()
            guard !processedNames.contains(lowercased) else { continue }
            processedNames.insert(lowercased)

            // 既存 ConceptPage 検索 (spec 078: canonical キー照合で表記ゆれ吸収 + categoryRaw 一致)
            let canonical = ConceptNameNormalizer.canonical(name)
            let existingPage = allConceptPages.first { page in
                page.categoryRaw == articleCategoryRaw &&
                ConceptNameNormalizer.canonicalNames(of: page).contains(canonical)
            }

            if let existingPage {
                // 関連記事 link、未 link なら追加 + isStale = true
                if !(existingPage.relatedArticles?.contains(where: { $0.id == article.id }) ?? false) {
                    if existingPage.relatedArticles == nil { existingPage.relatedArticles = [] }
                    existingPage.relatedArticles?.append(article)
                }
                existingPage.isStale = true
                existingPage.updatedAt = .now
            } else {
                // 過去の他 Article で同 entity 名が登場しているか count (今回の article 自身は除外)
                let priorArticles = allArticles.filter { other in
                    other.id != article.id &&
                    (other.extractedKnowledge?.entities ?? []).contains { e in
                        e.name.lowercased() == lowercased
                    } &&
                    resolveCategoryRaw(for: other) == articleCategoryRaw
                }

                guard !priorArticles.isEmpty else {
                    // 1 件目 (今回のみ) → 生成しない、graph ノードのみで十分
                    continue
                }

                // 2+ 件目 → ConceptPage 新規生成
                let newPage = ConceptPage(
                    name: name,
                    nameAliases: [],
                    categoryRaw: articleCategoryRaw,
                    summary: "",
                    crossSourceInsights: [],
                    relatedArticles: priorArticles + [article],
                    relatedConceptIDs: [],
                    isFollowing: false,
                    isStale: true
                )
                context.insert(newPage)
                logger.notice("concept page created: \(name, privacy: .public) [\(articleCategoryRaw, privacy: .public)] with \(priorArticles.count + 1) articles")
            }
        }

        try? context.save()
        refreshTrigger?.bump()
    }

    // MARK: - spec 074: 概念階層の upsert

    /// 抽出済み階層 (広い概念 + 具体概念) を ConceptPage に upsert。
    /// broad ページ (level=broad) + specific ページ (level=specific, parent=broad.id) を作成/更新し、
    /// 記事を両者に link、isStale=true。entity 共起の閾値 (2 記事) は使わず、1 記事目から階層を作る
    /// (記事が論じる具体概念はその記事だけでもページ化する。重複/正規化は agent loop = spec 076)。
    static func processConceptHierarchy(
        article: Article,
        hierarchy: ConceptHierarchyOutput,
        context: ModelContext,
        refreshTrigger: RefreshTrigger?,
        logger: Logger
    ) {
        let categoryRaw = resolveCategoryRaw(for: article)
        let broadName = hierarchy.broadConcept.trimmingCharacters(in: .whitespacesAndNewlines)
        guard broadName.count >= minEntityNameLength else { return }

        var pages: [ConceptPage] = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []

        // 1. 広い概念ページ (L1)
        let broadPage = upsertHierarchyPage(
            name: broadName, level: .broad, parentID: nil,
            categoryRaw: categoryRaw, article: article,
            pages: &pages, context: context, logger: logger
        )

        // 2. 具体概念ページ (L2、parent = broad)。広い概念と同名は skip。
        var seen = Set<String>([broadName.lowercased()])
        for raw in hierarchy.specificConcepts {
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.count >= minEntityNameLength else { continue }
            let lower = name.lowercased()
            guard !seen.contains(lower) else { continue }
            seen.insert(lower)
            _ = upsertHierarchyPage(
                name: name, level: .specific, parentID: broadPage.id,
                categoryRaw: categoryRaw, article: article,
                pages: &pages, context: context, logger: logger
            )
        }

        try? context.save()
        refreshTrigger?.bump()
    }

    /// 名前 + categoryRaw で既存ページを検索し link/昇格、無ければ新規作成。
    private static func upsertHierarchyPage(
        name: String,
        level: ConceptLevel,
        parentID: UUID?,
        categoryRaw: String,
        article: Article,
        pages: inout [ConceptPage],
        context: ModelContext,
        logger: Logger
    ) -> ConceptPage {
        // spec 078: canonical キー照合で表記ゆれ (全角半角/かな/case/空白) の重複を入口で防ぐ。
        let canonical = ConceptNameNormalizer.canonical(name)
        if let existing = pages.first(where: {
            $0.categoryRaw == categoryRaw && ConceptNameNormalizer.canonicalNames(of: $0).contains(canonical)
        }) {
            // 記事 link (重複なし)
            if !(existing.relatedArticles?.contains(where: { $0.id == article.id }) ?? false) {
                if existing.relatedArticles == nil { existing.relatedArticles = [] }
                existing.relatedArticles?.append(article)
            }
            // level/parent 調整: broad target は broad に昇格。specific target は parent 補完のみ
            // (既に broad のページは降格させない = 過剰降格防止)。
            if level == .broad {
                existing.level = .broad
                existing.parentConceptID = nil
            } else if existing.level != .broad, existing.parentConceptID == nil, let parentID {
                existing.parentConceptID = parentID
            }
            existing.isStale = true
            existing.updatedAt = .now
            return existing
        } else {
            let page = ConceptPage(
                name: name,
                categoryRaw: categoryRaw,
                relatedArticles: [article],
                isStale: true,
                parentConceptID: parentID,
                conceptLevelRaw: level.rawValue
            )
            context.insert(page)
            pages.append(page)
            logger.notice("concept page created: \(name, privacy: .public) [\(categoryRaw, privacy: .public)] (\(level.rawValue, privacy: .public))")
            return page
        }
    }

    /// Article から代表 categoryRaw を解決。
    /// 複数 tag があれば最頻出、tag が無ければ「その他」。
    static func resolveCategoryRaw(for article: Article) -> String {
        let other = CategorySeed.otherCategory.name
        let raws = (article.tags ?? []).compactMap(\.categoryRaw).filter { !$0.isEmpty }
        guard !raws.isEmpty else { return other }
        // 「その他」は人名等のノイズ entity からも付きやすく多数決を歪める (例: tech 記事が
        // 著者名の その他 票に負けて LLM技術[その他] になる)。実カテゴリが 1 つでもあれば
        // その他 を投票から除外し、最頻出の実カテゴリを採用。全部 その他 の時だけ その他。
        let real = raws.filter { $0 != other }
        let pool = real.isEmpty ? raws : real
        let counted = Dictionary(grouping: pool, by: { $0 }).mapValues(\.count)
        return counted.max(by: { $0.value < $1.value })?.key ?? other
    }

    /// ① 自己修復: 概念の categoryRaw を relatedArticles から再計算し、変化があれば更新。
    /// 記事 0 件や算出不能時は据え置き (既存値を壊さない)。save は呼び出し側に任せる。
    static func healCategory(_ conceptPage: ConceptPage, articles: [Article]) {
        guard !articles.isEmpty else { return }
        let newCat = resolveCategoryRaw(forArticles: articles)
        if !newCat.isEmpty && newCat != conceptPage.categoryRaw {
            conceptPage.categoryRaw = newCat
        }
    }

    /// 複数記事 (= 概念の relatedArticles) のタグから代表 categoryRaw を解決。
    /// 概念の categoryRaw 再計算 (① 自己修復 / ② backfill) で使う。その他 は実カテゴリがあれば除外。
    static func resolveCategoryRaw(forArticles articles: [Article]) -> String {
        let other = CategorySeed.otherCategory.name
        let raws = articles
            .flatMap { ($0.tags ?? []).compactMap(\.categoryRaw) }
            .filter { !$0.isEmpty }
        guard !raws.isEmpty else { return other }
        let real = raws.filter { $0 != other }
        let pool = real.isEmpty ? raws : real
        let counted = Dictionary(grouping: pool, by: { $0 }).mapValues(\.count)
        return counted.max(by: { $0.value < $1.value })?.key ?? other
    }

    /// spec 077: タグ分類完了時の再ヒール (AI 不要)。
    /// ingest のタイミング競合 (概念作成が tag 分類の完了を待たない) で `その他` に固着した概念を、
    /// タグ分類完了後 (TagStore の fire-and-forget) / lint 再分類後に実カテゴリへ修正する。
    /// tag の articles に紐づく ConceptPage のうち categoryRaw == その他 のものに healCategory を適用。
    static func healConcepts(forTag tag: Tag, context: ModelContext, refreshTrigger: RefreshTrigger?) {
        let other = CategorySeed.otherCategory.name
        let articles = tag.articles ?? []
        guard !articles.isEmpty else { return }
        var seen = Set<UUID>()
        var changed = false
        for article in articles {
            for page in (article.relatedConcepts ?? []) where page.categoryRaw == other {
                guard seen.insert(page.id).inserted else { continue }
                let before = page.categoryRaw
                healCategory(page, articles: page.relatedArticles ?? [])
                if page.categoryRaw != before { changed = true }
            }
        }
        if changed {
            try? context.save()
            refreshTrigger?.bump()
        }
    }
}

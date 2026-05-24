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

// MARK: - Protocol

@MainActor
protocol ConceptSynthesisServiceProtocol: AnyObject {
    /// 新規記事 ingest 時 (KnowledgeExtractionService.extract 末尾) に呼ばれる。
    /// 記事内 entity を見て、2+ Article に同名登場した entity について:
    /// - 既存 ConceptPage あり → isStale = true で再合成予約
    /// - 既存 ConceptPage なし → 新規生成 (isStale = true、relatedArticles に過去 + 今回 = 2 件)
    /// silent fire-and-forget、例外を throw しない。
    func processNewArticle(article: Article) async

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

    func resynthesize(_ conceptPage: ConceptPage) async {
        let articles = conceptPage.relatedArticles.sorted { $0.savedAt > $1.savedAt }
        let essences = articles.compactMap { $0.extractedKnowledge?.essence }.filter { !$0.isEmpty }

        if essences.isEmpty {
            conceptPage.summary = "「\(conceptPage.name)」に関する保存記事は \(articles.count) 件ありますが、本文要点がまだ整っていません。"
            conceptPage.crossSourceInsights = []
        } else {
            let joined = essences.prefix(3).joined(separator: "\n\n")
            conceptPage.summary = String(joined.prefix(400))
            conceptPage.crossSourceInsights = essences.prefix(3).compactMap { essence in
                let firstSentence = essence.split(whereSeparator: { $0 == "。" || $0 == "!" || $0 == "?" }).first
                return firstSentence.map(String.init)
            }
        }

        conceptPage.isStale = false
        conceptPage.updatedAt = .now
        try? context.save()
        refreshTrigger?.bump()
    }

    func resynthesizeAllStale() async {
        let descriptor = FetchDescriptor<ConceptPage>(
            predicate: #Predicate { $0.isStale == true },
            sortBy: [SortDescriptor(\.updatedAt)]
        )
        var bounded = descriptor
        bounded.fetchLimit = 5

        guard let pages = try? context.fetch(bounded) else { return }
        for page in pages {
            await resynthesize(page)
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
    /// 各 article の essence を prompt に含める最大文字数 (token 超過対策、2026-05-23 fix: 300→200)。
    /// spec 042 brushup で 300 → 200、spec 051 spike で 200 → 150。
    static let perArticleEssenceMaxChars = 150
    /// 各 article から prompt に含める KeyFact 件数 (2026-05-23 fix: 3→2)。
    static let perArticleKeyFactCount = 2
    /// 1 件あたり KeyFact 文字数上限 (2026-05-23 fix: 100→60)。
    /// spec 042 brushup で 100 → 60、spec 051 spike で 60 → 40。
    static let perKeyFactMaxChars = 40
    /// 各 article の title 上限 (2026-05-23 新規、長文 title 対策)。
    static let perArticleTitleMaxChars = 80

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

    func resynthesize(_ conceptPage: ConceptPage) async {
        guard availability.isAvailable else {
            await fallback.resynthesize(conceptPage)
            return
        }

        let articles = conceptPage.relatedArticles
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
            let output: ConceptSynthesisOutput
            if articles.count >= Self.hierarchicalThreshold {
                output = try await synthesizeHierarchical(conceptPage: conceptPage, articles: articles)
            } else {
                output = try await synthesizeOneShot(conceptPage: conceptPage, articles: articles)
            }

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
                conceptPage.crossSourceInsights = Array(output.crossSourceInsights.prefix(7))
            }

            // embedding 再生成 (summary が更新されたので)
            if let embeddingService, embeddingService.isAvailable,
               !trimmedSummary.isEmpty,
               let vector = embeddingService.embed(trimmedSummary) {
                conceptPage.embedding = vector.asEmbeddingData
            }

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

    func resynthesizeAllStale() async {
        let descriptor = FetchDescriptor<ConceptPage>(
            predicate: #Predicate { $0.isStale == true },
            sortBy: [SortDescriptor(\.updatedAt)]
        )
        var bounded = descriptor
        bounded.fetchLimit = 5

        guard let pages = try? context.fetch(bounded) else { return }
        for page in pages {
            await resynthesize(page)
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
        articles: [Article]
    ) async throws -> ConceptSynthesisOutput {
        let prompt = buildOneShotPrompt(conceptPage: conceptPage, articles: articles)
        return try await session.generateConceptSynthesis(prompt: prompt)
    }

    /// hierarchical + meta-summary (5+ 件、chunk_size=4 で分割 → 各 chunk 要約 → meta prompt で最終合成)。
    private func synthesizeHierarchical(
        conceptPage: ConceptPage,
        articles: [Article]
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
        return try await session.generateConceptSynthesis(prompt: metaPrompt)
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

        ## 出力要件
        - summary: 200〜400 字、原文に明示された内容のみ統合、断定調 (である / する / だ)
        - crossSourceInsights: 最大 7 件、各 50〜150 字、複数記事を並べて初めて見える発見
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
        - chunkSummary: 100〜200 字、原文に明示された内容のみ、断定調
        """
    }

    private func buildMetaPrompt(
        conceptPage: ConceptPage,
        chunkSummaries: [String],
        totalArticles: Int
    ) -> String {
        let aliasesText = conceptPage.nameAliases.isEmpty ? "(なし)" : conceptPage.nameAliases.joined(separator: "、")
        let categoryDisplay = CategorySeed.category(for: conceptPage.categoryRaw).name
        let chunkText = chunkSummaries.isEmpty
            ? "(中間要約が生成できませんでした)"
            : chunkSummaries.enumerated().map { idx, summary in "## チャンク \(idx + 1)\n\(summary)" }.joined(separator: "\n\n")

        return """
        あなたは複数の記事チャンク要約を統合して「\(conceptPage.name)」について「今わかっていること」を書く役割です。

        ## 概念
        名前: \(conceptPage.name)
        別名: \(aliasesText)
        カテゴリー: \(categoryDisplay)

        ## 記事チャンク要約 (元 \(totalArticles) 件記事)
        \(chunkText)

        ## 出力要件
        - summary: 200〜400 字、チャンク要約のみから統合、推測禁止、断定調
        - crossSourceInsights: 最大 7 件、各 50〜150 字、チャンクを横断して見える知見
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

            // 既存 ConceptPage 検索 (大文字小文字無視 + categoryRaw 一致)
            let existingPage = allConceptPages.first { page in
                page.categoryRaw == articleCategoryRaw &&
                page.searchableNames.contains(lowercased)
            }

            if let existingPage {
                // 関連記事 link、未 link なら追加 + isStale = true
                if !existingPage.relatedArticles.contains(where: { $0.id == article.id }) {
                    existingPage.relatedArticles.append(article)
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

    /// Article から代表 categoryRaw を解決。
    /// 複数 tag があれば最頻出、tag が無ければ「その他」。
    static func resolveCategoryRaw(for article: Article) -> String {
        let raws = article.tags.compactMap(\.categoryRaw).filter { !$0.isEmpty }
        if raws.isEmpty {
            return CategorySeed.otherCategory.name
        }
        // 最頻出を返す (同数なら最初のもの)
        let counted = Dictionary(grouping: raws, by: { $0 }).mapValues(\.count)
        return counted.max(by: { $0.value < $1.value })?.key ?? CategorySeed.otherCategory.name
    }
}

//
//  KnowledgeDigestService.swift
//  KnowledgeTree
//
//  spec 018 — Category 単位で複数記事の essence を AI 統合する service。
//
//  - protocol KnowledgeDigestService — UI から呼び出される interface
//  - FoundationModelsKnowledgeDigestService — Apple Foundation Models 経由
//  - FallbackKnowledgeDigestService — Apple Intelligence 不可時の essence 並べ簡易
//
//  contracts/knowledge-digest-service.md 準拠。
//

import Foundation
import SwiftData
import os

// MARK: - Protocol

@MainActor
protocol KnowledgeDigestService {
    /// 該当 Category の Article 群から AI 統合 Digest を生成。
    /// 古い同 Category Digest を delete + 新 Digest を insert のアトミック操作。
    /// マルチカード分割は AI 判断 (cards.count = 1〜3)。
    func regenerate(for category: Category) async throws -> [KnowledgeDigest]

    /// 全 Category の stale Digest を一括再生成。pull-to-refresh 用。
    func regenerateAllStale() async throws

    /// 記事追加時に該当 Category の Digest を stale 化。冪等。
    func markStale(for category: Category)
}

// MARK: - Foundation Models 実装

@MainActor
final class FoundationModelsKnowledgeDigestService: KnowledgeDigestService {
    private let session: LanguageModelSessionProtocol
    private let context: ModelContext
    private let availability: AvailabilityChecker
    private let fallback: KnowledgeDigestService
    /// spec 040: graph 構造を prompt に渡すための traversal (optional、nil なら従来 prompt)
    private let graphTraversal: GraphTraversalServiceProtocol?
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "digest")

    init(
        session: LanguageModelSessionProtocol,
        context: ModelContext,
        availability: AvailabilityChecker = SystemLanguageModelAvailabilityChecker(),
        fallback: KnowledgeDigestService,
        graphTraversal: GraphTraversalServiceProtocol? = nil
    ) {
        self.session = session
        self.context = context
        self.availability = availability
        self.fallback = fallback
        self.graphTraversal = graphTraversal
    }

    func regenerate(for category: Category) async throws -> [KnowledgeDigest] {
        guard availability.isAvailable else {
            logger.debug("regenerate fallback: language model unavailable for \(category.name, privacy: .public)")
            return try await fallback.regenerate(for: category)
        }

        let articles = fetchArticles(for: category, limit: 50)
        guard !articles.isEmpty else {
            // 既存 Digest を削除 (Category 内記事ゼロ)
            deleteExistingDigests(for: category)
            try? context.save()
            return []
        }

        let graphSection = buildGraphSection(categoryName: category.name)
        let prompt = Self.buildPrompt(articles: articles, categoryName: category.name, graphSection: graphSection)
        do {
            let output = try await session.generateDigest(prompt: prompt)
            return try persistDigests(output: output, for: category, articles: articles)
        } catch {
            logger.error("digest generation failed for \(category.name, privacy: .public): \(String(describing: error), privacy: .public)")
            return try await fallback.regenerate(for: category)
        }
    }

    func regenerateAllStale() async throws {
        // spec 018 fix: stale Digest だけでなく、記事はあるが Digest 未生成な Category も対象。
        // 初回起動時に既存記事から Digest を生成するため。
        let staleNames = Set(fetchStaleCategoryNames())
        let articleNames = Set(fetchCategoryNamesWithArticles())
        let digestNames = Set(fetchAllDigestCategoryNames())
        let missingNames = articleNames.subtracting(digestNames)
        let allToRegenerate = staleNames.union(missingNames)

        for name in allToRegenerate {
            guard let category = CategorySeed.allSeeds.first(where: { $0.name == name }) else {
                continue
            }
            _ = try? await regenerate(for: category)
        }
    }

    func markStale(for category: Category) {
        let categoryName = category.name
        let descriptor = FetchDescriptor<KnowledgeDigest>(
            predicate: #Predicate { $0.categoryRaw == categoryName }
        )
        let digests = (try? context.fetch(descriptor)) ?? []
        for digest in digests {
            digest.isStale = true
        }
        try? context.save()
    }

    // MARK: - Helpers

    private func fetchArticles(for category: Category, limit: Int) -> [Article] {
        let categoryName = category.name
        var descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { article in
                article.tags?.contains { $0.categoryRaw == categoryName } ?? false
            },
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchCategoryNamesWithArticles() -> [String] {
        // essence 持つ記事のある Category 名のみ集める
        let descriptor = FetchDescriptor<Article>()
        let articles = (try? context.fetch(descriptor)) ?? []
        let names = articles
            .filter { $0.extractedKnowledge?.essence?.isEmpty == false }
            .flatMap { ($0.tags ?? []).compactMap(\.categoryRaw) }
        return Array(Set(names))
    }

    private func fetchAllDigestCategoryNames() -> [String] {
        let descriptor = FetchDescriptor<KnowledgeDigest>()
        let digests = (try? context.fetch(descriptor)) ?? []
        return Array(Set(digests.map(\.categoryRaw)))
    }

    /// spec 040: graph 構造を「## このカテゴリーの主要エンティティと関係性」セクションに整形する。
    /// graphTraversal 不在 / 対象ノードなしは空文字。
    private func buildGraphSection(categoryName: String) -> String {
        guard let graphTraversal else { return "" }
        let topNodes = graphTraversal.topByDegree(categoryRaw: categoryName, limit: 5, in: context)
        guard !topNodes.isEmpty else { return "" }
        var graphLines: [String] = []
        for node in topNodes {
            // 各 node の outgoing edge 上位 2 件 (label + target、ラベル付きを優先)
            let labeledOutgoing = (node.outgoingEdges ?? [])
                .filter { $0.label != nil && $0.target?.isActive == true }
                .sorted { $0.weight > $1.weight }
                .prefix(2)
            let edgeStr = labeledOutgoing
                .compactMap { edge -> String? in
                    guard let label = edge.label, let target = edge.target else { return nil }
                    return "\(label) → \(target.name)"
                }
                .joined(separator: " / ")
            let line = edgeStr.isEmpty
                ? "・\(node.name) (記事数 \(node.mentionCount))"
                : "・\(node.name) (記事数 \(node.mentionCount)): \(edgeStr)"
            graphLines.append(line)
        }
        return """

        ## このカテゴリーの主要エンティティと関係性
        \(graphLines.joined(separator: "\n"))

        主要エンティティを中心に物語る文章を生成してください。
        """
    }

    /// i18n Phase B: 出力言語は `language` (既定 `PipelineLanguage.current`) に追従する。
    /// summary / topKeyFacts がパイプライン言語で出るよう出力言語ヘッダを明示する。
    /// graphTraversal (self) を持ち込まない純関数化のため graphSection は呼び出し側で組み立てる。
    static func buildPrompt(articles: [Article], categoryName: String, graphSection: String = "", language: PipelineLanguage = .current) -> String {
        let lines: [String] = articles.enumerated().compactMap { idx, article in
            guard let essence = article.extractedKnowledge?.essence,
                  !essence.isEmpty else { return nil }
            return "[\(idx + 1)] (id=\(article.id.uuidString)) \(essence)"
        }

        return """
            あなたは「\(categoryName)」カテゴリの \(lines.count) 件の記事要約を統合する AI です。
            出力言語: \(language.endonym)。スキーマの説明文が日本語でも、出力は必ず \(language.endonym) で書くこと。

            各記事の要点:
            \(lines.joined(separator: "\n"))
            \(graphSection)

            上記を統合し、1〜3 個の知識カードを生成してください。
            各カードは summary (150 字以内)、topKeyFacts (3 個)、topEntityNames (3 個)、
            sourceArticleIDs (該当記事の UUID) を含みます。

            1 つのトピックで完結するなら 1 カード、トピックが分散しているなら 2-3 カードに分割してください。
            \(language.outputInstruction)
            """
    }

    private func persistDigests(
        output: DigestOutput,
        for category: Category,
        articles: [Article]
    ) throws -> [KnowledgeDigest] {
        // 既存 Digest を削除
        deleteExistingDigests(for: category)

        let articleByID: [String: Article] = Dictionary(
            uniqueKeysWithValues: articles.map { ($0.id.uuidString, $0) }
        )

        var result: [KnowledgeDigest] = []
        for (index, card) in output.cards.enumerated() {
            // sourceArticleIDs に一致する Article を解決、見つからない場合は全記事から fallback
            let resolved = card.sourceArticleIDs.compactMap { articleByID[$0] }
            let sourceArticles = resolved.isEmpty ? articles : resolved

            guard !sourceArticles.isEmpty else { continue }

            let digest = KnowledgeDigest(
                categoryRaw: category.name,
                cardIndex: index,
                summary: card.summary,
                topKeyFacts: card.topKeyFacts,
                topEntityNames: card.topEntityNames,
                isStale: false,
                sourceArticles: sourceArticles
            )
            context.insert(digest)
            result.append(digest)
        }
        try context.save()
        return result
    }

    private func deleteExistingDigests(for category: Category) {
        let categoryName = category.name
        let descriptor = FetchDescriptor<KnowledgeDigest>(
            predicate: #Predicate { $0.categoryRaw == categoryName }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        for digest in existing {
            context.delete(digest)
        }
    }

    private func fetchStaleCategoryNames() -> [String] {
        let descriptor = FetchDescriptor<KnowledgeDigest>(
            predicate: #Predicate { $0.isStale == true }
        )
        let digests = (try? context.fetch(descriptor)) ?? []
        return Array(Set(digests.map(\.categoryRaw)))
    }
}

// MARK: - Fallback 実装

/// Apple Intelligence 利用不可時の簡易実装。AI を使わず essence 上位 3 件 + KeyFact list を結合。
@MainActor
final class FallbackKnowledgeDigestService: KnowledgeDigestService {
    private let context: ModelContext
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "digest-fallback")

    init(context: ModelContext) {
        self.context = context
    }

    func regenerate(for category: Category) async throws -> [KnowledgeDigest] {
        let articles = fetchArticles(for: category, limit: 10)
        guard !articles.isEmpty else {
            deleteExistingDigests(for: category)
            try? context.save()
            return []
        }

        deleteExistingDigests(for: category)

        let topEssences = articles.prefix(3).compactMap(\.extractedKnowledge?.essence).filter { !$0.isEmpty }
        let summary: String
        if topEssences.isEmpty {
            summary = "最近の \(articles.count) 件の記事を集約しました。"
        } else {
            summary = "最近の \(articles.count) 件から: " + topEssences.joined(separator: " / ")
        }

        let topKeyFacts = articles
            .flatMap { $0.extractedKnowledge?.keyFacts ?? [] }
            .sorted { $0.order < $1.order }
            .prefix(3)
            .map(\.statement)

        let topEntityNames = articles
            .flatMap { $0.extractedKnowledge?.entities ?? [] }
            .sorted { $0.salience > $1.salience }
            .prefix(3)
            .map(\.name)

        let digest = KnowledgeDigest(
            categoryRaw: category.name,
            cardIndex: 0,
            summary: summary,
            topKeyFacts: Array(topKeyFacts),
            topEntityNames: Array(topEntityNames),
            isStale: false,
            sourceArticles: articles
        )
        context.insert(digest)
        try context.save()
        return [digest]
    }

    func regenerateAllStale() async throws {
        // spec 018 fix: stale + 記事はあるが未生成な Category を統合
        let staleNames = Set(fetchStaleCategoryNames())
        let articleNames = Set(fetchCategoryNamesWithArticles())
        let digestNames = Set(fetchAllDigestCategoryNames())
        let missingNames = articleNames.subtracting(digestNames)
        let allToRegenerate = staleNames.union(missingNames)

        for name in allToRegenerate {
            guard let category = CategorySeed.allSeeds.first(where: { $0.name == name }) else {
                continue
            }
            _ = try? await regenerate(for: category)
        }
    }

    func markStale(for category: Category) {
        let categoryName = category.name
        let descriptor = FetchDescriptor<KnowledgeDigest>(
            predicate: #Predicate { $0.categoryRaw == categoryName }
        )
        let digests = (try? context.fetch(descriptor)) ?? []
        for digest in digests {
            digest.isStale = true
        }
        try? context.save()
    }

    // MARK: - Helpers

    private func fetchArticles(for category: Category, limit: Int) -> [Article] {
        let categoryName = category.name
        var descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { article in
                article.tags?.contains { $0.categoryRaw == categoryName } ?? false
            },
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchCategoryNamesWithArticles() -> [String] {
        let descriptor = FetchDescriptor<Article>()
        let articles = (try? context.fetch(descriptor)) ?? []
        let names = articles
            .filter { $0.extractedKnowledge?.essence?.isEmpty == false }
            .flatMap { ($0.tags ?? []).compactMap(\.categoryRaw) }
        return Array(Set(names))
    }

    private func fetchAllDigestCategoryNames() -> [String] {
        let descriptor = FetchDescriptor<KnowledgeDigest>()
        let digests = (try? context.fetch(descriptor)) ?? []
        return Array(Set(digests.map(\.categoryRaw)))
    }

    private func deleteExistingDigests(for category: Category) {
        let categoryName = category.name
        let descriptor = FetchDescriptor<KnowledgeDigest>(
            predicate: #Predicate { $0.categoryRaw == categoryName }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        for digest in existing {
            context.delete(digest)
        }
    }

    private func fetchStaleCategoryNames() -> [String] {
        let descriptor = FetchDescriptor<KnowledgeDigest>(
            predicate: #Predicate { $0.isStale == true }
        )
        let digests = (try? context.fetch(descriptor)) ?? []
        return Array(Set(digests.map(\.categoryRaw)))
    }
}

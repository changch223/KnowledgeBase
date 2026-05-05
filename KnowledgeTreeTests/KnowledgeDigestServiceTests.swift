//
//  KnowledgeDigestServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 018 — KnowledgeDigestService の 7 ケース。
//  Foundation Models 経由実装と Fallback 実装の両方を mock で隔離検証。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

private typealias Tag = KnowledgeTree.Tag

@MainActor
struct KnowledgeDigestServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    /// Article + Tag (categoryRaw 設定済み) を作成、双方向 link
    @discardableResult
    private func makeArticle(
        url: String,
        categoryRaw: String,
        essence: String?,
        in context: ModelContext
    ) -> Article {
        let article = Article(url: url, title: url)
        context.insert(article)

        let tag = Tag(name: "tag-\(url)", categoryRaw: categoryRaw)
        context.insert(tag)
        article.tags.append(tag)

        if let essence {
            let knowledge = ExtractedKnowledge(
                article: article,
                status: .succeeded
            )
            knowledge.essence = essence
            context.insert(knowledge)
            article.extractedKnowledge = knowledge
        }
        return article
    }

    private var techCategory: KnowledgeTree.Category {
        CategorySeed.allSeeds.first(where: { $0.name == "テクノロジー" })!
    }

    // MARK: - 1. regenerate produces digest with source articles

    @Test func testRegenerateProducesDigestWithSourceArticles() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        makeArticle(url: "a", categoryRaw: "テクノロジー", essence: "Swift の進化", in: context)
        makeArticle(url: "b", categoryRaw: "テクノロジー", essence: "iOS 26 機能", in: context)
        try context.save()

        let session = MockLanguageModelSession()
        session.nextDigestResult = .success(DigestOutput(cards: [
            DigestCardOutput(
                summary: "テクノロジーの最近トピック",
                topKeyFacts: ["Swift 6", "iOS 26", "AI"],
                topEntityNames: ["Apple", "Foundation Models", "Xcode"],
                sourceArticleIDs: []
            )
        ]))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true
        let fallback = FallbackKnowledgeDigestService(context: context)
        let service = FoundationModelsKnowledgeDigestService(
            session: session,
            context: context,
            availability: availability,
            fallback: fallback
        )

        let digests = try await service.regenerate(for: techCategory)

        #expect(digests.count == 1)
        #expect(digests.first?.summary == "テクノロジーの最近トピック")
        #expect(digests.first?.sourceArticles.count == 2)
        #expect(digests.first?.topKeyFacts.count == 3)
    }

    // MARK: - 2. regenerateAllStale skips non-stale

    @Test func testRegenerateAllStaleSkipsNonStale() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        makeArticle(url: "a", categoryRaw: "テクノロジー", essence: "x", in: context)
        try context.save()

        // 既存 (stale=false) Digest を 1 個 insert
        let existing = KnowledgeDigest(
            categoryRaw: "テクノロジー",
            cardIndex: 0,
            summary: "old",
            isStale: false  // not stale
        )
        context.insert(existing)
        try context.save()

        let session = MockLanguageModelSession()
        session.nextDigestResult = .success(DigestOutput(cards: [
            DigestCardOutput(summary: "new", topKeyFacts: [], topEntityNames: [], sourceArticleIDs: [])
        ]))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true
        let fallback = FallbackKnowledgeDigestService(context: context)
        let service = FoundationModelsKnowledgeDigestService(
            session: session,
            context: context,
            availability: availability,
            fallback: fallback
        )

        try await service.regenerateAllStale()

        // session は呼ばれない (stale=false のため)
        #expect(session.digestCallCount == 0)
        // 既存 Digest はそのまま残る
        let descriptor = FetchDescriptor<KnowledgeDigest>()
        let remaining = try context.fetch(descriptor)
        #expect(remaining.count == 1)
        #expect(remaining.first?.summary == "old")
    }

    // MARK: - 3. markStale sets flag

    @Test func testMarkStaleSetsFlag() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let digest = KnowledgeDigest(
            categoryRaw: "テクノロジー",
            cardIndex: 0,
            summary: "x",
            isStale: false
        )
        context.insert(digest)
        try context.save()

        let session = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        let fallback = FallbackKnowledgeDigestService(context: context)
        let service = FoundationModelsKnowledgeDigestService(
            session: session,
            context: context,
            availability: availability,
            fallback: fallback
        )

        service.markStale(for: techCategory)

        #expect(digest.isStale == true)
    }

    // MARK: - 4. fallback when availability unavailable

    @Test func testFallbackWhenAvailabilityUnavailable() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        makeArticle(url: "a", categoryRaw: "テクノロジー", essence: "Swift", in: context)
        try context.save()

        let session = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = false  // unavailable!
        let fallback = FallbackKnowledgeDigestService(context: context)
        let service = FoundationModelsKnowledgeDigestService(
            session: session,
            context: context,
            availability: availability,
            fallback: fallback
        )

        let digests = try await service.regenerate(for: techCategory)

        // Foundation session は呼ばれない
        #expect(session.digestCallCount == 0)
        // Fallback で 1 個生成される
        #expect(digests.count == 1)
        #expect(digests.first?.summary.contains("最近の") == true)
    }

    // MARK: - 5. multi-card split

    @Test func testMultiCardSplitWhenAIReturnsMultipleCards() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        makeArticle(url: "a", categoryRaw: "テクノロジー", essence: "AI 系記事", in: context)
        makeArticle(url: "b", categoryRaw: "テクノロジー", essence: "Mobile 系記事", in: context)
        try context.save()

        let session = MockLanguageModelSession()
        session.nextDigestResult = .success(DigestOutput(cards: [
            DigestCardOutput(
                summary: "AI トピック",
                topKeyFacts: ["a"], topEntityNames: ["x"], sourceArticleIDs: []
            ),
            DigestCardOutput(
                summary: "Mobile トピック",
                topKeyFacts: ["b"], topEntityNames: ["y"], sourceArticleIDs: []
            )
        ]))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true
        let fallback = FallbackKnowledgeDigestService(context: context)
        let service = FoundationModelsKnowledgeDigestService(
            session: session,
            context: context,
            availability: availability,
            fallback: fallback
        )

        let digests = try await service.regenerate(for: techCategory)

        #expect(digests.count == 2)
        #expect(digests[0].cardIndex == 0)
        #expect(digests[1].cardIndex == 1)
        #expect(digests[0].summary == "AI トピック")
        #expect(digests[1].summary == "Mobile トピック")
    }

    // MARK: - 6. idempotent multiple regenerate

    @Test func testIdempotentMultipleRegenerate() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        makeArticle(url: "a", categoryRaw: "テクノロジー", essence: "x", in: context)
        try context.save()

        let session = MockLanguageModelSession()
        session.nextDigestResult = .success(DigestOutput(cards: [
            DigestCardOutput(summary: "v1", topKeyFacts: [], topEntityNames: [], sourceArticleIDs: [])
        ]))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true
        let fallback = FallbackKnowledgeDigestService(context: context)
        let service = FoundationModelsKnowledgeDigestService(
            session: session,
            context: context,
            availability: availability,
            fallback: fallback
        )

        // 2 回 regenerate
        _ = try await service.regenerate(for: techCategory)
        _ = try await service.regenerate(for: techCategory)

        // 結果は常に 1 個 (古いは delete されて新しいだけ残る)
        let descriptor = FetchDescriptor<KnowledgeDigest>()
        let remaining = try context.fetch(descriptor)
        #expect(remaining.count == 1)
    }

    // MARK: - 7. empty category returns empty

    @Test func testEmptyCategoryReturnsEmpty() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        // 記事ゼロ
        try context.save()

        let session = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true
        let fallback = FallbackKnowledgeDigestService(context: context)
        let service = FoundationModelsKnowledgeDigestService(
            session: session,
            context: context,
            availability: availability,
            fallback: fallback
        )

        let digests = try await service.regenerate(for: techCategory)

        #expect(digests.isEmpty)
        #expect(session.digestCallCount == 0)
    }
}

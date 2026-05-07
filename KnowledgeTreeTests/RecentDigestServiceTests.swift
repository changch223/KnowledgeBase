//
//  RecentDigestServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 035 — RecentDigestService 5 ケース。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

@MainActor
struct RecentDigestServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    @discardableResult
    private func makeArticle(
        title: String,
        savedAt: Date,
        essence: String?,
        in context: ModelContext
    ) -> Article {
        let article = Article(url: "https://example.com/\(UUID().uuidString)", title: title, savedAt: savedAt)
        context.insert(article)
        if let essence {
            let knowledge = ExtractedKnowledge(article: article, status: .succeeded)
            knowledge.essence = essence
            context.insert(knowledge)
            article.extractedKnowledge = knowledge
        }
        return article
    }

    // MARK: - 1. since 以降の記事 0 件 → empty

    @Test func testGenerateReturnsEmptyWhenNoArticlesAfterSince() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let oldDate = Date.now.addingTimeInterval(-86400 * 7) // 7 日前
        makeArticle(title: "old", savedAt: oldDate, essence: "old essence", in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = RecentDigestService(session: mockSession, availability: availability)
        let result = try await service.generate(since: Date.now, in: context)

        #expect(result.isEmpty)
        #expect(result.articleCount == 0)
    }

    // MARK: - 2. Foundation Models で 3 段落生成

    @Test func testGenerateUsesFoundationModelsWhenAvailable() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let recent = Date.now.addingTimeInterval(-3600) // 1 時間前
        makeArticle(title: "新記事", savedAt: recent, essence: "Swift 6 が登場", in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextRecentDigestResult = .success(RecentDigestOutput(paragraphs: [
            "段落 1: Swift 6 の話題",
            "段落 2: 新機能の概要",
            "段落 3: 影響と展望"
        ]))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = RecentDigestService(session: mockSession, availability: availability)
        let since = Date.now.addingTimeInterval(-86400)
        let result = try await service.generate(since: since, in: context)

        #expect(result.paragraphs.count == 3)
        #expect(result.paragraphs[0].contains("Swift 6"))
        #expect(result.articleCount == 1)
    }

    // MARK: - 3. Foundation Models 不可 → Fallback で擬似 3 段落

    @Test func testGenerateFallsBackWhenLMUnavailable() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let recent = Date.now.addingTimeInterval(-3600)
        makeArticle(title: "記事 A", savedAt: recent, essence: "essence A", in: context)
        makeArticle(title: "記事 B", savedAt: recent.addingTimeInterval(-100), essence: "essence B", in: context)
        makeArticle(title: "記事 C", savedAt: recent.addingTimeInterval(-200), essence: "essence C", in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = false  // FM 不可

        let service = RecentDigestService(session: mockSession, availability: availability)
        let since = Date.now.addingTimeInterval(-86400)
        let result = try await service.generate(since: since, in: context)

        #expect(!result.isEmpty)
        #expect(result.articleCount == 3)
        #expect(mockSession.recentDigestCallCount == 0) // LM は呼ばれていない
    }

    // MARK: - 4. LM 失敗 → Fallback に切替

    @Test func testGenerateFallsBackOnLMError() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let recent = Date.now.addingTimeInterval(-3600)
        makeArticle(title: "記事", savedAt: recent, essence: "essence", in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextRecentDigestResult = .failure(MockLanguageModelError.safetyFiltered)
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = RecentDigestService(session: mockSession, availability: availability)
        let since = Date.now.addingTimeInterval(-86400)
        let result = try await service.generate(since: since, in: context)

        #expect(!result.isEmpty)
        #expect(result.articleCount == 1)
    }

    // MARK: - 5. 30 件超過 → 最新優先 truncate

    @Test func testGenerateTruncatesTo30Articles() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let now = Date.now
        for i in 0..<50 {
            let savedAt = now.addingTimeInterval(-Double(i) * 3600)
            makeArticle(title: "記事 \(i)", savedAt: savedAt, essence: "essence \(i)", in: context)
        }
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextRecentDigestResult = .success(RecentDigestOutput(paragraphs: ["P1", "P2", "P3"]))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = RecentDigestService(session: mockSession, availability: availability)
        let since = now.addingTimeInterval(-86400 * 7)
        let result = try await service.generate(since: since, in: context)

        #expect(result.articleCount == 30)
    }

    // MARK: - 6. fallbackParagraphs ユーティリティ

    @Test func testFallbackParagraphsGroupsArticles() {
        let now = Date.now
        let articles: [Article] = (0..<6).map { i in
            let a = Article(url: "https://example.com/\(i)", title: "記事 \(i)", savedAt: now)
            return a
        }
        let paragraphs = RecentDigestService.fallbackParagraphs(articles: articles)
        #expect(paragraphs.count <= 3)
        #expect(paragraphs.allSatisfy { !$0.isEmpty })
    }
}

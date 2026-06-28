//
//  BodyExtractionServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 003 — contracts/body-extraction-service.md
//

import Testing
import Foundation
@testable import KnowledgeBase

@MainActor
struct BodyExtractionServiceTests {

    private static let validHTML = """
    <html><body><article>
    <p>Sufficient body text for extraction. Long enough to exceed minimum threshold.</p>
    <p>Second paragraph adds more content. Total length should be over 100 characters.</p>
    <p>Third paragraph ensures comfortable margin above the minimum body length cutoff.</p>
    </article></body></html>
    """

    @Test func extractWithValidRawHTMLProducesSucceededStatus() async {
        let store = MockArticleBodyStore()
        let service = DefaultBodyExtractionService(store: store, minimumBodyLength: 50)
        let article = Article(url: "https://example.com/a", title: "A")
        let enrichment = ArticleEnrichment(article: article, status: .succeeded, rawHTML: Self.validHTML)
        article.enrichment = enrichment

        await service.extract(article: article)

        #expect(store.lastUpsert?.status == .succeeded)
        #expect((store.lastUpsert?.extractedText?.count ?? 0) >= 50)
    }

    @Test func extractWithMissingRawHTMLIsNoOp() async {
        let store = MockArticleBodyStore()
        let service = DefaultBodyExtractionService(store: store)
        let article = Article(url: "https://example.com/a", title: "A")
        // No enrichment / no rawHTML

        await service.extract(article: article)

        #expect(store.upsertCount == 0)
    }

    @Test func extractWithShortResultMarksFailed() async {
        let store = MockArticleBodyStore()
        let service = DefaultBodyExtractionService(store: store, minimumBodyLength: 1000)
        let article = Article(url: "https://example.com/a", title: "A")
        let enrichment = ArticleEnrichment(article: article, status: .succeeded, rawHTML: Self.validHTML)
        article.enrichment = enrichment

        await service.extract(article: article)

        #expect(store.lastUpsert?.status == .failed)
        #expect(store.lastUpsert?.extractedText == nil)
    }

    @Test func extractSkipsAlreadySucceededBody() async {
        let store = MockArticleBodyStore()
        let service = DefaultBodyExtractionService(store: store)
        let article = Article(url: "https://example.com/a", title: "A")
        let enrichment = ArticleEnrichment(article: article, status: .succeeded, rawHTML: Self.validHTML)
        article.enrichment = enrichment
        article.body = ArticleBody(article: article, status: .succeeded, extractedText: "Already done")

        await service.extract(article: article)

        #expect(store.upsertCount == 0)
    }

    @Test func backfillProcessesAllPendingArticles() async {
        let store = MockArticleBodyStore()
        let articleA = Article(url: "https://example.com/a", title: "A")
        let articleB = Article(url: "https://example.com/b", title: "B")
        articleA.enrichment = ArticleEnrichment(article: articleA, status: .succeeded, rawHTML: Self.validHTML)
        articleB.enrichment = ArticleEnrichment(article: articleB, status: .succeeded, rawHTML: Self.validHTML)
        store.pendingArticles = [articleA, articleB]
        let service = DefaultBodyExtractionService(store: store, minimumBodyLength: 50)

        await service.backfillAll()

        #expect(store.upsertCount >= 2)
    }
}

// MARK: - Mock

@MainActor
final class MockArticleBodyStore: ArticleBodyStoreProtocol {
    struct UpsertCall {
        let status: BodyExtractionStatus
        let extractedText: String?
        let extractionVersion: Int
        let lastExtractedAt: Date?
    }

    var calls: [UpsertCall] = []
    var upsertCount: Int { calls.count }
    var lastUpsert: UpsertCall? { calls.last(where: { $0.status != .extracting }) }
    var pendingArticles: [Article] = []
    var shouldThrowOnUpsert = false

    enum MockError: Error { case forced }

    func upsert(
        article: Article,
        status: BodyExtractionStatus,
        extractedText: String?,
        extractionVersion: Int,
        lastExtractedAt: Date?
    ) throws {
        if shouldThrowOnUpsert { throw MockError.forced }
        calls.append(UpsertCall(
            status: status,
            extractedText: extractedText,
            extractionVersion: extractionVersion,
            lastExtractedAt: lastExtractedAt
        ))
    }

    func fetchPendingArticles() throws -> [Article] { pendingArticles }
    func deleteAll() throws { calls.removeAll() }
}

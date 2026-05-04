//
//  ArticleEnrichmentServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 002 — contracts/article-enrichment-service.md
//

import Testing
import Foundation
@testable import KnowledgeTree

@MainActor
struct ArticleEnrichmentServiceTests {

    @Test func enrichWithSuccessfulFetchUpdatesStoreToSucceeded() async {
        let store = MockArticleEnrichmentStore()
        let session = MockURLSession(
            response: .success(html: """
            <title>Test</title>
            <meta name="description" content="Desc">
            """)
        )
        let service = DefaultArticleEnrichmentService(
            session: session,
            store: store,
            backoffSchedule: [.milliseconds(1)]
        )
        let article = Article(url: "https://example.com/a", title: "A")

        await service.enrich(article: article)

        #expect(store.lastUpsert?.status == .succeeded)
        #expect(store.lastUpsert?.canonicalTitle == "Test")
    }

    @Test func enrichWithHTTPSchemeMarksPermanentlyFailed() async {
        let store = MockArticleEnrichmentStore()
        let session = MockURLSession(response: .failure(URLError(.badServerResponse)))
        let service = DefaultArticleEnrichmentService(session: session, store: store)
        let article = Article(url: "http://example.com/a", title: "A")

        await service.enrich(article: article)

        #expect(store.lastUpsert?.status == .permanentlyFailed)
    }

    @Test func enrichSkipsAlreadySucceededArticle() async {
        let store = MockArticleEnrichmentStore()
        let session = MockURLSession(response: .success(html: "<title>X</title>"))
        let service = DefaultArticleEnrichmentService(session: session, store: store)
        let article = Article(url: "https://example.com/a", title: "A")
        article.enrichment = ArticleEnrichment(article: article, status: .succeeded)

        await service.enrich(article: article)

        #expect(store.upsertCount == 0)
    }

    @Test func enrichTriggersBodyExtractionOnSuccess() async {
        let store = MockArticleEnrichmentStore()
        let session = MockURLSession(response: .success(html: "<title>X</title>"))
        let bodyService = MockBodyExtractionService()
        let service = DefaultArticleEnrichmentService(
            session: session,
            store: store,
            bodyExtractionService: bodyService,
            backoffSchedule: [.milliseconds(1)]
        )
        let article = Article(url: "https://example.com/a", title: "A")

        await service.enrich(article: article)
        // Allow detached extraction Task to run
        try? await Task.sleep(for: .milliseconds(50))

        #expect(bodyService.extractCallCount >= 1)
    }
}

// MARK: - Mocks

@MainActor
final class MockArticleEnrichmentStore: ArticleEnrichmentStoreProtocol {
    struct UpsertCall {
        let status: EnrichmentStatus
        let canonicalTitle: String?
        let summary: String?
        let ogImageURL: String?
        let rawHTML: String?
        let retryCount: Int
    }

    var lastUpsert: UpsertCall?
    var upsertCount = 0
    var pendingArticles: [Article] = []
    var shouldThrowOnUpsert = false

    enum MockError: Error { case forced }

    func upsert(
        article: Article,
        status: EnrichmentStatus,
        canonicalTitle: String?,
        summary: String?,
        ogImageURL: String?,
        rawHTML: String?,
        retryCount: Int
    ) throws {
        if shouldThrowOnUpsert { throw MockError.forced }
        upsertCount += 1
        lastUpsert = UpsertCall(
            status: status,
            canonicalTitle: canonicalTitle,
            summary: summary,
            ogImageURL: ogImageURL,
            rawHTML: rawHTML,
            retryCount: retryCount
        )
    }

    func fetchPendingArticles() throws -> [Article] { pendingArticles }
    func deleteAll() throws {}
}

final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    enum MockResponse {
        case success(html: String, status: Int = 200)
        case failure(Error)
    }

    private let response: MockResponse

    init(response: MockResponse) {
        self.response = response
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        switch response {
        case .success(let html, let status):
            let data = html.data(using: .utf8) ?? Data()
            let url = request.url ?? URL(string: "https://example.com/")!
            let response = HTTPURLResponse(
                url: url, statusCode: status, httpVersion: nil, headerFields: nil
            )!
            return (data, response)
        case .failure(let error):
            throw error
        }
    }
}

@MainActor
final class MockBodyExtractionService: BodyExtractionServiceProtocol {
    var extractCallCount = 0
    var backfillCallCount = 0

    func extract(article: Article) async {
        extractCallCount += 1
    }

    func backfillAll() async {
        backfillCallCount += 1
    }

    func cancelAll() {}
}

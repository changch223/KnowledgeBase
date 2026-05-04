//
//  KnowledgeExtractionServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 004 — contracts/knowledge-extraction-service.md
//  Mock LanguageModelSession + Mock ArticleKnowledgeStore + Mock AvailabilityChecker。
//

import Testing
import Foundation
@testable import KnowledgeTree

@MainActor
struct KnowledgeExtractionServiceTests {

    private static let validBody = String(repeating: "本文テキスト。", count: 50)  // 200+ 字

    private func makeService(
        sessionResult: Result<ExtractedKnowledgeOutput, Error> = .success(.fixture()),
        availabilityIsAvailable: Bool = true
    ) -> (DefaultKnowledgeExtractionService, MockArticleKnowledgeStore, MockLanguageModelSession) {
        let session = MockLanguageModelSession()
        session.nextResult = sessionResult
        let extractor = KnowledgeExtractor(session: session)
        let store = MockArticleKnowledgeStore()
        let checker = MockAvailabilityChecker()
        checker.isAvailable = availabilityIsAvailable
        let service = DefaultKnowledgeExtractionService(
            extractor: extractor,
            store: store,
            availabilityChecker: checker
        )
        return (service, store, session)
    }

    private func makeArticleWithBody(_ text: String = validBody) -> Article {
        let article = Article(url: "https://example.com/a", title: "A")
        let body = ArticleBody(article: article, status: .succeeded, extractedText: text)
        article.body = body
        return article
    }

    @Test func extractWithFullOutputMarksSucceeded() async {
        let (service, store, session) = makeService()
        let article = makeArticleWithBody()

        await service.extract(article: article)

        #expect(session.callCount == 1)
        #expect(store.calls.last?.status == .succeeded)
        #expect(store.calls.last?.factCount == 3)
        #expect(store.calls.last?.entityCount == 5)
    }

    @Test func extractWithShortTextIsNoOp() async {
        let (service, store, session) = makeService()
        let article = makeArticleWithBody("短い本文")

        await service.extract(article: article)

        #expect(session.callCount == 0)
        #expect(store.calls.isEmpty)
    }

    @Test func extractWhenAppleIntelligenceUnavailableMarksSkipped() async {
        let (service, store, session) = makeService(availabilityIsAvailable: false)
        let article = makeArticleWithBody()

        await service.extract(article: article)

        #expect(session.callCount == 0)
        #expect(store.calls.last?.status == .skipped)
    }

    @Test func extractAlreadySucceededIsNoOp() async {
        let (service, store, session) = makeService()
        let article = makeArticleWithBody()
        let knowledge = ExtractedKnowledge(article: article, status: .succeeded)
        article.extractedKnowledge = knowledge

        await service.extract(article: article)

        #expect(session.callCount == 0)
        #expect(store.calls.isEmpty)
    }

    @Test func extractWhenModelThrowsMarksFailed() async {
        let (service, store, _) = makeService(
            sessionResult: .failure(MockLanguageModelError.safetyFiltered)
        )
        let article = makeArticleWithBody()

        await service.extract(article: article)

        #expect(store.calls.last?.status == .failed)
    }

    @Test func extractWithPartialOutputMarksPartiallySucceeded() async {
        let partial = ExtractedKnowledgeOutput(
            essence: "Apple は iOS 26 を発表した",
            summary: "詳細な要約",
            keyFacts: [],
            entities: []
        )
        let (service, store, _) = makeService(sessionResult: .success(partial))
        let article = makeArticleWithBody()

        await service.extract(article: article)

        #expect(store.calls.last?.status == .partiallySucceeded)
    }

    @Test func extractWithEmptyOutputMarksFailed() async {
        let empty = ExtractedKnowledgeOutput(
            essence: "", summary: "", keyFacts: [], entities: []
        )
        let (service, store, _) = makeService(sessionResult: .success(empty))
        let article = makeArticleWithBody()

        await service.extract(article: article)

        #expect(store.calls.last?.status == .failed)
    }

    @Test func backfillProcessesMultipleArticles() async {
        let (service, store, session) = makeService()
        let articleA = makeArticleWithBody()
        let articleB = Article(url: "https://example.com/b", title: "B")
        let bodyB = ArticleBody(article: articleB, status: .succeeded, extractedText: Self.validBody)
        articleB.body = bodyB

        store.pendingArticles = [articleA, articleB]

        await service.backfillAll()

        #expect(session.callCount >= 2)
    }

    @Test func determineStatusReturnsCorrectValue() {
        let full = ExtractedKnowledgeOutput.fixture()
        #expect(DefaultKnowledgeExtractionService.determineStatus(output: full) == .succeeded)

        let partial = ExtractedKnowledgeOutput(
            essence: "ess", summary: "sum", keyFacts: [], entities: []
        )
        #expect(DefaultKnowledgeExtractionService.determineStatus(output: partial) == .partiallySucceeded)

        let empty = ExtractedKnowledgeOutput(
            essence: "", summary: "", keyFacts: [], entities: []
        )
        #expect(DefaultKnowledgeExtractionService.determineStatus(output: empty) == .failed)
    }
}

// MARK: - Mocks

@MainActor
final class MockArticleKnowledgeStore: ArticleKnowledgeStoreProtocol {
    struct Call: Equatable {
        let articleID: UUID
        let status: ExtractionStatus
        let essence: String?
        let summary: String?
        let factCount: Int
        let entityCount: Int
    }

    var calls: [Call] = []
    var pendingArticles: [Article] = []
    var shouldThrowOnUpsert = false

    enum MockError: Error { case forced }

    func upsertStatus(article: Article, status: ExtractionStatus) throws {
        if shouldThrowOnUpsert { throw MockError.forced }
        calls.append(Call(
            articleID: article.id, status: status,
            essence: nil, summary: nil, factCount: 0, entityCount: 0
        ))
    }

    func upsertFailure(article: Article, reason: String) throws {
        if shouldThrowOnUpsert { throw MockError.forced }
        calls.append(Call(
            articleID: article.id, status: .failed,
            essence: nil, summary: nil, factCount: 0, entityCount: 0
        ))
    }

    func upsertSucceeded(
        article: Article,
        status: ExtractionStatus,
        output: ExtractedKnowledgeOutput,
        modelVersion: String?,
        durationMs: Int?
    ) throws {
        if shouldThrowOnUpsert { throw MockError.forced }
        calls.append(Call(
            articleID: article.id,
            status: status,
            essence: output.essence,
            summary: output.summary,
            factCount: output.keyFacts.count,
            entityCount: output.entities.count
        ))
    }

    func fetchPendingArticles() throws -> [Article] { pendingArticles }
    func deleteAll() throws { calls.removeAll() }
}

final class MockAvailabilityChecker: AvailabilityChecker, @unchecked Sendable {
    var isAvailable: Bool = true
}

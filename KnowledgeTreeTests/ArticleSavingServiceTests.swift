//
//  ArticleSavingServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 001 / contracts/article-saving-service.md "Tests" 表
//

import Testing
import Foundation
@testable import KnowledgeTree

@MainActor
struct ArticleSavingServiceTests {

    @Test func savesValidHttpsURLWithProvidedTitle() async {
        let store = MockArticleStore()
        let service = DefaultArticleSavingService(store: store)
        let url = URL(string: "https://example.com/article")!
        let result = await service.save(url: url, suppliedTitle: "Example Article")
        guard case .saved = result else {
            Issue.record("Expected .saved, got \(result)")
            return
        }
        #expect((store.articles ?? []).count == 1)
        #expect((store.articles ?? []).first?.title == "Example Article")
        #expect((store.articles ?? []).first?.url == url.absoluteString)
    }

    @Test func returnsMissingURLWhenURLIsNil() async {
        let store = MockArticleStore()
        let service = DefaultArticleSavingService(store: store)
        let result = await service.save(url: nil, suppliedTitle: "Anything")
        #expect(result == .missingURL)
        #expect((store.articles ?? []).isEmpty)
    }

    @Test func returnsUnsupportedSchemeForNonHTTP() async {
        let store = MockArticleStore()
        let service = DefaultArticleSavingService(store: store)
        let url = URL(string: "mailto:foo@bar.com")!
        let result = await service.save(url: url, suppliedTitle: nil)
        #expect(result == .unsupportedScheme)
        #expect((store.articles ?? []).isEmpty)
    }

    @Test func usesHostFallbackWhenTitleIsEmpty() async {
        let store = MockArticleStore()
        let service = DefaultArticleSavingService(store: store)
        let url = URL(string: "https://example.com/article")!
        let result = await service.save(url: url, suppliedTitle: "")
        guard case .saved = result else {
            Issue.record("Expected .saved, got \(result)")
            return
        }
        #expect((store.articles ?? []).first?.title == "example.com")
    }

    @Test func usesHostFallbackWhenTitleIsNil() async {
        let store = MockArticleStore()
        let service = DefaultArticleSavingService(store: store)
        let url = URL(string: "https://example.com/article")!
        let result = await service.save(url: url, suppliedTitle: nil)
        guard case .saved = result else {
            Issue.record("Expected .saved, got \(result)")
            return
        }
        #expect((store.articles ?? []).first?.title == "example.com")
    }

    @Test func detectsDuplicateOnSecondSave() async {
        let store = MockArticleStore()
        let service = DefaultArticleSavingService(store: store)
        let url = URL(string: "https://example.com/article")!
        _ = await service.save(url: url, suppliedTitle: "First")
        let second = await service.save(url: url, suppliedTitle: "Second")
        #expect(second == .duplicate)
        #expect((store.articles ?? []).count == 1)
    }

    @Test func duplicateDoesNotChangeSavedAt() async throws {
        let store = MockArticleStore()
        let service = DefaultArticleSavingService(store: store)
        let url = URL(string: "https://example.com/article")!
        _ = await service.save(url: url, suppliedTitle: "First")
        let originalSavedAt = (store.articles ?? []).first!.savedAt
        try await Task.sleep(for: .milliseconds(20))
        _ = await service.save(url: url, suppliedTitle: "Second")
        #expect((store.articles ?? []).first?.savedAt == originalSavedAt)
    }

    @Test func returnsPersistenceFailureWhenStoreThrows() async {
        let store = MockArticleStore()
        store.shouldThrowOnInsert = true
        let service = DefaultArticleSavingService(store: store)
        let url = URL(string: "https://example.com/article")!
        let result = await service.save(url: url, suppliedTitle: "Anything")
        guard case .persistenceFailure = result else {
            Issue.record("Expected .persistenceFailure, got \(result)")
            return
        }
    }
}

@MainActor
final class MockArticleStore: ArticleStoreProtocol {
    var articles: [Article] = []
    var shouldThrowOnInsert = false
    var shouldThrowOnExists = false

    enum MockError: Error { case forced }

    func exists(url: String) throws -> Bool {
        if shouldThrowOnExists { throw MockError.forced }
        return articles.contains(where: { $0.url == url })
    }

    func insert(_ article: Article) throws {
        if shouldThrowOnInsert { throw MockError.forced }
        articles.append(article)
    }

    func delete(_ article: Article) throws {
        articles.removeAll(where: { $0.id == article.id })
    }

    func fetchAllSortedBySavedAt() throws -> [Article] {
        articles.sorted(by: { $0.savedAt > $1.savedAt })
    }

    func fetchByID(_ id: UUID) throws -> Article? {
        articles.first { $0.id == id }
    }
}

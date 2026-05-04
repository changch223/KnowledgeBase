//
//  SwiftDataArticleStoreTests.swift
//  KnowledgeTreeTests
//
//  spec 001 / Constitution Quality Gate / テスト
//  in-memory ModelContainer (isStoredInMemoryOnly: true) を使う。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

@MainActor
struct SwiftDataArticleStoreTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Article.self, configurations: configuration)
    }

    @Test func insertAndFetchRoundTrip() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        try store.insert(article)
        let all = try store.fetchAllSortedBySavedAt()
        #expect(all.count == 1)
        #expect(all.first?.url == "https://example.com/a")
    }

    @Test func existsReturnsTrueForSavedURL() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleStore(context: container.mainContext)
        let url = "https://example.com/article"
        try store.insert(Article(url: url, title: "Title"))
        #expect(try store.exists(url: url))
        #expect(try !store.exists(url: "https://other.example.com/"))
    }

    @Test func deleteRemovesArticle() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        try store.insert(article)
        try store.delete(article)
        let all = try store.fetchAllSortedBySavedAt()
        #expect(all.isEmpty)
    }

    @Test func fetchAllSortsByMostRecentFirst() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleStore(context: container.mainContext)
        let older = Article(
            url: "https://example.com/older",
            title: "Older",
            savedAt: Date().addingTimeInterval(-100)
        )
        let newer = Article(
            url: "https://example.com/newer",
            title: "Newer",
            savedAt: Date()
        )
        try store.insert(older)
        try store.insert(newer)
        let all = try store.fetchAllSortedBySavedAt()
        #expect(all.count == 2)
        #expect(all[0].url == "https://example.com/newer")
        #expect(all[1].url == "https://example.com/older")
    }
}

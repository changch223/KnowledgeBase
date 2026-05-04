//
//  SwiftDataArticleBodyStoreTests.swift
//  KnowledgeTreeTests
//
//  spec 003 — contracts/article-body-store.md
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

@MainActor
struct SwiftDataArticleBodyStoreTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Article.self, ArticleEnrichment.self, ArticleBody.self,
            configurations: configuration
        )
    }

    @Test func upsertCreatesBodyForArticleWithoutOne() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleBodyStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        container.mainContext.insert(article)

        try store.upsert(
            article: article, status: .succeeded,
            extractedText: "Body text", extractionVersion: 1, lastExtractedAt: Date()
        )

        #expect(article.body != nil)
        #expect(article.body?.extractedText == "Body text")
        #expect(article.body?.status == .succeeded)
    }

    @Test func upsertUpdatesExistingBody() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleBodyStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        container.mainContext.insert(article)

        try store.upsert(
            article: article, status: .extracting,
            extractedText: nil, extractionVersion: 1, lastExtractedAt: Date()
        )
        let firstID = article.body?.id

        try store.upsert(
            article: article, status: .succeeded,
            extractedText: "Updated", extractionVersion: 1, lastExtractedAt: Date()
        )

        #expect(article.body?.id == firstID)
        #expect(article.body?.extractedText == "Updated")
        #expect(article.body?.status == .succeeded)
    }

    @Test func fetchPendingArticlesReturnsEmptyWhenNoEligibleArticles() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleBodyStore(context: container.mainContext)
        // No articles → empty
        let pending = try store.fetchPendingArticles()
        #expect(pending.isEmpty)
    }

    @Test func fetchPendingArticlesExcludesArticlesWithoutRawHTML() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleBodyStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        container.mainContext.insert(article)
        // No enrichment / no rawHTML → not pending
        let pending = try store.fetchPendingArticles()
        #expect(pending.isEmpty)
    }

    @Test func fetchPendingArticlesIncludesArticlesWithRawHTMLAndNoBody() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleBodyStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        let enrichment = ArticleEnrichment(
            article: article, status: .succeeded, rawHTML: "<html>...</html>"
        )
        container.mainContext.insert(article)
        container.mainContext.insert(enrichment)
        article.enrichment = enrichment
        try container.mainContext.save()

        let pending = try store.fetchPendingArticles()
        #expect(pending.contains(where: { $0.id == article.id }))
    }

    @Test func cascadeDeletesBodyWhenArticleDeleted() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleBodyStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        container.mainContext.insert(article)
        try store.upsert(
            article: article, status: .succeeded,
            extractedText: "X", extractionVersion: 1, lastExtractedAt: Date()
        )

        container.mainContext.delete(article)
        try container.mainContext.save()

        var descriptor = FetchDescriptor<ArticleBody>()
        descriptor.fetchLimit = 100
        let remaining = try container.mainContext.fetch(descriptor)
        #expect(remaining.isEmpty)
    }

    @Test func deleteAllRemovesAllBodyRecords() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleBodyStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        container.mainContext.insert(article)
        try store.upsert(
            article: article, status: .succeeded,
            extractedText: "X", extractionVersion: 1, lastExtractedAt: Date()
        )

        try store.deleteAll()

        var descriptor = FetchDescriptor<ArticleBody>()
        descriptor.fetchLimit = 100
        let remaining = try container.mainContext.fetch(descriptor)
        #expect(remaining.isEmpty)
    }
}

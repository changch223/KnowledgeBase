//
//  SwiftDataArticleEnrichmentStoreTests.swift
//  KnowledgeTreeTests
//
//  spec 002 — contracts/article-enrichment-store.md
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeBase

@MainActor
struct SwiftDataArticleEnrichmentStoreTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Article.self, ArticleEnrichment.self, ArticleBody.self,
            configurations: configuration
        )
    }

    @Test func upsertCreatesEnrichmentForArticleWithoutOne() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleEnrichmentStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        container.mainContext.insert(article)

        try store.upsert(
            article: article, status: .succeeded,
            canonicalTitle: "Canonical", summary: "Sum",
            ogImageURL: "https://example.com/og.jpg",
            rawHTML: "<html></html>", retryCount: 0
        )

        #expect(article.enrichment != nil)
        #expect(article.enrichment?.canonicalTitle == "Canonical")
        #expect(article.enrichment?.status == .succeeded)
    }

    @Test func upsertUpdatesExistingEnrichment() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleEnrichmentStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        container.mainContext.insert(article)

        try store.upsert(
            article: article, status: .pending,
            canonicalTitle: nil, summary: nil, ogImageURL: nil, rawHTML: nil, retryCount: 0
        )
        let firstID = article.enrichment?.id

        try store.upsert(
            article: article, status: .succeeded,
            canonicalTitle: "Canonical", summary: nil, ogImageURL: nil, rawHTML: nil, retryCount: 1
        )

        #expect(article.enrichment?.id == firstID)
        #expect(article.enrichment?.canonicalTitle == "Canonical")
        #expect(article.enrichment?.retryCount == 1)
    }

    @Test func fetchPendingArticlesReturnsEmptyWhenAllSucceeded() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleEnrichmentStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        container.mainContext.insert(article)
        try store.upsert(
            article: article, status: .succeeded,
            canonicalTitle: nil, summary: nil, ogImageURL: nil, rawHTML: nil, retryCount: 0
        )

        let pending = try store.fetchPendingArticles()
        #expect(pending.isEmpty)
    }

    @Test func fetchPendingArticlesIncludesArticleWithoutEnrichment() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleEnrichmentStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        container.mainContext.insert(article)

        let pending = try store.fetchPendingArticles()
        #expect(pending.contains(where: { $0.id == article.id }))
    }

    @Test func cascadeDeletesEnrichmentWhenArticleDeleted() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleEnrichmentStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        container.mainContext.insert(article)
        try store.upsert(
            article: article, status: .succeeded,
            canonicalTitle: "X", summary: nil, ogImageURL: nil, rawHTML: nil, retryCount: 0
        )

        container.mainContext.delete(article)
        try container.mainContext.save()

        var descriptor = FetchDescriptor<ArticleEnrichment>()
        descriptor.fetchLimit = 100
        let remaining = try container.mainContext.fetch(descriptor)
        #expect(remaining.isEmpty)
    }
}

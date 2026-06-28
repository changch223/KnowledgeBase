//
//  SwiftDataArticleKnowledgeStoreTests.swift
//  KnowledgeTreeTests
//
//  spec 004 — contracts/article-knowledge-store.md
//  in-memory ModelContainer で決定論的。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeBase

@MainActor
struct SwiftDataArticleKnowledgeStoreTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Article.self, ArticleEnrichment.self, ArticleBody.self,
                ExtractedKnowledge.self, KeyFact.self, KnowledgeEntity.self,
            configurations: configuration
        )
    }

    @Test func upsertStatusCreatesKnowledgeForArticleWithoutOne() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleKnowledgeStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        container.mainContext.insert(article)

        try store.upsertStatus(article: article, status: .skipped)

        #expect(article.extractedKnowledge != nil)
        #expect(article.extractedKnowledge?.status == .skipped)
    }

    @Test func upsertStatusUpdatesExistingKnowledge() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleKnowledgeStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        container.mainContext.insert(article)

        try store.upsertStatus(article: article, status: .pending)
        let firstID = article.extractedKnowledge?.id

        try store.upsertStatus(article: article, status: .extracting)
        #expect(article.extractedKnowledge?.id == firstID)
        #expect(article.extractedKnowledge?.status == .extracting)
    }

    @Test func upsertSucceededCreatesKnowledgeWithChildren() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleKnowledgeStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        container.mainContext.insert(article)

        try store.upsertSucceeded(
            article: article,
            status: .succeeded,
            output: .fixture(),
            modelVersion: "test-1.0",
            durationMs: 5000
        )

        #expect(article.extractedKnowledge != nil)
        #expect(article.extractedKnowledge?.status == .succeeded)
        #expect(article.extractedKnowledge?.essence?.isEmpty == false)
        #expect((article.extractedKnowledge?.keyFacts ?? []).count == 3)
        #expect((article.extractedKnowledge?.entities ?? []).count == 5)
    }

    @Test func upsertSucceededReplacesExistingChildren() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleKnowledgeStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        container.mainContext.insert(article)

        try store.upsertSucceeded(
            article: article, status: .succeeded,
            output: .fixture(), modelVersion: nil, durationMs: nil
        )
        #expect((article.extractedKnowledge?.keyFacts ?? []).count == 3)

        // 新規 output で上書き (1 fact + 1 entity に縮小)
        try store.upsertSucceeded(
            article: article, status: .succeeded,
            output: ExtractedKnowledgeOutput(
                essence: "新しい essence",
                summary: "新しい summary",
                keyFacts: [KeyFactOutput(statement: "新事実", type: .claim)],
                entities: [KnowledgeEntityOutput(name: "新エンティティ", type: .concept, salience: 3)]
            ),
            modelVersion: nil, durationMs: nil
        )

        #expect((article.extractedKnowledge?.keyFacts ?? []).count == 1)
        #expect((article.extractedKnowledge?.entities ?? []).count == 1)
        #expect(article.extractedKnowledge?.essence == "新しい essence")
    }

    @Test func fetchPendingArticlesReturnsEmptyWhenNoEligibleArticles() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleKnowledgeStore(context: container.mainContext)
        let pending = try store.fetchPendingArticles()
        #expect(pending.isEmpty)
    }

    @Test func fetchPendingArticlesIncludesArticleWithBodySucceededAndNoKnowledge() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleKnowledgeStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        let body = ArticleBody(
            article: article,
            status: .succeeded,
            extractedText: "本文..."
        )
        container.mainContext.insert(article)
        container.mainContext.insert(body)
        article.body = body
        try container.mainContext.save()

        let pending = try store.fetchPendingArticles()
        #expect(pending.contains(where: { $0.id == article.id }))
    }

    @Test func cascadeDeletesKnowledgeWhenArticleDeleted() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleKnowledgeStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        container.mainContext.insert(article)
        try store.upsertSucceeded(
            article: article, status: .succeeded,
            output: .fixture(), modelVersion: nil, durationMs: nil
        )

        container.mainContext.delete(article)
        try container.mainContext.save()

        var knowledgeDescriptor = FetchDescriptor<ExtractedKnowledge>()
        knowledgeDescriptor.fetchLimit = 100
        #expect(try container.mainContext.fetch(knowledgeDescriptor).isEmpty)

        var factDescriptor = FetchDescriptor<KeyFact>()
        factDescriptor.fetchLimit = 100
        #expect(try container.mainContext.fetch(factDescriptor).isEmpty)

        var entityDescriptor = FetchDescriptor<KnowledgeEntity>()
        entityDescriptor.fetchLimit = 100
        #expect(try container.mainContext.fetch(entityDescriptor).isEmpty)
    }

    @Test func deleteAllRemovesAllKnowledgeRecords() throws {
        let container = try makeContainer()
        let store = SwiftDataArticleKnowledgeStore(context: container.mainContext)
        let article = Article(url: "https://example.com/a", title: "A")
        container.mainContext.insert(article)
        try store.upsertSucceeded(
            article: article, status: .succeeded,
            output: .fixture(), modelVersion: nil, durationMs: nil
        )

        try store.deleteAll()

        var descriptor = FetchDescriptor<ExtractedKnowledge>()
        descriptor.fetchLimit = 100
        #expect(try container.mainContext.fetch(descriptor).isEmpty)
    }
}

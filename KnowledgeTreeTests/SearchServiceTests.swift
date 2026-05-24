//
//  SearchServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 044 — SearchService 5 ケース。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

@MainActor
struct SearchServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    @discardableResult
    private func makeArticle(
        title: String,
        essence: String? = nil,
        entityNames: [String] = [],
        tagNames: [String] = [],
        savedAt: Date = .now,
        in context: ModelContext
    ) -> Article {
        let article = Article(
            url: "https://example.com/\(UUID().uuidString)",
            title: title,
            savedAt: savedAt
        )
        context.insert(article)
        if essence != nil || !entityNames.isEmpty {
            let knowledge = ExtractedKnowledge(article: article, status: .succeeded)
            knowledge.essence = essence
            for (i, name) in entityNames.enumerated() {
                let entity = KnowledgeEntity(
                    knowledge: knowledge,
                    name: name,
                    typeRaw: EntityTypeStored.organization.rawValue,
                    salience: 5,
                    order: i
                )
                context.insert(entity)
                if knowledge.entities == nil { knowledge.entities = [] }
                knowledge.entities?.append(entity)
            }
            context.insert(knowledge)
            article.extractedKnowledge = knowledge
        }
        for name in tagNames {
            let tag = KnowledgeTree.Tag(name: name)
            context.insert(tag)
            if article.tags == nil { article.tags = [] }
            article.tags?.append(tag)
        }
        return article
    }

    // MARK: - 1. 空 query → 全 articles を score=0 で返す

    @Test func testEmptyQueryReturnsAllArticlesUnranked() throws {
        let container = try makeContainer()
        let context = container.mainContext
        makeArticle(title: "A", in: context)
        makeArticle(title: "B", in: context)
        try context.save()

        let articles = try context.fetch(FetchDescriptor<Article>())
        let results = SearchService.search(query: "  ", in: articles)
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.score == 0 && $0.matchedFields.isEmpty })
    }

    // MARK: - 2. title 完全一致は title 部分一致より上位

    @Test func testExactTitleMatchOutranksPartial() throws {
        let container = try makeContainer()
        let context = container.mainContext
        makeArticle(title: "Swift", in: context)
        makeArticle(title: "Swift 6 とは何か", in: context)
        try context.save()

        let articles = try context.fetch(FetchDescriptor<Article>())
        let results = SearchService.search(query: "Swift", in: articles)
        #expect(results.count == 2)
        #expect(results.first?.article.title == "Swift")
        #expect((results.first?.score ?? 0) > (results.last?.score ?? 0))
    }

    // MARK: - 3. entity match は essence match より高 score

    @Test func testEntityMatchScoresHigherThanEssence() throws {
        let container = try makeContainer()
        let context = container.mainContext
        // essence にだけ含む
        makeArticle(title: "記事 A", essence: "Apple について", in: context)
        // entity に含む
        makeArticle(title: "記事 B", entityNames: ["Apple"], in: context)
        try context.save()

        let articles = try context.fetch(FetchDescriptor<Article>())
        let results = SearchService.search(query: "Apple", in: articles)
        #expect(results.count == 2)
        #expect(results.first?.article.title == "記事 B")
        #expect(results.first?.matchedFields.contains(.entity) == true)
    }

    // MARK: - 4. tag match を matchedFields に含む

    @Test func testTagMatchIncludedInFields() throws {
        let container = try makeContainer()
        let context = container.mainContext
        makeArticle(title: "Untitled", tagNames: ["DevTools"], in: context)
        try context.save()

        let articles = try context.fetch(FetchDescriptor<Article>())
        let results = SearchService.search(query: "DevTools", in: articles)
        #expect(results.count == 1)
        #expect(results.first?.matchedFields.contains(.tag) == true)
    }

    // MARK: - 5. 同 score → savedAt desc tiebreaker

    @Test func testSameScoreSortsBySavedAtDesc() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date.now
        makeArticle(title: "古い記事 keyword", savedAt: now.addingTimeInterval(-3600), in: context)
        makeArticle(title: "新しい記事 keyword", savedAt: now, in: context)
        try context.save()

        let articles = try context.fetch(FetchDescriptor<Article>())
        let results = SearchService.search(query: "keyword", in: articles)
        #expect(results.count == 2)
        #expect(results.first?.article.title == "新しい記事 keyword")
    }
}

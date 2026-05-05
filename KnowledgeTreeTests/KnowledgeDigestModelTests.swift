//
//  KnowledgeDigestModelTests.swift
//  KnowledgeTreeTests
//
//  spec 018 — KnowledgeDigest @Model の 3 ケース。
//  - relationship .nullify: Article 削除で sourceArticles から外れる、Digest 自体は残る
//  - isStale デフォルト false
//  - cardIndex 順序
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

private typealias Tag = KnowledgeTree.Tag

@MainActor
struct KnowledgeDigestModelTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    @Test func testRelationshipNullifyOnArticleDelete() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article = Article(url: "https://example.com/a", title: "A")
        context.insert(article)
        try context.save()

        let digest = KnowledgeDigest(
            categoryRaw: "テクノロジー",
            cardIndex: 0,
            summary: "test",
            sourceArticles: [article]
        )
        context.insert(digest)
        try context.save()

        #expect(digest.sourceArticles.count == 1)

        // Article 削除
        context.delete(article)
        try context.save()

        // Digest は残る
        let descriptor = FetchDescriptor<KnowledgeDigest>()
        let remaining = try context.fetch(descriptor)
        #expect(remaining.count == 1)
        // sourceArticles から記事が外れる (.nullify)
        #expect(remaining.first?.sourceArticles.count == 0)
    }

    @Test func testIsStaleDefaultsFalse() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let digest = KnowledgeDigest(
            categoryRaw: "テクノロジー",
            cardIndex: 0,
            summary: "test"
        )
        context.insert(digest)
        try context.save()

        #expect(digest.isStale == false)
    }

    @Test func testCardIndexOrdering() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let d0 = KnowledgeDigest(categoryRaw: "テクノロジー", cardIndex: 0, summary: "first")
        let d2 = KnowledgeDigest(categoryRaw: "テクノロジー", cardIndex: 2, summary: "third")
        let d1 = KnowledgeDigest(categoryRaw: "テクノロジー", cardIndex: 1, summary: "second")
        context.insert(d2)
        context.insert(d0)
        context.insert(d1)
        try context.save()

        let descriptor = FetchDescriptor<KnowledgeDigest>(
            sortBy: [SortDescriptor(\.cardIndex)]
        )
        let sorted = try context.fetch(descriptor)
        #expect(sorted.map(\.cardIndex) == [0, 1, 2])
        #expect(sorted.map(\.summary) == ["first", "second", "third"])
    }
}

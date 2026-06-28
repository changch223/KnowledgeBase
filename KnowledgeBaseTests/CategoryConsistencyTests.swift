//
//  CategoryConsistencyTests.swift
//  KnowledgeTreeTests
//
//  spec 097 Phase 4 — 概念のカテゴリ不一致検出。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeBase

@Suite(.serialized)
@MainActor
struct CategoryConsistencyTests {

    static let container: ModelContainer = {
        try! ModelContainer(
            for: SharedSchema.all,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }()

    private func clean() {
        let ctx = Self.container.mainContext
        for c in (try? ctx.fetch(FetchDescriptor<ConceptPage>())) ?? [] { ctx.delete(c) }
        for a in (try? ctx.fetch(FetchDescriptor<Article>())) ?? [] { ctx.delete(a) }
        for t in (try? ctx.fetch(FetchDescriptor<KnowledgeBase.Tag>())) ?? [] { ctx.delete(t) }
        try? ctx.save()
    }

    private func makeArticle(tags: [(String, String)]) -> Article {
        let ctx = Self.container.mainContext
        let article = Article(url: "x://\(UUID())", title: "t")
        ctx.insert(article)
        article.tags = tags.map { (name, cat) in
            let tag = KnowledgeBase.Tag(name: name, categoryRaw: cat)
            ctx.insert(tag)
            return tag
        }
        return article
    }

    // タグが 2 つの実カテゴリに割れている → split。
    @Test func detectsSplit() {
        clean()
        let ctx = Self.container.mainContext
        let concept = ConceptPage(name: "医療AI", categoryRaw: "テクノロジー")
        ctx.insert(concept)
        concept.relatedArticles = [makeArticle(tags: [("AI", "テクノロジー"), ("医療", "健康")])]
        try? ctx.save()
        #expect(CategoryConsistency.isSplit(concept))
        #expect(CategoryConsistency.distinctRealCategories(of: concept).count == 2)
    }

    // 全タグ同じ実カテゴリ → split でない。
    @Test func sameCategoryNotSplit() {
        clean()
        let ctx = Self.container.mainContext
        let concept = ConceptPage(name: "Claude", categoryRaw: "テクノロジー")
        ctx.insert(concept)
        concept.relatedArticles = [makeArticle(tags: [("AI", "テクノロジー"), ("LLM", "テクノロジー")])]
        try? ctx.save()
        #expect(!CategoryConsistency.isSplit(concept))
    }

    // その他 は投票から除外 → 実カテゴリ1つなら split でない。
    @Test func otherIsIgnored() {
        clean()
        let ctx = Self.container.mainContext
        let concept = ConceptPage(name: "GitHub", categoryRaw: "テクノロジー")
        ctx.insert(concept)
        concept.relatedArticles = [makeArticle(tags: [("GitHub", "テクノロジー"), ("著者名", "その他")])]
        try? ctx.save()
        #expect(!CategoryConsistency.isSplit(concept))
    }
}

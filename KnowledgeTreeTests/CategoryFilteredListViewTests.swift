//
//  CategoryFilteredListViewTests.swift
//  KnowledgeTreeTests
//
//  spec 016 — CategoryFilter 純関数の 8 ケース。
//  in-memory ModelContainer + Tag/Article fixture。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

// SwiftUI の Tag 型 (Picker/TabView 用) と曖昧化解消 (spec 011-015 同パターン)
private typealias Tag = KnowledgeTree.Tag

@MainActor
struct CategoryFilteredListViewTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Article.self, ArticleEnrichment.self, ArticleBody.self,
                ExtractedKnowledge.self, KeyFact.self, KnowledgeEntity.self,
                Tag.self, KnowledgeChunkProgress.self,
                BackgroundExtractionQueueEntry.self,
            configurations: configuration
        )
    }

    /// 指定 Tag を作って Article 群と双方向リンク。
    @discardableResult
    private func makeTag(
        name: String,
        categoryRaw: String?,
        articleURLs: [String],
        savedAtList: [Date]? = nil,
        in context: ModelContext
    ) -> Tag {
        let tag = Tag(name: name, categoryRaw: categoryRaw)
        context.insert(tag)
        for (i, url) in articleURLs.enumerated() {
            let savedAt = savedAtList?[i] ?? Date()
            // 既存 Article があれば再利用
            let existing = try? context.fetch(FetchDescriptor<Article>(
                predicate: #Predicate { $0.url == url }
            )).first
            let article: Article
            if let existing {
                article = existing
            } else {
                article = Article(url: url, title: url, savedAt: savedAt)
                context.insert(article)
            }
            article.tags.append(tag)
        }
        return tag
    }

    // MARK: - categoryTags

    @Test func testCategoryTagsSortByArticleCountDesc() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let _ = makeTag(name: "Swift", categoryRaw: "テクノロジー", articleURLs: ["a", "b", "c"], in: context)
        let _ = makeTag(name: "iOS", categoryRaw: "テクノロジー", articleURLs: ["d", "e"], in: context)
        let _ = makeTag(name: "AI", categoryRaw: "テクノロジー", articleURLs: ["f"], in: context)
        try context.save()

        let allTags = try context.fetch(FetchDescriptor<Tag>())
        let result = CategoryFilter.categoryTags(allTags, category: CategorySeed.allSeeds[0]) // テクノロジー

        #expect(result.map(\.name) == ["Swift", "iOS", "AI"])
    }

    @Test func testCategoryTagsFiltersOutOtherCategories() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let _ = makeTag(name: "Swift", categoryRaw: "テクノロジー", articleURLs: ["a"], in: context)
        let _ = makeTag(name: "投資", categoryRaw: "経済", articleURLs: ["b", "c"], in: context)
        try context.save()

        let allTags = try context.fetch(FetchDescriptor<Tag>())
        let techCategory = CategorySeed.allSeeds.first { $0.name == "テクノロジー" }!
        let result = CategoryFilter.categoryTags(allTags, category: techCategory)

        #expect(result.count == 1)
        #expect(result.first?.name == "Swift")
    }

    // MARK: - displayedTags / hiddenTagCount

    @Test func testDisplayedTagsCollapsedShowsTopFive() throws {
        let container = try makeContainer()
        let context = container.mainContext
        for i in 0..<6 {
            _ = makeTag(name: "tag\(i)", categoryRaw: "テクノロジー", articleURLs: ["url\(i)"], in: context)
        }
        try context.save()

        let allTags = try context.fetch(FetchDescriptor<Tag>())
        let categoryTags = CategoryFilter.categoryTags(allTags, category: CategorySeed.allSeeds[0])
        let displayed = CategoryFilter.displayedTags(categoryTags, showsAll: false)
        let hidden = CategoryFilter.hiddenTagCount(categoryTags)

        #expect(displayed.count == 5)
        #expect(hidden == 1)
    }

    @Test func testDisplayedTagsExpandedShowsAll() throws {
        let container = try makeContainer()
        let context = container.mainContext
        for i in 0..<6 {
            _ = makeTag(name: "tag\(i)", categoryRaw: "テクノロジー", articleURLs: ["url\(i)"], in: context)
        }
        try context.save()

        let allTags = try context.fetch(FetchDescriptor<Tag>())
        let categoryTags = CategoryFilter.categoryTags(allTags, category: CategorySeed.allSeeds[0])
        let displayed = CategoryFilter.displayedTags(categoryTags, showsAll: true)

        #expect(displayed.count == 6)
    }

    @Test func testHiddenTagCountZeroWhenFiveOrFewer() throws {
        let container = try makeContainer()
        let context = container.mainContext
        for i in 0..<5 {
            _ = makeTag(name: "tag\(i)", categoryRaw: "テクノロジー", articleURLs: ["url\(i)"], in: context)
        }
        try context.save()

        let allTags = try context.fetch(FetchDescriptor<Tag>())
        let categoryTags = CategoryFilter.categoryTags(allTags, category: CategorySeed.allSeeds[0])

        #expect(CategoryFilter.hiddenTagCount(categoryTags) == 0)
    }

    // MARK: - filteredArticles

    @Test func testFilteredArticlesEmptySelectionShowsAllUnion() throws {
        // テクノロジー = "Swift" {A, B} + "iOS" {A, C} → union = {A, B, C}
        let container = try makeContainer()
        let context = container.mainContext
        let _ = makeTag(name: "Swift", categoryRaw: "テクノロジー", articleURLs: ["A", "B"], in: context)
        let _ = makeTag(name: "iOS", categoryRaw: "テクノロジー", articleURLs: ["A", "C"], in: context)
        try context.save()

        let allTags = try context.fetch(FetchDescriptor<Tag>())
        let categoryTags = CategoryFilter.categoryTags(allTags, category: CategorySeed.allSeeds[0])
        let result = CategoryFilter.filteredArticles(categoryTags, selectedNames: [])

        #expect(result.count == 3)
        let urls = Set(result.map(\.url))
        #expect(urls == ["A", "B", "C"])
    }

    @Test func testFilteredArticlesSingleSelectionShowsOnlyThatTag() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let _ = makeTag(name: "Swift", categoryRaw: "テクノロジー", articleURLs: ["A", "B"], in: context)
        let _ = makeTag(name: "iOS", categoryRaw: "テクノロジー", articleURLs: ["C"], in: context)
        try context.save()

        let allTags = try context.fetch(FetchDescriptor<Tag>())
        let categoryTags = CategoryFilter.categoryTags(allTags, category: CategorySeed.allSeeds[0])
        let result = CategoryFilter.filteredArticles(categoryTags, selectedNames: ["Swift"])

        #expect(result.count == 2)
        #expect(Set(result.map(\.url)) == ["A", "B"])
    }

    @Test func testFilteredArticlesMultiSelectionUsesOR() throws {
        // Swift {A}, iOS {B}, AI {C} → 選択 {Swift, iOS} → {A, B} OR
        let container = try makeContainer()
        let context = container.mainContext
        let _ = makeTag(name: "Swift", categoryRaw: "テクノロジー", articleURLs: ["A"], in: context)
        let _ = makeTag(name: "iOS", categoryRaw: "テクノロジー", articleURLs: ["B"], in: context)
        let _ = makeTag(name: "AI", categoryRaw: "テクノロジー", articleURLs: ["C"], in: context)
        try context.save()

        let allTags = try context.fetch(FetchDescriptor<Tag>())
        let categoryTags = CategoryFilter.categoryTags(allTags, category: CategorySeed.allSeeds[0])
        let result = CategoryFilter.filteredArticles(categoryTags, selectedNames: ["Swift", "iOS"])

        #expect(result.count == 2)
        #expect(Set(result.map(\.url)) == ["A", "B"])
    }

    @Test func testFilteredArticlesSortBySavedAtDesc() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let oldDate = now.addingTimeInterval(-3600 * 24 * 7)
        let midDate = now.addingTimeInterval(-3600 * 24)
        let _ = makeTag(
            name: "Swift",
            categoryRaw: "テクノロジー",
            articleURLs: ["old", "mid", "new"],
            savedAtList: [oldDate, midDate, now],
            in: context
        )
        try context.save()

        let allTags = try context.fetch(FetchDescriptor<Tag>())
        let categoryTags = CategoryFilter.categoryTags(allTags, category: CategorySeed.allSeeds[0])
        let result = CategoryFilter.filteredArticles(categoryTags, selectedNames: [])

        #expect(result.map(\.url) == ["new", "mid", "old"])
    }
}

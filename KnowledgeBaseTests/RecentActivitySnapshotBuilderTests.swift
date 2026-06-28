//
//  RecentActivitySnapshotBuilderTests.swift
//  KnowledgeTreeTests
//
//  spec 011 — contracts/recent-activity-cards.md 7 ケース。
//  時刻注入のため `sevenDaysAgo` を引数で渡す。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeBase

// SwiftUI も `Tag` 型 (Picker/TabView 用) を持つため、
// `@testable import KnowledgeBase` 経由で曖昧化する。明示 typealias で解決。
private typealias Tag = KnowledgeBase.Tag

@MainActor
struct RecentActivitySnapshotBuilderTests {

    // MARK: - Test fixture

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

    /// 1 つの article + (optional) entities を作成し、tag に紐づける。
    @discardableResult
    private func addArticle(
        toTag tag: Tag,
        savedAt: Date,
        urlSuffix: String,
        entities: [(name: String, salience: Int)] = [],
        in context: ModelContext
    ) -> Article {
        let article = Article(
            url: "https://example.com/\(urlSuffix)",
            title: urlSuffix,
            savedAt: savedAt
        )
        context.insert(article)
        article.tags?.append(tag)
        if !entities.isEmpty {
            let knowledge = ExtractedKnowledge(article: article, status: .succeeded)
            context.insert(knowledge)
            article.extractedKnowledge = knowledge
            for (idx, e) in entities.enumerated() {
                let entity = KnowledgeEntity(
                    knowledge: knowledge,
                    name: e.name,
                    typeRaw: "concept",
                    salience: e.salience,
                    order: idx
                )
                context.insert(entity)
                knowledge.entities?.append(entity)
            }
        }
        return article
    }

    private let now = Date(timeIntervalSince1970: 1_780_000_000)
    private var sevenDaysAgo: Date { now.addingTimeInterval(-7 * 86400) }
    private var threeDaysAgo: Date { now.addingTimeInterval(-3 * 86400) }
    private var tenDaysAgo: Date { now.addingTimeInterval(-10 * 86400) }

    private func allEntities(in context: ModelContext) throws -> [KnowledgeEntity] {
        let descriptor = FetchDescriptor<KnowledgeEntity>()
        return try context.fetch(descriptor)
    }

    // MARK: - Tests

    @Test func testEmptyTagsReturnsZeroSnapshot() throws {
        let snap = RecentActivitySnapshotBuilder.build(
            tags: [],
            entities: [],
            sevenDaysAgo: sevenDaysAgo
        )
        #expect(snap.articlesThisWeek == 0)
        #expect(snap.growingTags.isEmpty)
        #expect(snap.newConnections.isEmpty)
    }

    @Test func testArticlesThisWeekOnlyCountsRecent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let tag = Tag(name: "swift")
        context.insert(tag)
        addArticle(toTag: tag, savedAt: threeDaysAgo, urlSuffix: "recent1", in: context)
        addArticle(toTag: tag, savedAt: threeDaysAgo, urlSuffix: "recent2", in: context)
        addArticle(toTag: tag, savedAt: tenDaysAgo, urlSuffix: "old1", in: context)

        let snap = RecentActivitySnapshotBuilder.build(
            tags: [tag],
            entities: [],
            sevenDaysAgo: sevenDaysAgo
        )
        #expect(snap.articlesThisWeek == 2)
    }

    @Test func testGrowingTagsReturnsTop3DescendingByCount() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // tagA: 3 records, tagB: 5, tagC: 1, tagD: 4, tagE: 2 → Top3: B(5), D(4), A(3)
        let tagA = Tag(name: "a"); context.insert(tagA)
        let tagB = Tag(name: "b"); context.insert(tagB)
        let tagC = Tag(name: "c"); context.insert(tagC)
        let tagD = Tag(name: "d"); context.insert(tagD)
        let tagE = Tag(name: "e"); context.insert(tagE)
        for i in 0..<3 { addArticle(toTag: tagA, savedAt: threeDaysAgo, urlSuffix: "a\(i)", in: context) }
        for i in 0..<5 { addArticle(toTag: tagB, savedAt: threeDaysAgo, urlSuffix: "b\(i)", in: context) }
        for i in 0..<1 { addArticle(toTag: tagC, savedAt: threeDaysAgo, urlSuffix: "c\(i)", in: context) }
        for i in 0..<4 { addArticle(toTag: tagD, savedAt: threeDaysAgo, urlSuffix: "d\(i)", in: context) }
        for i in 0..<2 { addArticle(toTag: tagE, savedAt: threeDaysAgo, urlSuffix: "e\(i)", in: context) }

        let snap = RecentActivitySnapshotBuilder.build(
            tags: [tagA, tagB, tagC, tagD, tagE],
            entities: [],
            sevenDaysAgo: sevenDaysAgo
        )
        #expect(snap.growingTags.count == 3)
        #expect(snap.growingTags[0].name == "b")
        #expect(snap.growingTags[0].count == 5)
        #expect(snap.growingTags[1].name == "d")
        #expect(snap.growingTags[1].count == 4)
        #expect(snap.growingTags[2].name == "a")
        #expect(snap.growingTags[2].count == 3)
    }

    @Test func testGrowingTagsEmptyWhenNoRecentArticles() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let tag = Tag(name: "old"); context.insert(tag)
        addArticle(toTag: tag, savedAt: tenDaysAgo, urlSuffix: "x", in: context)

        let snap = RecentActivitySnapshotBuilder.build(
            tags: [tag],
            entities: [],
            sevenDaysAgo: sevenDaysAgo
        )
        #expect(snap.growingTags.isEmpty)
    }

    @Test func testNewConnectionsOnlyReturnsFirstAppearance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let tag = Tag(name: "ai"); context.insert(tag)

        // 旧 entity "openai" は 10 日前から存在
        addArticle(
            toTag: tag,
            savedAt: tenDaysAgo,
            urlSuffix: "old",
            entities: [(name: "openai", salience: 5)],
            in: context
        )
        // 新 entity "anthropic" は 3 日前に初出現
        addArticle(
            toTag: tag,
            savedAt: threeDaysAgo,
            urlSuffix: "new1",
            entities: [(name: "anthropic", salience: 4)],
            in: context
        )
        // 新 entity "claude" は 3 日前に初出現
        addArticle(
            toTag: tag,
            savedAt: threeDaysAgo,
            urlSuffix: "new2",
            entities: [(name: "claude", salience: 3)],
            in: context
        )

        let entities = try allEntities(in: context)
        let snap = RecentActivitySnapshotBuilder.build(
            tags: [tag],
            entities: entities,
            sevenDaysAgo: sevenDaysAgo
        )
        // openai は除外、anthropic + claude が新繋がりとしてペア化される
        #expect(snap.newConnections.count == 1)
        let pair = snap.newConnections[0]
        #expect(pair.first == "anthropic")
        #expect(pair.second == "claude")
    }

    @Test func testNewConnectionsLimitedTo2Pairs() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let tag = Tag(name: "many"); context.insert(tag)

        // 5 つの新 entity を 7 日以内に追加 (salience 5,4,3,2,1)
        // → ペア化: (5,4), (3,2) で 2 ペア。salience=1 はあぶれる
        let salienceList = [5, 4, 3, 2, 1]
        for (i, s) in salienceList.enumerated() {
            addArticle(
                toTag: tag,
                savedAt: threeDaysAgo,
                urlSuffix: "art\(i)",
                entities: [(name: "ent\(s)", salience: s)],
                in: context
            )
        }
        let entities = try allEntities(in: context)
        let snap = RecentActivitySnapshotBuilder.build(
            tags: [tag],
            entities: entities,
            sevenDaysAgo: sevenDaysAgo
        )
        #expect(snap.newConnections.count == 2)
        // 上位 4 entity (salience 5,4,3,2) でペア化
        #expect(snap.newConnections[0].first == "ent5")
        #expect(snap.newConnections[0].second == "ent4")
        #expect(snap.newConnections[1].first == "ent3")
        #expect(snap.newConnections[1].second == "ent2")
    }

    @Test func testEntityNameNormalization() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let tag = Tag(name: "test"); context.insert(tag)

        // "OpenAI" / "openai" / " OpenAI " は同一視 → 旧 entity 扱い
        addArticle(
            toTag: tag,
            savedAt: tenDaysAgo,  // 旧
            urlSuffix: "v1",
            entities: [(name: "OpenAI", salience: 5)],
            in: context
        )
        addArticle(
            toTag: tag,
            savedAt: threeDaysAgo,  // 新だが name 重複なので新繋がり扱いしない
            urlSuffix: "v2",
            entities: [(name: " openai ", salience: 5)],
            in: context
        )
        let entities = try allEntities(in: context)
        let snap = RecentActivitySnapshotBuilder.build(
            tags: [tag],
            entities: entities,
            sevenDaysAgo: sevenDaysAgo
        )
        // 唯一の name は normalize されて旧扱い → newConnections は空
        #expect(snap.newConnections.isEmpty)
    }
}

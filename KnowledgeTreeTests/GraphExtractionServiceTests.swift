//
//  GraphExtractionServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 040 — GraphExtractionService 10 ケース。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

private typealias Tag = KnowledgeTree.Tag

@MainActor
struct GraphExtractionServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    @discardableResult
    private func makeArticle(
        url: String,
        categoryRaw: String,
        essence: String?,
        entityNames: [String],
        in context: ModelContext
    ) -> Article {
        let article = Article(url: url, title: url)
        context.insert(article)
        // Tag 経由で Category 解決
        let tag = Tag(name: "tag-\(url)", categoryRaw: categoryRaw)
        context.insert(tag)
        article.tags?.append(tag)

        let knowledge = ExtractedKnowledge(article: article, status: .succeeded)
        knowledge.essence = essence
        for (i, name) in entityNames.enumerated() {
            let entity = KnowledgeEntity(
                knowledge: knowledge,
                name: name,
                typeRaw: EntityTypeStored.organization.rawValue,
                salience: 5 - i,
                order: i
            )
            context.insert(entity)
            knowledge.entities?.append(entity)
        }
        context.insert(knowledge)
        article.extractedKnowledge = knowledge
        return article
    }

    // MARK: - 1. AI が triple を返す → GraphNode + GraphEdge upsert

    @Test func testExtractCreatesNodesAndEdgesFromAITriples() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article = makeArticle(
            url: "a1",
            categoryRaw: "テクノロジー",
            essence: "Apple が Swift 6 をリリース",
            entityNames: ["Apple", "Swift 6"],
            in: context
        )
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextGraphTriplesResult = .success(GraphTripleOutput(triples: [
            GraphTripleItem(subject: "Apple", predicate: "release", object: "Swift 6", confidence: 0.9)
        ]))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = GraphExtractionService(
            context: context, session: mockSession, availability: availability
        )
        await service.extract(article: article)

        let nodes = try context.fetch(FetchDescriptor<GraphNode>())
        #expect(nodes.count == 2)
        #expect(nodes.contains(where: { $0.name == "Apple" }))
        #expect(nodes.contains(where: { $0.name == "Swift 6" }))

        let edges = try context.fetch(FetchDescriptor<GraphEdge>())
        #expect(edges.count == 1)
        #expect(edges.first?.label == "release")
        #expect(edges.first?.confidence == 0.9)
        #expect(edges.first?.isUncertain == false)
        #expect(edges.first?.weight == 1)
    }

    // MARK: - 2. confidence < 0.5 は silent skip

    @Test func testExtractSkipsLowConfidenceTriples() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article = makeArticle(
            url: "a", categoryRaw: "テクノロジー", essence: "x",
            entityNames: ["A", "B"], in: context
        )
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextGraphTriplesResult = .success(GraphTripleOutput(triples: [
            GraphTripleItem(subject: "A", predicate: "x", object: "B", confidence: 0.3)
        ]))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = GraphExtractionService(
            context: context, session: mockSession, availability: availability
        )
        await service.extract(article: article)

        let edges = try context.fetch(FetchDescriptor<GraphEdge>())
        #expect(edges.isEmpty)
    }

    // MARK: - 3. 中確信 (0.5-0.7) → isUncertain = true

    @Test func testExtractMarksUncertainEdgesInMidRange() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article = makeArticle(
            url: "a", categoryRaw: "テクノロジー", essence: "x",
            entityNames: ["A", "B"], in: context
        )
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextGraphTriplesResult = .success(GraphTripleOutput(triples: [
            GraphTripleItem(subject: "A", predicate: "maybe", object: "B", confidence: 0.6)
        ]))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = GraphExtractionService(
            context: context, session: mockSession, availability: availability
        )
        await service.extract(article: article)

        let edges = try context.fetch(FetchDescriptor<GraphEdge>())
        #expect(edges.count == 1)
        #expect(edges.first?.isUncertain == true)
        #expect(edges.first?.label == "maybe")
    }

    // MARK: - 4. AI 不可端末 → Fallback で entity 共起 (label=nil)

    @Test func testExtractFallsBackToCooccurrenceWhenLMUnavailable() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article = makeArticle(
            url: "a", categoryRaw: "テクノロジー", essence: "x",
            entityNames: ["A", "B", "C"], in: context
        )
        try context.save()

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = false

        let service = GraphExtractionService(
            context: context, session: mockSession, availability: availability
        )
        await service.extract(article: article)

        let edges = try context.fetch(FetchDescriptor<GraphEdge>())
        // 3 entities → C(3,2) = 3 pairs = 3 edges
        #expect(edges.count == 3)
        // 全部共起 (label=nil)
        #expect(edges.allSatisfy { $0.label == nil })
        #expect(mockSession.graphTriplesCallCount == 0)
    }

    // MARK: - 5. AI 失敗 → Fallback に切替

    @Test func testExtractFallsBackOnAIError() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article = makeArticle(
            url: "a", categoryRaw: "テクノロジー", essence: "x",
            entityNames: ["A", "B"], in: context
        )
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextGraphTriplesResult = .failure(MockLanguageModelError.safetyFiltered)
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = GraphExtractionService(
            context: context, session: mockSession, availability: availability
        )
        await service.extract(article: article)

        let edges = try context.fetch(FetchDescriptor<GraphEdge>())
        // Fallback で共起 1 edge
        #expect(edges.count == 1)
        #expect(edges.first?.label == nil)
    }

    // MARK: - 6. Category 未解決なら skip

    @Test func testExtractSkipsWhenCategoryUnresolved() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article = Article(url: "no-tag", title: "no-tag")
        context.insert(article)
        let knowledge = ExtractedKnowledge(article: article, status: .succeeded)
        context.insert(knowledge)
        article.extractedKnowledge = knowledge
        try context.save()

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = GraphExtractionService(
            context: context, session: mockSession, availability: availability
        )
        await service.extract(article: article)

        let nodes = try context.fetch(FetchDescriptor<GraphNode>())
        #expect(nodes.isEmpty)
        #expect(mockSession.graphTriplesCallCount == 0)
    }

    // MARK: - 7. 同 triple の重複 → weight++ + confidence max

    @Test func testExtractUpsertsExistingEdgeAndIncrementsWeight() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article1 = makeArticle(
            url: "a1", categoryRaw: "テクノロジー", essence: "x",
            entityNames: ["Apple", "Swift 6"], in: context
        )
        let article2 = makeArticle(
            url: "a2", categoryRaw: "テクノロジー", essence: "y",
            entityNames: ["Apple", "Swift 6"], in: context
        )
        try context.save()

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = GraphExtractionService(
            context: context, session: mockSession, availability: availability
        )

        // 1 回目: confidence 0.7
        mockSession.nextGraphTriplesResult = .success(GraphTripleOutput(triples: [
            GraphTripleItem(subject: "Apple", predicate: "release", object: "Swift 6", confidence: 0.7)
        ]))
        await service.extract(article: article1)

        // 2 回目: confidence 0.9
        mockSession.nextGraphTriplesResult = .success(GraphTripleOutput(triples: [
            GraphTripleItem(subject: "Apple", predicate: "release", object: "Swift 6", confidence: 0.9)
        ]))
        await service.extract(article: article2)

        let edges = try context.fetch(FetchDescriptor<GraphEdge>())
        #expect(edges.count == 1)
        #expect(edges.first?.weight == 2)
        #expect(edges.first?.confidence == 0.9)
        // 0.9 >= 0.7 → isUncertain=false
        #expect(edges.first?.isUncertain == false)
    }

    // MARK: - 8. self-loop は除外

    @Test func testExtractSkipsSelfLoop() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article = makeArticle(
            url: "a", categoryRaw: "テクノロジー", essence: "x",
            entityNames: ["A"], in: context
        )
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextGraphTriplesResult = .success(GraphTripleOutput(triples: [
            GraphTripleItem(subject: "A", predicate: "self", object: "A", confidence: 0.9)
        ]))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = GraphExtractionService(
            context: context, session: mockSession, availability: availability
        )
        await service.extract(article: article)

        let edges = try context.fetch(FetchDescriptor<GraphEdge>())
        #expect(edges.isEmpty)
    }

    // MARK: - 9. Category 内 30 node 上限 → salience 低を deactivate (AI 経路、35 triple)

    @Test func testExtractEnforcesNodeLimitDeactivatesLowSalience() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = GraphExtractionService(
            context: context, session: mockSession, availability: availability
        )

        // AI 経路: 35 個の異なる subject-object ペアを返す (35 entity)
        // 確信度高で全部採用
        var triples: [GraphTripleItem] = []
        // 1 つの hub 「Hub」と 35 個の周辺 entity (Hub と相互接続、35 node 生成)
        for i in 0..<35 {
            triples.append(GraphTripleItem(
                subject: "Hub", predicate: "rel-\(i)", object: "E-\(i)", confidence: 0.9
            ))
        }
        mockSession.nextGraphTriplesResult = .success(GraphTripleOutput(triples: triples))

        let article = makeArticle(
            url: "a", categoryRaw: "テクノロジー", essence: "x",
            entityNames: ["Hub"], in: context
        )
        try context.save()

        await service.extract(article: article)

        let allNodes = try context.fetch(FetchDescriptor<GraphNode>())
        let activeNodes = allNodes.filter { $0.isActive }
        // active node は 30 以下に制限
        #expect(activeNodes.count <= 30)
        // 合計 node 数は Hub + 35 周辺 entity = 36 (5 inactive あり)
        #expect(allNodes.count == 36)
        let inactiveNodes = allNodes.filter { !$0.isActive }
        #expect(!inactiveNodes.isEmpty)
    }

    // MARK: - 10. 同 article の重複 mention 防止

    @Test func testExtractAvoidsDuplicateMentionForSameArticle() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article = makeArticle(
            url: "a", categoryRaw: "テクノロジー", essence: "x",
            entityNames: ["Apple", "Swift 6"], in: context
        )
        try context.save()

        let mockSession = MockLanguageModelSession()
        // 同記事で同 triple を 2 度抽出 (重複)
        mockSession.nextGraphTriplesResult = .success(GraphTripleOutput(triples: [
            GraphTripleItem(subject: "Apple", predicate: "release", object: "Swift 6", confidence: 0.9),
            GraphTripleItem(subject: "Apple", predicate: "release", object: "Swift 6", confidence: 0.9)
        ]))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = GraphExtractionService(
            context: context, session: mockSession, availability: availability
        )
        await service.extract(article: article)

        let nodes = try context.fetch(FetchDescriptor<GraphNode>())
        let apple = nodes.first(where: { $0.name == "Apple" })
        // 同記事の重複 mention は防止 (count == 1、SwiftData @Relationship は
        // 一方向 inverse なしのため articles.count は in-memory test で
        // 即時反映されない場合あり、mentionCount で検証)
        #expect(apple?.mentionCount == 1)
    }
}

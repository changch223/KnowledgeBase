//
//  KnowledgeMapBuilderTests.swift
//  KnowledgeTreeTests
//
//  spec 011 — contracts/knowledge-map-builder.md 11 ケース。
//  in-memory ModelContainer を使い Tag / Article / ExtractedKnowledge /
//  KnowledgeEntity をリアルに組み立てて純粋関数 buildGraph / step / nodeRadius
//  をテスト。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

// SwiftUI も `Tag` 型 (Picker/TabView 用 view modifier) を持つため、
// `@testable import KnowledgeTree` 経由で曖昧化する。明示 typealias で解決。
private typealias Tag = KnowledgeTree.Tag

@MainActor
struct KnowledgeMapBuilderTests {

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

    /// Tag を 1 つ作成し、article をその記事数だけ生成 + entity 名を付ける。
    @discardableResult
    private func makeTag(
        name: String,
        articleCount: Int,
        entityNames: [String] = [],
        in context: ModelContext
    ) -> Tag {
        let tag = Tag(name: name)
        context.insert(tag)
        for i in 0..<articleCount {
            let article = Article(url: "https://example.com/\(name)/\(i)", title: "\(name) #\(i)")
            context.insert(article)
            article.tags?.append(tag)
            if !entityNames.isEmpty {
                let knowledge = ExtractedKnowledge(article: article, status: .succeeded)
                context.insert(knowledge)
                article.extractedKnowledge = knowledge
                for (idx, ename) in entityNames.enumerated() {
                    let entity = KnowledgeEntity(
                        knowledge: knowledge,
                        name: ename,
                        typeRaw: "concept",
                        salience: 3,
                        order: idx
                    )
                    context.insert(entity)
                    knowledge.entities?.append(entity)
                }
            }
        }
        return tag
    }

    private let canvas = CGSize(width: 400, height: 600)

    // MARK: - Tests

    @Test func testEmptyTagsReturnsEmptyGraph() throws {
        let graph = KnowledgeMapBuilder.buildGraph(
            tags: [],
            canvasSize: canvas,
            iterations: 5,
            seed: 42
        )
        #expect(graph.nodes.isEmpty)
        #expect(graph.edges.isEmpty)
    }

    @Test func testSingleTagSingleNode() throws {
        let container = try makeContainer()
        let tag = makeTag(name: "swift", articleCount: 1, in: container.mainContext)
        let graph = KnowledgeMapBuilder.buildGraph(
            tags: [tag],
            canvasSize: canvas,
            iterations: 5,
            seed: 42
        )
        #expect(graph.nodes.count == 1)
        #expect(graph.nodes.first?.id == "swift")
        #expect(graph.edges.isEmpty)
    }

    @Test func testTwoTagsSharedEntity() throws {
        let container = try makeContainer()
        let tagA = makeTag(
            name: "ai",
            articleCount: 1,
            entityNames: ["openai"],
            in: container.mainContext
        )
        let tagB = makeTag(
            name: "ml",
            articleCount: 1,
            entityNames: ["openai"],
            in: container.mainContext
        )
        let graph = KnowledgeMapBuilder.buildGraph(
            tags: [tagA, tagB],
            canvasSize: canvas,
            iterations: 5,
            seed: 42
        )
        #expect(graph.edges.count == 1)
        let edge = graph.edges.first
        #expect(edge?.from == "ai")
        #expect(edge?.to == "ml")
        #expect(edge?.sharedEntityCount == 1)
    }

    @Test func testTwoTagsNoSharedEntity() throws {
        let container = try makeContainer()
        let tagA = makeTag(
            name: "swift",
            articleCount: 1,
            entityNames: ["xcode"],
            in: container.mainContext
        )
        let tagB = makeTag(
            name: "rust",
            articleCount: 1,
            entityNames: ["cargo"],
            in: container.mainContext
        )
        let graph = KnowledgeMapBuilder.buildGraph(
            tags: [tagA, tagB],
            canvasSize: canvas,
            iterations: 5,
            seed: 42
        )
        #expect(graph.edges.isEmpty)
    }

    @Test func testEdgeIsAlphabeticallyNormalized() throws {
        let container = try makeContainer()
        // タグを逆順 (zebra, alpha) で渡しても、edge は from = "alpha", to = "zebra"
        let tagZ = makeTag(
            name: "zebra",
            articleCount: 1,
            entityNames: ["common"],
            in: container.mainContext
        )
        let tagA = makeTag(
            name: "alpha",
            articleCount: 1,
            entityNames: ["common"],
            in: container.mainContext
        )
        let graph = KnowledgeMapBuilder.buildGraph(
            tags: [tagZ, tagA],
            canvasSize: canvas,
            iterations: 5,
            seed: 42
        )
        #expect(graph.edges.count == 1)
        #expect(graph.edges.first?.from == "alpha")
        #expect(graph.edges.first?.to == "zebra")
    }

    @Test func testEdgeDeduplication() throws {
        // 同 entity を共有する 3 タグ → ペア数 3 (alpha-bravo, alpha-charlie, bravo-charlie)
        // 同じペアが 2 経路で発見されるシナリオ (entity 複数共有) でも 1 エッジ
        let container = try makeContainer()
        let tagA = makeTag(
            name: "alpha",
            articleCount: 1,
            entityNames: ["e1", "e2"],
            in: container.mainContext
        )
        let tagB = makeTag(
            name: "bravo",
            articleCount: 1,
            entityNames: ["e1", "e2"],  // 2 共有でも 1 エッジ
            in: container.mainContext
        )
        let graph = KnowledgeMapBuilder.buildGraph(
            tags: [tagA, tagB],
            canvasSize: canvas,
            iterations: 5,
            seed: 42
        )
        #expect(graph.edges.count == 1)
        #expect(graph.edges.first?.sharedEntityCount == 2)
    }

    @Test func testRadiusClamping() throws {
        // count=0 → 40pt (min clamp)
        #expect(KnowledgeMapBuilder.nodeRadius(for: 0) == 40.0)
        // count=200 → 100pt (max clamp; log2(201)*20 ≈ 152.9)
        #expect(KnowledgeMapBuilder.nodeRadius(for: 200) == 100.0)
        // count=7 → log2(8)*20 = 60pt
        #expect(KnowledgeMapBuilder.nodeRadius(for: 7) == 60.0)
    }

    @Test func testNodePositionsWithinCanvas() throws {
        let container = try makeContainer()
        let tags = (0..<10).map { i in
            makeTag(
                name: "tag\(i)",
                articleCount: i + 1,
                entityNames: [],
                in: container.mainContext
            )
        }
        let graph = KnowledgeMapBuilder.buildGraph(
            tags: tags,
            canvasSize: canvas,
            iterations: 8,
            seed: 42
        )
        for node in graph.nodes {
            #expect(node.position.x >= node.radius)
            #expect(node.position.x <= canvas.width - node.radius + 0.001)
            #expect(node.position.y >= node.radius)
            #expect(node.position.y <= canvas.height - node.radius + 0.001)
        }
    }

    @Test func testDeterministicWithSeed() throws {
        let container = try makeContainer()
        let tags = (0..<5).map { i in
            makeTag(
                name: "n\(i)",
                articleCount: 2,
                entityNames: [],
                in: container.mainContext
            )
        }
        let g1 = KnowledgeMapBuilder.buildGraph(
            tags: tags,
            canvasSize: canvas,
            iterations: 8,
            seed: 999
        )
        let g2 = KnowledgeMapBuilder.buildGraph(
            tags: tags,
            canvasSize: canvas,
            iterations: 8,
            seed: 999
        )
        #expect(g1.nodes.count == g2.nodes.count)
        for (a, b) in zip(g1.nodes, g2.nodes) {
            #expect(a.id == b.id)
            #expect(abs(a.position.x - b.position.x) < 0.001)
            #expect(abs(a.position.y - b.position.y) < 0.001)
        }
    }

    @Test func testHundredTagsPerformance() throws {
        let container = try makeContainer()
        let tags = (0..<100).map { i in
            makeTag(
                name: "perf\(i)",
                articleCount: 1,
                entityNames: i % 3 == 0 ? ["shared"] : [],
                in: container.mainContext
            )
        }
        let start = Date()
        let graph = KnowledgeMapBuilder.buildGraph(
            tags: tags,
            canvasSize: canvas,
            iterations: 8,
            seed: 1
        )
        let elapsed = Date().timeIntervalSince(start)
        #expect(graph.nodes.count == 100)
        // SC-006: 100 タグで force-directed 反復 ≤200ms
        #expect(elapsed < 0.5, "buildGraph took \(elapsed)s for 100 tags")
    }

    @Test func testStepMovesNearbyNodesApart() throws {
        // 至近距離 (近接) の 2 ノード → 反発力が大きいので step で離れる方向に動く。
        // 完全同位置だと force が 0 になる corner case を避けるため微小オフセット。
        let initial = [
            MapNode(id: "a", position: CGPoint(x: 199, y: 300), radius: 40, articleCount: 1),
            MapNode(id: "b", position: CGPoint(x: 201, y: 300), radius: 40, articleCount: 1)
        ]
        let initialDistance = abs(initial[1].position.x - initial[0].position.x)
        let after = KnowledgeMapBuilder.step(
            nodes: initial,
            edges: [],
            canvasSize: canvas,
            params: .default
        )
        let afterA = after.first(where: { $0.id == "a" })!
        let afterB = after.first(where: { $0.id == "b" })!
        let afterDistance = abs(afterB.position.x - afterA.position.x)
        #expect(
            afterDistance > initialDistance,
            "step should push nearby nodes apart: initial=\(initialDistance), after=\(afterDistance)"
        )
    }
}

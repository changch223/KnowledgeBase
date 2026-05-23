//
//  GraphTraversalServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 040 — GraphTraversalService 5 ケース。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

@MainActor
struct GraphTraversalServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    @discardableResult
    private func makeNode(name: String, category: String, salience: Int = 3, mentionCount: Int = 1, in context: ModelContext) -> GraphNode {
        let node = GraphNode(
            name: name,
            categoryRaw: category,
            salience: salience,
            mentionCount: mentionCount,
            isActive: true
        )
        context.insert(node)
        return node
    }

    @discardableResult
    private func makeEdge(source: GraphNode, target: GraphNode, label: String?, in context: ModelContext) -> GraphEdge {
        let edge = GraphEdge(
            source: source, target: target,
            label: label, confidence: 0.8,
            categoryRaw: source.categoryRaw
        )
        context.insert(edge)
        return edge
    }

    // MARK: - 1. resolveNodes: 名前で解決、active のみ

    @Test func testResolveNodesByName() throws {
        let container = try makeContainer()
        let context = container.mainContext
        makeNode(name: "Apple", category: "テクノロジー", in: context)
        let inactive = makeNode(name: "Old", category: "テクノロジー", in: context)
        inactive.isActive = false
        try context.save()

        let service = GraphTraversalService()
        let resolved = service.resolveNodes(entityNames: ["Apple", "Old", "Missing"], categoryRaw: "テクノロジー", in: context)
        #expect(resolved.count == 1)
        #expect(resolved.first?.name == "Apple")
    }

    // MARK: - 2. resolveNodes: 大文字小文字無視

    @Test func testResolveNodesCaseInsensitive() throws {
        let container = try makeContainer()
        let context = container.mainContext
        makeNode(name: "Apple", category: "テクノロジー", in: context)
        try context.save()

        let service = GraphTraversalService()
        let resolved = service.resolveNodes(entityNames: ["apple", "APPLE"], categoryRaw: nil, in: context)
        #expect(resolved.count == 1)
    }

    // MARK: - 3. neighbors: 1-hop outgoing + incoming、重複除外

    @Test func testNeighborsReturnsOneHop() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let apple = makeNode(name: "Apple", category: "テクノロジー", in: context)
        let swift = makeNode(name: "Swift 6", category: "テクノロジー", in: context)
        let tim = makeNode(name: "Tim Cook", category: "テクノロジー", in: context)
        let google = makeNode(name: "Google", category: "テクノロジー", in: context)
        // Apple --release--> Swift 6
        makeEdge(source: apple, target: swift, label: "release", in: context)
        // Tim Cook --CEO--> Apple
        makeEdge(source: tim, target: apple, label: "CEO", in: context)
        // Google は無関係
        _ = google
        try context.save()

        let service = GraphTraversalService()
        let neighbors = service.neighbors(of: apple)
        #expect(neighbors.count == 2)
        let names = Set(neighbors.map { $0.name })
        #expect(names == ["Swift 6", "Tim Cook"])
    }

    // MARK: - 4. neighbors: inactive node は除外

    @Test func testNeighborsExcludesInactiveNodes() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let apple = makeNode(name: "Apple", category: "テクノロジー", in: context)
        let old = makeNode(name: "Old", category: "テクノロジー", in: context)
        old.isActive = false
        makeEdge(source: apple, target: old, label: "x", in: context)
        try context.save()

        let service = GraphTraversalService()
        let neighbors = service.neighbors(of: apple)
        #expect(neighbors.isEmpty)
    }

    // MARK: - 5. topByDegree: degree 降順、importanceScore tiebreak

    @Test func testTopByDegreeOrdering() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let hub = makeNode(name: "Hub", category: "テクノロジー", salience: 5, mentionCount: 10, in: context)
        let n1 = makeNode(name: "N1", category: "テクノロジー", in: context)
        let n2 = makeNode(name: "N2", category: "テクノロジー", in: context)
        let n3 = makeNode(name: "N3", category: "テクノロジー", in: context)
        // hub に 3 edges (degree 3)、n1 に 1 edge (degree 1)
        makeEdge(source: hub, target: n1, label: "a", in: context)
        makeEdge(source: hub, target: n2, label: "b", in: context)
        makeEdge(source: hub, target: n3, label: "c", in: context)
        try context.save()

        let service = GraphTraversalService()
        let top = service.topByDegree(categoryRaw: "テクノロジー", limit: 2, in: context)
        #expect(top.count == 2)
        #expect(top.first?.name == "Hub")
    }
}

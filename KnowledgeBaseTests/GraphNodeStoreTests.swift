//
//  GraphNodeStoreTests.swift
//  KnowledgeTreeTests
//
//  spec 041 — GraphNodeStore 7 ケース。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeBase

@MainActor
struct GraphNodeStoreTests {

    // MARK: - Fixtures

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    @discardableResult
    private func makeNode(
        name: String,
        category: String = "テクノロジー",
        salience: Int = 3,
        mentionCount: Int = 1,
        in context: ModelContext
    ) -> GraphNode {
        let node = GraphNode(
            name: name,
            categoryRaw: category,
            salience: salience,
            mentionCount: mentionCount
        )
        context.insert(node)
        return node
    }

    @discardableResult
    private func makeEdge(
        source: GraphNode,
        target: GraphNode,
        label: String?,
        weight: Int = 1,
        confidence: Float = 0.8,
        in context: ModelContext
    ) -> GraphEdge {
        let edge = GraphEdge(
            source: source, target: target,
            label: label, confidence: confidence,
            weight: weight,
            categoryRaw: source.categoryRaw
        )
        context.insert(edge)
        return edge
    }

    // MARK: - 1. rename 正常

    @Test func testRenameUpdatesName() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let node = makeNode(name: "Old", in: context)
        try context.save()

        let store = GraphNodeStore(context: context)
        let result = try store.rename(node, to: "New")

        #expect(result.name == "New")
        #expect(node.name == "New")
    }

    // MARK: - 2. rename 空文字 → throws

    @Test func testRenameEmptyThrows() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let node = makeNode(name: "Apple", in: context)
        try context.save()

        let store = GraphNodeStore(context: context)
        #expect(throws: GraphNodeStoreError.self) {
            _ = try store.rename(node, to: "   ")
        }
        #expect(node.name == "Apple")
    }

    // MARK: - 3. rename で同名既存 node → merge

    @Test func testRenameMergesWhenNameExists() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let a = makeNode(name: "Apple", mentionCount: 2, in: context)
        let b = makeNode(name: "Banana", mentionCount: 3, in: context)
        try context.save()

        let store = GraphNodeStore(context: context)
        let result = try store.rename(b, to: "Apple")

        #expect(result.id == a.id)
        // b は削除済
        let all = try context.fetch(FetchDescriptor<GraphNode>())
        #expect(all.count == 1)
        #expect(all.first?.id == a.id)
    }

    // MARK: - 4. merge 同 ID → no-op

    @Test func testMergeSameNodeIsNoOp() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let node = makeNode(name: "Apple", in: context)
        try context.save()

        let store = GraphNodeStore(context: context)
        try store.merge(source: node, into: node)
        let all = try context.fetch(FetchDescriptor<GraphNode>())
        #expect(all.count == 1)
    }

    // MARK: - 5. merge: articles + edges 合算、self-loop 破棄

    @Test func testMergeCombinesArticlesAndEdges() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let source = makeNode(name: "Source", mentionCount: 2, in: context)
        let target = makeNode(name: "Target", mentionCount: 3, in: context)
        let other = makeNode(name: "Other", in: context)

        let article1 = Article(url: "https://a", title: "A1")
        let article2 = Article(url: "https://b", title: "A2")
        context.insert(article1)
        context.insert(article2)
        source.articles?.append(article1)
        target.articles?.append(article2)

        // source → other (edge to be reassigned)
        makeEdge(source: source, target: other, label: "rel1", in: context)
        // source → target (self-loop after merge → 破棄)
        makeEdge(source: source, target: target, label: "loop", in: context)
        try context.save()

        let store = GraphNodeStore(context: context)
        try store.merge(source: source, into: target)

        // source 削除
        let nodes = try context.fetch(FetchDescriptor<GraphNode>())
        #expect(nodes.count == 2)
        #expect(!nodes.contains(where: { $0.id == source.id }))

        // target に articles が合算
        #expect((target.articles ?? []).count == 2)

        // target → other の edge が 1 本残る、self-loop は破棄
        #expect((target.outgoingEdges ?? []).count == 1)
        #expect((target.outgoingEdges ?? []).first?.target?.id == other.id)
        #expect((target.outgoingEdges ?? []).first?.label == "rel1")
    }

    // MARK: - 6. merge: 重複 edge は weight 加算で統合

    @Test func testMergeDeduplicatesEdgesByWeight() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let source = makeNode(name: "Source", in: context)
        let target = makeNode(name: "Target", in: context)
        let other = makeNode(name: "Other", in: context)

        makeEdge(source: source, target: other, label: "rel", weight: 2, confidence: 0.7, in: context)
        makeEdge(source: target, target: other, label: "rel", weight: 3, confidence: 0.9, in: context)
        try context.save()

        let store = GraphNodeStore(context: context)
        try store.merge(source: source, into: target)

        // target → other の edge は 1 本に統合、weight = 3 + 2 = 5
        let outgoing = (target.outgoingEdges ?? []).filter { $0.target?.id == other.id }
        #expect(outgoing.count == 1)
        #expect(outgoing.first?.weight == 5)
        // confidence は max(0.7, 0.9) = 0.9
        #expect(outgoing.first?.confidence == 0.9)
    }

    // MARK: - 7. delete: cascade で edges も削除

    @Test func testDeleteRemovesNodeAndCascadesEdges() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let a = makeNode(name: "A", in: context)
        let b = makeNode(name: "B", in: context)
        makeEdge(source: a, target: b, label: "rel", in: context)
        try context.save()

        let store = GraphNodeStore(context: context)
        try store.delete(a)

        let nodes = try context.fetch(FetchDescriptor<GraphNode>())
        #expect(nodes.count == 1)
        #expect(nodes.first?.id == b.id)

        // edges も cascade で削除
        let edges = try context.fetch(FetchDescriptor<GraphEdge>())
        #expect(edges.isEmpty)
    }
}

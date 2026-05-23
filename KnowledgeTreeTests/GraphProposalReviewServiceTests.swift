//
//  GraphProposalReviewServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 041 — GraphProposalReviewService 3 ケース。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

@MainActor
struct GraphProposalReviewServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    private func makeUncertainEdge(in context: ModelContext) -> GraphEdge {
        let src = GraphNode(name: "S", categoryRaw: "テクノロジー")
        let dst = GraphNode(name: "T", categoryRaw: "テクノロジー")
        context.insert(src); context.insert(dst)
        let edge = GraphEdge(
            source: src, target: dst,
            label: "rel", confidence: 0.6,
            isUncertain: true,
            categoryRaw: "テクノロジー"
        )
        context.insert(edge)
        return edge
    }

    // MARK: - 1. accept: isUncertain=false + confidence 引き上げ

    @Test func testAcceptConfirmsEdge() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let edge = makeUncertainEdge(in: context)
        try context.save()

        let service = GraphProposalReviewService(context: context)
        try service.accept(edge: edge)

        #expect(edge.isUncertain == false)
        #expect(edge.confidence >= 0.8)
    }

    // MARK: - 2. reject: edge 削除

    @Test func testRejectDeletesEdge() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let edge = makeUncertainEdge(in: context)
        try context.save()

        let service = GraphProposalReviewService(context: context)
        try service.reject(edge: edge)

        let remaining = try context.fetch(FetchDescriptor<GraphEdge>())
        #expect(remaining.isEmpty)
    }

    // MARK: - 3. relabel: ラベル変更 + 確定化、空文字 throws

    @Test func testRelabelUpdatesAndConfirms() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let edge = makeUncertainEdge(in: context)
        try context.save()

        let service = GraphProposalReviewService(context: context)
        try service.relabel(edge: edge, to: "new label")
        #expect(edge.label == "new label")
        #expect(edge.isUncertain == false)

        #expect(throws: GraphProposalReviewError.self) {
            try service.relabel(edge: edge, to: "   ")
        }
    }
}

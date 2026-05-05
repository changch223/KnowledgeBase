//
//  HierarchicalChunkedSummarizerTests.swift
//  KnowledgeTreeTests
//
//  spec 010 — 階層化のグループ分割と orchestration の純粋関数テスト
//

import Testing
@testable import KnowledgeTree

@Suite("HierarchicalChunkedSummarizer.makeGroups")
struct HierarchicalChunkedSummarizerMakeGroupsTests {

    @Test("空配列は空配列")
    func emptyArray() {
        let result = HierarchicalChunkedSummarizer.makeGroups([Int](), groupSize: 10)
        #expect(result.isEmpty)
    }

    @Test("18 items を 10 ずつ分割 → [10, 8]")
    func eighteenItemsTen() {
        let items = Array(0..<18)
        let groups = HierarchicalChunkedSummarizer.makeGroups(items, groupSize: 10)
        #expect(groups.count == 2)
        #expect(groups[0].count == 10)
        #expect(groups[1].count == 8)
        #expect(groups[0] == Array(0..<10))
        #expect(groups[1] == Array(10..<18))
    }

    @Test("30 items を 10 ずつ → [10, 10, 10]")
    func thirtyItemsTen() {
        let items = Array(0..<30)
        let groups = HierarchicalChunkedSummarizer.makeGroups(items, groupSize: 10)
        #expect(groups.count == 3)
        #expect(groups.allSatisfy { $0.count == 10 })
    }

    @Test("groupSize=1 で 5 items → 5 単要素")
    func sizeOneAllSingletons() {
        let items = Array(0..<5)
        let groups = HierarchicalChunkedSummarizer.makeGroups(items, groupSize: 1)
        #expect(groups.count == 5)
        #expect(groups.allSatisfy { $0.count == 1 })
    }

    @Test("11 items を 10 ずつ → [10, 1]")
    func elevenSplits() {
        let items = Array(0..<11)
        let groups = HierarchicalChunkedSummarizer.makeGroups(items, groupSize: 10)
        #expect(groups.count == 2)
        #expect(groups[0].count == 10)
        #expect(groups[1].count == 1)
    }

    @Test("groups の連結は元 items と一致 (順序保持)")
    func concatenationMatchesOriginal() {
        let items = Array(0..<25)
        let groups = HierarchicalChunkedSummarizer.makeGroups(items, groupSize: 10)
        #expect(groups.flatMap { $0 } == items)
    }
}

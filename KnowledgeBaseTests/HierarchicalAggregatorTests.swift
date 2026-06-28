//
//  HierarchicalAggregatorTests.swift
//  KnowledgeTreeTests
//
//  spec 010 — ChunkedKnowledgeAggregator.mergeHierarchical の集約 / fallback ロジック
//

import Testing
import Foundation
@testable import KnowledgeBase

@Suite("ChunkedKnowledgeAggregator.mergeHierarchical")
struct HierarchicalAggregatorTests {

    private func chunkOutput(
        essence: String = "ess",
        summary: String = "sum",
        keyFacts: [KeyFactOutput] = [],
        entities: [KnowledgeEntityOutput] = []
    ) -> ExtractedKnowledgeOutput {
        ExtractedKnowledgeOutput(
            essence: essence,
            summary: summary,
            keyFacts: keyFacts,
            entities: entities
        )
    }

    @Test("全成功 (lvl1 + lvl2 + lvl3) → .succeeded、essence は lvl3 値")
    func allLevelsSucceed() {
        let lvl1Results = (0..<5).map {
            ChunkResult(chunkIndex: $0, output: chunkOutput(essence: "lvl1-\($0)"), error: nil)
        }
        let lvl2 = [
            IntermediateMetaResult(groupIndex: 0, chunkIndices: 0...4, output: chunkOutput(essence: "lvl2-0"), error: nil)
        ]
        let lvl3 = chunkOutput(essence: "lvl3-final", summary: "final summary")
        let aggregated = ChunkedKnowledgeAggregator.mergeHierarchical(
            lvl1Results: lvl1Results,
            lvl2Results: lvl2,
            lvl3Result: lvl3
        )
        #expect(aggregated.determineStatus() == .succeeded)
        #expect(aggregated.essence == "lvl3-final")
        #expect(aggregated.summary == "final summary")
    }

    @Test("lvl3 失敗 + lvl2 1+ 成功 → .partiallySucceeded、lvl2 essence 連結 fallback")
    func lvl3FailedWithLvl2Partial() {
        let lvl1Results = (0..<5).map {
            ChunkResult(chunkIndex: $0, output: chunkOutput(essence: "lvl1-\($0)"), error: nil)
        }
        let lvl2 = [
            IntermediateMetaResult(groupIndex: 0, chunkIndices: 0...4, output: chunkOutput(essence: "lvl2a"), error: nil),
            IntermediateMetaResult(groupIndex: 1, chunkIndices: 5...9, output: chunkOutput(essence: "lvl2b"), error: nil)
        ]
        let aggregated = ChunkedKnowledgeAggregator.mergeHierarchical(
            lvl1Results: lvl1Results,
            lvl2Results: lvl2,
            lvl3Result: nil
        )
        #expect(aggregated.determineStatus() == .partiallySucceeded)
        #expect(aggregated.essence == "lvl2a")
        #expect(aggregated.summary == "lvl2a\nlvl2b")
    }

    @Test("lvl2 全失敗 → .partiallySucceeded、lvl1 essence 連結 fallback")
    func allLvl2FailedFallbackToLvl1() {
        let lvl1Results = [
            ChunkResult(chunkIndex: 0, output: chunkOutput(essence: "lvl1-0"), error: nil),
            ChunkResult(chunkIndex: 1, output: chunkOutput(essence: "lvl1-1"), error: nil)
        ]
        let lvl2 = [
            IntermediateMetaResult(groupIndex: 0, chunkIndices: 0...1, output: nil, error: NSError(domain: "x", code: 0))
        ]
        let aggregated = ChunkedKnowledgeAggregator.mergeHierarchical(
            lvl1Results: lvl1Results,
            lvl2Results: lvl2,
            lvl3Result: nil
        )
        #expect(aggregated.determineStatus() == .partiallySucceeded)
        #expect(aggregated.essence == "lvl1-0")
        #expect(aggregated.summary == "lvl1-0\nlvl1-1")
    }

    @Test("lvl1 全失敗 → .failed")
    func lvl1AllFailed() {
        let lvl1Results: [ChunkResult] = (0..<3).map {
            ChunkResult(chunkIndex: $0, output: nil, error: NSError(domain: "x", code: $0))
        }
        let aggregated = ChunkedKnowledgeAggregator.mergeHierarchical(
            lvl1Results: lvl1Results,
            lvl2Results: [],
            lvl3Result: nil
        )
        #expect(aggregated.determineStatus() == .failed)
        #expect(aggregated.essence == "")
    }

    @Test("keyFacts / entities は lvl1 chunks のみから集約")
    func keyFactsAndEntitiesFromLvl1Only() {
        let f1 = KeyFactOutput(statement: "fact A", type: .claim)
        let f2 = KeyFactOutput(statement: "fact B", type: .definition)
        let e1 = KnowledgeEntityOutput(name: "X", type: .organization, salience: 5)
        let lvl1Results = [
            ChunkResult(chunkIndex: 0, output: chunkOutput(keyFacts: [f1], entities: [e1]), error: nil),
            ChunkResult(chunkIndex: 1, output: chunkOutput(keyFacts: [f2]), error: nil)
        ]
        // lvl2/lvl3 に keyFacts/entities が含まれていても、aggregator は無視する
        let lvl2 = [
            IntermediateMetaResult(
                groupIndex: 0, chunkIndices: 0...1,
                output: chunkOutput(keyFacts: [KeyFactOutput(statement: "noise", type: .quote)]),
                error: nil
            )
        ]
        let aggregated = ChunkedKnowledgeAggregator.mergeHierarchical(
            lvl1Results: lvl1Results,
            lvl2Results: lvl2,
            lvl3Result: chunkOutput(keyFacts: [KeyFactOutput(statement: "more noise", type: .quote)])
        )
        #expect((aggregated.keyFacts ?? []).count == 2)
        #expect(aggregated.keyFacts.contains { $0.statement == "fact A" })
        #expect(aggregated.keyFacts.contains { $0.statement == "fact B" })
        #expect(!aggregated.keyFacts.contains { $0.statement == "noise" })
        #expect(!aggregated.keyFacts.contains { $0.statement == "more noise" })
        #expect((aggregated.entities ?? []).count == 1)
        #expect(aggregated.entities[0].name == "X")
    }
}

//
//  ChunkedKnowledgeAggregatorTests.swift
//  KnowledgeTreeTests
//
//  spec 006 — ChunkedKnowledgeAggregator の重複排除と partial success 判定
//

import Testing
@testable import KnowledgeTree

@Suite("ChunkedKnowledgeAggregator")
struct ChunkedKnowledgeAggregatorTests {

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

    @Test("全 chunk 失敗 → status .failed、essence/summary 空")
    func allChunksFailed() {
        struct DummyError: Error {}
        let results: [ChunkResult] = [
            ChunkResult(chunkIndex: 0, output: nil, error: DummyError()),
            ChunkResult(chunkIndex: 1, output: nil, error: DummyError()),
        ]
        let aggregated = ChunkedKnowledgeAggregator.merge(results: results, metaSummary: nil)
        #expect(aggregated.determineStatus() == .failed)
        #expect(aggregated.essence == "")
        #expect(aggregated.summary == "")
        #expect(aggregated.successfulChunkCount == 0)
        #expect(aggregated.totalChunkCount == 2)
    }

    @Test("1 chunk 成功 + meta 成功 → .succeeded、meta 値を採用")
    func oneChunkAndMetaSucceeded() {
        let chunkOut = chunkOutput(essence: "chunk1 essence", summary: "chunk1 summary")
        let metaOut = chunkOutput(essence: "meta essence", summary: "meta summary")
        let results = [ChunkResult(chunkIndex: 0, output: chunkOut, error: nil)]
        let aggregated = ChunkedKnowledgeAggregator.merge(results: results, metaSummary: metaOut)
        #expect(aggregated.determineStatus() == .succeeded)
        #expect(aggregated.essence == "meta essence")
        #expect(aggregated.summary == "meta summary")
        #expect(aggregated.metaSummarySucceeded)
    }

    @Test("3 chunk 成功 + meta 失敗 → .partiallySucceeded、最初の chunk の essence を fallback")
    func metaFailsButChunksSucceed() {
        let c1 = chunkOutput(essence: "c1", summary: "")
        let c2 = chunkOutput(essence: "c2", summary: "")
        let c3 = chunkOutput(essence: "c3", summary: "")
        let results = [
            ChunkResult(chunkIndex: 0, output: c1, error: nil),
            ChunkResult(chunkIndex: 1, output: c2, error: nil),
            ChunkResult(chunkIndex: 2, output: c3, error: nil),
        ]
        let aggregated = ChunkedKnowledgeAggregator.merge(results: results, metaSummary: nil)
        #expect(aggregated.determineStatus() == .partiallySucceeded)
        #expect(aggregated.essence == "c1")
        #expect(aggregated.summary == "c1\nc2\nc3")
        #expect(!aggregated.metaSummarySucceeded)
    }

    @Test("keyFacts の重複排除 (trim 完全一致)")
    func keyFactsDeduplication() {
        let f1 = KeyFactOutput(statement: "事実 A", type: .claim)
        let f2 = KeyFactOutput(statement: "事実 A", type: .definition)  // 重複 statement
        let f3 = KeyFactOutput(statement: "事実 B", type: .claim)
        let c1 = chunkOutput(keyFacts: [f1])
        let c2 = chunkOutput(keyFacts: [f2, f3])
        let results = [
            ChunkResult(chunkIndex: 0, output: c1, error: nil),
            ChunkResult(chunkIndex: 1, output: c2, error: nil),
        ]
        let aggregated = ChunkedKnowledgeAggregator.merge(results: results, metaSummary: nil)
        #expect((aggregated.keyFacts ?? []).count == 2)
        #expect(aggregated.keyFacts[0].statement == "事実 A")
        #expect(aggregated.keyFacts[1].statement == "事実 B")
    }

    @Test("keyFacts の trim 違いは別 fact (空白 1 文字違い)")
    func keyFactsWhitespaceSensitive() {
        let f1 = KeyFactOutput(statement: "事実 A", type: .claim)
        let f2 = KeyFactOutput(statement: "事実 A.", type: .claim)  // 句点違い
        let c1 = chunkOutput(keyFacts: [f1, f2])
        let results = [ChunkResult(chunkIndex: 0, output: c1, error: nil)]
        let aggregated = ChunkedKnowledgeAggregator.merge(results: results, metaSummary: nil)
        #expect((aggregated.keyFacts ?? []).count == 2)
    }

    @Test("entities の case-insensitive 統合")
    func entitiesCaseInsensitiveMerge() {
        let e1 = KnowledgeEntityOutput(name: "Apple", type: .organization, salience: 5)
        let e2 = KnowledgeEntityOutput(name: "apple", type: .organization, salience: 3)
        let c1 = chunkOutput(entities: [e1, e2])
        let aggregated = ChunkedKnowledgeAggregator.merge(
            results: [ChunkResult(chunkIndex: 0, output: c1, error: nil)],
            metaSummary: nil
        )
        #expect((aggregated.entities ?? []).count == 1)
        #expect(aggregated.entities[0].salience == 5)  // max
    }

    @Test("entities の type は多数決")
    func entitiesTypeMajorityVote() {
        let e1 = KnowledgeEntityOutput(name: "Foo", type: .product, salience: 3)
        let e2 = KnowledgeEntityOutput(name: "foo", type: .organization, salience: 4)
        let e3 = KnowledgeEntityOutput(name: "FOO", type: .organization, salience: 2)
        let c1 = chunkOutput(entities: [e1, e2, e3])
        let aggregated = ChunkedKnowledgeAggregator.merge(
            results: [ChunkResult(chunkIndex: 0, output: c1, error: nil)],
            metaSummary: nil
        )
        #expect((aggregated.entities ?? []).count == 1)
        #expect(aggregated.entities[0].type == .organization)  // 2 vs 1 で organization 勝ち
        #expect(aggregated.entities[0].salience == 4)
    }

    @Test("空 results + nil meta は status .failed")
    func emptyResults() {
        let aggregated = ChunkedKnowledgeAggregator.merge(results: [], metaSummary: nil)
        #expect(aggregated.determineStatus() == .failed)
        #expect(aggregated.successfulChunkCount == 0)
        #expect(aggregated.totalChunkCount == 0)
    }

    @Test("toOutput が essence/summary/keyFacts/entities を持つ ExtractedKnowledgeOutput を返す")
    func toOutputProducesValidStruct() {
        let c1 = chunkOutput(
            essence: "e",
            summary: "s",
            keyFacts: [KeyFactOutput(statement: "f", type: .claim)],
            entities: [KnowledgeEntityOutput(name: "X", type: .concept, salience: 3)]
        )
        let aggregated = ChunkedKnowledgeAggregator.merge(
            results: [ChunkResult(chunkIndex: 0, output: c1, error: nil)],
            metaSummary: nil
        )
        let output = aggregated.toOutput()
        #expect(output.essence == "e")
        #expect((output.keyFacts ?? []).count == 1)
        #expect((output.entities ?? []).count == 1)
    }
}

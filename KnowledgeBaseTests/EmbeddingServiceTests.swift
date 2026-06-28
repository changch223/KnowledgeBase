//
//  EmbeddingServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 021 — contracts/embedding-service.md 5 ケース + Float↔Data round-trip。
//

import Testing
import Foundation
@testable import KnowledgeBase

@MainActor
struct EmbeddingServiceTests {

    // MARK: - cosineSimilarity (純関数、availability 不問)

    @Test func testCosineSimilarityIdentical() {
        let a: [Float] = [1, 0, 0]
        let b: [Float] = [1, 0, 0]
        let sim = EmbeddingService.cosineSimilarity(a, b)
        #expect(abs(sim - 1.0) < 1e-5)
    }

    @Test func testCosineSimilarityOrthogonal() {
        let a: [Float] = [1, 0, 0]
        let b: [Float] = [0, 1, 0]
        let sim = EmbeddingService.cosineSimilarity(a, b)
        #expect(abs(sim) < 1e-5)
    }

    @Test func testCosineSimilarityOpposite() {
        let a: [Float] = [1, 0, 0]
        let b: [Float] = [-1, 0, 0]
        let sim = EmbeddingService.cosineSimilarity(a, b)
        #expect(abs(sim - (-1.0)) < 1e-5)
    }

    // MARK: - topK

    @Test func testTopKReturnsDescendingByScore() {
        let query: [Float] = [1, 0, 0]
        let corpus: [(id: String, embedding: [Float])] = [
            ("a", [0.5, 0.5, 0]),    // sim ≈ 0.5
            ("b", [1, 0, 0]),         // sim ≈ 1.0
            ("c", [0, 1, 0]),         // sim ≈ 0.0
            ("d", [0.9, 0.1, 0]),     // sim ≈ 0.9
        ]
        let result = EmbeddingService.topK(query: query, corpus: corpus, k: 3)
        #expect(result.count == 3)
        #expect(result[0].id == "b")
        #expect(result[1].id == "d")
        #expect(result[2].id == "a")
        #expect(result[0].similarity >= result[1].similarity)
        #expect(result[1].similarity >= result[2].similarity)
    }

    @Test func testTopKReturnsAllWhenKExceedsCorpus() {
        let query: [Float] = [1, 0]
        let corpus: [(id: String, embedding: [Float])] = [
            ("a", [1, 0]),
            ("b", [0, 1]),
        ]
        let result = EmbeddingService.topK(query: query, corpus: corpus, k: 10)
        #expect(result.count == 2)
    }

    // MARK: - Float ↔ Data round-trip (Article.essenceEmbedding 永続化検証)

    @Test func testFloatArrayDataRoundTrip() {
        let original: [Float] = [0.1, -0.5, 0.7, 1.0, -1.0]
        let data = original.asEmbeddingData
        let decoded = data.asFloatArray
        #expect(decoded.count == original.count)
        for (a, b) in zip(original, decoded) {
            #expect(abs(a - b) < 1e-6)
        }
    }
}

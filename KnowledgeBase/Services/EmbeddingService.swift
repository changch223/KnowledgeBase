//
//  EmbeddingService.swift
//  KnowledgeTree
//
//  spec 021 — AI Chat (RAG) の文章 embedding 生成 + cosine similarity Service。
//
//  - NLEmbedding.sentenceEmbedding(for: .japanese) を起動時にロード、cache
//  - 出力は L2 正規化済み (cosine similarity = dot product 化、計算高速化)
//  - 不可端末では isAvailable = false で動作、ChatService 側でキーワードマッチに切替
//

import Foundation
import NaturalLanguage
import Accelerate

@MainActor
final class EmbeddingService {

    /// 起動時に sentenceEmbedding を 1 度ロード、以降 reuse。
    private let embedding: NLEmbedding?

    /// spec 086: 直近の embed 結果を text キーで cache (同一質問の重複推論を回避)。
    /// 1 チャットターンで retrieve が複数回 (standalone/raw/safety-net) 走り同じ質問を再 embed するため。
    private var cache: [String: [Float]] = [:]
    private var cacheOrder: [String] = []
    private let cacheLimit = 64

    /// embedding が利用可能か (Apple Intelligence 端末 + 言語サポート両方 OK)。
    var isAvailable: Bool { embedding != nil }

    /// embedding 次元数。不可端末は nil。
    var dimension: Int? { embedding?.dimension }

    init() {
        self.embedding = NLEmbedding.sentenceEmbedding(for: .japanese)
    }

    /// 文章 → L2 正規化済み embedding。空文字 / 不可端末 / 失敗時は nil。
    /// spec 086: 成功結果を cache し、同一テキストの再推論 (~200ms) を回避。
    func embed(_ text: String) -> [Float]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let embedding else { return nil }
        if let cached = cache[trimmed] { return cached }
        guard let vector = embedding.vector(for: trimmed) else { return nil }
        let floats = Self.l2Normalized(vector.map { Float($0) })
        cache[trimmed] = floats
        cacheOrder.append(trimmed)
        if cacheOrder.count > cacheLimit {
            let evict = cacheOrder.removeFirst()
            cache.removeValue(forKey: evict)
        }
        return floats
    }

    /// L2 正規化前提の dot product = cosine similarity。
    /// - Parameters:
    ///   - a: 同次元 [Float] (正規化済み)
    ///   - b: 同次元 [Float] (正規化済み)
    /// - Returns: -1.0 ~ 1.0
    /// spec 086: 純関数なので nonisolated。ChatService が cosine ループをメインスレッド外で実行できる。
    nonisolated static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        precondition(a.count == b.count, "embedding 次元不一致")
        var result: Float = 0
        vDSP_dotpr(a, 1, b, 1, &result, vDSP_Length(a.count))
        return result
    }

    /// query × corpus → top-k インデックス + similarity 降順。
    /// - Parameters:
    ///   - query: 正規化済み [Float]
    ///   - corpus: (id, 正規化済み embedding) 配列
    ///   - k: 上位 k 件
    /// - Returns: similarity 降順、k 件未満なら全件
    nonisolated static func topK(
        query: [Float],
        corpus: [(id: String, embedding: [Float])],
        k: Int
    ) -> [(id: String, similarity: Float)] {
        precondition(k > 0)
        let scored = corpus.map { entry in
            (id: entry.id, similarity: cosineSimilarity(query, entry.embedding))
        }
        return scored
            .sorted { $0.similarity > $1.similarity }
            .prefix(k)
            .map { ($0.id, $0.similarity) }
    }

    // MARK: - Private

    /// L2 正規化 (vector / ||vector||₂)。zero vector はそのまま返す。
    nonisolated private static func l2Normalized(_ vector: [Float]) -> [Float] {
        var sumSquares: Float = 0
        vDSP_svesq(vector, 1, &sumSquares, vDSP_Length(vector.count))
        let norm = sqrt(sumSquares)
        guard norm > 0 else { return vector }
        var result = [Float](repeating: 0, count: vector.count)
        var divisor = norm
        vDSP_vsdiv(vector, 1, &divisor, &result, 1, vDSP_Length(vector.count))
        return result
    }
}

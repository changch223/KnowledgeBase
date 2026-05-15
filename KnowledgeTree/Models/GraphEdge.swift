//
//  GraphEdge.swift
//  KnowledgeTree
//
//  spec 040 (Phase A) — Knowledge Graph のエッジ。
//  ラベル付き or 共起のハイブリッド (確信度判定):
//  - confidence >= 0.7 → ラベル付き edge (label != nil)
//  - 0.5 <= confidence < 0.7 → ラベル付き + isUncertain=true
//  - confidence < 0.5 → silent skip (Phase A では出力しない)
//  - Fallback (LM 不可) → 共起のみ (label=nil、confidence=0.0、weight=1)
//
//  同 (source.id, target.id, label) の triple は upsert (重複作成なし)。
//  observed 回数を weight に蓄積。
//

import Foundation
import SwiftData

@Model
final class GraphEdge {
    @Attribute(.unique) var id: UUID

    /// source ノード (relationship、inverse: GraphNode.outgoingEdges)
    var source: GraphNode?

    /// target ノード (relationship、inverse: GraphNode.incomingEdges)
    var target: GraphNode?

    /// 関係性ラベル (例: "release", "CEO of"、共起のみなら nil)
    var label: String?

    /// AI が triple 抽出した時の確信度 (0.0-1.0)、共起は 0.0
    var confidence: Float

    /// 0.5 <= confidence < 0.7 で true (Phase B の UI で「不確実」マーク)
    var isUncertain: Bool

    /// この triple が observed された回数 (同 triple を複数記事で発見 → weight 増加)
    var weight: Int

    /// 所属 Category (source/target と同じ、Category 内 query 用)
    var categoryRaw: String

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        source: GraphNode?,
        target: GraphNode?,
        label: String? = nil,
        confidence: Float = 0.0,
        isUncertain: Bool = false,
        weight: Int = 1,
        categoryRaw: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.source = source
        self.target = target
        self.label = label
        self.confidence = max(0.0, min(1.0, confidence))
        self.isUncertain = isUncertain
        self.weight = max(1, weight)
        self.categoryRaw = categoryRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension GraphEdge {
    /// label が付いているか (確信度 0.5 以上 → ラベル付き、Phase B で実線描画)
    var isLabeled: Bool { label != nil }
}

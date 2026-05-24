//
//  GraphNode.swift
//  KnowledgeTree
//
//  spec 040 (Phase A) — Knowledge Graph のノード。
//  Entity 単位 (KnowledgeEntity と 1:1 リンク、Category 内で unique)。
//  記事保存時に GraphExtractionService が upsert する。
//
//  Category 内最大 30 node (active)。超過時は salience 低を deactivate する
//  (delete はせず isActive=false で履歴保持)。
//

import Foundation
import SwiftData

@Model
final class GraphNode {
    var id: UUID = UUID()

    /// Entity 名 (KnowledgeEntity.name と同じ、Category 内で unique)
    var name: String = ""

    /// 所属 Category (Tag.categoryRaw と整合、Article の Category 解決経路と同じ)
    var categoryRaw: String = ""

    /// Entity 種別 (EntityTypeStored.rawValue: person / organization / location / concept / product / work)
    var entityType: String = ""

    /// 重要度 1-5 (1 が最低)、元 KnowledgeEntity.salience の集約平均 (round)
    var salience: Int = 0

    /// この entity が出現した記事数 (Category 内、deactivate 判定に使う)
    var mentionCount: Int = 0

    /// Category 内 30 node 上限超過で false に。再度 mention されたら自動 true 復帰。
    var isActive: Bool = false

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    /// この node を source とする edges (deleteRule: cascade)
    @Relationship(deleteRule: .cascade, inverse: \GraphEdge.source)
    var outgoingEdges: [GraphEdge]? = []

    /// この node を target とする edges (deleteRule: cascade)
    @Relationship(deleteRule: .cascade, inverse: \GraphEdge.target)
    var incomingEdges: [GraphEdge]? = []

    /// この entity が出現した記事 (deleteRule: nullify、記事削除で relationship 解除のみ)
    @Relationship(deleteRule: .nullify)
    var articles: [Article]? = []

    init(
        id: UUID = UUID(),
        name: String,
        categoryRaw: String,
        entityType: String = EntityTypeStored.concept.rawValue,
        salience: Int = 3,
        mentionCount: Int = 0,
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = Date.now
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = categoryRaw
        self.entityType = entityType
        self.salience = max(1, min(5, salience))
        self.mentionCount = mentionCount
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension GraphNode {
    /// 重要度スコア = salience × mentionCount (上位順表示 / deactivate 判定に使う)
    var importanceScore: Int {
        salience * max(1, mentionCount)
    }

    /// 次数 (degree) = outgoing + incoming edge 数 (中心 entity 選択用)
    /// spec 051 Phase A: Array @Relationship Optional 化、`?? []` で safe unwrap。
    var degree: Int {
        (outgoingEdges ?? []).count + (incomingEdges ?? []).count
    }
}

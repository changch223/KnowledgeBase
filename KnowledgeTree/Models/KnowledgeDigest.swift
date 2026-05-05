//
//  KnowledgeDigest.swift
//  KnowledgeTree
//
//  spec 018 — Category 単位の AI 統合ダイジェスト @Model。
//  KnowledgeDigestService が複数記事の essence を統合した結果を永続化。
//  - sourceArticles: deleteRule .nullify で Article 削除に追従しつつ Digest 自体は残る
//    (履歴保全 + Constitution III「ソースに基づいた知識生成」整合)
//  - cardIndex: AI が「散らかった内容」と判断した時のマルチカード分割順序
//  - isStale: 新記事追加時に true、pull-to-refresh で再集約 → false
//

import Foundation
import SwiftData

@Model
final class KnowledgeDigest {
    @Attribute(.unique) var id: UUID
    var categoryRaw: String              // CategorySeed.allSeeds.name
    var cardIndex: Int                   // 0 (単独) / 0,1,2 (マルチカード)
    var summary: String                  // AI 統合要約 (~150 字)
    var topKeyFacts: [String]            // 統合 KeyFact (3 個)
    var topEntityNames: [String]         // 関連エンティティ (3 個)
    var generatedAt: Date
    var isStale: Bool

    @Relationship(deleteRule: .nullify, inverse: \Article.digests)
    var sourceArticles: [Article] = []

    init(
        id: UUID = UUID(),
        categoryRaw: String,
        cardIndex: Int = 0,
        summary: String,
        topKeyFacts: [String] = [],
        topEntityNames: [String] = [],
        generatedAt: Date = .now,
        isStale: Bool = false,
        sourceArticles: [Article] = []
    ) {
        self.id = id
        self.categoryRaw = categoryRaw
        self.cardIndex = cardIndex
        self.summary = summary
        self.topKeyFacts = topKeyFacts
        self.topEntityNames = topEntityNames
        self.generatedAt = generatedAt
        self.isStale = isStale
        self.sourceArticles = sourceArticles
    }
}

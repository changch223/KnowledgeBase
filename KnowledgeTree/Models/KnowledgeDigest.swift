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
    var id: UUID = UUID()
    var categoryRaw: String = ""              // spec 051: CloudKit default
    var cardIndex: Int = 0                    // spec 051: CloudKit default (0=単独)
    var summary: String = ""                  // spec 051: CloudKit default
    var topKeyFacts: [String] = []            // spec 051: CloudKit default
    var topEntityNames: [String] = []         // spec 051: CloudKit default
    var generatedAt: Date = Date.now
    var isStale: Bool = false

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

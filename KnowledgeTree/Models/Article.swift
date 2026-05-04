//
//  Article.swift
//  KnowledgeTree
//
//  spec 001 — 記事保存 (Share Sheet 経由)
//  spec 002 — enrichment relationship 追加
//  spec 003 — body relationship 追加
//  spec 004 — extractedKnowledge relationship 追加
//

import Foundation
import SwiftData

@Model
final class Article {
    @Attribute(.unique) var id: UUID
    var url: String
    var title: String
    var savedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ArticleEnrichment.article)
    var enrichment: ArticleEnrichment?

    @Relationship(deleteRule: .cascade, inverse: \ArticleBody.article)
    var body: ArticleBody?

    @Relationship(deleteRule: .cascade, inverse: \ExtractedKnowledge.article)
    var extractedKnowledge: ExtractedKnowledge?

    init(id: UUID = UUID(), url: String, title: String, savedAt: Date = Date()) {
        self.id = id
        self.url = url
        self.title = title
        self.savedAt = savedAt
    }
}

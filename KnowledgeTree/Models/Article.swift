//
//  Article.swift
//  KnowledgeTree
//
//  spec 001 — 記事保存 (Share Sheet 経由)
//  spec 002 — enrichment relationship 追加
//  spec 003 — body relationship 追加
//  spec 004 — extractedKnowledge relationship 追加
//  spec 008 — tags relationship 追加 (Tag 多対多)
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

    /// spec 008: Article ↔ Tag 多対多。Tag 側 inverse は Tag.articles。
    /// Article 削除時は relationship のみ解除され Tag は残る。
    /// 孤児タグの削除は TagStore が責任を持つ。
    @Relationship var tags: [Tag] = []

    /// spec 018: KnowledgeDigest への inverse (Digest 側 sourceArticles の inverse)。
    /// Article 削除時は Digest 側 sourceArticles から null 化、Digest 自体は残る。
    @Relationship var digests: [KnowledgeDigest] = []

    init(id: UUID = UUID(), url: String, title: String, savedAt: Date = Date()) {
        self.id = id
        self.url = url
        self.title = title
        self.savedAt = savedAt
    }
}

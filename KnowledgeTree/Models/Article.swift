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
    // spec 051 Phase A: CloudKit sync 互換のため `@Attribute(.unique)` 削除 +
    // 全 non-optional / non-Array に default 追加。重複防止は ArticleStore で app-level dedup。
    var id: UUID = UUID()
    var url: String = ""
    var title: String = ""
    var savedAt: Date = Date.now

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

    /// spec 021: 文章 embedding (NLEmbedding.sentenceEmbedding(for: .japanese) 経由、
    /// L2 正規化済み Float Array の byte 表現)。AI Chat retrieval で cosine similarity 計算に使う。
    /// - Data 型 + .externalStorage で SQLite から外出し (1000 articles × 512 floats ≈ 2 MB)
    /// - nil = 未生成 (Apple Intelligence 不可端末 / 旧データ)
    @Attribute(.externalStorage) var essenceEmbedding: Data?

    /// spec 037: 時系列事実上書きで「旧情報」と判定された Article は true。
    /// KnowledgeDigest 生成時に「過去」併記 or skip される。
    /// ライブラリ表示は維持 (ユーザーは見られる)。
    var isObsolete: Bool = false

    init(id: UUID = UUID(), url: String, title: String, savedAt: Date = Date()) {
        self.id = id
        self.url = url
        self.title = title
        self.savedAt = savedAt
    }
}

// MARK: - spec 021: [Float] ↔ Data zero-copy 変換

extension Array where Element == Float {
    /// L2 正規化済み Float Array → SwiftData 永続化用 Data。
    var asEmbeddingData: Data {
        withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }
}

extension Data {
    /// SwiftData から取り出した Data → Float Array。
    var asFloatArray: [Float] {
        withUnsafeBytes { rawBuffer in
            Array(rawBuffer.bindMemory(to: Float.self))
        }
    }
}

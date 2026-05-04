//
//  SearchPredicate.swift
//  KnowledgeTree
//
//  spec 008 — 検索クエリから動的 Predicate<Article> を生成する純粋関数。
//  検索対象: title / canonicalTitle / summary / essence / extractedKnowledge.summary /
//          keyFact.statement / entity.name / tag.name (8 フィールド)。
//
//  iOS 26 SDK の SwiftData Predicate は relationship target の string contains を
//  サポート (research.md R1)。動かない場合の View 側 post-filter フォールバックは
//  ArticleListView 側で実施。
//

import Foundation
import SwiftData

enum SearchPredicate {
    /// 検索クエリから Predicate<Article> を生成。
    /// 注意: iOS 26 SwiftData Predicate macro が optional chaining + relationship target の
    /// string contains を完全サポートしていないため、Predicate は **Article 直接フィールド
    /// (title) のみ** に絞り、relationship target (enrichment / extractedKnowledge / tags)
    /// は View 側で `matches(article:query:)` で post-filter する (research.md R1 の B 案)。
    /// これでも 1000 記事規模なら 200ms 以内に収まる。
    static func make(query: String) -> Predicate<Article>? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return nil }

        return #Predicate<Article> { article in
            article.title.localizedStandardContains(q)
        }
    }

    /// SwiftData Predicate が動作しない場合の View 側 post-filter フォールバック。
    /// 同じ 8 フィールドを Swift コードで evaluate する。
    static func matches(article: Article, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }

        if article.title.localizedStandardContains(q) { return true }
        if let s = article.enrichment?.canonicalTitle, s.localizedStandardContains(q) { return true }
        if let s = article.enrichment?.summary, s.localizedStandardContains(q) { return true }
        if let s = article.extractedKnowledge?.essence, s.localizedStandardContains(q) { return true }
        if let s = article.extractedKnowledge?.summary, s.localizedStandardContains(q) { return true }
        if let facts = article.extractedKnowledge?.keyFacts,
           facts.contains(where: { $0.statement.localizedStandardContains(q) }) { return true }
        if let entities = article.extractedKnowledge?.entities,
           entities.contains(where: { $0.name.localizedStandardContains(q) }) { return true }
        if article.tags.contains(where: { $0.name.localizedStandardContains(q) }) { return true }
        return false
    }
}

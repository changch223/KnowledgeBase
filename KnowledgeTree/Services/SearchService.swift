//
//  SearchService.swift
//  KnowledgeTree
//
//  spec 044 — ArticleListView の検索結果に **relevance ranking** と
//  **matched field 表示** を加える純関数。
//
//  spec 008 SearchPredicate は 8 フィールドの substring match を提供するが、
//  結果は savedAt 順のみで「タイトル一致」が下位に埋もれる問題があった。
//  本 service は同 8 フィールドを field 別の score で重み付けして並び替える:
//    - title 完全一致 (大文字小文字無視): 100
//    - title 部分一致: 50
//    - entity / tag 名一致: 20
//    - essence / summary 一致: 10
//    - canonicalTitle / KeyFact 一致: 5
//  同 score なら savedAt desc。
//
//  matchedFields は ArticleRow が badge を出すヒント (どこで一致したか可視化)。
//

import Foundation
import SwiftData

enum SearchService {

    /// 検索結果 (元 Article + score + どのフィールドで一致したか)
    struct ScoredResult: Identifiable {
        var id: PersistentIdentifier { article.persistentModelID }
        let article: Article
        let score: Int
        let matchedFields: Set<MatchField>
    }

    /// 一致したフィールドの種類 (ArticleRow の badge 表示用)
    enum MatchField: String, CaseIterable, Hashable {
        case title
        case essence
        case summary
        case keyFact
        case entity
        case tag

        /// ローカライズキー (ArticleRow で localized string 表示)
        var localizationKey: String {
            switch self {
            case .title:   return "search.match.title"
            case .essence: return "search.match.essence"
            case .summary: return "search.match.summary"
            case .keyFact: return "search.match.keyFact"
            case .entity:  return "search.match.entity"
            case .tag:     return "search.match.tag"
            }
        }
    }

    /// 検索 query を articles 全件に適用して score 降順 + savedAt 降順で返す。
    /// query が空白のみ → 全 articles を score 0 + matchedFields 空で返す (検索 OFF 状態)。
    static func search(query: String, in articles: [Article]) -> [ScoredResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            return articles
                .sorted { $0.savedAt > $1.savedAt }
                .map { ScoredResult(article: $0, score: 0, matchedFields: []) }
        }

        var results: [ScoredResult] = []
        for article in articles {
            var score = 0
            var matched: Set<MatchField> = []

            // title (完全 50 + 部分 50 = 100 完全一致時、ぱ部分一致のみは 50)
            let titleLower = article.title.lowercased()
            if titleLower == q.lowercased() {
                score += 100
                matched.insert(.title)
            } else if article.title.localizedStandardContains(q) {
                score += 50
                matched.insert(.title)
            }

            if let canonical = article.enrichment?.canonicalTitle,
               canonical.localizedStandardContains(q) {
                score += 5
                matched.insert(.title)
            }

            if let essence = article.extractedKnowledge?.essence,
               essence.localizedStandardContains(q) {
                score += 10
                matched.insert(.essence)
            }
            if let summary = article.extractedKnowledge?.summary,
               summary.localizedStandardContains(q) {
                score += 10
                matched.insert(.summary)
            }
            if let enrSummary = article.enrichment?.summary,
               enrSummary.localizedStandardContains(q) {
                score += 5
                matched.insert(.summary)
            }
            if let facts = article.extractedKnowledge?.keyFacts,
               facts.contains(where: { $0.statement.localizedStandardContains(q) }) {
                score += 5
                matched.insert(.keyFact)
            }
            if let entities = article.extractedKnowledge?.entities,
               entities.contains(where: { $0.name.localizedStandardContains(q) }) {
                score += 20
                matched.insert(.entity)
            }
            if article.tags.contains(where: { $0.name.localizedStandardContains(q) }) {
                score += 20
                matched.insert(.tag)
            }

            if score > 0 {
                results.append(ScoredResult(article: article, score: score, matchedFields: matched))
            }
        }

        return results.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.article.savedAt > rhs.article.savedAt
        }
    }
}

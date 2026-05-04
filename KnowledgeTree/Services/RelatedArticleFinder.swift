//
//  RelatedArticleFinder.swift
//  KnowledgeTree
//
//  spec 008 — 共通 KnowledgeEntity を持つ記事を関連記事として算出する純粋関数。
//  共通数 desc + savedAt desc tiebreak で上位 limit 件返す。
//

import Foundation

struct RelatedArticle: Identifiable, Sendable {
    var id: UUID { article.id }
    let article: Article
    let commonEntityCount: Int
    /// 表示用の共通 entity 名 (上位 3 件、salience 降順)
    let commonEntities: [String]
}

enum RelatedArticleFinder {
    /// 基準記事と共通 entity を持つ他記事を上位 limit 件返す。
    static func find(
        for article: Article,
        in candidates: [Article],
        limit: Int = 5
    ) -> [RelatedArticle] {
        // 基準記事の entity 名 set (lowercase + trim)
        let baseKeys: Set<String> = Set(
            (article.extractedKnowledge?.entities ?? []).compactMap { entity in
                let key = entity.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                return key.isEmpty ? nil : key
            }
        )
        guard !baseKeys.isEmpty else { return [] }

        var results: [RelatedArticle] = []
        for other in candidates {
            guard other.id != article.id else { continue }
            let otherEntitiesByKey: [String: KnowledgeEntity] = Dictionary(
                (other.extractedKnowledge?.entities ?? []).compactMap { entity in
                    let key = entity.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    return key.isEmpty ? nil : (key, entity)
                },
                uniquingKeysWith: { first, _ in first }
            )
            let common = baseKeys.intersection(Set(otherEntitiesByKey.keys))
            guard !common.isEmpty else { continue }

            // 表示用 name (salience 降順、上位 3)
            let topNames = common
                .compactMap { otherEntitiesByKey[$0] }
                .sorted { $0.salience > $1.salience }
                .prefix(3)
                .map { $0.name }

            results.append(RelatedArticle(
                article: other,
                commonEntityCount: common.count,
                commonEntities: Array(topNames)
            ))
        }

        // commonCount desc, savedAt desc
        results.sort { lhs, rhs in
            if lhs.commonEntityCount != rhs.commonEntityCount {
                return lhs.commonEntityCount > rhs.commonEntityCount
            }
            return lhs.article.savedAt > rhs.article.savedAt
        }

        return Array(results.prefix(limit))
    }
}

//
//  SuggestedTagFinder.swift
//  KnowledgeTree
//
//  spec 008 — KnowledgeEntity (salience 4 以上) から「自動タグ候補」を抽出する純粋関数。
//

import Foundation

struct SuggestedTag: Identifiable, Sendable {
    var id: String { normalizedName }
    /// TagNormalizer.normalize 済の name (実際にタグ化される時の値)
    let normalizedName: String
    /// 元 entity.name (UI 表示用、case 含む)
    let displayName: String
    let salience: Int
}

enum SuggestedTagFinder {
    static let salienceThreshold = 4

    /// article の entity から salience >= 4 の候補を上位 limit 件返す。
    /// 既存タグ (existingTagNames、TagNormalizer.normalize 済) と重複するものは除外。
    static func find(
        for article: Article,
        existingTagNames: Set<String>,
        limit: Int = 5
    ) -> [SuggestedTag] {
        let entities = article.extractedKnowledge?.entities ?? []
        let raw: [SuggestedTag] = entities.compactMap { entity in
            guard entity.salience >= salienceThreshold else { return nil }
            guard let normalized = TagNormalizer.normalize(entity.name) else { return nil }
            guard !existingTagNames.contains(normalized) else { return nil }
            return SuggestedTag(
                normalizedName: normalized,
                displayName: entity.name,
                salience: entity.salience
            )
        }

        // dedupe by normalizedName (順序保持)
        var seen: Set<String> = []
        var unique: [SuggestedTag] = []
        for s in raw {
            if !seen.contains(s.normalizedName) {
                seen.insert(s.normalizedName)
                unique.append(s)
            }
        }

        // salience desc sort
        unique.sort { $0.salience > $1.salience }
        return Array(unique.prefix(limit))
    }
}

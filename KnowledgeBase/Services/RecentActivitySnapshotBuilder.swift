//
//  RecentActivitySnapshotBuilder.swift
//  KnowledgeTree
//
//  spec 011 — 元は KnowledgeMapBuilder.swift に同居していた純粋関数モジュール。
//
//  多言語対応 Phase A (死蔵 view 削除) で KnowledgeMapView / RecentActivityCards (共に AI ブレイン
//  タブ v1 の廃止 view) と KnowledgeMapBuilder.swift のグラフ配置ロジックを削除する際、
//  本体 (`RecentActivitySnapshot` / `RecentActivitySnapshotBuilder`) だけは
//  `RecentActivitySnapshotBuilderTests.swift` (7 ケース) が独立して検証し続けているため
//  この単独ファイルへ切り出して保持した。産物 View (`RecentActivityCards`) は既に死蔵だが、
//  ロジック自体は将来の再利用に耐える純粋関数のまま残す。
//
//  contracts/recent-activity-cards.md 準拠。
//

import Foundation

/// RecentActivityCards (旧 AI ブレインタブ Section 3) 用データ。
struct RecentActivitySnapshot: Sendable {
    /// 直近 7 日の Article 件数
    let articlesThisWeek: Int
    /// 直近 7 日で記事増加が多いタグ Top3
    let growingTags: [GrowingTag]
    /// 直近 7 日で初出現の entity ペア (上位 2 ペア)
    let newConnections: [Connection]

    struct GrowingTag: Hashable, Sendable {
        let name: String
        let count: Int
    }

    struct Connection: Hashable, Sendable {
        let first: String
        let second: String
    }

    static let empty = RecentActivitySnapshot(
        articlesThisWeek: 0,
        growingTags: [],
        newConnections: []
    )
}

/// `Tag` と `KnowledgeEntity` を入力に直近 7 日のアクティビティを集計する純粋関数モジュール。
///
/// contracts/recent-activity-cards.md 準拠。
enum RecentActivitySnapshotBuilder {
    /// 直近 7 日の活動スナップショットを生成。
    /// - Parameter tags: 全タグ
    /// - Parameter entities: 全 KnowledgeEntity (knowledge.article.savedAt から最古を判定)
    /// - Parameter sevenDaysAgo: 「今」から 7 日前の Date (テスト時は時刻注入)
    static func build(
        tags: [Tag],
        entities: [KnowledgeEntity],
        sevenDaysAgo: Date
    ) -> RecentActivitySnapshot {
        let articlesThisWeek = computeArticlesThisWeek(
            tags: tags,
            sevenDaysAgo: sevenDaysAgo
        )
        let growingTags = computeGrowingTags(
            tags: tags,
            sevenDaysAgo: sevenDaysAgo
        )
        let newConnections = computeNewConnections(
            entities: entities,
            sevenDaysAgo: sevenDaysAgo
        )
        return RecentActivitySnapshot(
            articlesThisWeek: articlesThisWeek,
            growingTags: growingTags,
            newConnections: newConnections
        )
    }

    /// 全タグに紐づく article を Set 化 (重複排除) → savedAt > sevenDaysAgo の件数
    static func computeArticlesThisWeek(tags: [Tag], sevenDaysAgo: Date) -> Int {
        var seen = Set<UUID>()
        var count = 0
        for tag in tags {
            for article in (tag.articles ?? []) {
                guard !seen.contains(article.id) else { continue }
                seen.insert(article.id)
                if article.savedAt > sevenDaysAgo {
                    count += 1
                }
            }
        }
        return count
    }

    /// 各タグの recent article 件数 desc Top3 (件数 0 除外)
    static func computeGrowingTags(
        tags: [Tag],
        sevenDaysAgo: Date
    ) -> [RecentActivitySnapshot.GrowingTag] {
        let counts: [(name: String, count: Int)] = tags.compactMap { tag in
            let recent = (tag.articles ?? []).filter { $0.savedAt > sevenDaysAgo }.count
            return recent > 0 ? (tag.name, recent) : nil
        }
        return counts
            .sorted { $0.count > $1.count }
            .prefix(3)
            .map { RecentActivitySnapshot.GrowingTag(name: $0.name, count: $0.count) }
    }

    /// entity 名 (lowercased + trim) でグループ化 → 各グループの最古 savedAt 取得 →
    /// `> sevenDaysAgo` のグループから salience desc Top2 でペア化
    static func computeNewConnections(
        entities: [KnowledgeEntity],
        sevenDaysAgo: Date
    ) -> [RecentActivitySnapshot.Connection] {
        // 1. グループ化: 正規化 name → (最古 savedAt, 最大 salience, 元 name 例)
        struct EntityGroup {
            var earliestDate: Date
            var maxSalience: Int
            var displayName: String
        }
        var groups: [String: EntityGroup] = [:]
        for entity in entities {
            let normalized = entity.name
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            guard let savedAt = entity.knowledge?.article?.savedAt else { continue }
            if var existing = groups[normalized] {
                if savedAt < existing.earliestDate {
                    existing.earliestDate = savedAt
                }
                if entity.salience > existing.maxSalience {
                    existing.maxSalience = entity.salience
                    existing.displayName = entity.name
                }
                groups[normalized] = existing
            } else {
                groups[normalized] = EntityGroup(
                    earliestDate: savedAt,
                    maxSalience: entity.salience,
                    displayName: entity.name
                )
            }
        }

        // 2. 7 日以内に初出現したものだけ抽出
        let recentGroups = groups.values.filter { $0.earliestDate > sevenDaysAgo }

        // 3. salience desc で sort、上位 4 件をペア化 (2 ペア)
        let sorted = recentGroups.sorted { $0.maxSalience > $1.maxSalience }
        var pairs: [RecentActivitySnapshot.Connection] = []
        var index = 0
        while index + 1 < sorted.count && pairs.count < 2 {
            pairs.append(RecentActivitySnapshot.Connection(
                first: sorted[index].displayName,
                second: sorted[index + 1].displayName
            ))
            index += 2
        }
        return pairs
    }
}

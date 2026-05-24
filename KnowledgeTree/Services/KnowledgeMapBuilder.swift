//
//  KnowledgeMapBuilder.swift
//  KnowledgeTree
//
//  spec 011 — AI ブレインタブ KnowledgeMapView 用の純粋関数モジュール。
//  Tag 配列を入力に MapGraph (ノード位置 + エッジ) を返す。
//
//  data-model.md Section B + contracts/knowledge-map-builder.md 準拠。
//  Phase 2: stub 実装 (中心配置のみ)。
//  Phase 5 / US2 (T021-T023): force-directed 本実装。
//

import Foundation
import SwiftUI

// MARK: - Transient types (永続化なし)

/// KnowledgeMap の 1 ノード = 1 Tag。位置と半径を保持。
struct MapNode: Identifiable, Hashable, Sendable {
    /// Tag.name (TagNormalizer 済の正規化値)
    let id: String
    /// force-directed 後の最終位置 (Canvas 座標系、単位 pt)
    var position: CGPoint
    /// 円のサイズ (40-100pt、(tag.articles ?? []).count 対数スケール)
    var radius: CGFloat
    /// 表示用 (VoiceOver / Tooltip 対応)
    let articleCount: Int
}

/// KnowledgeMap のエッジ = 共通 KnowledgeEntity を持つ Tag ペア。
/// from < to で正規化され Set 重複排除に対応。
struct MapEdge: Hashable, Sendable {
    let from: String
    let to: String
    let sharedEntityCount: Int
}

/// buildGraph の戻り値。
struct MapGraph: Sendable {
    let nodes: [MapNode]
    let edges: [MapEdge]

    static let empty = MapGraph(nodes: [], edges: [])
}

/// RecentActivityCards の 3 枚分のデータ (data-model.md B-4)。
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

// MARK: - Force parameters

/// force-directed layout の物理パラメータ。
struct ForceParams: Sendable {
    let repulsion: Double
    let spring: Double
    let centerPull: Double
    let damping: Double
    let idealEdgeLength: Double

    static let `default` = ForceParams(
        repulsion: 1500.0,
        spring: 0.05,
        centerPull: 0.02,
        damping: 0.85,
        idealEdgeLength: 120.0
    )
}

// MARK: - Seeded RNG (test-deterministic)

/// 決定論的テスト用 RNG。`SeededRandomNumberGenerator(seed: 42)` で固定。
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // 0 を避けるため (xorshift は 0 で degenerate)
        state = seed == 0 ? 0xdeadbeef : seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - KnowledgeMapBuilder

enum KnowledgeMapBuilder {
    /// production 用。canvasSize は KnowledgeMapView の GeometryReader から渡される。
    /// seed なし呼び出しは Date().timeIntervalSince1970 ベースで毎回違う配置になる。
    static func buildGraph(
        tags: [Tag],
        canvasSize: CGSize,
        iterations: Int = 8
    ) -> MapGraph {
        let seed = UInt64(Date().timeIntervalSince1970 * 1000)
        return buildGraph(
            tags: tags,
            canvasSize: canvasSize,
            iterations: iterations,
            seed: seed
        )
    }

    /// テスト用。固定 seed で決定論的レイアウト生成。
    static func buildGraph(
        tags: [Tag],
        canvasSize: CGSize,
        iterations: Int,
        seed: UInt64
    ) -> MapGraph {
        precondition(canvasSize.width > 0 && canvasSize.height > 0,
                     "canvasSize must be positive")
        guard !tags.isEmpty else { return .empty }

        let clampedIterations = max(1, min(50, iterations))

        // 1. エッジ計算
        let edges = computeEdges(tags: tags)

        // 2. 初期位置 (中心 ± random offset)
        var rng = SeededRandomNumberGenerator(seed: seed)
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let scatter = min(canvasSize.width, canvasSize.height) / 4.0
        var nodes: [MapNode] = tags.map { tag in
            let dx = Double.random(in: -scatter...scatter, using: &rng)
            let dy = Double.random(in: -scatter...scatter, using: &rng)
            return MapNode(
                id: tag.name,
                position: CGPoint(x: center.x + dx, y: center.y + dy),
                radius: nodeRadius(for: (tag.articles ?? []).count),
                articleCount: (tag.articles ?? []).count
            )
        }

        // 3. force-directed 反復
        for _ in 0..<clampedIterations {
            nodes = step(
                nodes: nodes,
                edges: edges,
                canvasSize: canvasSize,
                params: .default
            )
        }

        // 4. 最終 clamp (radius を考慮して境界を超えないように)
        nodes = nodes.map { node in
            var n = node
            n.position = clampToCanvas(n.position, radius: n.radius, canvasSize: canvasSize)
            return n
        }

        return MapGraph(nodes: nodes, edges: edges)
    }

    /// 1 反復だけ進める純粋関数。
    /// 反発力 (逆 2 乗) + バネ力 (エッジ) + 中心引力 を計算し、damping 後の position を返す。
    static func step(
        nodes: [MapNode],
        edges: [MapEdge],
        canvasSize: CGSize,
        params: ForceParams
    ) -> [MapNode] {
        guard !nodes.isEmpty else { return nodes }

        let n = nodes.count
        var forces = Array(repeating: CGPoint.zero, count: n)
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let indexByID: [String: Int] = Dictionary(
            uniqueKeysWithValues: nodes.enumerated().map { ($1.id, $0) }
        )

        // 反発力: 全ペア (i, j), i < j
        if n >= 2 {
            for i in 0..<(n - 1) {
                for j in (i + 1)..<n {
                    let dx = Double(nodes[j].position.x - nodes[i].position.x)
                    let dy = Double(nodes[j].position.y - nodes[i].position.y)
                    let distSq = max(1.0, dx * dx + dy * dy)
                    let dist = distSq.squareRoot()
                    let mag = params.repulsion / distSq
                    let fx = mag * dx / dist
                    let fy = mag * dy / dist
                    forces[i].x -= fx
                    forces[i].y -= fy
                    forces[j].x += fx
                    forces[j].y += fy
                }
            }
        }

        // バネ力: edges
        for edge in edges {
            guard let i = indexByID[edge.from], let j = indexByID[edge.to] else { continue }
            let dx = Double(nodes[j].position.x - nodes[i].position.x)
            let dy = Double(nodes[j].position.y - nodes[i].position.y)
            let dist = max(0.1, (dx * dx + dy * dy).squareRoot())
            let mag = params.spring * (dist - params.idealEdgeLength)
            let fx = mag * dx / dist
            let fy = mag * dy / dist
            forces[i].x += fx
            forces[i].y += fy
            forces[j].x -= fx
            forces[j].y -= fy
        }

        // 中心引力 + 速度更新
        return nodes.enumerated().map { (idx, node) in
            var n = node
            let toCenterX = Double(center.x - n.position.x) * params.centerPull
            let toCenterY = Double(center.y - n.position.y) * params.centerPull
            let totalFx = (forces[idx].x + toCenterX) * params.damping
            let totalFy = (forces[idx].y + toCenterY) * params.damping
            n.position = CGPoint(
                x: n.position.x + totalFx,
                y: n.position.y + totalFy
            )
            n.position = clampToCanvas(n.position, radius: n.radius, canvasSize: canvasSize)
            return n
        }
    }

    /// articles.count から円の半径を算出 (40-100pt、対数スケール)。
    /// 計算式: min(100, max(40, log2(count + 1) * 20))
    static func nodeRadius(for articleCount: Int) -> CGFloat {
        let scaled = log2(Double(max(0, articleCount)) + 1) * 20
        return CGFloat(min(100.0, max(40.0, scaled)))
    }

    // MARK: - Internals

    /// Tag ペアで KnowledgeEntity name set の intersection が空でなければ MapEdge を生成。
    /// 戻り値の edges は from < to 順序で正規化済 + 重複なし。
    static func computeEdges(tags: [Tag]) -> [MapEdge] {
        // 各タグの entity name set
        var entitySetByTag: [String: Set<String>] = [:]
        for tag in tags {
            var set = Set<String>()
            for article in (tag.articles ?? []) {
                guard let knowledge = article.extractedKnowledge else { continue }
                for entity in (knowledge.entities ?? []) {
                    let normalized = entity.name
                        .lowercased()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !normalized.isEmpty {
                        set.insert(normalized)
                    }
                }
            }
            entitySetByTag[tag.name] = set
        }

        // タグ名アルファベット順に sort
        let names = tags.map { $0.name }.sorted()
        var edges: Set<MapEdge> = []
        guard names.count >= 2 else { return [] }
        for i in 0..<(names.count - 1) {
            for j in (i + 1)..<names.count {
                let a = names[i]
                let b = names[j]
                guard let setA = entitySetByTag[a], let setB = entitySetByTag[b] else {
                    continue
                }
                let intersection = setA.intersection(setB)
                if !intersection.isEmpty {
                    edges.insert(MapEdge(
                        from: a,
                        to: b,
                        sharedEntityCount: intersection.count
                    ))
                }
            }
        }
        return Array(edges)
    }

    /// canvas 境界内に position を clamp。radius 分だけ余白を取る。
    private static func clampToCanvas(
        _ position: CGPoint,
        radius: CGFloat,
        canvasSize: CGSize
    ) -> CGPoint {
        let minX = radius
        let maxX = max(radius, canvasSize.width - radius)
        let minY = radius
        let maxY = max(radius, canvasSize.height - radius)
        return CGPoint(
            x: min(maxX, max(minX, position.x)),
            y: min(maxY, max(minY, position.y))
        )
    }
}

// MARK: - CGPoint convenience

private extension CGPoint {
    static let zero = CGPoint(x: 0, y: 0)
}

// MARK: - RecentActivitySnapshotBuilder

/// AI ブレインタブ Section 3 用の純粋関数モジュール。
/// `Tag` と `KnowledgeEntity` を入力に直近 7 日のアクティビティを集計する。
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

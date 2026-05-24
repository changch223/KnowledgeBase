//
//  TopicClusteringService.swift
//  KnowledgeTree
//
//  spec 036 — 動的トピック自動発見。
//  spec 021 essence embedding を K-means clustering して、各 cluster を
//  Foundation Models で命名 → UserTopic として候補保存。
//  起動時 + 7 日に 1 回 batch 実行。
//

import Foundation
import SwiftData
import Accelerate
import os

@MainActor
protocol TopicClusteringServiceProtocol: AnyObject {
    /// 必要なら batch 実行 (前回実行から 7 日経過 or 強制 force=true)。
    func runIfDue(force: Bool) async
}

@MainActor
final class TopicClusteringService: TopicClusteringServiceProtocol {

    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "topic-clustering")
    private let context: ModelContext
    private let session: LanguageModelSessionProtocol
    private let availability: AvailabilityChecker
    private let defaults: UserDefaults

    private let lastRunKey = "topicClustering.lastRunAt"
    private let runIntervalDays: Double = 7
    private let minArticles = 10            // これ未満は clustering せず
    private let minClusterSize = 3          // cluster の最低構成記事数
    private let maxK = 20                   // K の上限
    private let centroidDuplicateThreshold: Float = 0.7  // 既存 UserTopic との重複判定

    /// dismiss 後 30 日間は同 centroid の cluster を再候補化しない
    private let dismissCooldownDays: Double = 30

    init(
        context: ModelContext,
        session: LanguageModelSessionProtocol,
        availability: AvailabilityChecker = SystemLanguageModelAvailabilityChecker(),
        defaults: UserDefaults = .standard
    ) {
        self.context = context
        self.session = session
        self.availability = availability
        self.defaults = defaults
    }

    // MARK: - Entry Point

    func runIfDue(force: Bool = false) async {
        guard force || isDue() else { return }
        await runBatch()
        defaults.set(Date.now.timeIntervalSince1970, forKey: lastRunKey)
    }

    private func isDue() -> Bool {
        let lastRunTI = defaults.double(forKey: lastRunKey)
        guard lastRunTI > 0 else { return true }
        let lastRun = Date(timeIntervalSince1970: lastRunTI)
        let daysAgo = Date.now.timeIntervalSince(lastRun) / 86400
        return daysAgo >= runIntervalDays
    }

    // MARK: - Batch

    private func runBatch() async {
        // 1. essence embedding を持つ Article を fetch
        let allArticles = (try? context.fetch(FetchDescriptor<Article>())) ?? []
        let withEmbedding: [(Article, [Float])] = allArticles.compactMap { article in
            guard let data = article.essenceEmbedding else { return nil }
            return (article, data.asFloatArray)
        }

        guard withEmbedding.count >= minArticles else {
            logger.notice("topic clustering skipped: only \(withEmbedding.count) articles with embedding")
            return
        }

        // 2. K-means clustering
        let k = min(maxK, max(2, withEmbedding.count / 10))
        let clusters = Self.kmeans(
            entries: withEmbedding,
            k: k,
            maxIterations: 50
        )

        // 3. minClusterSize 以上のクラスタのみ採用
        let validClusters = clusters.filter { ($0.articles ?? []).count >= minClusterSize }
        let minSize = self.minClusterSize
        guard !validClusters.isEmpty else {
            logger.notice("topic clustering: no valid clusters (min size \(minSize))")
            return
        }

        // 4. 既存 UserTopic と重複していない cluster のみ候補化
        let existingTopics = (try? context.fetch(FetchDescriptor<UserTopic>())) ?? []
        let cooldownDate = Date.now.addingTimeInterval(-dismissCooldownDays * 86400)

        for cluster in validClusters {
            // 既存 centroid との distance check
            let isDuplicate = existingTopics.contains { topic in
                guard let existingData = topic.clusterCentroid else { return false }
                let existingCentroid = existingData.asFloatArray
                guard existingCentroid.count == cluster.centroid.count else { return false }
                let sim = EmbeddingService.cosineSimilarity(existingCentroid, cluster.centroid)
                if sim >= centroidDuplicateThreshold {
                    // 採用済 / 候補は重複として skip
                    if topic.acceptedAt != nil || topic.dismissedAt == nil {
                        return true
                    }
                    // dismissed で cooldown 内 → skip
                    if let resolved = topic.dismissedAt, resolved > cooldownDate {
                        return true
                    }
                }
                return false
            }
            if isDuplicate { continue }

            // 5. Foundation Models で命名
            let name = await nameCluster(articles: cluster.articles)

            // 6. UserTopic 作成 (候補)
            let topic = UserTopic(
                name: name,
                clusterCentroid: cluster.centroid.asEmbeddingData,
                articles: cluster.articles
            )
            context.insert(topic)
        }
        try? context.save()
    }

    // MARK: - Naming (AI or Fallback)

    private func nameCluster(articles: [Article]) async -> String {
        if availability.isAvailable {
            do {
                let prompt = Self.buildNamingPrompt(articles: articles)
                let output = try await session.generateTopicName(prompt: prompt)
                let trimmed = output.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    // 20 字以内に truncate
                    return String(trimmed.prefix(20))
                }
            } catch {
                logger.error("topic naming LM failed: \(String(describing: error), privacy: .public)")
            }
        }
        // Fallback: 上位 entity 名を結合
        return Self.fallbackName(articles: articles)
    }

    static func buildNamingPrompt(articles: [Article]) -> String {
        var prompt = """
        以下の記事群の共通テーマを 5-20 字の自然な日本語で命名してください。
        ユーザーが直感的に理解できる名前を付けてください。技術用語を避けてください。

        例: 『AI と Product Management』『SwiftUI 状態管理』『日本企業 DX 動向』

        ## 記事 (件数: \(articles.count))
        """
        for (i, article) in articles.prefix(10).enumerated() {
            let essence = article.extractedKnowledge?.essence ?? ""
            prompt += "\n[\(i + 1)] \(article.title) — \(essence)"
        }
        return prompt
    }

    static func fallbackName(articles: [Article]) -> String {
        // 全記事の entity を集計、上位 2 件を結合
        var counts: [String: Int] = [:]
        for article in articles {
            for entity in article.extractedKnowledge?.entities ?? [] {
                counts[entity.name, default: 0] += 1
            }
        }
        let top = counts.sorted { $0.value > $1.value }.prefix(2).map { $0.key }
        if top.isEmpty {
            return "新しいトピック"
        }
        return top.joined(separator: " / ")
    }

    // MARK: - K-means (cosine similarity ベース、L2 正規化済 embedding 前提)

    struct Cluster {
        let centroid: [Float]
        let articles: [Article]
    }

    static func kmeans(
        entries: [(Article, [Float])],
        k: Int,
        maxIterations: Int
    ) -> [Cluster] {
        guard !entries.isEmpty, k >= 1 else { return [] }
        let dim = entries[0].1.count
        guard dim > 0 else { return [] }

        // 初期 centroids = ランダム選択 (シード固定で deterministic)
        var generator = SystemRandomNumberGenerator()
        var initial = entries.indices.shuffled(using: &generator).prefix(k).map { entries[$0].1 }
        var centroids: [[Float]] = initial.map { $0 }

        var assignments: [Int] = Array(repeating: 0, count: entries.count)

        for _ in 0..<maxIterations {
            var changed = false

            // 1. 各 entry を最近 centroid に assign
            for (idx, (_, vec)) in entries.enumerated() {
                let bestIdx = (0..<centroids.count).max { lhs, rhs in
                    EmbeddingService.cosineSimilarity(vec, centroids[lhs]) < EmbeddingService.cosineSimilarity(vec, centroids[rhs])
                } ?? 0
                if assignments[idx] != bestIdx {
                    assignments[idx] = bestIdx
                    changed = true
                }
            }

            // 2. 各 cluster の centroid を更新 (mean → L2 正規化)
            var newCentroids: [[Float]] = Array(repeating: [Float](repeating: 0, count: dim), count: centroids.count)
            var counts: [Int] = Array(repeating: 0, count: centroids.count)
            for (idx, (_, vec)) in entries.enumerated() {
                let c = assignments[idx]
                counts[c] += 1
                for d in 0..<dim {
                    newCentroids[c][d] += vec[d]
                }
            }
            for c in 0..<centroids.count where counts[c] > 0 {
                let invCount = 1.0 / Float(counts[c])
                for d in 0..<dim {
                    newCentroids[c][d] *= invCount
                }
                // L2 正規化
                var sumSquares: Float = 0
                vDSP_svesq(newCentroids[c], 1, &sumSquares, vDSP_Length(dim))
                let norm = sqrt(sumSquares)
                if norm > 0 {
                    var divisor = norm
                    var normalized = [Float](repeating: 0, count: dim)
                    vDSP_vsdiv(newCentroids[c], 1, &divisor, &normalized, 1, vDSP_Length(dim))
                    newCentroids[c] = normalized
                }
            }
            centroids = newCentroids

            if !changed { break }
        }

        // 各 cluster に assign された記事をまとめる
        var clustered: [[Article]] = Array(repeating: [], count: centroids.count)
        for (idx, (article, _)) in entries.enumerated() {
            clustered[assignments[idx]].append(article)
        }

        var clusters: [Cluster] = []
        for c in 0..<centroids.count where !clustered[c].isEmpty {
            clusters.append(Cluster(centroid: centroids[c], articles: clustered[c]))
        }
        // 用済の initial 配列を release
        _ = initial
        return clusters
    }
}

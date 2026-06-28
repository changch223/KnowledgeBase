//
//  UserTopic.swift
//  KnowledgeTree
//
//  spec 036 — 動的トピック自動発見 @Model。
//  AI が essence embedding clustering で発見、ユーザーが「採用」したトピックは
//  Category と並列で表示される。
//

import Foundation
import SwiftData

@Model
final class UserTopic {
    var id: UUID = UUID()

    /// AI が命名したトピック名 (5-20 字、日本語)
    var name: String = ""

    var createdAt: Date = Date.now

    /// ユーザーが「採用」した時刻。nil = まだ候補。
    var acceptedAt: Date?

    /// ユーザーが「却下」した時刻。nil = まだ却下されていない。
    var dismissedAt: Date?

    /// クラスタの重心 embedding (L2 正規化済み Float Array byte 表現)。
    /// 重複 cluster 検出 + 新記事マッチに使う。
    @Attribute(.externalStorage) var clusterCentroid: Data?

    /// 構成記事 (deleteRule: .nullify、Article 削除時は relationship 解除)
    @Relationship(deleteRule: .nullify) var articles: [Article]? = []

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        acceptedAt: Date? = nil,
        dismissedAt: Date? = nil,
        clusterCentroid: Data? = nil,
        articles: [Article] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.acceptedAt = acceptedAt
        self.dismissedAt = dismissedAt
        self.clusterCentroid = clusterCentroid
        self.articles = articles
    }
}

extension UserTopic {
    /// 採用済 (UI でメインに表示するべきもの)
    var isAccepted: Bool {
        acceptedAt != nil && dismissedAt == nil
    }

    /// 候補 (採用も却下もされていない)
    var isCandidate: Bool {
        acceptedAt == nil && dismissedAt == nil
    }

    /// 重要度スコア = 構成記事数 × 最新性 (簡易、上位 N で並べ替え用)
    /// spec 051 Phase A: articles が Optional 化、`?? []` で safe unwrap。
    var importanceScore: Double {
        let arts = articles ?? []
        let count = Double(arts.count)
        guard let latestSavedAt = arts.map({ $0.savedAt }).max() else {
            return count
        }
        // 最新性: 7 日以内 = 1.0、30 日以内 = 0.5、それ以上 = 0.2
        let daysAgo = Date.now.timeIntervalSince(latestSavedAt) / 86400
        let recency = daysAgo < 7 ? 1.0 : (daysAgo < 30 ? 0.5 : 0.2)
        return count * recency
    }
}

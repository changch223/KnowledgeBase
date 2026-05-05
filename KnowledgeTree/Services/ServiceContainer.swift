//
//  ServiceContainer.swift
//  KnowledgeTree
//
//  spec 005 — 各 Service への参照を Environment 経由でビューに配るためのコンテナ。
//  bootstrap で 3 service を生成 → ServiceContainer に bind →
//  ArticleListView / ArticleDetailView から再抽出などの手動操作で参照する。
//

import Foundation
import Observation

@MainActor
@Observable
final class ServiceContainer {
    var enrichmentService: ArticleEnrichmentServiceProtocol?
    var bodyService: BodyExtractionServiceProtocol?
    var knowledgeService: KnowledgeExtractionServiceProtocol?
    /// spec 008: タグの CRUD を担当
    var tagStore: TagStore?
    /// spec 009: BG queue (Detail UI で「待機中」表示判定 + chunked 開始時の enqueue)
    var backgroundQueue: BackgroundExtractionQueueProtocol?
    /// spec 018: Category 統合 AI ダイジェスト生成 service
    var digestService: KnowledgeDigestService?
}

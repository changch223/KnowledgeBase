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
    /// spec 021: NLEmbedding ベース文章 embedding service
    var embeddingService: EmbeddingService?
    /// spec 021: AI Chat (RAG) service
    var chatService: ChatServiceProtocol?
    /// spec 035: 「最近のあなた」差分ダイジェスト service
    var recentDigestService: RecentDigestServiceProtocol?
    /// spec 035: 知識 Clip タブの最後に開いた時刻 store
    var lastOpenedStore: LastOpenedStore?
    /// spec 037: 時系列事実上書き検出 service
    var conflictDetectionService: ConflictDetectionServiceProtocol?
    /// spec 036: 動的トピック clustering service
    var topicClusteringService: TopicClusteringServiceProtocol?
    /// spec 040: Knowledge Graph 抽出 service (記事保存 hook で fire-and-forget)
    var graphExtractionService: GraphExtractionServiceProtocol?
    /// spec 040: Knowledge Graph traversal service (Digest / Chat prompt 拡張で使用)
    var graphTraversalService: GraphTraversalServiceProtocol?
    /// spec 041: Knowledge Graph 編集 store (rename / merge / delete)
    var graphNodeStore: GraphNodeStore?
    /// spec 041: AI 提案 (isUncertain edge) のレビュー service
    var graphProposalReviewService: GraphProposalReviewServiceProtocol?
    /// spec 042: Apple Translation framework の en→ja セットアップ状態管理
    var translationAvailability: TranslationAvailabilityProtocol?
}

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
    /// spec 042: ConceptPage 自動生成 / 再合成 service (Foundation + Fallback の 2 経路)
    var conceptSynthesisService: ConceptSynthesisServiceProtocol?
    /// spec 042: ConceptPage の編集 store (rename / merge / delete / setFollowing)、Phase 6 で実装
    var conceptPageStore: ConceptPageStore?
    /// spec 043: SavedAnswer 自動保存 + pin / delete / isStale 連鎖 service
    var savedAnswerService: SavedAnswerServiceProtocol?
    /// spec 044: 学習タブの surface 候補生成 (5-tier scoring)
    var understandingCardSurfaceService: UnderstandingCardSurfaceServiceProtocol?
    /// spec 044: 学習行動の永続化 + ConceptPage.userUnderstanding +1 + 1-hop graph 波及
    var understandingTrackerService: UnderstandingTrackerServiceProtocol?
    /// spec 044: 学習カードから deep dive chat を起動する wrapper (ChatService 流用、旧経路)
    /// 注: spec 044 brushup で DeepDiveChatService に置き換え済。互換のため optional 残置するが
    /// 新コードは `deepDiveChatService` を使うこと。
    var deepDiveChatStarter: DeepDiveChatStarterProtocol?
    /// spec 044 brushup: 家庭教師モード専用 chat service (Foundation Models 直接呼び、retrieval なし)
    var deepDiveChatService: DeepDiveChatServiceProtocol?
    /// spec 045: SavedAnswer の「再生成」trigger。SavedAnswerDetailView がセット → KnowledgeTreeApp が観測して AI チャットタブに切替 + ChatTabView が消費して新 ChatSession + question 自動送信。
    var pendingRegenerateRequest: PendingRegenerateRequest?
    /// spec 048: Apple Intelligence 可用性 (banner 表示判定用)。
    /// bootstrap 完了後に set される。nil ならまだ初期化中 = banner も非表示。
    var availabilityChecker: AvailabilityChecker?
    /// spec 052: Widget deep link `iknow://learning/card/{uuid}` 経由で起動された時の対象 card ID。
    /// KnowledgeTreeApp.onOpenURL がセット → selectedTab=.learning に切替 →
    /// UnderstandingTabView が観測して DeepDiveChatView を push → consume して nil に戻す。
    var pendingDeepLinkCardID: UUID?
    /// spec 056: 「最近の記事」セクションの差分判定 + cache 維持 service
    var recentArticlesService: RecentArticlesServiceProtocol?
    /// spec 056: AI チャット空状態の suggested prompts 動的生成 service
    var suggestedPromptGenerator: SuggestedPromptGeneratorProtocol?
    /// spec 058: Lint loop 6 step を週 1 BGTask + 「今すぐ整理」 button から実行
    var lintEngine: LintEngineProtocol?
    /// spec 058: 健全性スコア計算 service (Settings 表示用)
    var healthScoreService: HealthScoreServiceProtocol?
}

/// spec 045: 「再生成」trigger payload。
struct PendingRegenerateRequest: Equatable {
    let question: String
    let originalAnswerID: UUID
}

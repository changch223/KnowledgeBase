//
//  KnowledgeTreeApp.swift
//  KnowledgeTree
//
//  Created by chang chiawei on 2026/05/04.
//
//  spec 001 — App Group ModelContainer
//  spec 002 — ArticleEnrichment schema + EnrichmentService bootstrap + backfill
//  spec 003 — ArticleBody schema + BodyExtractionService bootstrap + backfill
//  spec 004 — ExtractedKnowledge / KeyFact / KnowledgeEntity schema +
//             KnowledgeExtractionService bootstrap + 3 service chain backfill
//  spec 005 — ProcessingMonitor / RefreshTrigger / ServiceContainer を Environment 経由で配信
//  spec 011 — TabView 化 (ライブラリ / AI ブレイン)。ArticleListView は内部 NavigationStack
//             を保持しているのでそのまま配置 (改修なし)。AIBrainView 側は内部に独自
//             NavigationStack を持つ。
//

import SwiftUI
import SwiftData

/// spec 035: TabView selection 識別子。
enum AppTab: Hashable {
    case library
    case knowledgeClip
    case aibrain
    case chat
}

@main
struct KnowledgeTreeApp: App {
    @State private var processingMonitor = ProcessingMonitor()
    @State private var refreshTrigger = RefreshTrigger()
    @State private var serviceContainer = ServiceContainer()
    /// spec 035: 起動時 default は知識 Clip タブ (「最近のあなた」を最初に見せる)
    @State private var selectedTab: AppTab = .knowledgeClip

    @MainActor
    init() {
        // spec 009: BGTaskScheduler への register は launch 最早タイミングで必須。
        // bootstrap (.task) では遅すぎる (View 描画後なので、launch 時 BGTask 通知を取りこぼす)。
        BackgroundExtractionScheduler.shared.registerHandler()
    }

    var sharedModelContainer: ModelContainer = {
        // CoreData / SwiftData が ApplicationSupport directory を自動 create する前に
        // 先回りで作成しておく。実機初回起動時の "Sandbox access denied" recovery ログ
        // を抑止するため。
        AppGroup.ensureContainerDirectoryExists()

        // spec 005: SharedSchema 経由で Share Extension と完全に同一定義を使う。
        do {
            return try ModelContainer(
                for: SharedSchema.all,
                configurations: [SharedSchema.sharedConfiguration()]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                ArticleListView()
                    .tabItem {
                        Label("library.tab.title", systemImage: "books.vertical")
                    }
                    .tag(AppTab.library)
                    .accessibilityIdentifier("tab.library")

                // spec 018: 知識 Clip タブ (3rd タブ、Library と AI ブレインの間)
                // spec 035: 起動時 default selection
                KnowledgeClipView()
                    .tabItem {
                        Label("clip.tab.title", systemImage: "lightbulb.fill")
                    }
                    .tag(AppTab.knowledgeClip)
                    .accessibilityIdentifier("tab.knowledgeClip")

                AIBrainView()
                    .tabItem {
                        Label("aibrain.tab.title", systemImage: "brain")
                    }
                    .tag(AppTab.aibrain)
                    .accessibilityIdentifier("tab.aibrain")

                // spec 021: AI チャット (4th タブ)
                ChatTabView()
                    .tabItem {
                        Label("chat.tab.title", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                    .tag(AppTab.chat)
                    .accessibilityIdentifier("tab.chat")
            }
            .environment(processingMonitor)
            .environment(refreshTrigger)
            .environment(serviceContainer)
            .task {
                await bootstrap()
            }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func bootstrap() async {
        // 二重 bootstrap 抑止: scene 復帰時の .task 再実行で backfill が重複しないように。
        guard serviceContainer.knowledgeService == nil else { return }

        let context = sharedModelContainer.mainContext

        // spec 009: ChunkProgressStore (incremental 永続化)
        let chunkProgressStore = SwiftDataChunkProgressStore(
            context: context,
            refreshTrigger: refreshTrigger
        )

        // spec 015: AutoCategoryClassifier (Foundation Models 経由で Tag → Category 推論)
        let categoryClassifier: AutoCategoryClassifier = FoundationModelsAutoCategoryClassifier()

        // spec 008: TagStore (spec 012 で knowledgeService に inject するため先に構築)
        // spec 015: TagStore に classifier を inject、新規 Tag 作成時の自動 Category 分類を有効化
        let tagStore = TagStore(
            context: context,
            refreshTrigger: refreshTrigger,
            categoryClassifier: categoryClassifier
        )

        // spec 018: KnowledgeDigestService (Foundation + Fallback) を先に構築、
        // KnowledgeExtractionService に inject する
        let session = FoundationModelLanguageModelSession()
        let availability = SystemLanguageModelAvailabilityChecker()

        // spec 040: Knowledge Graph 抽出 + traversal service
        // (Digest / Chat / Extraction の prompt 拡張 + 記事保存 hook で inject)
        let graphTraversalService: GraphTraversalServiceProtocol = GraphTraversalService()
        let graphExtractionService: GraphExtractionServiceProtocol = GraphExtractionService(
            context: context,
            session: session,
            availability: availability
        )

        let fallbackDigestService = FallbackKnowledgeDigestService(context: context)
        let digestService: KnowledgeDigestService = FoundationModelsKnowledgeDigestService(
            session: session,
            context: context,
            availability: availability,
            fallback: fallbackDigestService,
            graphTraversal: graphTraversalService
        )

        // spec 021: NLEmbedding ベースの文章 embedding service (起動時に 1 度ロード)
        let embeddingService = EmbeddingService()

        // spec 037: ConflictDetectionService (knowledge service の hook 用に先構築)
        let conflictDetectionService: ConflictDetectionServiceProtocol = ConflictDetectionService(
            context: context,
            session: session,
            availability: availability
        )

        // spec 036: TopicClusteringService (起動時 + 7 日 batch)
        let topicClusteringService: TopicClusteringServiceProtocol = TopicClusteringService(
            context: context,
            session: session,
            availability: availability
        )

        // spec 004 + 009 + 010 + 012 + 018 + 021 + 037: 知識抽出 service
        // (auto-tag 用 tagStore + digest stale 化 + essence embedding 生成 hook + conflict 検出 hook)
        let knowledgeStore = SwiftDataArticleKnowledgeStore(
            context: context,
            refreshTrigger: refreshTrigger
        )
        let knowledgeExtractor = KnowledgeExtractor(session: session)
        let knowledgeService = DefaultKnowledgeExtractionService(
            extractor: knowledgeExtractor,
            store: knowledgeStore,
            processingMonitor: processingMonitor,
            chunkProgressStore: chunkProgressStore,
            tagStore: tagStore,
            digestService: digestService,
            embeddingService: embeddingService,
            conflictDetectionService: conflictDetectionService,
            graphExtractionService: graphExtractionService
        )

        // spec 003: 本文抽出 service (knowledge service を inject)
        let bodyStore = SwiftDataArticleBodyStore(
            context: context,
            refreshTrigger: refreshTrigger
        )
        let bodyService = DefaultBodyExtractionService(
            store: bodyStore,
            knowledgeExtractionService: knowledgeService,
            processingMonitor: processingMonitor
        )

        // spec 002: enrichment service (body service を inject)
        let enrichmentStore = SwiftDataArticleEnrichmentStore(
            context: context,
            refreshTrigger: refreshTrigger
        )
        let enrichmentService = DefaultArticleEnrichmentService(
            session: URLSession.shared,
            store: enrichmentStore,
            bodyExtractionService: bodyService,
            processingMonitor: processingMonitor
        )

        // spec 009: BackgroundExtractionQueue + Runner
        let articleStore = SwiftDataArticleStore(context: context)
        let bgQueue = BackgroundExtractionQueue(context: context, refreshTrigger: refreshTrigger)
        let bgRunner = BackgroundExtractionRunner(
            knowledgeService: knowledgeService,
            articleStore: articleStore,
            queue: bgQueue
        )
        BackgroundExtractionScheduler.shared.queueProvider = { [weak bgQueue] in bgQueue }
        BackgroundExtractionScheduler.shared.runnerProvider = { [weak bgRunner] in bgRunner }

        // spec 021: ChatService 構築 (embedding + Foundation Models + availability で 3 経路分岐)
        // spec 040: graphTraversal を inject、RAG prompt に「## 関連エンティティ」を追加
        let chatService: ChatServiceProtocol = ChatService(
            context: context,
            embeddingService: embeddingService,
            session: session,
            availability: availability,
            graphTraversal: graphTraversalService
        )

        // spec 035: RecentDigestService + LastOpenedStore 構築
        let recentDigestService: RecentDigestServiceProtocol = RecentDigestService(
            session: session,
            availability: availability
        )
        let lastOpenedStore = LastOpenedStore()

        // ServiceContainer に登録 (再抽出ボタン等で参照)
        serviceContainer.enrichmentService = enrichmentService
        serviceContainer.bodyService = bodyService
        serviceContainer.knowledgeService = knowledgeService
        serviceContainer.tagStore = tagStore
        serviceContainer.backgroundQueue = bgQueue
        serviceContainer.digestService = digestService  // spec 018
        serviceContainer.embeddingService = embeddingService  // spec 021
        serviceContainer.chatService = chatService            // spec 021
        serviceContainer.recentDigestService = recentDigestService  // spec 035
        serviceContainer.lastOpenedStore = lastOpenedStore          // spec 035
        serviceContainer.conflictDetectionService = conflictDetectionService // spec 037
        serviceContainer.topicClusteringService = topicClusteringService     // spec 036
        serviceContainer.graphExtractionService = graphExtractionService     // spec 040
        serviceContainer.graphTraversalService = graphTraversalService       // spec 040

        // 既存記事の backfill (順次): enrichment → body → knowledge
        await enrichmentService.backfillAll()
        await bodyService.backfillAll()
        await knowledgeService.backfillAll()
        // spec 008: 孤児タグの cleanup (起動時 1 回)
        try? tagStore.cleanupOrphans()

        // spec 013: 既存記事への auto-tag backfill (1 度限り、永続フラグで重複防止)
        let backfillRunner = AutoTagBackfillRunner(
            context: context,
            tagStore: tagStore,
            processingMonitor: processingMonitor
        )
        await backfillRunner.run()

        // spec 015: 既存 Tag の Category 自動分類 backfill (1 度限り、永続フラグで重複防止)
        let categoryBackfillRunner = AutoCategoryBackfillRunner(
            context: context,
            classifier: categoryClassifier,
            processingMonitor: processingMonitor
        )
        await categoryBackfillRunner.run()

        // spec 018: 起動時の stale Digest 全再集約 (新記事追加分が反映される)
        try? await digestService.regenerateAllStale()

        // spec 021: 既存記事への essence embedding backfill (Apple Intelligence 端末のみ動作)
        await chatService.backfillEmbeddings()

        // spec 036: 動的トピック batch (前回から 7 日経過していれば実行)
        await topicClusteringService.runIfDue(force: false)
    }
}

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
/// spec 056: V3.0 redesign で 3 タブに削減 (知識 Clip / ライブラリ / AI チャット)。
/// 学習タブ / AI ブレインタブ / Settings root tab は削除、機能は新動線で完全保持。
enum AppTab: Hashable {
    case knowledgeClip  // spec 056: 起動 default、Today タブ
    case library
    case chat
}

@main
struct KnowledgeTreeApp: App {
    @State private var processingMonitor = ProcessingMonitor()
    @State private var refreshTrigger = RefreshTrigger()
    @State private var serviceContainer = ServiceContainer()
    /// spec 056: 起動 default は知識 Clip (Today タブ)、毎回起動で強制 `.knowledgeClip`
    /// (LastOpenedStore.lastTab は無視、新習慣定着のため)。
    @State private var selectedTab: AppTab = .knowledgeClip
    /// spec 049: 初回起動時の onboarding 表示。
    @State private var showOnboarding: Bool = !OnboardingFlagStore.shared.hasCompleted
    /// spec 061 (P1-6): 永続 store 構築失敗 → in-memory fallback で起動した印。
    /// true なら「データ読み込みに問題」banner を表示する。
    @State private var storeLoadFailed: Bool = UserDefaults.standard.bool(forKey: "spec061_storeLoadFailed")

    @MainActor
    init() {
        // spec 009: BGTaskScheduler への register は launch 最早タイミングで必須。
        // bootstrap (.task) では遅すぎる (View 描画後なので、launch 時 BGTask 通知を取りこぼす)。
        BackgroundExtractionScheduler.shared.registerHandler()
        // spec 042: ConceptPage 再合成 BGTask handler の register (chunked extraction とは別 identifier)
        BackgroundExtractionScheduler.shared.registerConceptResynthesisHandler()
        // spec 058: 週 1 Lint loop BGTask handler の register (日曜 3 AM、別 identifier)
        BackgroundExtractionScheduler.shared.registerWeeklyLintHandler()
        // spec 058: Schema 外出し (docs/iknow-schema.md) を memory cache、fallback で安全保証
        SchemaLoader.shared.load()
        // spec 056: V3.0 redesign で起動 default は知識 Clip に固定 (毎回 reset)。
        // 旧 spec 044 / spec 035 の tab migration flag は不要 (default を struct init で強制)。
        // spec 051 Phase A 完成: iCloud toggle が有効 (forced reset 削除)。
    }

    var sharedModelContainer: ModelContainer = {
        AppGroup.ensureContainerDirectoryExists()

        // spec 051 Phase A 完成: UserDefaults `icloud_sync_enabled` flag を読んで
        // CloudKit private DB と App Group を同時指定。CloudKit 失敗時は local-only fallback。
        do {
            return try ModelContainer(
                for: SharedSchema.all,
                configurations: [SharedSchema.sharedConfiguration()]
            )
        } catch {
            if SharedSchema.isCloudKitEnabledByUser {
                NSLog("⚠️ CloudKit ModelContainer init failed, falling back to local-only: \(error)")
                do {
                    return try ModelContainer(
                        for: SharedSchema.all,
                        configurations: [SharedSchema.sharedConfiguration(cloudKitEnabled: false)]
                    )
                } catch {
                    return Self.inMemoryFallbackContainer(reason: error)
                }
            }
            return Self.inMemoryFallbackContainer(reason: error)
        }
    }()

    /// spec 061 (P1-6): 永続 store 構築が完全に失敗したときの最終 fallback。
    /// fatalError で hard-crash させると再インストール (= 全データ消失) 以外の復旧手段が
    /// なくなるため、in-memory store で「起動だけは成功させる」。
    /// 永続化は失われるが crash は防ぎ、起動後に banner で状態を伝える (storeLoadFailed flag)。
    @MainActor
    private static func inMemoryFallbackContainer(reason: Error) -> ModelContainer {
        NSLog("⚠️ ModelContainer init failed entirely, using in-memory store: \(reason)")
        #if DEBUG
        assertionFailure("ModelContainer init failed, using in-memory fallback: \(reason)")
        #endif
        UserDefaults.standard.set(true, forKey: "spec061_storeLoadFailed")
        do {
            let inMemory = ModelConfiguration(isStoredInMemoryOnly: true)
            return try ModelContainer(for: SharedSchema.all, configurations: [inMemory])
        } catch {
            // in-memory すら作れない場合は本当に異常 (理論上ほぼ起きない)。
            fatalError("Even in-memory ModelContainer failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                // spec 056: 3 タブ構成 V3.0 (起動 default = 知識 Clip)
                KnowledgeClipView()
                    .tabItem {
                        Label("clip.tab.title", systemImage: "newspaper.fill")
                    }
                    .tag(AppTab.knowledgeClip)
                    .accessibilityIdentifier("tab.knowledgeClip")

                ArticleListView()
                    .tabItem {
                        Label("library.tab.title", systemImage: "books.vertical")
                    }
                    .tag(AppTab.library)
                    .accessibilityIdentifier("tab.library")

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
            // spec 061 (P1-6): in-memory fallback 起動時に上部へ軽い警告 banner。
            .safeAreaInset(edge: .top) {
                if storeLoadFailed {
                    storeLoadFailedBanner
                }
            }
            // V3.0 polish (2026-05-28): AI 出力含む全 Text を長押しで選択 + Copy 可能に。
            // TabView root に適用すると全 descendant の Text に伝播 (Apple HIG 準拠)。
            .textSelection(.enabled)
            .task {
                await bootstrap()
            }
            // spec 045: 「再生成」trigger を検知して AI チャットタブに自動切替
            .onChange(of: serviceContainer.pendingRegenerateRequest) { _, new in
                if new != nil {
                    selectedTab = .chat
                }
            }
            // spec 049: 初回起動 onboarding (fullScreenCover)
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(isPresented: $showOnboarding)
            }
            // spec 052: Widget deep link `iknow://learning/card/{uuid}`
            .onOpenURL { url in
                handleDeepLink(url: url)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    /// spec 061 (P1-6): in-memory fallback 起動時の警告 banner。
    @ViewBuilder
    private var storeLoadFailedBanner: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("error.store.loadFailed.title")
                    .font(.callout.weight(.semibold))
                Text("error.store.loadFailed.body")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button {
                storeLoadFailed = false
                UserDefaults.standard.set(false, forKey: "spec061_storeLoadFailed")
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(Text("common.ok"))
        }
        .padding(DS.Spacing.lg)
        .background(.regularMaterial)
        .accessibilityIdentifier("banner.storeLoadFailed")
    }

    /// spec 052 + spec 056: Widget deep link を解析 → 知識 Clip タブに切替 + ServiceContainer に card ID をセット。
    /// spec 056 V3.0: 学習タブが廃止されたため、知識 Clip タブの「続きが気になる」セクション経由で
    /// DeepDiveChatView 遷移を行う (KnowledgeClipView が pendingDeepLinkCardID を観測して navigate)。
    /// URL format: `iknow://learning/card/{uuid}` (旧 path 互換)
    @MainActor
    private func handleDeepLink(url: URL) {
        guard url.scheme == "iknow" else { return }
        let components = url.pathComponents.filter { $0 != "/" }
        guard url.host == "learning",
              components.count >= 2,
              components[0] == "card",
              let uuid = UUID(uuidString: components[1]) else {
            return
        }
        selectedTab = .knowledgeClip
        serviceContainer.pendingDeepLinkCardID = uuid
    }

    @MainActor
    private func bootstrap() async {
        // 二重 bootstrap 抑止: scene 復帰時の .task 再実行で backfill が重複しないように。
        guard serviceContainer.knowledgeService == nil else { return }

        // spec 071: token 実測診断 (デバッグ専用、生成は呼ばない)。入力 truncate 緩和の数値根拠用。
        #if DEBUG
        await TokenBudgetProbe.runDiagnostics()
        #endif

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

        // spec 067: TopicClusteringService 退役 (UserTopic 生成停止 + UI 孤児ゆえ削除)。
        // @Model UserTopic は CloudKit record type 保護のため残置。

        // spec 042: ConceptPage 自動生成 service (Fallback 先構築 → Foundation に inject)
        let fallbackConceptService = FallbackConceptSynthesisService(
            context: context,
            refreshTrigger: refreshTrigger
        )
        let conceptSynthesisService: ConceptSynthesisServiceProtocol = FoundationModelsConceptSynthesisService(
            session: session,
            availability: availability,
            fallback: fallbackConceptService,
            embeddingService: embeddingService,
            context: context,
            refreshTrigger: refreshTrigger
        )

        // spec 043: SavedAnswer service (純粋ロジック層、AI 不要)
        // knowledgeService と chatService 両方に inject されるため先に構築
        let savedAnswerService: SavedAnswerServiceProtocol = DefaultSavedAnswerService(
            context: context,
            refreshTrigger: refreshTrigger
        )

        // spec 004 + 009 + 010 + 012 + 018 + 021 + 037 + 042: 知識抽出 service
        // (auto-tag 用 tagStore + digest stale 化 + essence embedding 生成 hook + conflict 検出 hook + ConceptPage 自動生成 hook)
        let knowledgeStore = SwiftDataArticleKnowledgeStore(
            context: context,
            refreshTrigger: refreshTrigger
        )
        // spec 042: 翻訳失敗 → SettingsView 誘導 flag
        let translationAvailability = TranslationAvailability()
        let knowledgeExtractor = KnowledgeExtractor(
            session: session,
            translationAvailability: translationAvailability
        )
        let knowledgeService = DefaultKnowledgeExtractionService(
            extractor: knowledgeExtractor,
            store: knowledgeStore,
            processingMonitor: processingMonitor,
            chunkProgressStore: chunkProgressStore,
            tagStore: tagStore,
            digestService: digestService,
            embeddingService: embeddingService,
            conflictDetectionService: conflictDetectionService,
            // spec 065 (軽さ優先): graph 抽出 hook を停止 (-1 回/記事)。関係発見は spec 064 で
            // WikiPage (relatedConceptIDs + 本文リンク) が引き継いだため、GraphNode 生成は不要。
            // 既存 GraphNode は残る (ChatService RAG / Digest は既存ノードで継続)。@Model 削除は spec 066。
            graphExtractionService: nil,
            conceptSynthesisService: conceptSynthesisService,
            savedAnswerService: savedAnswerService
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
        // spec 042: ConceptPage 再合成 BGTask に synthesis service を bind
        BackgroundExtractionScheduler.shared.conceptSynthesisProvider = { conceptSynthesisService }
        // spec 058: 週 1 Lint loop BGTask に LintEngine を bind
        let lintEngine: LintEngineProtocol = DefaultLintEngine(
            context: context,
            refreshTrigger: refreshTrigger,
            categoryClassifier: categoryClassifier
        )
        BackgroundExtractionScheduler.shared.lintEngineProvider = { lintEngine }

        // spec 021: ChatService 構築 (embedding + Foundation Models + availability で 3 経路分岐)
        // spec 040: graphTraversal を inject、RAG prompt に「## 関連エンティティ」を追加
        let chatService: ChatServiceProtocol = ChatService(
            context: context,
            embeddingService: embeddingService,
            session: session,
            availability: availability,
            graphTraversal: graphTraversalService,
            savedAnswerService: savedAnswerService
        )

        // spec 035: RecentDigestService + LastOpenedStore 構築
        let recentDigestService: RecentDigestServiceProtocol = RecentDigestService(
            session: session,
            availability: availability
        )
        let lastOpenedStore = LastOpenedStore()

        // spec 041: Knowledge Graph 編集 store + 提案レビュー service
        let graphNodeStore = GraphNodeStore(context: context, refreshTrigger: refreshTrigger)
        let graphProposalReviewService: GraphProposalReviewServiceProtocol = GraphProposalReviewService(
            context: context,
            refreshTrigger: refreshTrigger
        )

        // spec 042: ConceptPage 編集 store (rename / merge / delete / setFollowing)
        let conceptPageStore = ConceptPageStore(context: context, refreshTrigger: refreshTrigger)

        // spec 044: 学習タブ用 service 群 (surface / tracker / deep dive chat)
        let understandingSurfaceService: UnderstandingCardSurfaceServiceProtocol = DefaultUnderstandingCardSurfaceService(context: context)
        let understandingTrackerService: UnderstandingTrackerServiceProtocol = DefaultUnderstandingTrackerService(
            context: context,
            refreshTrigger: refreshTrigger
        )
        // spec 044 brushup: DeepDiveChatService (Foundation Models 直接呼び、ChatService の RAG 経路を回避)
        let deepDiveChatService: DeepDiveChatServiceProtocol = DefaultDeepDiveChatService(
            context: context,
            session: session,
            availability: availability,
            tracker: understandingTrackerService
        )
        // 互換: 旧 DeepDiveChatStarter (内部で ChatService.send を呼ぶ古い経路、UI は使わない)
        let deepDiveChatStarter: DeepDiveChatStarterProtocol = DefaultDeepDiveChatStarter(
            chatService: chatService,
            tracker: understandingTrackerService
        )

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
        // spec 067: topicClusteringService 退役
        serviceContainer.graphExtractionService = graphExtractionService     // spec 040
        serviceContainer.graphTraversalService = graphTraversalService       // spec 040
        serviceContainer.graphNodeStore = graphNodeStore                     // spec 041
        serviceContainer.graphProposalReviewService = graphProposalReviewService // spec 041
        serviceContainer.translationAvailability = translationAvailability   // spec 042
        serviceContainer.conceptSynthesisService = conceptSynthesisService   // spec 042
        serviceContainer.conceptPageStore = conceptPageStore                 // spec 042
        serviceContainer.savedAnswerService = savedAnswerService             // spec 043
        serviceContainer.understandingCardSurfaceService = understandingSurfaceService  // spec 044
        serviceContainer.understandingTrackerService = understandingTrackerService      // spec 044
        serviceContainer.deepDiveChatStarter = deepDiveChatStarter                      // spec 044 (旧、互換)
        serviceContainer.deepDiveChatService = deepDiveChatService                      // spec 044 brushup
        serviceContainer.availabilityChecker = availability                             // spec 048 (UI banner 表示用)
        // spec 056: V3.0 redesign 用の新 service 2 つ
        serviceContainer.recentArticlesService = DefaultRecentArticlesService()
        serviceContainer.suggestedPromptGenerator = DefaultSuggestedPromptGenerator()
        // spec 058: LintEngine (週 1 BGTask + Settings 「今すぐ整理」 button から呼ばれる)
        // 上記で BGTaskScheduler 用に作成済の lintEngine を ServiceContainer にも入れる
        serviceContainer.lintEngine = lintEngine
        serviceContainer.healthScoreService = DefaultHealthScoreService(context: context)

        // 既存記事の backfill: enrichment → body → knowledge は依存 chain のため直列維持。
        await enrichmentService.backfillAll()
        await bodyService.backfillAll()
        await knowledgeService.backfillAll()

        // spec 061 (P1-7): knowledge 完了後の独立 backfill 群を並列化して cold start を短縮。
        // 全て @MainActor のため真の並列計算ではないが、各 service の await suspend
        // (I/O / Foundation Models 呼び出し) が重なり待ち時間が短縮される。
        // 依存 chain (enrichment→body→knowledge) は上で直列維持済 (FR-010)。

        // spec 008: 孤児タグの cleanup は同期 @MainActor 処理のため async let に乗せず先に実行 (軽量)。
        try? tagStore.cleanupOrphans()

        // runner は async let に渡す前に生成
        let backfillRunner = AutoTagBackfillRunner(
            context: context,
            tagStore: tagStore,
            processingMonitor: processingMonitor
        )
        let categoryBackfillRunner = AutoCategoryBackfillRunner(
            context: context,
            classifier: categoryClassifier,
            processingMonitor: processingMonitor
        )

        async let autoTag: Void = backfillRunner.run()                              // spec 013
        async let categoryBackfill: Void = categoryBackfillRunner.run()             // spec 015
        // spec 065 (軽さ優先): 起動時の digest 一括生成 (spec 018) と UserTopic clustering (spec 036) を停止。
        //   - digest: pull-to-refresh / Category 詳細でオンデマンド生成に寄せる (News+ = spec 066 が役割継承)
        //   - topic clustering: 表示 UI が無い (orphan) ため起動 K-means は無駄
        //   @Model・service は残す (生成を止めるだけ、退役は spec 066)。
        async let embeddings: Void = chatService.backfillEmbeddings()               // spec 021
        async let concepts: Void = Self.runConceptBackfill(conceptSynthesisService) // spec 042

        // 全 backfill の完了を待つ
        _ = await (autoTag, categoryBackfill, embeddings, concepts)

        // BGTask 予約は全 backfill 完了後 (最後)
        await BackgroundExtractionScheduler.shared.scheduleNextConceptResynthesis() // spec 042
        await BackgroundExtractionScheduler.shared.scheduleNextWeeklyLint()         // spec 058
    }

    // spec 061 (P1-7): async let に乗せる throwing / 多段 await を包む @MainActor helper。
    @MainActor
    private static func runDigestBackfill(_ service: KnowledgeDigestService) async {
        try? await service.regenerateAllStale()  // spec 018
    }

    @MainActor
    private static func runConceptBackfill(_ service: ConceptSynthesisServiceProtocol) async {
        await service.backfillFromExistingArticles()  // spec 042
        await service.resynthesizeAllStale()
    }
}

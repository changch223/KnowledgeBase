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
//

import SwiftUI
import SwiftData

@main
struct KnowledgeTreeApp: App {
    @State private var processingMonitor = ProcessingMonitor()
    @State private var refreshTrigger = RefreshTrigger()
    @State private var serviceContainer = ServiceContainer()

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
            ArticleListView()
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

        // spec 004: 知識抽出 service
        let knowledgeStore = SwiftDataArticleKnowledgeStore(
            context: context,
            refreshTrigger: refreshTrigger
        )
        let knowledgeExtractor = KnowledgeExtractor(session: FoundationModelLanguageModelSession())
        let knowledgeService = DefaultKnowledgeExtractionService(
            extractor: knowledgeExtractor,
            store: knowledgeStore,
            processingMonitor: processingMonitor
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

        // spec 008: TagStore
        let tagStore = TagStore(context: context, refreshTrigger: refreshTrigger)

        // ServiceContainer に登録 (再抽出ボタン等で参照)
        serviceContainer.enrichmentService = enrichmentService
        serviceContainer.bodyService = bodyService
        serviceContainer.knowledgeService = knowledgeService
        serviceContainer.tagStore = tagStore

        // 既存記事の backfill (順次): enrichment → body → knowledge
        await enrichmentService.backfillAll()
        await bodyService.backfillAll()
        await knowledgeService.backfillAll()
        // spec 008: 孤児タグの cleanup (起動時 1 回)
        try? tagStore.cleanupOrphans()
    }
}

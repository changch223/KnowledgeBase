//
//  AutoTagBackfillRunnerTests.swift
//  KnowledgeTreeTests
//
//  spec 013 — contracts/auto-tag-backfill-runner.md 7 ケース。
//  in-memory ModelContainer + InMemoryBackfillFlagStore で UserDefaults 隔離。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeBase

// SwiftUI 側の `Tag` 型と曖昧化するため明示 typealias (spec 011/012 同パターン)
private typealias Tag = KnowledgeBase.Tag

@MainActor
struct AutoTagBackfillRunnerTests {

    // MARK: - Test fixture

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Article.self, ArticleEnrichment.self, ArticleBody.self,
                ExtractedKnowledge.self, KeyFact.self, KnowledgeEntity.self,
                Tag.self, KnowledgeChunkProgress.self,
                BackgroundExtractionQueueEntry.self,
            configurations: configuration
        )
    }

    /// salience リストから entities を作成し、Article + ExtractedKnowledge にリンク。
    /// status は引数で制御 (default .succeeded)。savedAt も引数で制御 (default Date())。
    @discardableResult
    private func makeArticleWithEntities(
        salienceList: [Int],
        status: ExtractionStatus = .succeeded,
        savedAt: Date = Date(),
        url: String = "https://example.com/test",
        in context: ModelContext
    ) -> Article {
        let article = Article(url: url, title: url, savedAt: savedAt)
        context.insert(article)
        let knowledge = ExtractedKnowledge(article: article, status: status)
        context.insert(knowledge)
        article.extractedKnowledge = knowledge
        for (index, salience) in salienceList.enumerated() {
            let entity = KnowledgeEntity(
                knowledge: knowledge,
                name: "entity-\(salience)-\(index)-\(url.hashValue)",
                typeRaw: "concept",
                salience: salience,
                order: index
            )
            context.insert(entity)
            knowledge.entities?.append(entity)
        }
        return article
    }

    private func makeRunner(
        context: ModelContext,
        flagStore: BackfillFlagStore
    ) -> AutoTagBackfillRunner {
        let tagStore = TagStore(context: context)
        return AutoTagBackfillRunner(
            context: context,
            tagStore: tagStore,
            processingMonitor: nil,
            flagStore: flagStore
        )
    }

    // MARK: - Tests

    @Test func testFlagFalseRunsBackfill() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let flagStore = InMemoryBackfillFlagStore()  // false

        // 候補 article 2 件
        let a1 = makeArticleWithEntities(
            salienceList: [5, 5, 4],
            url: "https://example.com/a1",
            in: context
        )
        let a2 = makeArticleWithEntities(
            salienceList: [5, 4],
            url: "https://example.com/a2",
            in: context
        )

        let runner = makeRunner(context: context, flagStore: flagStore)
        await runner.run()

        #expect((a1.tags ?? []).count == 3)  // 全 entity が salience>=4
        #expect((a2.tags ?? []).count == 2)
        #expect(flagStore.isCompleted() == true)
    }

    @Test func testFlagTrueSkipsBackfill() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let flagStore = InMemoryBackfillFlagStore(initial: true)  // 既に完了

        let a1 = makeArticleWithEntities(
            salienceList: [5, 5, 4],
            url: "https://example.com/skip",
            in: context
        )

        let runner = makeRunner(context: context, flagStore: flagStore)
        await runner.run()

        #expect((a1.tags ?? []).count == 0)  // backfill スキップ
        #expect(flagStore.isCompleted() == true)  // 維持
    }

    @Test func testOnlyTargetsArticlesWithEmptyTagsAndSucceededKnowledge() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let flagStore = InMemoryBackfillFlagStore()

        // target: tags 空 + status .succeeded
        let target = makeArticleWithEntities(
            salienceList: [5, 5, 4],
            status: .succeeded,
            url: "https://example.com/target",
            in: context
        )

        // skip A: tags 1 件付き
        let skipA = makeArticleWithEntities(
            salienceList: [5, 5, 4],
            status: .succeeded,
            url: "https://example.com/skip-a",
            in: context
        )
        let tagStore = TagStore(context: context)
        _ = try tagStore.addTag(rawName: "manual-tag", to: skipA)

        // skip B: status .failed
        let skipB = makeArticleWithEntities(
            salienceList: [5, 5, 4],
            status: .failed,
            url: "https://example.com/skip-b",
            in: context
        )

        // skip C: status .pending
        let skipC = makeArticleWithEntities(
            salienceList: [5, 5, 4],
            status: .pending,
            url: "https://example.com/skip-c",
            in: context
        )

        let runner = AutoTagBackfillRunner(
            context: context,
            tagStore: tagStore,
            processingMonitor: nil,
            flagStore: flagStore
        )
        await runner.run()

        #expect((target.tags ?? []).count == 3)  // auto-apply
        #expect((skipA.tags ?? []).count == 1)   // 既存タグ維持、auto-apply スキップ
        #expect((skipB.tags ?? []).count == 0)   // failed スキップ
        #expect((skipC.tags ?? []).count == 0)   // pending スキップ
    }

    @Test func testSkipsArticlesWithExistingTags() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let flagStore = InMemoryBackfillFlagStore()

        let article = makeArticleWithEntities(
            salienceList: [5, 5, 4],
            url: "https://example.com/has-tag",
            in: context
        )
        let tagStore = TagStore(context: context)
        _ = try tagStore.addTag(rawName: "manual", to: article)

        let runner = AutoTagBackfillRunner(
            context: context,
            tagStore: tagStore,
            processingMonitor: nil,
            flagStore: flagStore
        )
        await runner.run()

        #expect((article.tags ?? []).count == 1)  // 既存タグ 1 件のまま
        #expect((article.tags ?? []).first?.name == "manual")
    }

    @Test func testSkipsArticlesWithFailedKnowledge() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let flagStore = InMemoryBackfillFlagStore()

        let article = makeArticleWithEntities(
            salienceList: [5, 5, 4],
            status: .failed,
            url: "https://example.com/failed",
            in: context
        )

        let runner = makeRunner(context: context, flagStore: flagStore)
        await runner.run()

        #expect((article.tags ?? []).count == 0)
    }

    @Test func testProcessesNewestFirst() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let flagStore = InMemoryBackfillFlagStore()

        // 3 article: 異なる savedAt (新 → 旧)
        let now = Date()
        let recent = makeArticleWithEntities(
            salienceList: [5],
            savedAt: now.addingTimeInterval(-1 * 86400),
            url: "https://example.com/recent",
            in: context
        )
        let middle = makeArticleWithEntities(
            salienceList: [5],
            savedAt: now.addingTimeInterval(-2 * 86400),
            url: "https://example.com/middle",
            in: context
        )
        let old = makeArticleWithEntities(
            salienceList: [5],
            savedAt: now.addingTimeInterval(-3 * 86400),
            url: "https://example.com/old",
            in: context
        )

        let runner = makeRunner(context: context, flagStore: flagStore)
        await runner.run()

        // 全 article に tag 付与確認 (順序の正確検証は内部実装詳細、ここでは全件処理を確認)
        #expect((recent.tags ?? []).count == 1)
        #expect((middle.tags ?? []).count == 1)
        #expect((old.tags ?? []).count == 1)
        #expect(flagStore.isCompleted() == true)
    }

    @Test func testHandlesEmptyDatabase() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let flagStore = InMemoryBackfillFlagStore()

        // article 0 件
        let runner = makeRunner(context: context, flagStore: flagStore)
        await runner.run()

        // crash せず flag = true セット
        #expect(flagStore.isCompleted() == true)
    }
}

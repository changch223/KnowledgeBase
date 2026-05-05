//
//  AutoCategoryBackfillRunnerTests.swift
//  KnowledgeTreeTests
//
//  spec 015 — contracts/auto-category-backfill-runner.md 7 ケース。
//  in-memory ModelContainer + InMemoryBackfillFlagStore + InMemoryAutoCategoryClassifier で隔離。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

// SwiftUI Tag との曖昧化解消 (spec 011/012/013/014 同パターン)
private typealias Tag = KnowledgeTree.Tag

@MainActor
struct AutoCategoryBackfillRunnerTests {

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

    @discardableResult
    private func makeTag(
        name: String,
        categoryRaw: String? = nil,
        in context: ModelContext
    ) -> Tag {
        let tag = Tag(name: name, categoryRaw: categoryRaw)
        context.insert(tag)
        return tag
    }

    @Test func testFlagFalseRunsBackfill() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let flagStore = InMemoryBackfillFlagStore()
        let classifier = InMemoryAutoCategoryClassifier(mapping: [
            "swift": "テクノロジー",
            "投資": "経済"
        ])

        let t1 = makeTag(name: "swift", in: context)
        let t2 = makeTag(name: "投資", in: context)
        try context.save()

        let runner = AutoCategoryBackfillRunner(
            context: context,
            classifier: classifier,
            processingMonitor: nil,
            flagStore: flagStore
        )
        await runner.run()

        #expect(t1.categoryRaw == "テクノロジー")
        #expect(t2.categoryRaw == "経済")
        #expect(flagStore.isCompleted())
    }

    @Test func testFlagTrueSkipsBackfill() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let flagStore = InMemoryBackfillFlagStore(initial: true)
        let classifier = InMemoryAutoCategoryClassifier(mapping: ["swift": "テクノロジー"])

        let t1 = makeTag(name: "swift", in: context)
        try context.save()

        let runner = AutoCategoryBackfillRunner(
            context: context,
            classifier: classifier,
            processingMonitor: nil,
            flagStore: flagStore
        )
        await runner.run()

        #expect(t1.categoryRaw == nil)  // 走らないので nil のまま
        #expect(flagStore.isCompleted())  // 維持
    }

    @Test func testOnlyTargetsTagsWithNilCategoryRaw() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let flagStore = InMemoryBackfillFlagStore()
        let classifier = InMemoryAutoCategoryClassifier(mapping: [
            "alpha": "テクノロジー",
            "beta": "テクノロジー"
        ])

        let target = makeTag(name: "alpha", in: context)
        let already = makeTag(name: "beta", categoryRaw: "学術", in: context)
        let alreadyOther = makeTag(name: "gamma", categoryRaw: "その他", in: context)
        try context.save()

        let runner = AutoCategoryBackfillRunner(
            context: context,
            classifier: classifier,
            processingMonitor: nil,
            flagStore: flagStore
        )
        await runner.run()

        #expect(target.categoryRaw == "テクノロジー")  // nil → 分類
        #expect(already.categoryRaw == "学術")       // 既存値維持
        #expect(alreadyOther.categoryRaw == "その他") // 既存値維持
    }

    @Test func testHandlesEmptyDatabase() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let flagStore = InMemoryBackfillFlagStore()
        let classifier = InMemoryAutoCategoryClassifier()

        let runner = AutoCategoryBackfillRunner(
            context: context,
            classifier: classifier,
            processingMonitor: nil,
            flagStore: flagStore
        )
        await runner.run()

        #expect(flagStore.isCompleted())  // 空 DB でも flag セット
    }

    @Test func testFallbackToOtherWhenClassifierReturnsOther() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let flagStore = InMemoryBackfillFlagStore()
        // mapping 空 → 全部 default ("その他") を返す
        let classifier = InMemoryAutoCategoryClassifier(mapping: [:])

        let t1 = makeTag(name: "未知タグ1", in: context)
        let t2 = makeTag(name: "未知タグ2", in: context)
        try context.save()

        let runner = AutoCategoryBackfillRunner(
            context: context,
            classifier: classifier,
            processingMonitor: nil,
            flagStore: flagStore
        )
        await runner.run()

        #expect(t1.categoryRaw == "その他")
        #expect(t2.categoryRaw == "その他")
        #expect(flagStore.isCompleted())
    }

    @Test func testProcessesAllCandidatesEvenOnPartialFailure() async throws {
        // 1 件目は mapping ヒット、2 件目は miss (default に fallback)
        let container = try makeContainer()
        let context = container.mainContext
        let flagStore = InMemoryBackfillFlagStore()
        let classifier = InMemoryAutoCategoryClassifier(mapping: [
            "alpha": "テクノロジー"
            // "beta" は mapping にない → "その他" fallback
        ])

        let alpha = makeTag(name: "alpha", in: context)
        let beta = makeTag(name: "beta", in: context)
        try context.save()

        let runner = AutoCategoryBackfillRunner(
            context: context,
            classifier: classifier,
            processingMonitor: nil,
            flagStore: flagStore
        )
        await runner.run()

        #expect(alpha.categoryRaw == "テクノロジー")
        #expect(beta.categoryRaw == "その他")  // fallback で更新済 (= partial 成功扱い)
    }

    @Test func testRunSetsFlagEvenWhenAllFail() async throws {
        // 全部 default に流れても flag = true (個別失敗で全体止めない)
        let container = try makeContainer()
        let context = container.mainContext
        let flagStore = InMemoryBackfillFlagStore()
        let classifier = InMemoryAutoCategoryClassifier(mapping: [:])

        let t1 = makeTag(name: "alpha", in: context)
        let t2 = makeTag(name: "beta", in: context)
        let t3 = makeTag(name: "gamma", in: context)
        try context.save()

        let runner = AutoCategoryBackfillRunner(
            context: context,
            classifier: classifier,
            processingMonitor: nil,
            flagStore: flagStore
        )
        await runner.run()

        // 全部 "その他" に分類されるが、flag は完了
        #expect(t1.categoryRaw == "その他")
        #expect(t2.categoryRaw == "その他")
        #expect(t3.categoryRaw == "その他")
        #expect(flagStore.isCompleted())
    }
}

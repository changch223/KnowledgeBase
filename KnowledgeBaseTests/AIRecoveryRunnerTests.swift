//
//  AIRecoveryRunnerTests.swift
//  KnowledgeTreeTests
//
//  AI 復旧機能 — AI 復活検知で skip/劣化生成された知識・まとめを自動再生成する runner の検証。
//  in-memory ModelContainer + InMemoryBackfillFlagStore で UserDefaults 隔離。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeBase

@MainActor
struct AIRecoveryRunnerTests {

    // MARK: - Test fixture

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    private func makeRunner(
        context: ModelContext,
        knowledgeService: KnowledgeExtractionServiceProtocol,
        conceptSynthesisService: ConceptSynthesisServiceProtocol,
        isAvailable: Bool = true,
        retroactiveFlagStore: BackfillFlagStore = InMemoryBackfillFlagStore(initial: true)
    ) -> DefaultAIRecoveryRunner {
        let checker = MockAvailabilityChecker()
        checker.isAvailable = isAvailable
        return DefaultAIRecoveryRunner(
            context: context,
            knowledgeService: knowledgeService,
            conceptSynthesisService: conceptSynthesisService,
            availabilityChecker: checker,
            processingMonitor: nil,
            refreshTrigger: nil,
            retroactiveFlagStore: retroactiveFlagStore
        )
    }

    // MARK: - 1. 劣化ページが isStale=true になり resynthesizeAllStale + backfillAll が呼ばれる

    @Test func testDegradedPageMarkedStaleAndResynthesizeCalled() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let page = ConceptPage(
            name: "Apple",
            categoryRaw: "テクノロジー",
            summary: "essence 並べただけの簡易 summary",
            isStale: false,
            synthesizedWithoutAI: true
        )
        context.insert(page)
        try context.save()

        let knowledgeService = MockKnowledgeExtractionServiceForRecovery()
        let conceptService = MockConceptSynthesisServiceForRecovery()
        let runner = makeRunner(context: context, knowledgeService: knowledgeService, conceptSynthesisService: conceptService)

        await runner.runIfNeeded()

        #expect(page.isStale == true)
        #expect(conceptService.resynthesizeAllStaleCallCount == 1)
        #expect(knowledgeService.backfillAllCallCount == 1)
    }

    // MARK: - 2. availability 不可なら no-op

    @Test func testAvailabilityUnavailableIsNoOp() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let page = ConceptPage(
            name: "Apple",
            categoryRaw: "テクノロジー",
            summary: "essence 並べただけの簡易 summary",
            isStale: false,
            synthesizedWithoutAI: true
        )
        context.insert(page)
        try context.save()

        let knowledgeService = MockKnowledgeExtractionServiceForRecovery()
        let conceptService = MockConceptSynthesisServiceForRecovery()
        let runner = makeRunner(
            context: context,
            knowledgeService: knowledgeService,
            conceptSynthesisService: conceptService,
            isAvailable: false
        )

        await runner.runIfNeeded()

        #expect(page.isStale == false)  // 触られない
        #expect(conceptService.resynthesizeAllStaleCallCount == 0)
        #expect(knowledgeService.backfillAllCallCount == 0)
    }

    // MARK: - 3. 多重起動ガード (実行中は再入しない)

    @Test func testConcurrentRunGuardPreventsReentry() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let page = ConceptPage(
            name: "Apple",
            categoryRaw: "テクノロジー",
            summary: "essence 並べただけの簡易 summary",
            isStale: false,
            synthesizedWithoutAI: true
        )
        context.insert(page)
        try context.save()

        let knowledgeService = MockKnowledgeExtractionServiceForRecovery()
        let conceptService = BlockingConceptSynthesisService()
        conceptService.shouldBlock = true
        let runner = makeRunner(context: context, knowledgeService: knowledgeService, conceptSynthesisService: conceptService)

        let task1 = Task { @MainActor in
            await runner.runIfNeeded()
        }
        // task1 が resynthesizeAllStale 内の continuation で止まるまで進める。
        await Task.yield()

        // 再入は即 no-op で return するはず (task1 が保持中のため)。
        await runner.runIfNeeded()
        #expect(conceptService.resynthesizeAllStaleCallCount == 1)  // task1 分のみ
        #expect(knowledgeService.backfillAllCallCount == 0)  // task1 はまだ resynthesize で止まっている

        conceptService.resume()
        await task1.value

        #expect(conceptService.resynthesizeAllStaleCallCount == 1)
        #expect(knowledgeService.backfillAllCallCount == 1)  // task1 が最後まで完走
    }

    // MARK: - 4. retroactive backfill: fallback 署名判定 (bodyMarkdown==summary は対象、bodyEditedByUser は除外)

    @Test func testRetroactiveBackfillMarksFallbackSignaturePages() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        // (a) bodyMarkdown == summary (非空) → fallback 署名に一致
        let copiedBody = ConceptPage(
            name: "A", categoryRaw: "テクノロジー",
            summary: "同じ文言",
            isStale: false
        )
        copiedBody.bodyMarkdown = "同じ文言"

        // (b) summary 空 → fallback 署名に一致
        let emptySummary = ConceptPage(
            name: "B", categoryRaw: "テクノロジー",
            summary: "",
            isStale: false
        )

        // (c) bodyMarkdown == summary だが bodyEditedByUser=true → 除外 (ユーザー訂正保護)
        let userEdited = ConceptPage(
            name: "C", categoryRaw: "テクノロジー",
            summary: "ユーザーが書いた文言",
            isStale: false,
            bodyEditedByUser: true
        )
        userEdited.bodyMarkdown = "ユーザーが書いた文言"

        // (d) AI 生成済で summary と bodyMarkdown が異なる → 対象外
        let healthy = ConceptPage(
            name: "D", categoryRaw: "テクノロジー",
            summary: "AI が書いた要約",
            isStale: false
        )
        healthy.bodyMarkdown = "AI が書いた詳しい本文 (要約とは別)"

        // (e) summary は非空だが bodyMarkdown が空 → Fallback (bodyMarkdown を書かない) の署名に一致
        let bodyEmpty = ConceptPage(
            name: "E", categoryRaw: "テクノロジー",
            summary: "essence 並べただけの簡易 summary",
            isStale: false
        )

        for page in [copiedBody, emptySummary, userEdited, healthy, bodyEmpty] {
            context.insert(page)
        }
        try context.save()

        let knowledgeService = MockKnowledgeExtractionServiceForRecovery()
        let conceptService = MockConceptSynthesisServiceForRecovery()
        let runner = makeRunner(
            context: context,
            knowledgeService: knowledgeService,
            conceptSynthesisService: conceptService,
            retroactiveFlagStore: InMemoryBackfillFlagStore(initial: false)
        )

        await runner.runIfNeeded()

        #expect(copiedBody.synthesizedWithoutAI == true)
        #expect(emptySummary.synthesizedWithoutAI == true)
        #expect(userEdited.synthesizedWithoutAI == false)  // 除外
        #expect(healthy.synthesizedWithoutAI == false)     // 対象外
        #expect(bodyEmpty.synthesizedWithoutAI == true)    // summary 非空 + body 空 → flag される
    }

    // MARK: - 5. retroactive backfill: 一回性 (2 回目は再スキャンしない)

    @Test func testRetroactiveBackfillRunsOnlyOnce() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let flagStore = InMemoryBackfillFlagStore(initial: false)

        let knowledgeService = MockKnowledgeExtractionServiceForRecovery()
        let conceptService = MockConceptSynthesisServiceForRecovery()
        let runner = makeRunner(
            context: context,
            knowledgeService: knowledgeService,
            conceptSynthesisService: conceptService,
            retroactiveFlagStore: flagStore
        )

        await runner.runIfNeeded()
        #expect(flagStore.isCompleted() == true)

        // 1 回目完了後にフォールバック署名のページを追加。
        let lateArrival = ConceptPage(name: "Late", categoryRaw: "テクノロジー", summary: "", isStale: false)
        context.insert(lateArrival)
        try context.save()

        await runner.runIfNeeded()

        // フラグが既に true なので 2 回目のスキャンは走らず、後から追加されたページは対象にならない。
        #expect(lateArrival.synthesizedWithoutAI == false)
    }

    // MARK: - 6. 復旧ループ化: 5 件超の劣化ページが 1 回の runIfNeeded で全件復旧される

    @Test func testDegradedPagesExceedingBatchSizeAreFullyRecoveredInOneRun() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        var pages: [ConceptPage] = []
        for i in 0..<7 {
            let page = ConceptPage(
                name: "Concept \(i)",
                categoryRaw: "テクノロジー",
                summary: "essence 並べただけの簡易 summary",
                isStale: false,
                synthesizedWithoutAI: true
            )
            context.insert(page)
            pages.append(page)
        }
        try context.save()

        let knowledgeService = MockKnowledgeExtractionServiceForRecovery()
        let conceptService = ResolvingConceptSynthesisServiceForRecovery(context: context)
        let runner = makeRunner(context: context, knowledgeService: knowledgeService, conceptSynthesisService: conceptService)

        await runner.runIfNeeded()

        #expect(pages.allSatisfy { $0.isStale == false })
        #expect(pages.allSatisfy { $0.synthesizedWithoutAI == false })
        // ceil(7 / 5) = 2 回のループ反復で全件復旧する (旧実装は 1 回で 5 件しか進まなかった)。
        #expect(conceptService.resynthesizeAllStaleCallCount == 2)
        #expect(knowledgeService.backfillAllCallCount == 1)
    }

    // MARK: - 7. 復旧ループ化: 残数が減らないケースで有界脱出する (無限ループしない)

    @Test func testNoProgressBreaksLoopWithoutSpinning() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        for i in 0..<10 {
            let page = ConceptPage(
                name: "Concept \(i)",
                categoryRaw: "テクノロジー",
                summary: "essence 並べただけの簡易 summary",
                isStale: false,
                synthesizedWithoutAI: true
            )
            context.insert(page)
        }
        try context.save()

        let knowledgeService = MockKnowledgeExtractionServiceForRecovery()
        // 常に no-op (isStale/synthesizedWithoutAI が下りない) → 合成が失敗し続けるケースを再現。
        let conceptService = MockConceptSynthesisServiceForRecovery()
        let runner = makeRunner(context: context, knowledgeService: knowledgeService, conceptSynthesisService: conceptService)

        await runner.runIfNeeded()

        // 進捗が無いので 30 回上限まで空回りせず、1 回呼んだ時点で即中断する。
        #expect(conceptService.resynthesizeAllStaleCallCount == 1)
        #expect(knowledgeService.backfillAllCallCount == 1)
    }

    // MARK: - 8. 復旧ループ化: ループ途中で availability が落ちたら中断する

    @Test func testAvailabilityDropMidLoopSuspendsRecovery() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        for i in 0..<7 {
            let page = ConceptPage(
                name: "Concept \(i)",
                categoryRaw: "テクノロジー",
                summary: "essence 並べただけの簡易 summary",
                isStale: false,
                synthesizedWithoutAI: true
            )
            context.insert(page)
        }
        try context.save()

        let knowledgeService = MockKnowledgeExtractionServiceForRecovery()
        let conceptService = ResolvingConceptSynthesisServiceForRecovery(context: context)
        // 1 回目 (トップレベル guard) = available、2 回目 (ループ 1 周目直前) = available、
        // 3 回目 (ループ 2 周目直前) = unavailable に落ちる想定。
        let checker = SequencedAvailabilityChecker([true, true, false])
        let runner = DefaultAIRecoveryRunner(
            context: context,
            knowledgeService: knowledgeService,
            conceptSynthesisService: conceptService,
            availabilityChecker: checker,
            processingMonitor: nil,
            refreshTrigger: nil,
            retroactiveFlagStore: InMemoryBackfillFlagStore(initial: true)
        )

        await runner.runIfNeeded()

        // 2 周目に入る前に availability が落ちたので 1 回しか呼ばれない。
        #expect(conceptService.resynthesizeAllStaleCallCount == 1)
        let remainingStale = try context.fetch(
            FetchDescriptor<ConceptPage>(predicate: #Predicate { $0.isStale == true })
        )
        #expect(remainingStale.count == 2)  // 7 - 5 = 2 件が次回の復活検知のために残る
    }

    // MARK: - 9. 復旧ループ化: 非劣化 stale が top-5 を占有しても劣化ページが取り残されない (誤った無進捗 break の修正)

    @Test func testMixedDegradedAndNonDegradedStaleBothProgressWithoutPrematureBreak() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        // 非劣化 stale 5 件 (直近の記事に紐付き、recency 順で先頭に来る。AI 復旧とは無関係な通常の再合成待ち)。
        for i in 0..<5 {
            let article = Article(
                url: "https://example.com/fresh\(i)",
                title: "Fresh \(i)",
                savedAt: Date(timeIntervalSinceNow: Double(100 - i))
            )
            context.insert(article)
            let page = ConceptPage(
                name: "Fresh \(i)",
                categoryRaw: "テクノロジー",
                relatedArticles: [article],
                isStale: true,
                synthesizedWithoutAI: false
            )
            context.insert(page)
        }

        // 劣化 stale 3 件 (古い記事に紐付き、recency 順で後回しになる)。
        for i in 0..<3 {
            let article = Article(
                url: "https://example.com/degraded\(i)",
                title: "Degraded \(i)",
                savedAt: Date(timeIntervalSinceNow: -Double(100 + i))
            )
            context.insert(article)
            let page = ConceptPage(
                name: "Degraded \(i)",
                categoryRaw: "テクノロジー",
                summary: "essence 並べただけの簡易 summary",
                relatedArticles: [article],
                isStale: false,
                synthesizedWithoutAI: true
            )
            context.insert(page)
        }
        try context.save()

        let knowledgeService = MockKnowledgeExtractionServiceForRecovery()
        // recency 順 top-5 解決を維持する Mock (本実装の resynthesizeAllStale と同じソート)。
        let conceptService = ResolvingConceptSynthesisServiceForRecovery(context: context)
        let runner = makeRunner(context: context, knowledgeService: knowledgeService, conceptSynthesisService: conceptService)

        await runner.runIfNeeded()

        // 旧実装: 1 周目で非劣化 5 件のみ解決され劣化残数 3 が変化しないため誤って中断し、
        // 劣化 3 件が stale のまま取り残されていた。
        // 新実装: 全 stale 残数の減少も進捗として数えるので 2 周目で劣化 3 件も解決される。
        #expect(conceptService.resynthesizeAllStaleCallCount == 2)
        let remainingStale = try context.fetch(
            FetchDescriptor<ConceptPage>(predicate: #Predicate { $0.isStale == true })
        )
        #expect(remainingStale.isEmpty)
        #expect(knowledgeService.backfillAllCallCount == 1)
    }
}

// MARK: - Mocks (test 限定)

@MainActor
private final class MockKnowledgeExtractionServiceForRecovery: KnowledgeExtractionServiceProtocol {
    var extractCallCount = 0
    var backfillAllCallCount = 0

    func extract(article: Article) async { extractCallCount += 1 }
    func backfillAll() async { backfillAllCallCount += 1 }
    func cancelAll() {}
    func cancelInFlight(article: Article) async {}
}

@MainActor
private final class MockConceptSynthesisServiceForRecovery: ConceptSynthesisServiceProtocol {
    var resynthesizeAllStaleCallCount = 0

    func processNewArticle(article: Article) async {}
    func ingestArticle(_ article: Article) async {}
    func processConceptHierarchy(article: Article, hierarchy: ConceptHierarchyOutput) async {}
    func resynthesize(_ conceptPage: ConceptPage) async {}
    func resynthesizeAllStale() async { resynthesizeAllStaleCallCount += 1 }
    func backfillFromExistingArticles() async {}
}

/// resynthesizeAllStale をテストが明示的に resume するまで止めておく Mock (多重起動ガード検証用)。
@MainActor
private final class BlockingConceptSynthesisService: ConceptSynthesisServiceProtocol {
    var resynthesizeAllStaleCallCount = 0
    var shouldBlock = false
    private var continuation: CheckedContinuation<Void, Never>?

    func processNewArticle(article: Article) async {}
    func ingestArticle(_ article: Article) async {}
    func processConceptHierarchy(article: Article, hierarchy: ConceptHierarchyOutput) async {}
    func resynthesize(_ conceptPage: ConceptPage) async {}
    func resynthesizeAllStale() async {
        resynthesizeAllStaleCallCount += 1
        guard shouldBlock else { return }
        await withCheckedContinuation { cont in
            continuation = cont
        }
    }
    func backfillFromExistingArticles() async {}

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

/// 呼び出し毎に isStale==true のページを最大 batchSize 件だけ実際に解決する Mock
/// (本実装の resynthesizeAllStale が prefix(5) しか処理しない挙動を模倣、復旧ループ検証用)。
/// 本実装と同じく関連 Article の最新 savedAt 降順 (recency 順) で top-N を解決する。
@MainActor
private final class ResolvingConceptSynthesisServiceForRecovery: ConceptSynthesisServiceProtocol {
    private let context: ModelContext
    var resynthesizeAllStaleCallCount = 0
    var batchSize = 5

    init(context: ModelContext, batchSize: Int = 5) {
        self.context = context
        self.batchSize = batchSize
    }

    func processNewArticle(article: Article) async {}
    func ingestArticle(_ article: Article) async {}
    func processConceptHierarchy(article: Article, hierarchy: ConceptHierarchyOutput) async {}
    func resynthesize(_ conceptPage: ConceptPage) async {}
    func resynthesizeAllStale() async {
        resynthesizeAllStaleCallCount += 1
        let descriptor = FetchDescriptor<ConceptPage>(predicate: #Predicate { $0.isStale == true })
        guard let stale = try? context.fetch(descriptor) else { return }
        let sorted = stale.sorted { lhs, rhs in
            let lhsLatest = (lhs.relatedArticles ?? []).map(\.savedAt).max() ?? .distantPast
            let rhsLatest = (rhs.relatedArticles ?? []).map(\.savedAt).max() ?? .distantPast
            return lhsLatest > rhsLatest
        }
        for page in sorted.prefix(batchSize) {
            page.isStale = false
            page.synthesizedWithoutAI = false
        }
        try? context.save()
    }
    func backfillFromExistingArticles() async {}
}

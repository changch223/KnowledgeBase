//
//  ConceptSynthesisServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 042 — ConceptSynthesisService の 10 ケース。
//  Foundation Models 経路と Fallback 経路の両方を Mock LM で隔離検証。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeBase

private typealias Tag = KnowledgeBase.Tag

@MainActor
struct ConceptSynthesisServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    /// Article + categoryRaw 設定済 Tag + entity 配列を持たせる。
    @discardableResult
    private func makeArticle(
        url: String,
        title: String,
        categoryRaw: String,
        entityNames: [String],
        essence: String? = "essence text",
        savedAt: Date = .now,
        in context: ModelContext
    ) -> Article {
        let article = Article(url: url, title: title, savedAt: savedAt)
        context.insert(article)

        let tag = Tag(name: "tag-\(url)", categoryRaw: categoryRaw)
        context.insert(tag)
        article.tags?.append(tag)

        let knowledge = ExtractedKnowledge(article: article, status: .succeeded)
        if let essence { knowledge.essence = essence }
        context.insert(knowledge)
        article.extractedKnowledge = knowledge

        for (idx, name) in entityNames.enumerated() {
            let entity = KnowledgeEntity(
                knowledge: knowledge,
                name: name,
                typeRaw: EntityTypeStored.concept.rawValue,
                salience: 4,
                order: idx
            )
            context.insert(entity)
            knowledge.entities?.append(entity)
        }
        return article
    }

    private func makeFoundationService(
        context: ModelContext,
        session: MockLanguageModelSession,
        availabilityIsAvailable: Bool = true
    ) -> FoundationModelsConceptSynthesisService {
        let checker = MockAvailabilityChecker()
        checker.isAvailable = availabilityIsAvailable
        let fallback = FallbackConceptSynthesisService(context: context, refreshTrigger: nil)
        return FoundationModelsConceptSynthesisService(
            session: session,
            availability: checker,
            fallback: fallback,
            embeddingService: nil,
            context: context,
            refreshTrigger: nil
        )
    }

    // MARK: - 1. processNewArticle: 1 件のみ → ConceptPage 生成しない

    @Test func testProcessNewArticleWithSingleEntityDoesNotCreatePage() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        makeArticle(url: "a", title: "Apple について", categoryRaw: "テクノロジー", entityNames: ["Apple"], in: context)
        try context.save()

        let session = MockLanguageModelSession()
        let service = makeFoundationService(context: context, session: session)

        await service.processNewArticle(article: try context.fetch(FetchDescriptor<Article>()).first!)

        let pages = try context.fetch(FetchDescriptor<ConceptPage>())
        #expect(pages.isEmpty)
    }

    // MARK: - 2. processNewArticle: 2+ 件で ConceptPage 自動生成

    @Test func testProcessNewArticleWithSecondOccurrenceCreatesPage() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let articleA = makeArticle(url: "a", title: "Apple A", categoryRaw: "テクノロジー", entityNames: ["Apple"], in: context)
        let articleB = makeArticle(url: "b", title: "Apple B", categoryRaw: "テクノロジー", entityNames: ["Apple"], in: context)
        _ = articleA
        try context.save()

        let session = MockLanguageModelSession()
        // 即時 synthesis (Fix 2) の Mock summary 提供 (空 summary だと defensive code で既存維持)
        session.nextConceptSynthesisResult = .success(ConceptSynthesisOutput(
            summary: "Apple 統合 summary (mock)",
            crossSourceInsights: ["insight"]
        ))
        let service = makeFoundationService(context: context, session: session)

        await service.processNewArticle(article: articleB)

        let pages = try context.fetch(FetchDescriptor<ConceptPage>())
        #expect(pages.count == 1)
        let page = pages[0]
        #expect(page.name == "Apple")
        #expect(page.categoryRaw == "テクノロジー")
        #expect((page.relatedArticles ?? []).count == 2)
        // Fix 2: 即時 synthesis が走るので、isStale=false + summary が生成される
        #expect(page.isStale == false)
        #expect(page.summary == "Apple 統合 summary (mock)")
        #expect(session.conceptSynthesisCallCount >= 1)
    }

    // MARK: - 3. processNewArticle: 既存 ConceptPage + 新記事 → 即時再合成 (Fix 2)
    //   旧: isStale=true でマークし resynthesize は BGTask 待ち
    //   新 (Fix 2): processNewArticle 末尾で resynthesizeAllStale を呼ぶ → 即時 synthesis
    //   Mock LM が empty summary を返すケースは defensive code で既存 summary を保持

    @Test func testProcessNewArticleWithExistingPageImmediatelyResynthesizes() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let articleA = makeArticle(url: "a", title: "Apple A", categoryRaw: "テクノロジー", entityNames: ["Apple"], in: context)
        let articleB = makeArticle(url: "b", title: "Apple B", categoryRaw: "テクノロジー", entityNames: ["Apple"], in: context)
        let existing = ConceptPage(
            name: "Apple",
            categoryRaw: "テクノロジー",
            summary: "既存の要約",
            relatedArticles: [articleA, articleB],
            isStale: false
        )
        context.insert(existing)
        try context.save()

        let articleC = makeArticle(url: "c", title: "Apple C", categoryRaw: "テクノロジー", entityNames: ["Apple"], in: context)
        try context.save()

        let session = MockLanguageModelSession()
        // Mock が空 summary を返す状態 (デフォルト) → defensive code で既存 summary 保持
        let service = makeFoundationService(context: context, session: session)

        await service.processNewArticle(article: articleC)

        let pages = try context.fetch(FetchDescriptor<ConceptPage>())
        #expect(pages.count == 1)
        #expect((pages[0].relatedArticles ?? []).count == 3)
        // Fix 2: 即時 synthesis 走るので isStale=false
        #expect(pages[0].isStale == false)
        // 空 summary 返却時の defensive code で既存 summary 維持
        #expect(pages[0].summary == "既存の要約")
        #expect(session.conceptSynthesisCallCount >= 1)
    }

    // MARK: - 4. resynthesize: Foundation 経路で summary 更新

    @Test func testResynthesizeFoundationUpdatesSummary() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let articleA = makeArticle(url: "a", title: "Apple A", categoryRaw: "テクノロジー", entityNames: ["Apple"], in: context)
        let articleB = makeArticle(url: "b", title: "Apple B", categoryRaw: "テクノロジー", entityNames: ["Apple"], in: context)
        let page = ConceptPage(
            name: "Apple",
            categoryRaw: "テクノロジー",
            relatedArticles: [articleA, articleB],
            isStale: true
        )
        context.insert(page)
        try context.save()

        let session = MockLanguageModelSession()
        session.nextConceptSynthesisResult = .success(ConceptSynthesisOutput(
            summary: "Apple は iPhone を販売する企業である。",
            crossSourceInsights: ["複数記事を統合した知見 1", "複数記事を統合した知見 2"]
        ))
        let service = makeFoundationService(context: context, session: session)

        await service.resynthesize(page)

        #expect(page.summary == "Apple は iPhone を販売する企業である。")
        #expect(page.crossSourceInsights.count == 2)
        #expect(page.isStale == false)
        #expect(session.conceptSynthesisCallCount == 1)
    }

    // MARK: - 5. resynthesize: threshold 未満 (≤2 件) は 1-shot (chunked 呼ばれない)
    //   Fix (2026-05-23): hierarchicalThreshold を 5→3 に下げたため、2 件で 1-shot 検証

    @Test func testResynthesizeSmallSetUsesOneShot() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let articles = (0..<2).map { i in
            makeArticle(url: "a\(i)", title: "T\(i)", categoryRaw: "テクノロジー", entityNames: ["Apple"], in: context)
        }
        let page = ConceptPage(
            name: "Apple",
            categoryRaw: "テクノロジー",
            relatedArticles: articles,
            isStale: true
        )
        context.insert(page)
        try context.save()

        let session = MockLanguageModelSession()
        session.nextConceptSynthesisResult = .success(ConceptSynthesisOutput(
            summary: "2 記事統合 summary",
            crossSourceInsights: []
        ))
        let service = makeFoundationService(context: context, session: session)

        await service.resynthesize(page)

        #expect(session.conceptSummaryChunkCallCount == 0)  // chunk 呼ばれない
        #expect(session.conceptSynthesisCallCount == 1)
    }

    // MARK: - 6. resynthesize: threshold 以上 (3+ 件) は hierarchical (chunked + meta)
    //   Fix (2026-05-23): threshold 3、chunk_size 2 に変更

    @Test func testResynthesizeLargeSetUsesHierarchical() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let articles = (0..<8).map { i in
            makeArticle(url: "a\(i)", title: "T\(i)", categoryRaw: "テクノロジー", entityNames: ["Apple"], in: context)
        }
        let page = ConceptPage(
            name: "Apple",
            categoryRaw: "テクノロジー",
            relatedArticles: articles,
            isStale: true
        )
        context.insert(page)
        try context.save()

        let session = MockLanguageModelSession()
        session.nextConceptSummaryChunkResult = .success(ConceptSummaryChunk(chunkSummary: "chunk 要約"))
        session.nextConceptSynthesisResult = .success(ConceptSynthesisOutput(
            summary: "meta 統合 summary",
            crossSourceInsights: ["x"]
        ))
        let service = makeFoundationService(context: context, session: session)

        await service.resynthesize(page)

        // spec 051 spike: chunk_size 2 → 1。8 記事 / 1 = 8 chunk → 8 回 chunk 呼び出し + 1 回 meta 合成
        #expect(session.conceptSummaryChunkCallCount == 8)
        #expect(session.conceptSynthesisCallCount == 1)
        #expect(page.summary == "meta 統合 summary")
    }

    // MARK: - 7. Fallback 経路 (availability=false) → essence 並べ summary

    @Test func testResynthesizeFallbackWhenUnavailable() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let articleA = makeArticle(
            url: "a", title: "A", categoryRaw: "テクノロジー",
            entityNames: ["Apple"], essence: "essence A 内容", in: context
        )
        let articleB = makeArticle(
            url: "b", title: "B", categoryRaw: "テクノロジー",
            entityNames: ["Apple"], essence: "essence B 内容", in: context
        )
        let page = ConceptPage(
            name: "Apple", categoryRaw: "テクノロジー",
            relatedArticles: [articleA, articleB], isStale: true
        )
        context.insert(page)
        try context.save()

        let session = MockLanguageModelSession()
        let service = makeFoundationService(context: context, session: session, availabilityIsAvailable: false)

        await service.resynthesize(page)

        #expect(session.conceptSynthesisCallCount == 0)  // Foundation 経路は呼ばれない
        #expect(page.isStale == false)
        #expect(page.summary.contains("essence"))  // essence が含まれる
    }

    // MARK: - 8. Foundation 経路エラー → Fallback service に自動委譲 (safety net)
    //   Fix (2026-05-23): isStale loop 防止のため、AI 失敗時に Fallback service が走る

    @Test func testResynthesizeOnFoundationErrorFallsBackToEssenceList() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let articleA = makeArticle(
            url: "a", title: "A", categoryRaw: "テクノロジー",
            entityNames: ["Apple"], essence: "essence A about Apple",
            in: context
        )
        let articleB = makeArticle(
            url: "b", title: "B", categoryRaw: "テクノロジー",
            entityNames: ["Apple"], essence: "essence B about Apple",
            in: context
        )
        let page = ConceptPage(
            name: "Apple", categoryRaw: "テクノロジー",
            relatedArticles: [articleA, articleB], isStale: true
        )
        context.insert(page)
        try context.save()

        let session = MockLanguageModelSession()
        session.nextConceptSynthesisResult = .failure(MockLanguageModelError.safetyFiltered)
        let service = makeFoundationService(context: context, session: session)

        await service.resynthesize(page)

        // throws しない、Fallback service が essence 並べた summary を生成
        #expect(page.isStale == false)
        #expect(page.summary.contains("essence"))
    }

    // MARK: - 9. backfillFromExistingArticles: UserDefaults flag で 1 度限り

    @Test func testBackfillFromExistingArticlesFlagPreventsRepeat() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        // テスト隔離: flag を必ずクリア
        UserDefaults.standard.removeObject(forKey: FallbackConceptSynthesisService.backfillFlagKey)

        // 同 entity を 3 記事に登場させる → 1 ConceptPage 生成のはず
        makeArticle(url: "a", title: "A", categoryRaw: "テクノロジー", entityNames: ["Apple"], in: context)
        makeArticle(url: "b", title: "B", categoryRaw: "テクノロジー", entityNames: ["Apple"], in: context)
        makeArticle(url: "c", title: "C", categoryRaw: "テクノロジー", entityNames: ["Apple"], in: context)
        try context.save()

        let session = MockLanguageModelSession()
        let service = makeFoundationService(context: context, session: session)

        await service.backfillFromExistingArticles()
        let firstCount = try context.fetch(FetchDescriptor<ConceptPage>()).count
        #expect(firstCount >= 1)
        #expect(UserDefaults.standard.bool(forKey: FallbackConceptSynthesisService.backfillFlagKey) == true)

        // 2 回目呼び出しは flag で早期 return
        let pageCountBefore = firstCount
        await service.backfillFromExistingArticles()
        let pageCountAfter = try context.fetch(FetchDescriptor<ConceptPage>()).count
        #expect(pageCountAfter == pageCountBefore)

        // テスト隔離: flag をクリア (他テストに影響しない)
        UserDefaults.standard.removeObject(forKey: FallbackConceptSynthesisService.backfillFlagKey)
    }

    // MARK: - 10. 大文字小文字違い → 同 ConceptPage に統合

    @Test func testCaseInsensitiveSameEntityMergesIntoOnePage() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        // 同 entity 名の大文字小文字違いを 2 記事に登場させる
        let articleA = makeArticle(url: "a", title: "A", categoryRaw: "テクノロジー", entityNames: ["Apple"], in: context)
        let articleB = makeArticle(url: "b", title: "B", categoryRaw: "テクノロジー", entityNames: ["apple"], in: context)
        _ = articleA
        try context.save()

        let session = MockLanguageModelSession()
        let service = makeFoundationService(context: context, session: session)

        await service.processNewArticle(article: articleB)

        let pages = try context.fetch(FetchDescriptor<ConceptPage>())
        #expect(pages.count == 1)
        #expect((pages[0].relatedArticles ?? []).count == 2)
    }

    // MARK: - 11. spec 078: 全角/かな 表記ゆれ → 同 ConceptPage に統合 (canonical 照合)

    @Test func testCanonicalVariantLinksToExistingPageNotDuplicate() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        // "Apple" を 2 記事に登場させて ConceptPage を生成
        let articleA = makeArticle(url: "a", title: "A", categoryRaw: "テクノロジー", entityNames: ["Apple"], in: context)
        let articleB = makeArticle(url: "b", title: "B", categoryRaw: "テクノロジー", entityNames: ["Apple"], in: context)
        _ = articleA
        // 全角変種 "ＡＰＰＬＥ" を持つ 3 本目 → canonical "apple" で既存にリンク (重複ページを作らない)
        let articleC = makeArticle(url: "c", title: "C", categoryRaw: "テクノロジー", entityNames: ["ＡＰＰＬＥ"], in: context)
        try context.save()

        let session = MockLanguageModelSession()
        session.nextConceptSynthesisResult = .success(ConceptSynthesisOutput(
            summary: "Apple summary (mock)", crossSourceInsights: ["insight"]
        ))
        let service = makeFoundationService(context: context, session: session)

        await service.processNewArticle(article: articleB)  // → "Apple" ページ (A+B)
        await service.processNewArticle(article: articleC)   // ＡＰＰＬＥ → canonical "apple" で既存にリンク

        let pages = try context.fetch(FetchDescriptor<ConceptPage>())
        let applePages = pages.filter { ConceptNameNormalizer.canonical($0.name) == "apple" }
        #expect(applePages.count == 1)  // 全角変種で重複ページが作られない
        #expect((applePages.first?.relatedArticles ?? []).count == 3)  // A+B+C すべてリンク
    }

    // MARK: - 12. spec 080: 要点 (crossSourceInsights) は最大 5 件に cap

    @Test func testResynthesizeCapsKeyPointsAtFive() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let a = makeArticle(url: "a", title: "A", categoryRaw: "テクノロジー", entityNames: ["X"], in: context)
        let b = makeArticle(url: "b", title: "B", categoryRaw: "テクノロジー", entityNames: ["X"], in: context)
        let page = ConceptPage(name: "X", categoryRaw: "テクノロジー", relatedArticles: [a, b], isStale: true)
        context.insert(page)
        try context.save()

        let session = MockLanguageModelSession()
        // AI が 6 件返しても prefix(5) で 5 件に cap される
        session.nextConceptSynthesisResult = .success(ConceptSynthesisOutput(
            summary: "要約",
            crossSourceInsights: ["要点1", "要点2", "要点3", "要点4", "要点5", "要点6"]
        ))
        let service = makeFoundationService(context: context, session: session)

        await service.resynthesize(page)

        #expect(page.crossSourceInsights.count == 5)  // spec 080: 最大 5
    }

    // MARK: - 13. spec 080拡張: overflow → compact adaptive retry

    @Test func testResynthesizeAdaptiveRetryOnOverflow() async throws {
        struct OverflowErr: Error, CustomStringConvertible {
            var description: String { "exceededContextWindowSize(Content contains 4091 tokens)" }
        }
        let container = try makeContainer()
        let context = container.mainContext

        let a = makeArticle(url: "a", title: "A", categoryRaw: "テクノロジー", entityNames: ["X"], in: context)
        let b = makeArticle(url: "b", title: "B", categoryRaw: "テクノロジー", entityNames: ["X"], in: context)
        let page = ConceptPage(name: "X", categoryRaw: "テクノロジー", relatedArticles: [a, b], isStale: true)
        context.insert(page)
        try context.save()

        let session = MockLanguageModelSession()
        // 通常合成は overflow → compact 再試行は成功
        session.nextConceptSynthesisResult = .failure(OverflowErr())
        session.nextConceptSynthesisCompactResult = .success(
            ConceptSynthesisCompactOutput(summary: "compact 要約", crossSourceInsights: ["要点1", "要点2"])
        )
        let service = makeFoundationService(context: context, session: session)

        await service.resynthesize(page)

        #expect(page.summary == "compact 要約")          // compact 再試行が反映 (essence-list fallback に落ちない)
        #expect(page.isStale == false)
        #expect(session.conceptSynthesisCompactCallCount == 1)  // compact が 1 回呼ばれた
    }

    // spec 089: 要点 → 元記事 出典照合 (keyword 経路、embeddingService nil)。
    @Test func testMatchInsightSourcesKeyword() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let swiftArticle = makeArticle(url: "a1", title: "Swift 6 リリース", categoryRaw: "テクノロジー", entityNames: [], essence: "Swift 6 の並行性が強化された", in: context)
        let pythonArticle = makeArticle(url: "a2", title: "Python 入門", categoryRaw: "テクノロジー", entityNames: [], essence: "Python はデータ分析に強い", in: context)
        try context.save()

        let insights = ["Swift の並行性について", "Python のデータ分析"]
        let ids = ConceptSynthesisCommon.matchInsightSources(
            insights: insights,
            articles: [swiftArticle, pythonArticle],
            embeddingService: nil
        )

        #expect(ids.count == 2)
        #expect(ids[0] == swiftArticle.id.uuidString)   // Swift 要点 → Swift 記事
        #expect(ids[1] == pythonArticle.id.uuidString)  // Python 要点 → Python 記事
    }

    // spec 089: 記事ゼロ / insight ゼロは空配列。
    @Test func testMatchInsightSourcesEmpty() {
        #expect(ConceptSynthesisCommon.matchInsightSources(insights: [], articles: [], embeddingService: nil).isEmpty)
    }
}

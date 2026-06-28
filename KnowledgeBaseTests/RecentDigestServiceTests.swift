//
//  RecentDigestServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 035 — RecentDigestService 5 ケース。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeBase

@MainActor
struct RecentDigestServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    /// V3.0 polish: 各テストで isolated UserDefaults を作る (cache test 間で漏れないように)
    private func makeIsolatedDefaults() -> UserDefaults {
        let suite = "RecentDigestServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @discardableResult
    private func makeArticle(
        title: String,
        savedAt: Date,
        essence: String?,
        in context: ModelContext
    ) -> Article {
        let article = Article(url: "https://example.com/\(UUID().uuidString)", title: title, savedAt: savedAt)
        context.insert(article)
        if let essence {
            let knowledge = ExtractedKnowledge(article: article, status: .succeeded)
            knowledge.essence = essence
            context.insert(knowledge)
            article.extractedKnowledge = knowledge
        }
        return article
    }

    // MARK: - 1. 4 tier fallback 階層 (V3.0 polish 2026-05-27)
    // Tier 1: since 以降あり + AI 生成成功 → cache 保存
    // Tier 2: since 以降 0 件 → 前回 cache 復元
    // Tier 3: cache 無し → 最新 1 件の essence を headline 化
    // Tier 4: 記事ゼロ → empty

    /// Tier 3: since 以降 0 件 + cache 無し → 全 Article 最新 1 件の essence を headline 化
    @Test func testTier3FallsBackToLatestArticleHeadline() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let oldDate = Date.now.addingTimeInterval(-86400 * 7) // 7 日前
        makeArticle(title: "古い記事タイトル", savedAt: oldDate, essence: "古い記事のエッセンス", in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = false

        let service = RecentDigestService(
            session: mockSession,
            availability: availability,
            userDefaults: makeIsolatedDefaults()  // cache 無し state を保証
        )
        let result = try await service.generate(since: Date.now, in: context)

        #expect(!result.isEmpty)
        #expect(result.articleCount == 1)
        // headline = essence、theme = title prefix (or entity)
        #expect(result.paragraphs.first == "古い記事のエッセンス")
    }

    /// Tier 2: 1 回目で cache 保存、2 回目 since 以降 0 件 → cache から復元
    @Test func testTier2RestoresFromCacheWhenSinceIsEmpty() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeIsolatedDefaults()

        // 1 回目: since 以降の記事 1 件 + availability=true + Mock の AI 成功
        let recent = Date.now.addingTimeInterval(-3600)  // 1 時間前
        makeArticle(title: "新記事", savedAt: recent, essence: "新エッセンス", in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextRecentDigestResult = .success(
            RecentDigestOutput(paragraphs: ["AI ヘッドライン", "テーマ A", "テーマ B", "テーマ C"])
        )
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = RecentDigestService(session: mockSession, availability: availability, userDefaults: defaults)

        let firstSince = Date.now.addingTimeInterval(-86400)  // 1 日前 (新記事は since 以降)
        let firstResult = try await service.generate(since: firstSince, in: context)
        #expect(firstResult.paragraphs.first == "AI ヘッドライン")  // cache 保存される

        // 2 回目: since を「今」にして since 以降 0 件 → Tier 2 cache restore
        let secondResult = try await service.generate(since: Date.now, in: context)
        #expect(secondResult.paragraphs.first == "AI ヘッドライン")
        #expect(secondResult.paragraphs.count == 4)  // cache の paragraphs と一致
    }

    /// Tier 4: 記事ゼロ → empty
    @Test func testTier4EmptyWhenNoArticlesAtAll() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = RecentDigestService(
            session: mockSession,
            availability: availability,
            userDefaults: makeIsolatedDefaults()
        )
        let result = try await service.generate(since: Date.now, in: context)

        #expect(result.isEmpty)
        #expect(result.articleCount == 0)
    }

    // MARK: - 2. Foundation Models で 3 段落生成

    @Test func testGenerateUsesFoundationModelsWhenAvailable() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let recent = Date.now.addingTimeInterval(-3600) // 1 時間前
        makeArticle(title: "新記事", savedAt: recent, essence: "Swift 6 が登場", in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextRecentDigestResult = .success(RecentDigestOutput(paragraphs: [
            "段落 1: Swift 6 の話題",
            "段落 2: 新機能の概要",
            "段落 3: 影響と展望"
        ]))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = RecentDigestService(session: mockSession, availability: availability)
        let since = Date.now.addingTimeInterval(-86400)
        let result = try await service.generate(since: since, in: context)

        #expect(result.paragraphs.count == 3)
        #expect(result.paragraphs[0].contains("Swift 6"))
        #expect(result.articleCount == 1)
    }

    // MARK: - 3. Foundation Models 不可 → Fallback で擬似 3 段落

    @Test func testGenerateFallsBackWhenLMUnavailable() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let recent = Date.now.addingTimeInterval(-3600)
        makeArticle(title: "記事 A", savedAt: recent, essence: "essence A", in: context)
        makeArticle(title: "記事 B", savedAt: recent.addingTimeInterval(-100), essence: "essence B", in: context)
        makeArticle(title: "記事 C", savedAt: recent.addingTimeInterval(-200), essence: "essence C", in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = false  // FM 不可

        let service = RecentDigestService(session: mockSession, availability: availability)
        let since = Date.now.addingTimeInterval(-86400)
        let result = try await service.generate(since: since, in: context)

        #expect(!result.isEmpty)
        #expect(result.articleCount == 3)
        #expect(mockSession.recentDigestCallCount == 0) // LM は呼ばれていない
    }

    // MARK: - 4. LM 失敗 → Fallback に切替

    @Test func testGenerateFallsBackOnLMError() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let recent = Date.now.addingTimeInterval(-3600)
        makeArticle(title: "記事", savedAt: recent, essence: "essence", in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextRecentDigestResult = .failure(MockLanguageModelError.safetyFiltered)
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = RecentDigestService(session: mockSession, availability: availability)
        let since = Date.now.addingTimeInterval(-86400)
        let result = try await service.generate(since: since, in: context)

        #expect(!result.isEmpty)
        #expect(result.articleCount == 1)
    }

    // MARK: - 5. 30 件超過 → 最新優先 truncate

    @Test func testGenerateTruncatesTo30Articles() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let now = Date.now
        for i in 0..<50 {
            let savedAt = now.addingTimeInterval(-Double(i) * 3600)
            makeArticle(title: "記事 \(i)", savedAt: savedAt, essence: "essence \(i)", in: context)
        }
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextRecentDigestResult = .success(RecentDigestOutput(paragraphs: ["P1", "P2", "P3"]))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = RecentDigestService(session: mockSession, availability: availability)
        let since = now.addingTimeInterval(-86400 * 7)
        let result = try await service.generate(since: since, in: context)

        #expect(result.articleCount == 30)
    }

    // MARK: - 6. fallbackParagraphs ユーティリティ
    // V3.0 polish (2026-05-26): 「3 段落 80-150 字」→「ヘッドライン 1 文 + テーマ 3 個」に変更。
    // paragraphs[0] = ヘッドライン、paragraphs[1..3] = テーマ (各 10-20 字、最大 3 件)。

    @Test func testFallbackParagraphsReturnsHeadlinePlusThemes() {
        let now = Date.now
        let articles: [Article] = (0..<6).map { i in
            let a = Article(url: "https://example.com/\(i)", title: "記事 \(i)", savedAt: now)
            return a
        }
        let paragraphs = RecentDigestService.fallbackParagraphs(articles: articles)
        // 上限 4 件 (ヘッドライン 1 + テーマ 3)
        #expect(paragraphs.count <= 4)
        // ヘッドラインは必須、テーマは最大 3
        #expect(!paragraphs.isEmpty)
        #expect(paragraphs.allSatisfy { !$0.isEmpty })
    }

    @Test func testFallbackParagraphsHeadlineMentionsCount() {
        let now = Date.now
        let articles: [Article] = (0..<3).map { i in
            Article(url: "https://example.com/\(i)", title: "記事 \(i)", savedAt: now)
        }
        let paragraphs = RecentDigestService.fallbackParagraphs(articles: articles)
        // 記事 2 件以上ならヘッドラインに件数 (「3 件」) が出現
        #expect(paragraphs.first?.contains("3") == true)
    }

    @Test func testFallbackParagraphsEmptyForNoArticles() {
        let paragraphs = RecentDigestService.fallbackParagraphs(articles: [])
        #expect(paragraphs.isEmpty)
    }

    // MARK: - V3.0 polish: firstCompleteSentence (Tier 3 文字切れ対策)

    @Test func testFirstCompleteSentenceCutsAtPeriod() {
        let input = "AI エージェントは効率を高める。次の話題はここから先。"
        let result = RecentDigestService.firstCompleteSentence(input)
        #expect(result == "AI エージェントは効率を高める。")
    }

    @Test func testFirstCompleteSentenceCutsAtNewline() {
        let input = "見出し的な 1 行\n本文がここから始まる"
        let result = RecentDigestService.firstCompleteSentence(input)
        #expect(result.contains("見出し的な 1 行"))
        #expect(!result.contains("本文"))
    }

    @Test func testFirstCompleteSentenceKeepsShortTextWhole() {
        let input = "短い 1 文"  // 終端なし、100 字以下
        let result = RecentDigestService.firstCompleteSentence(input)
        #expect(result == "短い 1 文")
    }

    @Test func testFirstCompleteSentenceTruncatesLongWithoutTerminator() {
        let input = String(repeating: "あ", count: 150)  // 終端なし、100 字超
        let result = RecentDigestService.firstCompleteSentence(input)
        #expect(result.hasSuffix("…"))
        #expect(result.count == 101)  // 100 + "…"
    }

    // MARK: - spec 060 (P1-10): buildPrompt token 超過防止

    /// 50 件 (各 title/essence 長め) でも buildPrompt の文字数が安全上限 (3500 字) 以内。
    /// 旧実装は 30 件全列挙で ~4089 token → 4096 超過していた。
    @Test func testBuildPromptStaysUnderCharBudget() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let now = Date.now
        var articles: [Article] = []
        for i in 0..<50 {
            // title / essence を長めにして worst case を作る
            let article = makeArticle(
                title: "記事タイトル番号 \(i) " + String(repeating: "長", count: 40),
                savedAt: now.addingTimeInterval(-Double(i) * 60),
                essence: String(repeating: "要点テキスト", count: 20),  // ~120 字
                in: context
            )
            articles.append(article)
        }
        try context.save()

        let prompt = RecentDigestService.buildPrompt(articles: articles)
        // 安全上限 3500 字以内 (promptCharBudget 3000 + 固定フッタ余裕)
        #expect(prompt.count <= 3500, "buildPrompt が \(prompt.count) 字、3500 字を超過 (token 超過リスク)")
        // 件数表示は実件数 (50) を維持
        #expect(prompt.contains("件数 50"))
    }

    /// buildPrompt は promptArticleLimit (8) 件しか列挙しない (9 件目以降は非含有)。
    @Test func testBuildPromptLimitsArticleCount() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let now = Date.now
        var articles: [Article] = []
        for i in 0..<20 {
            // 固有な識別子を title に埋め込む
            let article = makeArticle(
                title: "UNIQUEMARK\(i)",
                savedAt: now.addingTimeInterval(-Double(i) * 60),
                essence: "essence \(i)",
                in: context
            )
            articles.append(article)
        }
        try context.save()

        let prompt = RecentDigestService.buildPrompt(articles: articles)
        // 先頭 8 件 (0-7) は含まれる
        #expect(prompt.contains("UNIQUEMARK0"))
        #expect(prompt.contains("UNIQUEMARK7"))
        // 9 件目以降 (8, 9, ...) は含まれない (promptArticleLimit=8)
        #expect(!prompt.contains("UNIQUEMARK8"))
        #expect(!prompt.contains("UNIQUEMARK15"))
    }
}

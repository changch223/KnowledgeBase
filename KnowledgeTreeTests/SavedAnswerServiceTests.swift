//
//  SavedAnswerServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 043 — SavedAnswerService の 10 ケース。
//  Mock LM 不要 (純粋ロジック層、AI 使用なし)、in-memory ModelContainer + SharedSchema.all。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

@MainActor
struct SavedAnswerServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    @discardableResult
    private func makeArticle(
        url: String,
        title: String,
        savedAt: Date = .now,
        in context: ModelContext
    ) -> Article {
        let article = Article(url: url, title: title, savedAt: savedAt)
        context.insert(article)
        return article
    }

    @discardableResult
    private func makeConceptPage(
        name: String,
        categoryRaw: String = "テクノロジー",
        relatedArticles: [Article],
        in context: ModelContext
    ) -> ConceptPage {
        let page = ConceptPage(
            name: name,
            categoryRaw: categoryRaw,
            relatedArticles: relatedArticles,
            isStale: false
        )
        context.insert(page)
        return page
    }

    // MARK: - 1. captureIfWorthy で 2+ 引用 + 50+ 字 → 保存

    @Test func testCaptureIfWorthyWithValidConditionsCreatesSavedAnswer() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let articleA = makeArticle(url: "a", title: "A", in: context)
        let articleB = makeArticle(url: "b", title: "B", in: context)
        try context.save()

        let service = DefaultSavedAnswerService(context: context, refreshTrigger: nil)
        let answer = String(repeating: "あ", count: 80)  // 80 字、50+ クリア

        await service.captureIfWorthy(
            question: "Apple Vision Pro について教えて",
            answer: answer,
            citedArticleIDs: [articleA.id.uuidString, articleB.id.uuidString],
            sessionID: UUID()
        )

        let saved = try context.fetch(FetchDescriptor<SavedAnswer>())
        #expect(saved.count == 1)
        let s = saved[0]
        #expect(s.question == "Apple Vision Pro について教えて")
        #expect(s.answer.count == 80)
        #expect(s.citedArticles.count == 2)
        #expect(s.savedAutomatically == true)
        #expect(s.chatSessionID != nil)
    }

    // MARK: - 2. 1 引用 → 保存しない

    @Test func testCaptureIfWorthySkipsWithSingleCitation() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let articleA = makeArticle(url: "a", title: "A", in: context)
        try context.save()

        let service = DefaultSavedAnswerService(context: context)

        await service.captureIfWorthy(
            question: "test?",
            answer: String(repeating: "あ", count: 80),
            citedArticleIDs: [articleA.id.uuidString],
            sessionID: nil
        )

        let saved = try context.fetch(FetchDescriptor<SavedAnswer>())
        #expect(saved.isEmpty)
    }

    // MARK: - 3. 49 字 answer → 保存しない

    @Test func testCaptureIfWorthySkipsWithShortAnswer() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let articleA = makeArticle(url: "a", title: "A", in: context)
        let articleB = makeArticle(url: "b", title: "B", in: context)
        try context.save()

        let service = DefaultSavedAnswerService(context: context)

        await service.captureIfWorthy(
            question: "test?",
            answer: String(repeating: "あ", count: 49),  // 49 字、50 字未満
            citedArticleIDs: [articleA.id.uuidString, articleB.id.uuidString],
            sessionID: nil
        )

        let saved = try context.fetch(FetchDescriptor<SavedAnswer>())
        #expect(saved.isEmpty)
    }

    // MARK: - 4. 同 question 重複 → 2 件目作成しない

    @Test func testCaptureIfWorthyDeduplicatesByQuestion() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let articleA = makeArticle(url: "a", title: "A", in: context)
        let articleB = makeArticle(url: "b", title: "B", in: context)
        try context.save()

        let service = DefaultSavedAnswerService(context: context)
        let answer80 = String(repeating: "あ", count: 80)

        // 1 回目
        await service.captureIfWorthy(
            question: "Apple について",
            answer: answer80,
            citedArticleIDs: [articleA.id.uuidString, articleB.id.uuidString],
            sessionID: nil
        )

        // 2 回目 (同 question、前後空白だけ違うが trim で同一視)
        await service.captureIfWorthy(
            question: "  Apple について  ",
            answer: answer80,
            citedArticleIDs: [articleA.id.uuidString, articleB.id.uuidString],
            sessionID: nil
        )

        let saved = try context.fetch(FetchDescriptor<SavedAnswer>())
        #expect(saved.count == 1)
    }

    // MARK: - 5. relatedConceptIDs 解決: overlap > 0 の ConceptPage が紐付く、無関係は除外
    //
    // 注: SwiftData @Relationship without inverse の挙動上、複数 ConceptPage が同 Article を
    // 共有する fixture は不安定 (Article が後発 page に「移動」する模様)。
    // 各 page に専用の Article を持たせて分離型でテストする。

    @Test func testCaptureIfWorthyResolvesRelatedConceptIDs() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        // page1 専用 article
        let article1 = makeArticle(url: "a1", title: "A1", in: context)
        let article2 = makeArticle(url: "a2", title: "A2", in: context)
        // page2 専用 article
        let article3 = makeArticle(url: "b1", title: "B1", in: context)
        // 無関係な article
        let articleZ = makeArticle(url: "z", title: "Z", in: context)

        let page1 = makeConceptPage(name: "p1", relatedArticles: [article1, article2], in: context)
        let page2 = makeConceptPage(name: "p2", relatedArticles: [article3], in: context)
        _ = makeConceptPage(name: "p3", relatedArticles: [articleZ], in: context)  // overlap 0
        try context.save()

        let service = DefaultSavedAnswerService(context: context)

        // 引用: article1, article2, article3 → page1 overlap=2、page2 overlap=1、p3 overlap=0
        await service.captureIfWorthy(
            question: "test?",
            answer: String(repeating: "あ", count: 80),
            citedArticleIDs: [article1.id.uuidString, article2.id.uuidString, article3.id.uuidString],
            sessionID: nil
        )

        let saved = try context.fetch(FetchDescriptor<SavedAnswer>())
        #expect(saved.count == 1)
        let s = saved[0]
        // page1 (overlap 2) と page2 (overlap 1) が含まれ、p3 (overlap 0) は除外
        #expect(s.relatedConceptIDs.count == 2)
        #expect(Set(s.relatedConceptIDs) == Set([page1.id, page2.id]))
        // overlap desc なので page1 が先頭
        #expect(s.relatedConceptIDs.first == page1.id)
    }

    // MARK: - 6. 引用記事 0 件 (存在しない UUID) → 保存しない

    @Test func testCaptureIfWorthyWithMissingArticlesSkips() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let service = DefaultSavedAnswerService(context: context)
        let fakeID1 = UUID().uuidString
        let fakeID2 = UUID().uuidString

        await service.captureIfWorthy(
            question: "test?",
            answer: String(repeating: "あ", count: 80),
            citedArticleIDs: [fakeID1, fakeID2],
            sessionID: nil
        )

        let saved = try context.fetch(FetchDescriptor<SavedAnswer>())
        #expect(saved.isEmpty)
    }

    // MARK: - 7. chatSessionID = nil でも保存可能

    @Test func testCaptureIfWorthyWithNilSessionID() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let articleA = makeArticle(url: "a", title: "A", in: context)
        let articleB = makeArticle(url: "b", title: "B", in: context)
        try context.save()

        let service = DefaultSavedAnswerService(context: context)

        await service.captureIfWorthy(
            question: "test?",
            answer: String(repeating: "あ", count: 80),
            citedArticleIDs: [articleA.id.uuidString, articleB.id.uuidString],
            sessionID: nil
        )

        let saved = try context.fetch(FetchDescriptor<SavedAnswer>())
        #expect(saved.count == 1)
        #expect(saved[0].chatSessionID == nil)
    }

    // MARK: - 8. setPinned: false → true → false で永続化

    @Test func testSetPinnedToggles() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let articleA = makeArticle(url: "a", title: "A", in: context)
        let articleB = makeArticle(url: "b", title: "B", in: context)
        let answer = SavedAnswer(
            question: "Q?",
            answer: String(repeating: "あ", count: 80),
            citedArticles: [articleA, articleB]
        )
        context.insert(answer)
        try context.save()
        #expect(answer.isPinned == false)

        let service = DefaultSavedAnswerService(context: context)

        try service.setPinned(answer, isPinned: true)
        #expect(answer.isPinned == true)

        try service.setPinned(answer, isPinned: false)
        #expect(answer.isPinned == false)
    }

    // MARK: - 9. delete: SavedAnswer 削除、Article 残存

    @Test func testDeleteRemovesAnswerButKeepsArticles() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let articleA = makeArticle(url: "a", title: "A", in: context)
        let articleB = makeArticle(url: "b", title: "B", in: context)
        let answer = SavedAnswer(
            question: "Q?",
            answer: String(repeating: "あ", count: 80),
            citedArticles: [articleA, articleB]
        )
        context.insert(answer)
        try context.save()

        let service = DefaultSavedAnswerService(context: context)
        try service.delete(answer)

        // SavedAnswer 削除
        let savedCount = try context.fetch(FetchDescriptor<SavedAnswer>()).count
        #expect(savedCount == 0)
        // Article 残存
        let articleCount = try context.fetch(FetchDescriptor<Article>()).count
        #expect(articleCount == 2)
    }

    // MARK: - 10. markStaleForArticle: 引用記事 → 関連 ConceptPage → SavedAnswer の isStale 連鎖

    @Test func testMarkStaleForArticleChainsThroughConceptPage() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let articleA = makeArticle(url: "a", title: "A", in: context)
        let articleB = makeArticle(url: "b", title: "B", in: context)
        // ConceptPage P が article A を含む
        let pageP = makeConceptPage(name: "P", relatedArticles: [articleA], in: context)

        // SavedAnswer は relatedConceptIDs に pageP.id を含む
        let answer = SavedAnswer(
            question: "Q?",
            answer: String(repeating: "あ", count: 80),
            citedArticles: [articleA, articleB],
            relatedConceptIDs: [pageP.id],
            isStale: false
        )
        context.insert(answer)
        try context.save()
        #expect(answer.isStale == false)

        let service = DefaultSavedAnswerService(context: context)
        // articleA の新規 ingest 想定 → pageP 影響 → answer.isStale=true 連鎖
        await service.markStaleForArticle(articleA)

        #expect(answer.isStale == true)

        // 無関係 article は影響なし
        let unrelated = makeArticle(url: "z", title: "Z", in: context)
        try context.save()
        let answer2 = SavedAnswer(
            question: "Q2?",
            answer: String(repeating: "い", count: 80),
            citedArticles: [unrelated],
            relatedConceptIDs: [],  // 空 → 連鎖対象外
            isStale: false
        )
        context.insert(answer2)
        try context.save()

        await service.markStaleForArticle(unrelated)
        #expect(answer2.isStale == false)
    }
}

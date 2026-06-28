//
//  UnderstandingCardSurfaceServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 044 — UnderstandingCardSurfaceService の 10 ケース。
//  Mock 不要 (純粋ロジック層、AI なし)、in-memory ModelContainer + SharedSchema.all。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeBase

@MainActor
struct UnderstandingCardSurfaceServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    @discardableResult
    private func makeArticle(
        url: String,
        title: String,
        savedAt: Date,
        in context: ModelContext
    ) -> Article {
        let article = Article(url: url, title: title, savedAt: savedAt)
        context.insert(article)
        return article
    }

    @discardableResult
    private func makeConceptPage(
        name: String,
        userUnderstanding: Int = 0,
        isFollowing: Bool = false,
        createdAt: Date = .now,
        relatedArticles: [Article] = [],
        in context: ModelContext
    ) -> ConceptPage {
        let page = ConceptPage(
            name: name,
            categoryRaw: "テクノロジー",
            relatedArticles: relatedArticles,
            userUnderstanding: userUnderstanding,
            isFollowing: isFollowing,
            isStale: false,
            createdAt: createdAt
        )
        context.insert(page)
        return page
    }

    @discardableResult
    private func makeSavedAnswer(
        question: String,
        isStale: Bool = false,
        savedAt: Date = .now,
        relatedConceptIDs: [UUID] = [],
        in context: ModelContext
    ) -> SavedAnswer {
        let answer = SavedAnswer(
            question: question,
            answer: "これは spec 044 テスト用の答え本文です (50 字以上)。",
            relatedConceptIDs: relatedConceptIDs,
            isStale: isStale,
            savedAt: savedAt
        )
        context.insert(answer)
        return answer
    }

    @discardableResult
    private func makeInteraction(
        targetID: UUID,
        kind: UnderstandingInteraction.Kind,
        action: UnderstandingInteraction.Action,
        at occurredAt: Date,
        in context: ModelContext
    ) -> UnderstandingInteraction {
        let ix = UnderstandingInteraction(
            kind: kind,
            targetID: targetID,
            action: action,
            occurredAt: occurredAt
        )
        context.insert(ix)
        return ix
    }

    // MARK: - 1. 空状態

    @Test func test_emptyState_returnsEmpty() async throws {
        let container = try makeContainer()
        let service = DefaultUnderstandingCardSurfaceService(context: container.mainContext)
        let cards = await service.surfaceTopCards(limit: 5)
        #expect(cards.isEmpty)
    }

    // MARK: - 2. newKnowledge 優先 (24h 以内 + understanding=0)

    @Test func test_newConceptPageGetsNewKnowledgeLabelAndHighestScore() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let recent = now.addingTimeInterval(-3600)  // 1h 前
        _ = makeConceptPage(name: "Apple Vision Pro", userUnderstanding: 0, createdAt: recent, in: context)
        try context.save()

        let service = DefaultUnderstandingCardSurfaceService(context: context, now: { now })
        let cards = await service.surfaceTopCards(limit: 5)
        #expect(cards.count == 1)
        #expect(cards[0].label == .newKnowledge)
        #expect(cards[0].priorityScore == 100)
    }

    // MARK: - 3. needsUpdate 優先 (isStale SavedAnswer)

    @Test func test_staleSavedAnswerGetsNeedsUpdateLabel() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = makeSavedAnswer(question: "GPT-4 とは?", isStale: true, in: context)
        try context.save()

        let service = DefaultUnderstandingCardSurfaceService(context: context)
        let cards = await service.surfaceTopCards(limit: 5)
        #expect(cards.count == 1)
        #expect(cards[0].label == .needsUpdate)
        #expect(cards[0].priorityScore == 90)
    }

    // MARK: - 4. shallow (understanding 0-1 + 関連記事 7d 以内)

    @Test func test_shallowLabelWhenRecentArticleAndLowUnderstanding() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let old = now.addingTimeInterval(-3 * 86_400)  // 3 日前
        let article = makeArticle(url: "x", title: "x", savedAt: now.addingTimeInterval(-86_400), in: context)
        let page = makeConceptPage(
            name: "OpenAI",
            userUnderstanding: 1,
            createdAt: old,
            relatedArticles: [article],
            in: context
        )
        try context.save()

        let service = DefaultUnderstandingCardSurfaceService(context: context, now: { now })
        let cards = await service.surfaceTopCards(limit: 5)
        #expect(cards.count == 1)
        #expect(cards[0].id == page.id)
        #expect(cards[0].label == .shallow)
        #expect(cards[0].priorityScore == 80)
    }

    // MARK: - 5. dismissed -10 補正

    @Test func test_dismissedPageGetsScorePenalty() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let pageDismissed = makeConceptPage(name: "X", userUnderstanding: 0, createdAt: now.addingTimeInterval(-3600), in: context)
        let pageFresh = makeConceptPage(name: "Y", userUnderstanding: 0, createdAt: now.addingTimeInterval(-7200), in: context)
        try context.save()
        _ = makeInteraction(targetID: pageDismissed.id, kind: .conceptPage, action: .dismissed, at: now.addingTimeInterval(-1800), in: context)
        try context.save()

        let service = DefaultUnderstandingCardSurfaceService(context: context, now: { now })
        let cards = await service.surfaceTopCards(limit: 5)
        // 両方 newKnowledge (100) 候補だが dismissed の方が -10 で下位
        #expect(cards.count == 2)
        #expect(cards[0].id == pageFresh.id)
        #expect(cards[0].priorityScore == 100)
        #expect(cards[1].id == pageDismissed.id)
        #expect(cards[1].priorityScore == 90)
    }

    // MARK: - 6. limit=5 で上限切り取り

    @Test func test_surfaceTopCardsRespectsLimit() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        for i in 0 ..< 8 {
            _ = makeConceptPage(
                name: "P\(i)",
                userUnderstanding: 0,
                createdAt: now.addingTimeInterval(-3600 - Double(i)),
                in: context
            )
        }
        try context.save()

        let service = DefaultUnderstandingCardSurfaceService(context: context, now: { now })
        let cards = await service.surfaceTopCards(limit: 5)
        #expect(cards.count == 5)
    }

    // MARK: - 7. ConceptPage + SavedAnswer ブレンド sort

    @Test func test_blendsConceptAndSavedAnswer() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let newConcept = makeConceptPage(name: "New", userUnderstanding: 0, createdAt: now.addingTimeInterval(-3600), in: context)  // newKnowledge 100
        let stale = makeSavedAnswer(question: "stale?", isStale: true, savedAt: now.addingTimeInterval(-7200), relatedConceptIDs: [newConcept.id], in: context)  // needsUpdate 90
        try context.save()

        let service = DefaultUnderstandingCardSurfaceService(context: context, now: { now })
        let cards = await service.surfaceTopCards(limit: 5)
        #expect(cards.count == 2)
        #expect(cards[0].id == newConcept.id)  // 100 > 90
        #expect(cards[0].priorityScore == 100)
        #expect(cards[1].id == stale.id)
        #expect(cards[1].priorityScore == 90)
    }

    // MARK: - 8. 全 max userUnderstanding で review fallback (lastInteractedAt 古)

    @Test func test_allMaxUnderstandingFallsToReviewIfStale() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        // userUnderstanding=5 で newKnowledge / shallow / deepDive 不適合、lastInteractedAt なし → review に該当
        _ = makeConceptPage(
            name: "Mastered",
            userUnderstanding: 5,
            createdAt: now.addingTimeInterval(-60 * 86_400),  // 60 日前
            in: context
        )
        try context.save()

        let service = DefaultUnderstandingCardSurfaceService(context: context, now: { now })
        let cards = await service.surfaceTopCards(limit: 5)
        #expect(cards.count == 1)
        #expect(cards[0].label == .review)
        #expect(cards[0].priorityScore == 40)
    }

    // MARK: - 9. deepDive label (understanding 2-3 + isFollowing)

    @Test func test_deepDiveLabelWhenFollowingAndMidUnderstanding() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        _ = makeConceptPage(
            name: "Deepening",
            userUnderstanding: 2,
            isFollowing: true,
            createdAt: now.addingTimeInterval(-30 * 86_400),
            in: context
        )
        try context.save()

        let service = DefaultUnderstandingCardSurfaceService(context: context, now: { now })
        let cards = await service.surfaceTopCards(limit: 5)
        #expect(cards.count == 1)
        #expect(cards[0].label == .deepDive)
        #expect(cards[0].priorityScore == 60)
    }

    // MARK: - 10. tiebreak: 同 priority は savedAt/createdAt desc

    @Test func test_samePriorityTiebreaksByCreatedAtDesc() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date()
        let older = makeConceptPage(
            name: "Older",
            userUnderstanding: 0,
            createdAt: now.addingTimeInterval(-7200),  // 2h 前
            in: context
        )
        let newer = makeConceptPage(
            name: "Newer",
            userUnderstanding: 0,
            createdAt: now.addingTimeInterval(-1800),  // 30m 前
            in: context
        )
        try context.save()

        let service = DefaultUnderstandingCardSurfaceService(context: context, now: { now })
        let cards = await service.surfaceTopCards(limit: 5)
        #expect(cards.count == 2)
        #expect(cards[0].id == newer.id)
        #expect(cards[1].id == older.id)
    }
}

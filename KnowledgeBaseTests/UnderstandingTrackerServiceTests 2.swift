//
//  UnderstandingTrackerServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 044 — UnderstandingTrackerService の 8 ケース。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeBase

@MainActor
struct UnderstandingTrackerServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    @discardableResult
    private func makeConceptPage(
        name: String,
        userUnderstanding: Int = 0,
        relatedConceptIDs: [UUID] = [],
        in context: ModelContext
    ) -> ConceptPage {
        let page = ConceptPage(
            name: name,
            categoryRaw: "テクノロジー",
            relatedConceptIDs: relatedConceptIDs,
            userUnderstanding: userUnderstanding,
            isStale: false
        )
        context.insert(page)
        return page
    }

    @discardableResult
    private func makeSavedAnswer(
        question: String,
        relatedConceptIDs: [UUID],
        in context: ModelContext
    ) -> SavedAnswer {
        let answer = SavedAnswer(
            question: question,
            answer: "これは spec 044 テスト答え本文 (50 字以上の content です)。",
            relatedConceptIDs: relatedConceptIDs
        )
        context.insert(answer)
        return answer
    }

    private func interactionsCount(
        for targetID: UUID,
        action: UnderstandingInteraction.Action,
        in context: ModelContext
    ) throws -> Int {
        let raw = action.rawValue
        let descriptor = FetchDescriptor<UnderstandingInteraction>(
            predicate: #Predicate { $0.targetID == targetID && $0.action == raw }
        )
        return try context.fetchCount(descriptor)
    }

    // MARK: - 1. recordUnderstood: userUnderstanding 0 → 1

    @Test func test_recordUnderstoodIncrementsBy1() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = makeConceptPage(name: "A", userUnderstanding: 0, in: context)
        try context.save()

        let tracker = DefaultUnderstandingTrackerService(context: context)
        let card = UnderstandingCard.fromConceptPage(page)
        try await tracker.recordUnderstood(card: card)

        #expect(page.userUnderstanding == 1)
        let count = try interactionsCount(for: page.id, action: .understood, in: context)
        #expect(count == 1)
    }

    // MARK: - 2. max clamp = 5

    @Test func test_recordUnderstoodClampsAtMax5() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = makeConceptPage(name: "A", userUnderstanding: 5, in: context)
        try context.save()

        let tracker = DefaultUnderstandingTrackerService(context: context)
        let card = UnderstandingCard.fromConceptPage(page)
        try await tracker.recordUnderstood(card: card)

        #expect(page.userUnderstanding == 5)
        // 履歴は記録されている
        let count = try interactionsCount(for: page.id, action: .understood, in: context)
        #expect(count == 1)
    }

    // MARK: - 3. 1-hop 波及 (累積 2 件 = +1)

    @Test func test_recordUnderstoodPropagatesToNeighbors() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let neighbor = makeConceptPage(name: "Neighbor", userUnderstanding: 0, in: context)
        let center = makeConceptPage(
            name: "Center",
            userUnderstanding: 0,
            relatedConceptIDs: [neighbor.id],
            in: context
        )
        try context.save()

        let tracker = DefaultUnderstandingTrackerService(context: context)
        let card = UnderstandingCard.fromConceptPage(center)

        // 1 回目: neighbor は propagated 1 件 → floor(1/2)=0、まだ +1 されない
        try await tracker.recordUnderstood(card: card)
        #expect(center.userUnderstanding == 1)
        #expect(neighbor.userUnderstanding == 0)

        // 2 回目: neighbor は propagated 2 件累積 → floor(2/2)=1、+1 される
        try await tracker.recordUnderstood(card: card)
        #expect(center.userUnderstanding == 2)
        #expect(neighbor.userUnderstanding == 1)
    }

    // MARK: - 4. recordNeedMore: 不変 + 履歴記録

    @Test func test_recordNeedMoreDoesNotChangeUnderstanding() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = makeConceptPage(name: "A", userUnderstanding: 2, in: context)
        try context.save()

        let tracker = DefaultUnderstandingTrackerService(context: context)
        let card = UnderstandingCard.fromConceptPage(page)
        try await tracker.recordNeedMore(card: card)

        #expect(page.userUnderstanding == 2)
        let count = try interactionsCount(for: page.id, action: .needMore, in: context)
        #expect(count == 1)
    }

    // MARK: - 5. recordDismissed: 不変 + 履歴記録

    @Test func test_recordDismissedDoesNotChangeUnderstandingButRecordsInteraction() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = makeConceptPage(name: "A", userUnderstanding: 3, in: context)
        try context.save()

        let tracker = DefaultUnderstandingTrackerService(context: context)
        let card = UnderstandingCard.fromConceptPage(page)
        try await tracker.recordDismissed(card: card)

        #expect(page.userUnderstanding == 3)
        let count = try interactionsCount(for: page.id, action: .dismissed, in: context)
        #expect(count == 1)
    }

    // MARK: - 6. SavedAnswer 経由の +1 (relatedConceptIDs 全て)

    @Test func test_recordUnderstoodFromSavedAnswerIncrementsAllRelatedConcepts() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pageA = makeConceptPage(name: "A", userUnderstanding: 0, in: context)
        let pageB = makeConceptPage(name: "B", userUnderstanding: 1, in: context)
        let answer = makeSavedAnswer(question: "Q?", relatedConceptIDs: [pageA.id, pageB.id], in: context)
        try context.save()

        let tracker = DefaultUnderstandingTrackerService(context: context)
        let card = UnderstandingCard.fromSavedAnswer(answer)
        try await tracker.recordUnderstood(card: card)

        #expect(pageA.userUnderstanding == 1)
        #expect(pageB.userUnderstanding == 2)
    }

    // MARK: - 7. graph 不存在 (relatedConceptIDs 空) で silent (本体のみ +1)

    @Test func test_recordUnderstoodSilentlyHandlesNoNeighbors() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = makeConceptPage(name: "Lonely", userUnderstanding: 2, relatedConceptIDs: [], in: context)
        try context.save()

        let tracker = DefaultUnderstandingTrackerService(context: context)
        let card = UnderstandingCard.fromConceptPage(page)
        try await tracker.recordUnderstood(card: card)
        // 本体だけ +1、エラーなし
        #expect(page.userUnderstanding == 3)
    }

    // MARK: - 8. 連打 6 回で max 5 停止 + 全 6 件履歴記録

    @Test func test_repeatedUnderstoodCapsAt5ButRecordsAllInteractions() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = makeConceptPage(name: "Spam", userUnderstanding: 0, in: context)
        try context.save()

        let tracker = DefaultUnderstandingTrackerService(context: context)
        let card = UnderstandingCard.fromConceptPage(page)
        for _ in 0 ..< 6 {
            try await tracker.recordUnderstood(card: card)
        }
        #expect(page.userUnderstanding == 5)
        let count = try interactionsCount(for: page.id, action: .understood, in: context)
        #expect(count == 6)
    }
}

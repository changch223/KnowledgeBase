//
//  ConflictDetectionServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 037 — ConflictDetectionService 7 ケース。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

@MainActor
struct ConflictDetectionServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    @discardableResult
    private func makeArticle(
        title: String,
        savedAt: Date,
        essence: String?,
        entityNames: [String],
        in context: ModelContext
    ) -> Article {
        let article = Article(url: "https://example.com/\(UUID().uuidString)", title: title, savedAt: savedAt)
        context.insert(article)
        let knowledge = ExtractedKnowledge(article: article, status: .succeeded)
        knowledge.essence = essence
        for (i, name) in entityNames.enumerated() {
            let entity = KnowledgeEntity(
                knowledge: knowledge,
                name: name,
                typeRaw: EntityTypeStored.organization.rawValue,
                salience: 5 - i,
                order: i
            )
            context.insert(entity)
            knowledge.entities.append(entity)
        }
        context.insert(knowledge)
        article.extractedKnowledge = knowledge
        return article
    }

    // MARK: - 1. 矛盾あり → ConflictProposal 作成

    @Test func testDetectCreatesProposalWhenConflict() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let oldArticle = makeArticle(
            title: "〇〇店オープン",
            savedAt: Date.now.addingTimeInterval(-86400 * 365),
            essence: "〇〇店が新規オープンしました",
            entityNames: ["〇〇店"],
            in: context
        )
        let newArticle = makeArticle(
            title: "〇〇店閉店",
            savedAt: Date.now,
            essence: "〇〇店が閉店しました",
            entityNames: ["〇〇店"],
            in: context
        )
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextConflictDetectionResult = .success(ConflictDetectionOutput(
            hasConflict: true,
            conflictDescription: "前回は開店、今回は閉店",
            newFact: "〇〇店が閉店",
            oldFact: "〇〇店がオープン"
        ))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ConflictDetectionService(
            context: context,
            session: mockSession,
            availability: availability
        )
        await service.detect(article: newArticle)

        let proposals = try context.fetch(FetchDescriptor<ConflictProposal>())
        #expect(proposals.count == 1)
        #expect(proposals.first?.entityName == "〇〇店")
        #expect(proposals.first?.status == ConflictStatus.pending.rawValue)
        _ = oldArticle
    }

    // MARK: - 2. 矛盾なし → ConflictProposal 作らない

    @Test func testDetectSkipsWhenNoConflict() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        makeArticle(title: "古", savedAt: Date.now.addingTimeInterval(-86400), essence: "old", entityNames: ["X"], in: context)
        let new = makeArticle(title: "新", savedAt: Date.now, essence: "new", entityNames: ["X"], in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextConflictDetectionResult = .success(ConflictDetectionOutput(
            hasConflict: false, conflictDescription: "", newFact: "", oldFact: ""
        ))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ConflictDetectionService(
            context: context, session: mockSession, availability: availability
        )
        await service.detect(article: new)

        let proposals = try context.fetch(FetchDescriptor<ConflictProposal>())
        #expect(proposals.isEmpty)
    }

    // MARK: - 3. 同 entity 持つ過去記事なし → ConflictProposal 作らない

    @Test func testDetectSkipsWhenNoMatchingEntity() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        makeArticle(title: "他", savedAt: Date.now.addingTimeInterval(-86400), essence: "old", entityNames: ["別の entity"], in: context)
        let new = makeArticle(title: "新", savedAt: Date.now, essence: "new", entityNames: ["X"], in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ConflictDetectionService(
            context: context, session: mockSession, availability: availability
        )
        await service.detect(article: new)

        let proposals = try context.fetch(FetchDescriptor<ConflictProposal>())
        #expect(proposals.isEmpty)
        #expect(mockSession.conflictDetectionCallCount == 0)
    }

    // MARK: - 4. AI 不可端末 → 検出スキップ

    @Test func testDetectSkipsWhenLMUnavailable() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        makeArticle(title: "古", savedAt: Date.now.addingTimeInterval(-86400), essence: "old", entityNames: ["X"], in: context)
        let new = makeArticle(title: "新", savedAt: Date.now, essence: "new", entityNames: ["X"], in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = false

        let service = ConflictDetectionService(
            context: context, session: mockSession, availability: availability
        )
        await service.detect(article: new)

        let proposals = try context.fetch(FetchDescriptor<ConflictProposal>())
        #expect(proposals.isEmpty)
        #expect(mockSession.conflictDetectionCallCount == 0)
    }

    // MARK: - 5. 同ペアの pending 提案あり → 重複作成しない

    @Test func testDetectSkipsExistingPendingProposal() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let old = makeArticle(title: "古", savedAt: Date.now.addingTimeInterval(-86400), essence: "old", entityNames: ["X"], in: context)
        let new = makeArticle(title: "新", savedAt: Date.now, essence: "new", entityNames: ["X"], in: context)

        // 既存の ConflictProposal (pending)
        let existing = ConflictProposal(
            newArticle: new, oldArticle: old, entityName: "X",
            conflictDescription: "old proposal", newFact: "f1", oldFact: "f2"
        )
        context.insert(existing)
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextConflictDetectionResult = .success(ConflictDetectionOutput(
            hasConflict: true, conflictDescription: "新", newFact: "n", oldFact: "o"
        ))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ConflictDetectionService(
            context: context, session: mockSession, availability: availability
        )
        await service.detect(article: new)

        let proposals = try context.fetch(FetchDescriptor<ConflictProposal>())
        #expect(proposals.count == 1) // 既存のみ
        #expect(mockSession.conflictDetectionCallCount == 0)
    }

    // MARK: - 6. AI 失敗 → silent (エラー throw しない)

    @Test func testDetectIgnoresLMError() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        makeArticle(title: "古", savedAt: Date.now.addingTimeInterval(-86400), essence: "old", entityNames: ["X"], in: context)
        let new = makeArticle(title: "新", savedAt: Date.now, essence: "new", entityNames: ["X"], in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextConflictDetectionResult = .failure(MockLanguageModelError.safetyFiltered)
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ConflictDetectionService(
            context: context, session: mockSession, availability: availability
        )
        await service.detect(article: new)

        let proposals = try context.fetch(FetchDescriptor<ConflictProposal>())
        #expect(proposals.isEmpty)
    }

    // MARK: - 7. entity 名 case insensitive マッチ

    @Test func testDetectMatchesEntityCaseInsensitive() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        makeArticle(title: "古", savedAt: Date.now.addingTimeInterval(-86400), essence: "old", entityNames: ["Apple"], in: context)
        let new = makeArticle(title: "新", savedAt: Date.now, essence: "new", entityNames: ["apple"], in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextConflictDetectionResult = .success(ConflictDetectionOutput(
            hasConflict: true, conflictDescription: "矛盾", newFact: "n", oldFact: "o"
        ))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ConflictDetectionService(
            context: context, session: mockSession, availability: availability
        )
        await service.detect(article: new)

        let proposals = try context.fetch(FetchDescriptor<ConflictProposal>())
        #expect(proposals.count == 1)
    }
}

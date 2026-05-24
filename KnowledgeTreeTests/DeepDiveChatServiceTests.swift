//
//  DeepDiveChatServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 044 brushup — DeepDiveChatService の 7 ケース。
//  Foundation Models 不要 (MockLanguageModelSession 経由)。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

@MainActor
struct DeepDiveChatServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    private struct FixedAvailability: AvailabilityChecker {
        let isAvailable: Bool
    }

    private final class CountingTracker: UnderstandingTrackerServiceProtocol {
        var openedCount: Int = 0
        var understoodCount: Int = 0
        var needMoreCount: Int = 0
        var dismissedCount: Int = 0

        func recordUnderstood(card: UnderstandingCard) async throws { understoodCount += 1 }
        func recordNeedMore(card: UnderstandingCard) async throws { needMoreCount += 1 }
        func recordDismissed(card: UnderstandingCard) async throws { dismissedCount += 1 }
        func recordOpenedChat(card: UnderstandingCard) async throws { openedCount += 1 }
    }

    // MARK: - 1. startTutorSession: ChatSession + 初回 AI 発話 + openedChat 履歴

    @Test func test_startTutorSessionCreatesSessionAndAssistantMessage() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = ConceptPage(name: "Apple Vision Pro", categoryRaw: "テクノロジー", summary: "AR/VR ヘッドセット", isStale: false)
        context.insert(page)
        try context.save()

        let mockLM = MockLanguageModelSession()
        mockLM.nextTutorReplyResult = .success("Apple Vision Pro について、何が一番気になりますか?")
        let tracker = CountingTracker()
        let service = DefaultDeepDiveChatService(
            context: context,
            session: mockLM,
            availability: FixedAvailability(isAvailable: true),
            tracker: tracker
        )

        let card = UnderstandingCard.fromConceptPage(page)
        let session = try await service.startTutorSession(for: card)

        #expect(session.title.contains("Apple Vision Pro"))
        #expect(session.messages.count == 1)
        #expect(session.messages[0].role == ChatMessageRole.assistant.rawValue)
        #expect(session.messages[0].text.contains("気になりますか"))
        #expect(tracker.openedCount == 1)
        #expect(mockLM.tutorReplyCallCount == 1)
    }

    // MARK: - 2. tutor prompt に concept name が含まれる (system prompt 露出回避の検証)

    @Test func test_tutorPromptContainsConceptNameButNotInUserMessage() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = ConceptPage(name: "Foundation Models", categoryRaw: "テクノロジー", isStale: false)
        context.insert(page)
        try context.save()

        let mockLM = MockLanguageModelSession()
        mockLM.nextTutorReplyResult = .success("どのような点を知りたいですか?")
        let service = DefaultDeepDiveChatService(
            context: context,
            session: mockLM,
            availability: FixedAvailability(isAvailable: true)
        )

        let card = UnderstandingCard.fromConceptPage(page)
        let session = try await service.startTutorSession(for: card)

        // prompt 側に concept name が含まれている
        let prompt = mockLM.lastTutorReplyPrompt ?? ""
        #expect(prompt.contains("Foundation Models"))
        #expect(prompt.contains("家庭教師"))

        // session には user_message が無い (初回は AI 発話のみ、これが「system prompt 露出」bug の根本修正)
        let userMessages = session.messages.filter { $0.role == ChatMessageRole.user.rawValue }
        #expect(userMessages.isEmpty)
    }

    // MARK: - 3. sendUserMessage: user + assistant の 2 件追加

    @Test func test_sendUserMessageAppendsUserAndAssistantMessages() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = ConceptPage(name: "GPT", categoryRaw: "テクノロジー", isStale: false)
        context.insert(page)
        try context.save()

        let mockLM = MockLanguageModelSession()
        mockLM.nextTutorReplyResult = .success("最初の質問のお返事ですね")
        let service = DefaultDeepDiveChatService(
            context: context,
            session: mockLM,
            availability: FixedAvailability(isAvailable: true)
        )

        let card = UnderstandingCard.fromConceptPage(page)
        let session = try await service.startTutorSession(for: card)
        let beforeCount = session.messages.count

        mockLM.nextTutorReplyResult = .success("いい質問ですね。GPT は大規模言語モデルで、…")
        _ = try await service.sendUserMessage("GPT とは何ですか?", in: session, card: card)

        // user + assistant の 2 件追加
        #expect(session.messages.count == beforeCount + 2)
        let lastUser = session.messages.first { $0.role == ChatMessageRole.user.rawValue }
        #expect(lastUser?.text == "GPT とは何ですか?")
        let assistantTexts = session.messages.filter { $0.role == ChatMessageRole.assistant.rawValue }.map(\.text)
        #expect(assistantTexts.contains("いい質問ですね。GPT は大規模言語モデルで、…"))
    }

    // MARK: - 4. Apple Intelligence 不可で fallback (concept summary を返す)

    @Test func test_unavailableLMReturnsFallbackMessage() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = ConceptPage(name: "X", categoryRaw: "テクノロジー", summary: "これは X の保存サマリです。", isStale: false)
        context.insert(page)
        try context.save()

        let mockLM = MockLanguageModelSession()
        let service = DefaultDeepDiveChatService(
            context: context,
            session: mockLM,
            availability: FixedAvailability(isAvailable: false)
        )

        let card = UnderstandingCard.fromConceptPage(page)
        let session = try await service.startTutorSession(for: card)

        // fallback で初回 AI 発話が永続化される (LM 呼ばれない)
        #expect(mockLM.tutorReplyCallCount == 0)
        #expect(session.messages.count == 1)
        #expect(session.messages[0].text.contains("X"))
    }

    // MARK: - 5. LM が throws しても fallback で session 作成成功

    @Test func test_lmThrowsFallsBackGracefully() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = ConceptPage(name: "Y", categoryRaw: "テクノロジー", isStale: false)
        context.insert(page)
        try context.save()

        let mockLM = MockLanguageModelSession()
        mockLM.nextTutorReplyResult = .failure(NSError(domain: "test", code: 1))
        let service = DefaultDeepDiveChatService(
            context: context,
            session: mockLM,
            availability: FixedAvailability(isAvailable: true)
        )

        let card = UnderstandingCard.fromConceptPage(page)
        let session = try await service.startTutorSession(for: card)

        // throws しない (内部で catch + fallback)、session は返却され message 1 件あり
        #expect(session.messages.count == 1)
        #expect(!session.messages[0].text.isEmpty)
    }

    // MARK: - 6. SavedAnswer 経路: prompt に question + answer 抜粋

    @Test func test_savedAnswerCardPromptIncludesQuestionAndAnswer() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let answer = SavedAnswer(
            question: "Foundation Models の長所と短所は?",
            answer: "Foundation Models は on-device で動作しプライバシーが守られる一方、精度は限定的です。"
        )
        context.insert(answer)
        try context.save()

        let mockLM = MockLanguageModelSession()
        mockLM.nextTutorReplyResult = .success("どの部分から深めますか?")
        let service = DefaultDeepDiveChatService(
            context: context,
            session: mockLM,
            availability: FixedAvailability(isAvailable: true)
        )

        let card = UnderstandingCard.fromSavedAnswer(answer)
        _ = try await service.startTutorSession(for: card)

        let prompt = mockLM.lastTutorReplyPrompt ?? ""
        #expect(prompt.contains("Foundation Models の長所と短所"))
        #expect(prompt.contains("on-device"))
        #expect(prompt.contains("家庭教師"))
    }

    // MARK: - 7. 空 user input は throws

    @Test func test_emptyUserInputThrows() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = ConceptPage(name: "X", categoryRaw: "テクノロジー", isStale: false)
        context.insert(page)
        try context.save()

        let mockLM = MockLanguageModelSession()
        mockLM.nextTutorReplyResult = .success("初回")
        let service = DefaultDeepDiveChatService(
            context: context,
            session: mockLM,
            availability: FixedAvailability(isAvailable: true)
        )

        let card = UnderstandingCard.fromConceptPage(page)
        let session = try await service.startTutorSession(for: card)

        await #expect(throws: DeepDiveChatError.self) {
            _ = try await service.sendUserMessage("   ", in: session, card: card)
        }
    }
}

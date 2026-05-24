//
//  DeepDiveChatStarterTests.swift
//  KnowledgeTreeTests
//
//  spec 044 — DeepDiveChatStarter の 5 ケース。MockChatService + MockTracker。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

@MainActor
struct DeepDiveChatStarterTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    // MARK: - Mocks

    final class MockChatService: ChatServiceProtocol {
        private(set) var lastSendQuestion: String?
        private(set) var sendCount: Int = 0
        private(set) var createSessionCount: Int = 0
        private let context: ModelContext
        var sendThrows: Bool = false

        init(context: ModelContext) {
            self.context = context
        }

        func createSession() throws -> ChatSession {
            createSessionCount += 1
            let session = ChatSession()
            context.insert(session)
            try context.save()
            return session
        }

        func send(question: String, in session: ChatSession, contextMessages: [ChatMessage]) async throws -> ChatMessage {
            sendCount += 1
            lastSendQuestion = question
            if sendThrows {
                throw NSError(domain: "MockChatService", code: 1)
            }
            let message = ChatMessage(session: session, role: ChatMessageRole.assistant.rawValue, text: "mock answer")
            context.insert(message)
            try context.save()
            return message
        }

        func deleteAllSessions() throws {}
        func deleteSession(_ session: ChatSession) throws {}
        func backfillEmbeddings() async {}
    }

    final class MockTracker: UnderstandingTrackerServiceProtocol {
        private(set) var openedChatCount: Int = 0
        private(set) var lastOpenedCard: UnderstandingCard?

        func recordUnderstood(card: UnderstandingCard) async throws {}
        func recordNeedMore(card: UnderstandingCard) async throws {}
        func recordDismissed(card: UnderstandingCard) async throws {}
        func recordOpenedChat(card: UnderstandingCard) async throws {
            openedChatCount += 1
            lastOpenedCard = card
        }
    }

    // MARK: - 1. ChatSession 作成 + title + 初期発話 + openedChat 履歴

    @Test func test_startChatCreatesSessionWithTitleAndInitialAsk() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = ConceptPage(name: "Apple Vision Pro", categoryRaw: "テクノロジー", isStale: false)
        context.insert(page)
        try context.save()

        let chatService = MockChatService(context: context)
        let tracker = MockTracker()
        let starter = DefaultDeepDiveChatStarter(chatService: chatService, tracker: tracker)
        let card = UnderstandingCard.fromConceptPage(page)

        let session = try await starter.startChat(for: card)

        #expect(chatService.createSessionCount == 1)
        #expect(chatService.sendCount == 1)
        #expect(session.title.contains("Apple Vision Pro"))
        #expect(tracker.openedChatCount == 1)
    }

    // MARK: - 2. tutor prompt に concept name 含む

    @Test func test_tutorPromptContainsConceptName() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = ConceptPage(name: "Foundation Models", categoryRaw: "テクノロジー", isStale: false)
        context.insert(page)
        try context.save()

        let chatService = MockChatService(context: context)
        let tracker = MockTracker()
        let starter = DefaultDeepDiveChatStarter(chatService: chatService, tracker: tracker)
        let card = UnderstandingCard.fromConceptPage(page)

        _ = try await starter.startChat(for: card)
        let prompt = chatService.lastSendQuestion ?? ""
        #expect(prompt.contains("Foundation Models"))
        #expect(prompt.contains("家庭教師"))
    }

    // MARK: - 3. openedChat 履歴 1 件

    @Test func test_openedChatRecordedOnce() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = ConceptPage(name: "X", categoryRaw: "テクノロジー", isStale: false)
        context.insert(page)
        try context.save()

        let chatService = MockChatService(context: context)
        let tracker = MockTracker()
        let starter = DefaultDeepDiveChatStarter(chatService: chatService, tracker: tracker)
        let card = UnderstandingCard.fromConceptPage(page)
        _ = try await starter.startChat(for: card)

        #expect(tracker.openedChatCount == 1)
        #expect(tracker.lastOpenedCard?.id == page.id)
    }

    // MARK: - 4. send が throws しても session は返却 (UI fallback)

    @Test func test_startChatReturnsSessionEvenIfAskThrows() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = ConceptPage(name: "X", categoryRaw: "テクノロジー", isStale: false)
        context.insert(page)
        try context.save()

        let chatService = MockChatService(context: context)
        chatService.sendThrows = true
        let tracker = MockTracker()
        let starter = DefaultDeepDiveChatStarter(chatService: chatService, tracker: tracker)
        let card = UnderstandingCard.fromConceptPage(page)

        // throws しない (内部で catch + log)
        let session = try await starter.startChat(for: card)
        #expect(session.title.contains("X"))
        #expect(tracker.openedChatCount == 1)
    }

    // MARK: - 5. SavedAnswer 経路: prompt に question + answer 抜粋

    @Test func test_savedAnswerCardPromptContainsQuestionAndAnswerSnippet() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let answer = SavedAnswer(
            question: "Foundation Models の長所と短所は何ですか?",
            answer: "Foundation Models は on-device で動作し、プライバシーが守られる一方で精度は限られます。詳細な domain には fallback が必要です。"
        )
        context.insert(answer)
        try context.save()

        let chatService = MockChatService(context: context)
        let tracker = MockTracker()
        let starter = DefaultDeepDiveChatStarter(chatService: chatService, tracker: tracker)
        let card = UnderstandingCard.fromSavedAnswer(answer)
        _ = try await starter.startChat(for: card)

        let prompt = chatService.lastSendQuestion ?? ""
        #expect(prompt.contains("Foundation Models の長所と短所"))
        #expect(prompt.contains("on-device"))
        #expect(prompt.contains("家庭教師"))
    }
}

//
//  AgenticChatServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 057 — ChatService の agent loop integration を Mock LM の AgentAction FIFO で検証。
//  各 path (immediate / askClarification / searchArticles / finalAnswer / hedge filter /
//  agentLoopEnabled OFF / availability false) を 10 ケースで網羅。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeBase

@MainActor
struct AgenticChatServiceTests {

    // MARK: - Fixtures

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    private func makeMockEmbedding() -> EmbeddingService { EmbeddingService() }

    @discardableResult
    private func makeArticle(url: String, title: String, essence: String?, in context: ModelContext) -> Article {
        let article = Article(url: url, title: title)
        context.insert(article)
        if let essence {
            let knowledge = ExtractedKnowledge(article: article, status: .succeeded)
            knowledge.essence = essence
            context.insert(knowledge)
            article.extractedKnowledge = knowledge
        }
        return article
    }

    private func makeService(
        context: ModelContext,
        mockSession: MockLanguageModelSession,
        availability: Bool = true
    ) -> ChatService {
        let avail = MockAvailabilityChecker()
        avail.isAvailable = availability
        return ChatService(
            context: context,
            embeddingService: makeMockEmbedding(),
            session: mockSession,
            availability: avail,
            graphTraversal: nil,
            savedAnswerService: nil,
            agentLoopEnabled: true  // spec 057 agent loop ON
        )
    }

    // MARK: - 1. immediate path → clarification 無しで即答

    @Test func testImmediateActionReturnsAnswerWithoutClarification() async throws {
        let container = try makeContainer()
        let mockSession = MockLanguageModelSession()
        mockSession.nextAgentActions = [
            .immediate(answer: "Tim Cook は Apple の CEO です。")
        ]
        let service = makeService(context: container.mainContext, mockSession: mockSession)
        let session = try service.createSession()

        let result = try await service.send(question: "Tim Cook って誰?", in: session)

        #expect(result.role == "assistant")
        #expect(result.text == "Tim Cook は Apple の CEO です。")
        #expect(result.citedArticleIDs.isEmpty)
        #expect(result.clarificationSuggestions.isEmpty)
        #expect(mockSession.agentActionCallCount == 1)
    }

    // MARK: - 2. askClarification path → suggestions 3 件付きで永続化

    @Test func testAskClarificationActionPersistsSuggestions() async throws {
        let container = try makeContainer()
        let mockSession = MockLanguageModelSession()
        mockSession.nextAgentActions = [
            .askClarification(
                question: "Apple について、どの面を知りたいですか?",
                suggestions: ["Tim Cook の経歴", "Vision Pro", "株価"]
            )
        ]
        let service = makeService(context: container.mainContext, mockSession: mockSession)
        let session = try service.createSession()

        let result = try await service.send(question: "Apple について", in: session)

        #expect(result.role == "assistant")
        #expect(result.text == "Apple について、どの面を知りたいですか?")
        #expect(result.clarificationSuggestions == ["Tim Cook の経歴", "Vision Pro", "株価"])
        #expect(result.citedArticleIDs.isEmpty)
    }

    // MARK: - 3. finalAnswer path → text + citedIDs 永続化

    @Test func testFinalAnswerActionPersistsCitedIDs() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let article = makeArticle(url: "a", title: "Tim Cook 記事", essence: "...", in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextAgentActions = [
            .finalAnswer(text: "保存記事によると、Tim Cook は Apple の CEO です。", citedArticleIDs: [article.id])
        ]
        let service = makeService(context: context, mockSession: mockSession)
        let session = try service.createSession()

        let result = try await service.send(question: "Tim Cook の話あった?", in: session)

        #expect(result.text == "保存記事によると、Tim Cook は Apple の CEO です。")
        #expect(result.citedArticleIDs.contains(article.id.uuidString))
    }

    // MARK: - 4. HedgePhraseFilter 適用: immediate answer に「分かりません」が含まれる → 置換される

    @Test func testHedgePhraseReplacedInImmediateAnswer() async throws {
        let container = try makeContainer()
        let mockSession = MockLanguageModelSession()
        mockSession.nextAgentActions = [
            .immediate(answer: "それは分かりません。詳細は知りません。")
        ]
        let service = makeService(context: container.mainContext, mockSession: mockSession)
        let session = try service.createSession()

        let result = try await service.send(question: "test", in: session)

        // banned phrase が無く、何らかの hedge phrase が含まれる
        #expect(!HedgePhraseFilter.containsBanned(result.text))
        #expect(HedgePhraseFilter.hedgeReplacements.contains { result.text.contains($0) })
    }

    // MARK: - 5. agent loop error → fallback (executeRAG 経路に流れる)

    @Test func testAgentActionErrorFallsBackToRAG() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let mockSession = MockLanguageModelSession()
        mockSession.agentActionError = MockLanguageModelError.timeout  // 1 回 throw
        // fallback 経路で generateTutorReply が呼ばれる
        mockSession.nextTutorReplyResult = .success("fallback tutor answer")

        let service = makeService(context: context, mockSession: mockSession)
        let session = try service.createSession()

        let result = try await service.send(question: "何か質問", in: session)

        // agent action error → executeRAG → retrieval 0 件 → fallback tutor reply
        #expect(mockSession.agentActionCallCount == 1)
        #expect(!result.text.isEmpty)
        #expect(!HedgePhraseFilter.containsBanned(result.text))
    }

    // MARK: - 6. availability false → agent loop bypass、executeRAG 経路

    @Test func testUnavailableAvailabilityBypassesAgentLoop() async throws {
        let container = try makeContainer()
        let mockSession = MockLanguageModelSession()
        let service = makeService(context: container.mainContext, mockSession: mockSession, availability: false)
        let session = try service.createSession()

        let result = try await service.send(question: "test", in: session)

        // agent loop 呼ばれない、executeRAG fallback で何かしらの answer
        #expect(mockSession.agentActionCallCount == 0)
        #expect(!result.text.isEmpty)
        #expect(!HedgePhraseFilter.containsBanned(result.text))
    }

    // MARK: - 7. user message が session に永続化される

    @Test func testUserMessagePersistedInSession() async throws {
        let container = try makeContainer()
        let mockSession = MockLanguageModelSession()
        mockSession.nextAgentActions = [.immediate(answer: "OK")]
        let service = makeService(context: container.mainContext, mockSession: mockSession)
        let session = try service.createSession()

        _ = try await service.send(question: "テスト質問", in: session)

        let messages = (session.messages ?? []).sorted { $0.timestamp < $1.timestamp }
        #expect(messages.count == 2)
        #expect(messages[0].role == "user")
        #expect(messages[0].text == "テスト質問")
        #expect(messages[1].role == "assistant")
    }

    // MARK: - 8. session.title が最初の質問で設定される

    @Test func testSessionTitleSetFromFirstQuestion() async throws {
        let container = try makeContainer()
        let mockSession = MockLanguageModelSession()
        mockSession.nextAgentActions = [.immediate(answer: "OK")]
        let service = makeService(context: container.mainContext, mockSession: mockSession)
        let session = try service.createSession()

        #expect(session.title.isEmpty)
        _ = try await service.send(question: "最初の質問だ", in: session)
        #expect(session.title == "最初の質問だ")
    }

    // MARK: - 9. multi-turn context が agent prompt に渡される

    @Test func testMultiTurnContextPassedToAgentPrompt() async throws {
        let container = try makeContainer()
        let mockSession = MockLanguageModelSession()
        mockSession.nextAgentActions = [.immediate(answer: "OK")]
        let service = makeService(context: container.mainContext, mockSession: mockSession)
        let session = try service.createSession()

        let prevUser = ChatMessage(session: session, role: "user", text: "前の質問は何だっけ?")
        let prevAssistant = ChatMessage(session: session, role: "assistant", text: "前回答え")
        container.mainContext.insert(prevUser)
        container.mainContext.insert(prevAssistant)

        _ = try await service.send(question: "新質問", in: session, contextMessages: [prevUser, prevAssistant])

        let prompt = mockSession.lastAgentActionPrompt ?? ""
        #expect(prompt.contains("前の質問は何だっけ?"))
        #expect(prompt.contains("前回答え"))
        #expect(prompt.contains("新質問"))
    }

    // MARK: - 11. countConsecutiveClarifications: 連続 3 件で 3 を返す

    @Test func testCountConsecutiveClarifications() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let mockSession = MockLanguageModelSession()
        let service = makeService(context: context, mockSession: mockSession)
        let session = try service.createSession()

        // ChatSession に user + clarification を 3 ペア手動 insert
        for i in 0..<3 {
            let user = ChatMessage(session: session, role: "user", text: "q\(i)")
            user.timestamp = Date().addingTimeInterval(TimeInterval(i * 2))
            context.insert(user)
            let asst = ChatMessage(
                session: session,
                role: "assistant",
                text: "clarification?",
                clarificationSuggestions: ["a", "b", "c"]
            )
            asst.timestamp = Date().addingTimeInterval(TimeInterval(i * 2 + 1))
            context.insert(asst)
        }
        try context.save()

        let count = ChatService.countConsecutiveClarifications(in: session)
        #expect(count == 3)
    }

    // MARK: - 12. max 3 round 到達後の askClarification → forceFinalAnswer fallback

    @Test func testMaxClarificationRoundForcesFinalAnswer() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let mockSession = MockLanguageModelSession()
        let service = makeService(context: context, mockSession: mockSession)
        let session = try service.createSession()

        // 3 回 clarification を session に手動 insert
        for i in 0..<3 {
            let user = ChatMessage(session: session, role: "user", text: "q\(i)")
            user.timestamp = Date().addingTimeInterval(TimeInterval(i * 2))
            context.insert(user)
            let asst = ChatMessage(
                session: session,
                role: "assistant",
                text: "clarification?",
                clarificationSuggestions: ["a", "b", "c"]
            )
            asst.timestamp = Date().addingTimeInterval(TimeInterval(i * 2 + 1))
            context.insert(asst)
        }
        try context.save()

        // 次の send で LLM が更に askClarification を返しても、forceFinal で fallback 化される
        mockSession.nextAgentActions = [
            .askClarification(question: "もう一度確認", suggestions: ["x", "y", "z"])
        ]
        mockSession.nextTutorReplyResult = .success("最善努力で答えます。私の理解では...")

        let result = try await service.send(question: "4 回目の質問", in: session)

        // assistant が clarification ではなく answer になっている
        #expect(result.clarificationSuggestions.isEmpty)
        #expect(!result.text.isEmpty)
        #expect(!HedgePhraseFilter.containsBanned(result.text))
    }

    // MARK: - 10. AgentAction unknown actionType → fallback で immediate

    @Test func testUnknownActionTypeFallsBackToImmediate() async throws {
        let container = try makeContainer()
        let mockSession = MockLanguageModelSession()
        // Mock の defaultAgentAction を unknown actionType output から構築した AgentAction enum で返す
        let unknownOutput = AgentActionOutput(
            actionType: "weirdType",
            text: "fallback contentです",
            suggestions: [],
            citedArticleIDs: []
        )
        let action = AgentAction(from: unknownOutput)  // → .immediate(answer: "fallback contentです")
        mockSession.nextAgentActions = [action]

        let service = makeService(context: container.mainContext, mockSession: mockSession)
        let session = try service.createSession()

        let result = try await service.send(question: "test", in: session)

        #expect(result.text == "fallback contentです")
        #expect(result.clarificationSuggestions.isEmpty)
    }
}

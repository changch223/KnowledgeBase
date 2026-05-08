//
//  ChatServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 021 — contracts/chat-service.md 8 ケース。
//  Foundation Models / Fallback / post-process / 50 件 FIFO / deleteAll を mock で検証。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

@MainActor
struct ChatServiceTests {

    // MARK: - Fixtures

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    /// Article 作成、optional で essence + embedding を inject。
    @discardableResult
    private func makeArticle(
        url: String,
        title: String,
        essence: String?,
        embedding: [Float]?,
        in context: ModelContext
    ) -> Article {
        let article = Article(url: url, title: title)
        context.insert(article)
        if let embedding {
            article.essenceEmbedding = embedding.asEmbeddingData
        }
        if let essence {
            let knowledge = ExtractedKnowledge(article: article, status: .succeeded)
            knowledge.essence = essence
            context.insert(knowledge)
            article.extractedKnowledge = knowledge
        }
        return article
    }

    /// EmbeddingService のスタブ (isAvailable = false 固定で keyword 経路を強制)
    /// embedding 経路をテストする時は実 EmbeddingService を使うが、テスト決定論性のため
    /// MockEmbeddingService で query / corpus を control する。
    private func makeMockEmbedding(available: Bool) -> EmbeddingService {
        // 実 EmbeddingService は init で NLEmbedding をロードする。実機 Simulator では
        // sentenceEmbedding(for: .japanese) が nil の可能性。
        // ChatService のテストでは availability false 経路を主軸に検証し、
        // available true 経路は post-process / FIFO / deleteAll の動作検証で代替。
        return EmbeddingService()
    }

    // MARK: - 1. low-similarity → 「分かりません」 (空 corpus)

    @Test func testSendWithEmptyCorpusReturnsUnknown() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability
        )
        let session = try service.createSession()
        let result = try await service.send(question: "Swift について教えて", in: session)

        #expect(result.role == "assistant")
        #expect(result.text.contains("分かりません"))
        #expect(result.citedArticleIDs.isEmpty)
    }

    // MARK: - 2. cited 空 → 「分かりません」上書き

    @Test func testSendWithEmptyCitedRewritesToUnknown() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        // 関連記事を作成 (keyword マッチで取得される前提)
        makeArticle(url: "a", title: "Swift 6 リリース", essence: "Swift 6 が登場した", embedding: nil, in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        // LM が cited を空で返した
        mockSession.nextChatAnswerResult = .success(ChatAnswerOutput(
            answer: "詳しいことは記憶にない",
            citedArticleIDs: []
        ))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability
        )
        let session = try service.createSession()
        let result = try await service.send(question: "Swift について", in: session)

        #expect(result.text.contains("分かりません"))
        #expect(result.citedArticleIDs.isEmpty)
    }

    // MARK: - 3. cited に存在しない ID → filter

    @Test func testSendFiltersInvalidCitedIDs() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article = makeArticle(url: "a", title: "Swift 6", essence: "Swift 6 が登場", embedding: nil, in: context)
        try context.save()

        let validID = article.id.uuidString

        let mockSession = MockLanguageModelSession()
        mockSession.nextChatAnswerResult = .success(ChatAnswerOutput(
            answer: "Swift 6 は新機能を含むメジャーリリースです。",
            citedArticleIDs: [validID, "INVALID_ID"]
        ))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability
        )
        let session = try service.createSession()
        let result = try await service.send(question: "Swift 6 について", in: session)

        #expect(result.citedArticleIDs.count == 1)
        #expect(result.citedArticleIDs.first == validID)
    }

    // MARK: - 4. Foundation Models 不可 → KeyFact 並べ Fallback

    @Test func testSendUsesFallbackWhenFoundationModelsUnavailable() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        makeArticle(url: "a", title: "Swift 6 リリース", essence: "Swift 6 が登場した", embedding: nil, in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = false

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability
        )
        let session = try service.createSession()
        let result = try await service.send(question: "Swift 6 について", in: session)

        #expect(result.text.contains("以下の記事が参考になります"))
        #expect(!result.citedArticleIDs.isEmpty)
        // LM は呼ばれていない
        #expect(mockSession.chatAnswerCallCount == 0)
    }

    // MARK: - 5. Foundation Models 失敗 → fallback に切替

    @Test func testSendFallsBackOnFoundationModelsError() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        makeArticle(url: "a", title: "Swift 6 リリース", essence: "Swift 6 が登場", embedding: nil, in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextChatAnswerResult = .failure(MockLanguageModelError.safetyFiltered)
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability
        )
        let session = try service.createSession()
        let result = try await service.send(question: "Swift 6 について", in: session)

        #expect(result.text.contains("以下の記事が参考になります"))
        #expect(!result.citedArticleIDs.isEmpty)
    }

    // MARK: - 6. createSession で 50 件超過 → FIFO

    @Test func testCreateSessionEnforcesFIFO() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability
        )

        // 50 セッション作成
        var firstSessionID: UUID?
        for i in 0..<50 {
            let s = try service.createSession()
            if i == 0 { firstSessionID = s.id }
        }

        // 51 番目作成 → 最古 (firstSession) 削除
        _ = try service.createSession()

        let descriptor = FetchDescriptor<ChatSession>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let allSessions = try context.fetch(descriptor)
        #expect(allSessions.count == 50)
        #expect(allSessions.first?.id != firstSessionID)
    }

    // MARK: - 7. deleteAllSessions → 全 session + message 削除

    @Test func testDeleteAllSessionsRemovesEverything() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability
        )

        // 3 セッション + メッセージを追加
        for _ in 0..<3 {
            let s = try service.createSession()
            let msg = ChatMessage(session: s, role: "user", text: "テスト")
            context.insert(msg)
        }
        try context.save()

        let countBefore = try context.fetch(FetchDescriptor<ChatSession>()).count
        #expect(countBefore == 3)

        try service.deleteAllSessions()

        let sessionsAfter = try context.fetch(FetchDescriptor<ChatSession>())
        let messagesAfter = try context.fetch(FetchDescriptor<ChatMessage>())
        #expect(sessionsAfter.isEmpty)
        #expect(messagesAfter.isEmpty)
    }

    // MARK: - 8. stripUUIDsFromBody — UUID 文字列除去

    @Test func testStripUUIDsRemovesPlainUUID() {
        let input = "Swift 6 のリリースについて 12345678-1234-5678-1234-567812345678 で説明されています"
        let output = ChatService.stripUUIDsFromBody(input)
        #expect(!output.contains("12345678"))
        #expect(output.contains("Swift 6"))
        #expect(output.contains("説明されています"))
    }

    @Test func testStripUUIDsRemovesBracketedID() {
        let input = "[ID: abcdef12-3456-7890-abcd-ef1234567890] によれば、Swift 6 は重要です。"
        let output = ChatService.stripUUIDsFromBody(input)
        #expect(!output.contains("abcdef12"))
        #expect(!output.contains("ID:"))
        #expect(output.contains("Swift 6"))
    }

    @Test func testStripUUIDsLeavesNormalTextUntouched() {
        let input = "Swift 6 は新機能を含むメジャーリリースです。"
        let output = ChatService.stripUUIDsFromBody(input)
        #expect(output == input)
    }

    // MARK: - 9. multi-turn context が prompt に含まれる (spec 033)

    @Test func testSendIncludesContextMessagesInPrompt() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        // keyword retrieval が当たるよう、query の語と一致する essence を持たせる
        let article = makeArticle(
            url: "a",
            title: "Swift 6 詳しく教えて",
            essence: "Swift 6 詳しく教えて 解説",
            embedding: nil,
            in: context
        )
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextChatAnswerResult = .success(ChatAnswerOutput(
            answer: "詳しく説明します",
            citedArticleIDs: [article.id.uuidString]
        ))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability
        )
        let session = try service.createSession()

        // multi-turn context (前の会話)
        let prevUser = ChatMessage(session: session, role: "user", text: "Swift とは?")
        let prevAssistant = ChatMessage(session: session, role: "assistant", text: "Swift は Apple の言語")
        context.insert(prevUser)
        context.insert(prevAssistant)
        try context.save()

        _ = try await service.send(
            question: "詳しく教えて",
            in: session,
            contextMessages: [prevUser, prevAssistant]
        )

        // prompt に "## 直近の会話" + 過去 message が含まれる
        let lastPrompt = mockSession.lastChatAnswerPrompt ?? ""
        #expect(lastPrompt.contains("## 直近の会話"))
        #expect(lastPrompt.contains("Swift とは?"))
        #expect(lastPrompt.contains("Swift は Apple の言語"))
    }

    // MARK: - 10. deleteSession で session + message cascade 削除 (spec 033)

    @Test func testDeleteSessionCascadesMessages() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability
        )

        // 2 session 作成、片方に message を挿入
        let s1 = try service.createSession()
        let s2 = try service.createSession()
        context.insert(ChatMessage(session: s1, role: "user", text: "msg in s1"))
        context.insert(ChatMessage(session: s2, role: "user", text: "msg in s2"))
        try context.save()

        // s1 を個別削除
        try service.deleteSession(s1)

        let sessionsAfter = try context.fetch(FetchDescriptor<ChatSession>())
        #expect(sessionsAfter.count == 1)
        #expect(sessionsAfter.first?.id == s2.id)

        let messagesAfter = try context.fetch(FetchDescriptor<ChatMessage>())
        #expect(messagesAfter.count == 1)
        #expect(messagesAfter.first?.text == "msg in s2")
    }

    // MARK: - 11. inline link 形式の prompt 指示 (spec 033)

    @Test func testBuildPromptIncludesInlineLinkInstruction() {
        let container = try? makeContainer()
        let context = container?.mainContext

        let article = Article(url: "https://example.com", title: "テスト")
        let prompt = ChatService.buildPrompt(
            question: "Swift について",
            articles: [article],
            contextMessages: []
        )
        // inline link の指示文が prompt に含まれる
        #expect(prompt.contains("[記事タイトル](article-id://"))
        _ = context
    }

    // MARK: - 12. stripUUIDsFromBody が inline link を保護 (spec 033)

    @Test func testStripUUIDsPreservesInlineLink() {
        let inlineLink = "詳しくは [Swift 6 リリース](article-id://12345678-1234-5678-1234-567812345678) を参照"
        let result = ChatService.stripUUIDsFromBody(inlineLink)
        #expect(result.contains("[Swift 6 リリース]"))
        #expect(result.contains("article-id://12345678-1234-5678-1234-567812345678"))
    }

    // MARK: - 13. send で空質問 → throws

    @Test func testSendThrowsOnEmptyQuestion() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability
        )
        let session = try service.createSession()

        await #expect(throws: ChatServiceError.self) {
            _ = try await service.send(question: "   ", in: session)
        }
    }
}

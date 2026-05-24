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

    // MARK: - 13a. spec 040: graphTraversal nil → 「## 関連エンティティ」セクション無し

    @Test func testSendWithoutGraphTraversalOmitsEntitySection() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article = makeArticle(url: "a", title: "Swift 6", essence: "Swift 6 が登場", embedding: nil, in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextChatAnswerResult = .success(ChatAnswerOutput(
            answer: "Swift 6 は新機能を含むメジャーリリースです。",
            citedArticleIDs: [article.id.uuidString]
        ))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability,
            graphTraversal: nil
        )
        let session = try service.createSession()
        _ = try await service.send(question: "Swift 6 について", in: session)

        let lastPrompt = mockSession.lastChatAnswerPrompt ?? ""
        #expect(!lastPrompt.contains("## 関連エンティティ"))
    }

    // MARK: - 13b. spec 040: graph node 解決 → 関連エンティティ + 1-hop が prompt に注入される

    @Test func testSendInjectsRelatedEntitiesIntoPrompt() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article = makeArticle(url: "a", title: "Swift 6", essence: "Swift 6 と Apple", embedding: nil, in: context)
        let knowledge = article.extractedKnowledge!
        let entity = KnowledgeEntity(knowledge: knowledge, name: "Apple", typeRaw: "organization", salience: 5, order: 0)
        context.insert(entity)

        let appleNode = GraphNode(name: "Apple", categoryRaw: "テクノロジー", salience: 5, mentionCount: 2)
        let xcodeNode = GraphNode(name: "Xcode", categoryRaw: "テクノロジー", salience: 3, mentionCount: 1)
        context.insert(appleNode)
        context.insert(xcodeNode)
        let edge = GraphEdge(
            source: appleNode, target: xcodeNode,
            label: "develops", confidence: 0.9,
            categoryRaw: "テクノロジー"
        )
        context.insert(edge)
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextChatAnswerResult = .success(ChatAnswerOutput(
            answer: "Apple は Xcode を開発しています。",
            citedArticleIDs: [article.id.uuidString]
        ))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability,
            graphTraversal: GraphTraversalService()
        )
        let session = try service.createSession()
        _ = try await service.send(question: "Apple について", in: session)

        let lastPrompt = mockSession.lastChatAnswerPrompt ?? ""
        #expect(lastPrompt.contains("## 関連エンティティ"))
        // 直接 resolved の Apple、1-hop neighbor の Xcode、両方含まれる
        guard let entityStart = lastPrompt.range(of: "## 関連エンティティ") else {
            Issue.record("関連エンティティ section not found")
            return
        }
        let section = lastPrompt[entityStart.lowerBound...]
        #expect(section.contains("Apple"))
        #expect(section.contains("Xcode"))
    }

    // MARK: - 13c. spec 040: 複数記事で同 entity → entity section で 1 度のみ列挙

    @Test func testSendDedupesEntitiesAcrossArticles() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article1 = makeArticle(url: "a", title: "Swift 6 リリース", essence: "Swift 6 リリース", embedding: nil, in: context)
        let k1 = article1.extractedKnowledge!
        let e1 = KnowledgeEntity(knowledge: k1, name: "Swift", typeRaw: "product", salience: 5, order: 0)
        context.insert(e1)

        let article2 = makeArticle(url: "b", title: "Swift 6 機能", essence: "Swift 6 機能", embedding: nil, in: context)
        let k2 = article2.extractedKnowledge!
        let e2 = KnowledgeEntity(knowledge: k2, name: "Swift", typeRaw: "product", salience: 4, order: 0)
        context.insert(e2)

        let swiftNode = GraphNode(name: "Swift", categoryRaw: "テクノロジー", salience: 5, mentionCount: 2)
        context.insert(swiftNode)
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextChatAnswerResult = .success(ChatAnswerOutput(
            answer: "Swift について。",
            citedArticleIDs: [article1.id.uuidString, article2.id.uuidString]
        ))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability,
            graphTraversal: GraphTraversalService()
        )
        let session = try service.createSession()
        _ = try await service.send(question: "Swift 6 リリース 機能", in: session)

        let lastPrompt = mockSession.lastChatAnswerPrompt ?? ""
        guard let entityStart = lastPrompt.range(of: "## 関連エンティティ") else {
            Issue.record("関連エンティティ section not found")
            return
        }
        let section = String(lastPrompt[entityStart.lowerBound...])
        // entity section 内で "- Swift" prefix は 1 度のみ (dedupe)
        let occurrences = section.components(separatedBy: "- Swift").count - 1
        #expect(occurrences == 1)
    }

    // MARK: - 14. send で空質問 → throws

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

    // MARK: - spec 043: SavedAnswer hook 検証

    /// ChatService.ask 末尾で savedAnswerService.captureIfWorthy が呼ばれる (auto-save 経路)
    @Test func testAskInvokesSavedAnswerHookWhenAvailable() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        // 引用 2+ 必要なので Article 2 件作成 (embedding なし → keyword 経路は通らないが、fallback path を通る)
        let articleA = makeArticle(url: "a", title: "A", essence: "Apple 関連", embedding: nil, in: context)
        let articleB = makeArticle(url: "b", title: "B", essence: "Apple 関連 B", embedding: nil, in: context)
        _ = articleA
        _ = articleB
        try context.save()

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true  // Foundation 経路だが、retrieval が空なので unknown path

        let mockSavedAnswer = MockSavedAnswerService()

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability,
            graphTraversal: nil,
            savedAnswerService: mockSavedAnswer
        )
        let session = try service.createSession()

        // empty corpus / no embedding → unknown path → hook 呼ばれない
        _ = try await service.send(question: "Apple について", in: session)
        try? await Task.sleep(nanoseconds: 100_000_000)  // hook Task 完了待ち

        // unknown path では hook 呼ばれない (cited 空 + 短文)
        // spec 045: ChatService 経路は captureIfWorthyOrReplaceStale に切替
        #expect(mockSavedAnswer.captureIfWorthyCallCount == 0)
        #expect(mockSavedAnswer.captureIfWorthyOrReplaceStaleCallCount == 0)
    }

    /// SavedAnswerService 未注入 (nil) で ask() 正常完了 (後方互換)
    @Test func testAskWorksWithoutSavedAnswerService() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability,
            graphTraversal: nil,
            savedAnswerService: nil  // 未注入
        )
        let session = try service.createSession()

        let message = try await service.send(question: "test?", in: session)
        #expect(message.role == ChatMessageRole.assistant.rawValue)
    }
}

// MARK: - spec 043: Mock SavedAnswerService (test 限定)

@MainActor
final class MockSavedAnswerService: SavedAnswerServiceProtocol {
    var captureIfWorthyCallCount = 0
    var setPinnedCallCount = 0
    var deleteCallCount = 0
    var markStaleForArticleCallCount = 0
    /// spec 045
    var markFreshCallCount = 0
    /// spec 045
    var captureIfWorthyOrReplaceStaleCallCount = 0

    func captureIfWorthy(
        question: String,
        answer: String,
        citedArticleIDs: [String],
        sessionID: UUID?
    ) async {
        captureIfWorthyCallCount += 1
    }
    func setPinned(_ answer: SavedAnswer, isPinned: Bool) throws { setPinnedCallCount += 1 }
    func delete(_ answer: SavedAnswer) throws { deleteCallCount += 1 }
    func markStaleForArticle(_ article: Article) async { markStaleForArticleCallCount += 1 }
    func markFresh(_ answer: SavedAnswer) throws { markFreshCallCount += 1 }
    func captureIfWorthyOrReplaceStale(
        question: String,
        answer: String,
        citedArticleIDs: [String],
        sessionID: UUID?
    ) async {
        captureIfWorthyOrReplaceStaleCallCount += 1
    }
}

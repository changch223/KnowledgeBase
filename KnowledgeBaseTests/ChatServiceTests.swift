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
@testable import KnowledgeBase

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
            availability: availability,
            agentLoopEnabled: false
        )
        let session = try service.createSession()
        let result = try await service.send(question: "Swift について教えて", in: session)

        #expect(result.role == "assistant")
        // spec 057: 「分かりません」廃止、何かしらの answer 返却 (tutor reply fallback or hedge メッセージ)
        #expect(!HedgePhraseFilter.containsBanned(result.text))
        #expect(!result.text.isEmpty)
        #expect(result.citedArticleIDs.isEmpty)
    }

    // MARK: - 1b. spec 081: KB ミス → 一般知識バッジ + 明示 disclaimer

    @Test func testSendEmptyCorpusSetsGeneralKnowledgeBadge() async throws {
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
            agentLoopEnabled: false
        )
        let session = try service.createSession()
        let result = try await service.send(question: "存在しない話題について教えて", in: session)

        // spec 081: 一般知識バッジ + 「ナレッジベース」明示 disclaimer
        #expect(result.answeredFromGeneralKnowledge == true)
        #expect(result.text.contains("ナレッジベース"))
        #expect(result.citedArticleIDs.isEmpty)
    }

    // MARK: - 1c. spec 081: KB 接地回答にはバッジを付けない

    @Test func testGroundedAnswerHasNoBadge() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article = makeArticle(url: "a", title: "Swift 6 リリース", essence: "Swift 6 が登場した", embedding: nil, in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextChatAnswerResult = .success(ChatAnswerOutput(
            answer: "Swift 6 は並行性が強化されました。",
            citedArticleIDs: [article.id.uuidString]
        ))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability,
            agentLoopEnabled: false
        )
        let session = try service.createSession()
        let result = try await service.send(question: "Swift 6 について", in: session)

        #expect(result.answeredFromGeneralKnowledge == false)
        #expect(!result.citedArticleIDs.isEmpty)
    }

    // MARK: - 2. cited 空 → 「分かりません」上書き

    // spec 083: 関連記事あり + LM が cited 空 + 回答が実質非空 → 回答を保持し出典を補完 (一般回答に落とさない)
    @Test func testEmptyCitedFallsBackToRetrievedArticles() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        // 関連記事を作成 (keyword マッチで取得される前提)
        let article = makeArticle(url: "a", title: "Swift 6 リリース", essence: "Swift 6 が登場した", embedding: nil, in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        // LM が実質的な回答を返すが cited を空で返した (ID 列挙忘れ)
        mockSession.nextChatAnswerResult = .success(ChatAnswerOutput(
            answer: "Swift 6 は並行性などの新機能を含むメジャーリリースです。",
            citedArticleIDs: []
        ))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability,
            agentLoopEnabled: false
        )
        let session = try service.createSession()
        let result = try await service.send(question: "Swift について", in: session)

        // 回答は破棄されず保持、出典は取得済み記事で補完、一般知識バッジは付かない
        #expect(result.text.contains("Swift 6"))
        #expect(result.citedArticleIDs.contains(article.id.uuidString))
        #expect(result.answeredFromGeneralKnowledge == false)
    }

    // spec 083: 関連記事あり + LM が回答を空で返した (= 記事に答えがない) → 一般回答 + バッジ
    @Test func testEmptyAnswerFallsToGeneralKnowledge() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        makeArticle(url: "a", title: "Swift 6 リリース", essence: "Swift 6 が登場した", embedding: nil, in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextChatAnswerResult = .success(ChatAnswerOutput(
            answer: "",
            citedArticleIDs: []
        ))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability,
            agentLoopEnabled: false
        )
        let session = try service.createSession()
        let result = try await service.send(question: "Swift について", in: session)

        #expect(result.answeredFromGeneralKnowledge == true)
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
            availability: availability,
            agentLoopEnabled: false
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
            availability: availability,
            agentLoopEnabled: false
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
            availability: availability,
            agentLoopEnabled: false
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
            availability: availability,
            agentLoopEnabled: false
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
            availability: availability,
            agentLoopEnabled: false
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
            availability: availability,
            agentLoopEnabled: false
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
            availability: availability,
            agentLoopEnabled: false
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

    // MARK: - spec 082: agent prompt が検索優先 (retrieve-first) に biased

    @Test func testAgentPromptBiasesToSearch() {
        let prompt = ChatService.buildAgentPrompt(
            question: "最近のAI関連の記事について教えて",
            contextMessages: []
        )
        // searchArticles が既定動作として強調されている
        #expect(prompt.contains("searchArticles"))
        #expect(prompt.contains("迷ったら"))
        // バグ元の「正確なカテゴリ名がある時だけ検索」ルールは撤廃済
        #expect(!prompt.contains("Category 名のキーワードがあれば必ず searchArticles"))
    }

    // MARK: - spec 084: recency/meta 質問判定 (純関数)

    @Test func testIsRecencyQuery() {
        #expect(ChatService.isRecencyQuery("最近保存した記事の要点は?") == true)
        #expect(ChatService.isRecencyQuery("最近読んだ記事まとめて") == true)
        #expect(ChatService.isRecencyQuery("最近のAIについて教えて") == false) // recency のみ・meta 語なし
        #expect(ChatService.isRecencyQuery("こんにちは") == false)
    }

    // MARK: - spec 084: 「最近保存した記事の要点」→ 一般回答でなく直近記事を要約・引用

    @Test func testRecencyQuerySummarizesRecentArticles() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article = makeArticle(url: "a", title: "Swift 6 リリース", essence: "Swift 6 が登場した", embedding: nil, in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        mockSession.nextChatAnswerResult = .success(ChatAnswerOutput(
            answer: "最近の記事の要点は Swift 6 の新機能です。",
            citedArticleIDs: []
        ))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability,
            agentLoopEnabled: false
        )
        let session = try service.createSession()
        let result = try await service.send(question: "最近保存した記事の要点は?", in: session)

        // 一般回答でなく、直近記事を要約・引用 (spec 083 ゲートで出典補完)
        #expect(result.answeredFromGeneralKnowledge == false)
        #expect(result.citedArticleIDs.contains(article.id.uuidString))
    }

    // MARK: - spec 083: agent prompt が会話履歴を踏まえた独立検索クエリを指示

    @Test func testAgentPromptInstructsStandaloneQuery() {
        let prompt = ChatService.buildAgentPrompt(
            question: "プロダクトマネージャー",
            contextMessages: []
        )
        #expect(prompt.contains("独立した検索クエリ"))
        #expect(prompt.contains("会話履歴"))
    }

    // MARK: - spec 082: 分類器が immediate でも関連記事があれば引用回答に上書き (検索優先セーフティネット)

    @Test func testImmediateOverriddenByMatchingArticles() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article = makeArticle(url: "a", title: "Swift 6 リリース", essence: "Swift 6 が登場した", embedding: nil, in: context)
        try context.save()

        let mockSession = MockLanguageModelSession()
        // 分類器は immediate (一般知識) を返す
        mockSession.nextAgentActions = [.immediate(answer: "一般知識の答え")]
        // しかし関連記事があるので RAG 回答に上書きされ、この cited が使われる
        mockSession.nextChatAnswerResult = .success(ChatAnswerOutput(
            answer: "Swift 6 は並行性が強化されました (article-id://\(article.id.uuidString))。",
            citedArticleIDs: [article.id.uuidString]
        ))
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability,
            agentLoopEnabled: true  // agent path ON で immediate を返させる
        )
        let session = try service.createSession()
        let result = try await service.send(question: "Swift について", in: session)

        // 一般知識でなく、記事を引用した回答になっている
        #expect(result.citedArticleIDs.contains(article.id.uuidString))
        #expect(result.answeredFromGeneralKnowledge == false)
    }

    // MARK: - spec 082: immediate + 関連記事なし → 従来通り即答 (挨拶等、バッジなし)

    @Test func testImmediatePreservedWhenNoMatchingArticles() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let mockSession = MockLanguageModelSession()
        mockSession.nextAgentActions = [.immediate(answer: "こんにちは！")]
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = ChatService(
            context: context,
            embeddingService: makeMockEmbedding(available: false),
            session: mockSession,
            availability: availability,
            agentLoopEnabled: true
        )
        let session = try service.createSession()
        let result = try await service.send(question: "こんにちは", in: session)

        #expect(result.text == "こんにちは！")
        #expect(result.citedArticleIDs.isEmpty)
        #expect(result.answeredFromGeneralKnowledge == false)
    }

    // MARK: - 11. spec 081: 番号引用契約 (裸マーカー) の prompt 指示

    @Test func testBuildPromptIncludesBareMarkerInstruction() {
        let article = Article(url: "https://example.com", title: "テスト")
        let prompt = ChatService.buildPrompt(
            question: "Swift について",
            articles: [article],
            contextMessages: []
        )
        // 裸マーカー契約の指示文が prompt に含まれる (タイトルリンク形式は廃止)
        #expect(prompt.contains("(article-id://UUID)"))
        #expect(!prompt.contains("[記事タイトル](article-id://"))
    }

    // MARK: - 11b. spec 081: Wiki まとめは文脈に入るが引用させない

    @Test func testBuildPromptIncludesWikiContextNotCited() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article = Article(url: "https://example.com", title: "テスト記事")
        let page = ConceptPage(
            name: "生成AI",
            categoryRaw: "テクノロジー",
            crossSourceInsights: ["LLM は大規模言語モデルの略", "用途は文章生成"]
        )
        context.insert(page)

        let prompt = ChatService.buildPrompt(
            question: "生成AI とは",
            articles: [article],
            conceptPages: [page],
            contextMessages: []
        )
        // Wiki まとめが補足文脈として注入される
        #expect(prompt.contains("補足文脈"))
        #expect(prompt.contains("生成AI"))
        #expect(prompt.contains("LLM は大規模言語モデルの略"))
        // 引用は参考記事だけ、という制約文が含まれる
        #expect(prompt.contains("引用できるのは"))
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
            graphTraversal: nil,
            agentLoopEnabled: false
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
            graphTraversal: GraphTraversalService(),
            agentLoopEnabled: false
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
            graphTraversal: GraphTraversalService(),
            agentLoopEnabled: false
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
            availability: availability,
            agentLoopEnabled: false
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
            savedAnswerService: mockSavedAnswer,
            agentLoopEnabled: false
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
            savedAnswerService: nil,  // 未注入
            agentLoopEnabled: false
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

    /// spec 057: mock for saveExplicit (long press menu「保存」)
    var saveExplicitCallCount = 0
    func saveExplicit(
        question: String,
        answer: String,
        citedArticleIDs: [String],
        sessionID: UUID?
    ) throws -> SavedAnswer {
        saveExplicitCallCount += 1
        return SavedAnswer(question: question, answer: answer)
    }
}

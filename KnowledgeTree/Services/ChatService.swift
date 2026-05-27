//
//  ChatService.swift
//  KnowledgeTree
//
//  spec 021 — AI Chat (RAG) のオーケストレーション。
//  質問 → retrieval (embedding or keyword) → 回答生成 (Foundation Models or Fallback) →
//  ハルシネーション post-process → ChatMessage 永続化。
//
//  3 段階 availability 分岐 (R10):
//  - Embedding 不可: title / essence のキーワードマッチで retrieval
//  - Foundation Models 不可: top-k 記事の essence + KeyFact を整形して "回答" に
//  - 両方 OK: 通常 RAG 経路
//
//  ハルシネーション抑止 (R7):
//  - prompt: 「一般知識禁止」「分かりません fallback」を明示
//  - post-process: cited 空 → 「分かりません」上書き / 存在しない ID → filter
//  - 早期 return: top-k 全 < 0.3 → Foundation Models 呼び出しせず
//

import Foundation
import SwiftData
import os

@MainActor
protocol ChatServiceProtocol: AnyObject {
    /// 質問を送信、retrieval + 回答生成 + 永続化を行い、assistant ChatMessage を返す。
    /// spec 033: contextMessages で直前の会話履歴 (multi-turn 対応)。default 空 = single-turn。
    func send(question: String, in session: ChatSession, contextMessages: [ChatMessage]) async throws -> ChatMessage
    /// 新セッション作成 (50 件超過なら最古を FIFO 削除)。
    func createSession() throws -> ChatSession
    /// 全セッション + メッセージ削除。
    func deleteAllSessions() throws
    /// spec 033: 個別セッション削除 (cascade で message も削除)
    func deleteSession(_ session: ChatSession) throws
    /// 既存記事への embedding backfill (起動時 / 必要な時に呼び出す)。
    func backfillEmbeddings() async
}

extension ChatServiceProtocol {
    /// 後方互換用: 既存 (single-turn) 呼び出しを維持。
    func send(question: String, in session: ChatSession) async throws -> ChatMessage {
        try await send(question: question, in: session, contextMessages: [])
    }
}

@MainActor
final class ChatService: ChatServiceProtocol {

    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "chat")
    private let context: ModelContext
    private let embeddingService: EmbeddingService
    private let session: LanguageModelSessionProtocol
    private let availability: AvailabilityChecker
    /// spec 040: graph traversal で関連 entity を context に追加 (optional、nil なら従来動作)
    private let graphTraversal: GraphTraversalServiceProtocol?
    /// spec 043: AI 答え永続化時の SavedAnswer 自動保存用 (optional、nil で後方互換)
    private weak var savedAnswerService: SavedAnswerServiceProtocol?

    /// 上位 k の retrieval 件数。
    private let topK: Int = 5

    /// 早期 return 用の最低 similarity 閾値。これ未満は「該当する情報が見つからない」と判定。
    private let minSimilarity: Float = 0.3

    /// 1 ユーザーあたりの最大セッション数 (FIFO で古いを削除)。
    private let maxSessions: Int = 50

    /// spec 057: Agentic Chat agent loop を有効にするか (default true、production)。
    /// test では false にして既存 RAG 経路テストを継続実行可能。
    private let agentLoopEnabled: Bool

    /// spec 057: 連続 clarification の最大 round 数 (これ以上は forceFinalAnswer)。
    private let maxClarificationRounds: Int = 3

    init(
        context: ModelContext,
        embeddingService: EmbeddingService,
        session: LanguageModelSessionProtocol,
        availability: AvailabilityChecker = SystemLanguageModelAvailabilityChecker(),
        graphTraversal: GraphTraversalServiceProtocol? = nil,
        savedAnswerService: SavedAnswerServiceProtocol? = nil,
        agentLoopEnabled: Bool = true
    ) {
        self.context = context
        self.embeddingService = embeddingService
        self.session = session
        self.availability = availability
        self.graphTraversal = graphTraversal
        self.savedAnswerService = savedAnswerService
        self.agentLoopEnabled = agentLoopEnabled
    }

    // MARK: - send

    func send(question: String, in session: ChatSession, contextMessages: [ChatMessage] = []) async throws -> ChatMessage {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ChatServiceError.emptyQuestion
        }

        // 1. user message 永続化
        let userMessage = ChatMessage(
            session: session,
            role: ChatMessageRole.user.rawValue,
            text: trimmed,
            citedArticleIDs: []
        )
        context.insert(userMessage)

        // session.title 更新 (最初の user message のみ)
        if session.title.isEmpty {
            session.title = String(trimmed.prefix(30))
        }
        session.lastMessageAt = .now

        // spec 057: Agentic Chat — Agent loop で intent 判定
        // - Apple Intelligence 利用可 + agentLoopEnabled なら AgentAction 取得 → switch 分岐
        // - 不可 / agent loop error / agentLoopEnabled=false → 既存 RAG 経路に fallback
        // - max 3 round 連続 clarification 後は forceFinalAnswer flag で askClarification 抑制
        if agentLoopEnabled, availability.isAvailable {
            let consecutiveClarifications = Self.countConsecutiveClarifications(in: session)
            let shouldForceFinal = consecutiveClarifications >= maxClarificationRounds

            if let agentAction = await tryGenerateAgentAction(question: trimmed, contextMessages: contextMessages, forceFinalAnswer: shouldForceFinal) {
                switch agentAction {
                case .immediate(let answer):
                    let filtered = HedgePhraseFilter.replace(answer)
                    return try persistAssistant(text: filtered, citedIDs: [], suggestions: [], in: session)

                case .askClarification(let q, let suggestions):
                    if shouldForceFinal {
                        // max round 到達後の clarification は強制的に「最善努力 immediate」化
                        let fallback = await tryGenerateFallbackAnswer(question: trimmed) ?? "私の理解では、もう少し具体的な質問をいただけると、お手伝いできるかもしれません。"
                        let filtered = HedgePhraseFilter.replace(fallback)
                        return try persistAssistant(text: filtered, citedIDs: [], suggestions: [], in: session)
                    }
                    return try persistAssistant(text: q, citedIDs: [], suggestions: Array(suggestions.prefix(3)), in: session)

                case .searchArticles(let searchQuery):
                    return try await executeRAG(originalQuestion: trimmed, searchQuestion: searchQuery, contextMessages: contextMessages, in: session)

                case .finalAnswer(let text, let ids):
                    let filtered = HedgePhraseFilter.replace(text)
                    let citedStrings = ids.map { $0.uuidString }
                    return try persistAssistant(text: filtered, citedIDs: citedStrings, suggestions: [], in: session)
                }
            }
        }

        // Fallback: 既存 RAG 経路
        return try await executeRAG(originalQuestion: trimmed, searchQuestion: trimmed, contextMessages: contextMessages, in: session)
    }

    /// session 内で「直近 user message 以前の連続 clarification (assistant + clarificationSuggestions 非空) 数」を数える。
    /// 例: [user1, asst_clar, user2, asst_clar, user3, asst_clar, **NEW user**]
    ///     → consecutiveClarifications = 3 (user3 以前の連続 clarification 3 件)
    /// spec 057: max 3 round clarification の判定用。
    static func countConsecutiveClarifications(in session: ChatSession) -> Int {
        let sorted = (session.messages ?? []).sorted { $0.timestamp < $1.timestamp }
        // 後ろから走査、user message に当たるまで連続 clarification をカウント
        var count = 0
        for msg in sorted.reversed() {
            if msg.role == ChatMessageRole.assistant.rawValue, !msg.clarificationSuggestions.isEmpty {
                count += 1
            } else if msg.role == ChatMessageRole.assistant.rawValue {
                // 非 clarification な assistant message → streak break
                break
            }
            // user message は skip (streak 継続判定の境界)
        }
        return count
    }

    // MARK: - spec 057: Agent loop helpers

    /// Agent loop の最初の 1 round で AgentAction を取得。エラー時 nil (caller が fallback 経路)。
    /// - Parameter forceFinalAnswer: max 3 round 到達時に true、prompt に「askClarification 禁止」 instruction を追加
    private func tryGenerateAgentAction(question: String, contextMessages: [ChatMessage], forceFinalAnswer: Bool = false) async -> AgentAction? {
        let prompt = Self.buildAgentPrompt(question: question, contextMessages: contextMessages, forceFinalAnswer: forceFinalAnswer)
        do {
            return try await session.generateAgentAction(prompt: prompt)
        } catch {
            logger.error("AgentAction generation failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Agent loop で使う prompt 生成。
    /// - Parameter forceFinalAnswer: true なら「もう聞き返し不可、必ず answer を返す」 instruction を追加。
    static func buildAgentPrompt(question: String, contextMessages: [ChatMessage], forceFinalAnswer: Bool = false) -> String {
        let recent = contextMessages.suffix(4)
        let contextLines = recent.map { msg in
            let role = msg.role == ChatMessageRole.user.rawValue ? "ユーザー" : "アシスタント"
            let snippet = String(msg.text.prefix(200))
            return "\(role): \(snippet)"
        }.joined(separator: "\n")

        let forceClause = forceFinalAnswer ? """

        ## 最重要 (forceFinalAnswer)
        既に 3 回 clarification を行いました。**askClarification は使わない**でください。
        現時点の情報で最善努力答えを生成してください (immediate or finalAnswer)。
        情報不足なら「私の理解では」「あくまで概要として」等の hedge を使って、それでも何かしらの答えを返してください。
        """ : ""

        return """
        あなたは iKnow の AI アシスタント。ユーザーの質問に対して、4 つの行動から 1 つを選ぶ:

        - immediate(answer): 明確で一般知識で答えられる質問なら即答
        - askClarification(question, suggestions): 質問が曖昧、聞き返しと 3 候補で確認
        - searchArticles(query): 保存記事を検索する必要あり、検索 query を指定
        - finalAnswer(text, citedArticleIDs): 検索結果統合後の最終答え

        ## 重要ルール
        - 「分かりません」「答えられません」「情報がありません」「知りません」は絶対に出力しない
        - 情報不足なら「私の理解では」「一般的には」「あくまで概要として」等の hedge を使う
        - askClarification の suggestions は厳密に 3 つ、各 30 字以内
        - 「保存した記事」「あの記事」「私の」等のキーワードがあれば searchArticles を選ぶ
        - **「〇〇分野」「〇〇カテゴリ」「テクノロジー」「経済」「健康」「デザイン」「学術」「アート」「ニュース」「スポーツ」「エンタメ」等の Category 名のキーワードがあれば必ず searchArticles を選んで、Category 名を query として渡す**
        - 「最近」「今週」「今月」のキーワード + Category なら、その Category の最近記事の要点まとめを期待していると判断
        \(forceClause)
        \(contextLines.isEmpty ? "" : "## 直前の会話\n\(contextLines)\n")
        ## 質問
        \(question)
        """
    }

    /// 既存 RAG 経路を実行 (retrieval + Foundation Models or fallback)。
    /// originalQuestion: ユーザー入力テキスト (cleanedAnswer hedge 等で使用)
    /// searchQuestion: embedding 検索に使う query (agent action.searchArticles の query があれば置換可能)
    private func executeRAG(
        originalQuestion: String,
        searchQuestion: String,
        contextMessages: [ChatMessage],
        in session: ChatSession
    ) async throws -> ChatMessage {
        // spec 058 polish: Category 名キーワード検出 → category filter 経路
        // 例: 「テクノロジー分野で何があった?」 → テクノロジー Tag を持つ記事のみで answer 生成
        if let category = Self.detectCategoryKeyword(in: searchQuestion) {
            let categoryArticles = fetchArticlesInCategory(category)
            if !categoryArticles.isEmpty {
                logger.notice("ChatService: category filter hit, category=\(category, privacy: .public), articles=\(categoryArticles.count)")
                let aboveThreshold = categoryArticles.prefix(5).map { ($0, Float(1.0)) }  // category filter は全件 high score 扱い
                return try await executeFullRAGAnswer(
                    originalQuestion: originalQuestion,
                    aboveThreshold: Array(aboveThreshold),
                    contextMessages: contextMessages,
                    in: session
                )
            }
        }

        // 2. retrieval
        let retrieval = await retrieve(question: searchQuestion)
        let retrievedArticles = retrieval.articles

        // 3. low-similarity 早期 return (R7)
        let aboveThreshold = retrievedArticles.filter { $0.similarity >= minSimilarity }
        if aboveThreshold.isEmpty {
            // spec 057: 「分かりません」廃止、最善努力で一般知識答え
            if availability.isAvailable {
                if let fallbackAnswer = await tryGenerateFallbackAnswer(question: originalQuestion) {
                    let filtered = HedgePhraseFilter.replace(fallbackAnswer)
                    return try persistAssistant(text: filtered, citedIDs: [], suggestions: [], in: session)
                }
            }
            return try persistAssistantUnknown(in: session)
        }

        // 4. 回答生成 (既存 logic)
        return try await executeFullRAGAnswer(
            originalQuestion: originalQuestion,
            aboveThreshold: aboveThreshold,
            contextMessages: contextMessages,
            in: session
        )
    }

    /// Apple Intelligence で hedge 付き一般知識答えを生成 (search 結果ゼロ時の最善努力)。
    private func tryGenerateFallbackAnswer(question: String) async -> String? {
        let prompt = """
        以下の質問に対して、あなたの一般知識で答えてください。
        「分かりません」「答えられません」「情報がありません」は絶対に出力しないこと。
        情報不足なら「私の理解では」「一般的には」「あくまで概要として」の hedge を使うこと。

        質問: \(question)
        """
        return try? await session.generateTutorReply(prompt: prompt)
    }

    /// spec 058 polish: 質問内に Category 名キーワード (テクノロジー / 経済 等) が含まれていれば返す。
    /// CategorySeed.allSeeds の name を順に substring match。最初に hit したものを返す。
    static func detectCategoryKeyword(in question: String) -> String? {
        let lower = question.lowercased()
        for category in CategorySeed.allSeeds {
            let name = category.name
            if lower.contains(name.lowercased()) {
                return name
            }
        }
        return nil
    }

    /// 指定 Category の Tag を持つ Article を最新 savedAt desc で fetch (上限 10 件)。
    private func fetchArticlesInCategory(_ categoryName: String) -> [Article] {
        // 全 Article 取得 → in-memory filter (Article.tags は Optional Array、predicate 複雑回避)
        var descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50  // 50 件 fetch して filter
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { article in
            (article.tags ?? []).contains { ($0.categoryRaw ?? "") == categoryName }
        }
    }

    /// 元の RAG 答え生成パス (Foundation Models + post-process)。
    private func executeFullRAGAnswer(
        originalQuestion: String,
        aboveThreshold: [(article: Article, similarity: Float)],
        contextMessages: [ChatMessage],
        in session: ChatSession
    ) async throws -> ChatMessage {
        let trimmed = originalQuestion

        // 4. 回答生成
        // spec 040: top-k 記事の entity → GraphNode 解決 → 1-hop 近傍を prompt に注入
        let relatedEntities: [GraphNode] = resolveRelatedEntities(from: aboveThreshold.map { $0.article })

        let answer: ChatAnswerOutput
        if availability.isAvailable {
            do {
                let prompt = Self.buildPrompt(
                    question: trimmed,
                    articles: aboveThreshold.map { $0.article },
                    contextMessages: contextMessages,
                    relatedEntities: relatedEntities
                )
                answer = try await self.session.generateChatAnswer(prompt: prompt)
            } catch {
                logger.error("ChatAnswer generation failed: \(String(describing: error), privacy: .public)")
                // Foundation Models 失敗 → KeyFact 並べに fallback
                return try persistAssistantFallback(in: session, articles: aboveThreshold.map { $0.article })
            }
        } else {
            // Foundation Models 不可 → KeyFact 並べ
            return try persistAssistantFallback(in: session, articles: aboveThreshold.map { $0.article })
        }

        // 5. post-process (R7)
        let availableIDs = Set(aboveThreshold.map { $0.article.id.uuidString })
        let filteredCited = answer.citedArticleIDs.filter { availableIDs.contains($0) }

        // cited 空 → 「分かりません」上書き
        if filteredCited.isEmpty {
            return try persistAssistantUnknown(in: session)
        }

        // 答え本文中の UUID 文字列を除去 (LM が prompt に反して本文にも ID を書くケースへの保険)
        let cleanedAnswer = Self.stripUUIDsFromBody(answer.answer)

        // 6. assistant message 永続化
        let assistantMessage = ChatMessage(
            session: session,
            role: ChatMessageRole.assistant.rawValue,
            text: cleanedAnswer,
            citedArticleIDs: filteredCited
        )
        context.insert(assistantMessage)
        session.lastMessageAt = .now
        try context.save()

        // spec 043 + spec 045: 答えが条件を満たせば SavedAnswer 自動保存 (fire-and-forget、silent fail)
        // spec 045 で captureIfWorthyOrReplaceStale に切替:
        //   - fresh duplicate あり → skip (従来通り)
        //   - 同 question で isStale=true な古いのみ → 古いを残して新規 insert (再生成 path 自動対応)
        //   - 重複なし → 通常 insert
        let sessionID = session.id
        Task { [weak self] in
            await self?.savedAnswerService?.captureIfWorthyOrReplaceStale(
                question: trimmed,
                answer: cleanedAnswer,
                citedArticleIDs: filteredCited,
                sessionID: sessionID
            )
        }

        return assistantMessage
    }

    // MARK: - createSession

    func createSession() throws -> ChatSession {
        // 50 件超過なら最古を FIFO 削除
        let descriptor = FetchDescriptor<ChatSession>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        if existing.count >= maxSessions {
            let toDelete = existing.prefix(existing.count - maxSessions + 1)
            for old in toDelete {
                context.delete(old)
            }
        }
        let session = ChatSession(title: "")
        context.insert(session)
        try context.save()
        return session
    }

    // MARK: - deleteAllSessions

    func deleteAllSessions() throws {
        let descriptor = FetchDescriptor<ChatSession>()
        let all = (try? context.fetch(descriptor)) ?? []
        for session in all {
            context.delete(session)
        }
        try context.save()
    }

    // MARK: - deleteSession (spec 033)

    func deleteSession(_ session: ChatSession) throws {
        // cascade で messages も削除される (spec 021 ChatSession の @Relationship)
        context.delete(session)
        try context.save()
    }

    // MARK: - backfillEmbeddings

    func backfillEmbeddings() async {
        guard embeddingService.isAvailable else { return }
        let descriptor = FetchDescriptor<Article>()
        let articles = (try? context.fetch(descriptor)) ?? []
        for article in articles where article.essenceEmbedding == nil {
            if let text = embeddingText(for: article),
               let vector = embeddingService.embed(text) {
                article.essenceEmbedding = vector.asEmbeddingData
            }
        }
        try? context.save()
    }

    // MARK: - Private helpers

    /// 質問 → top-k 関連記事。embedding 可なら cosine、不可なら keyword マッチ。
    private func retrieve(question: String) async -> ChatRetrievalResult {
        let descriptor = FetchDescriptor<Article>()
        let allArticles = (try? context.fetch(descriptor)) ?? []

        if embeddingService.isAvailable, let queryVector = embeddingService.embed(question) {
            // Embedding 経路
            let corpus: [(id: String, embedding: [Float], article: Article)] = allArticles.compactMap { article in
                guard let data = article.essenceEmbedding else { return nil }
                let vector = data.asFloatArray
                return (id: article.id.uuidString, embedding: vector, article: article)
            }
            let scored: [(article: Article, similarity: Float)] = corpus.map { entry in
                let sim = EmbeddingService.cosineSimilarity(queryVector, entry.embedding)
                return (article: entry.article, similarity: sim)
            }
            let topResults = scored
                .sorted { $0.similarity > $1.similarity }
                .prefix(topK)
            return ChatRetrievalResult(articles: Array(topResults), mode: .embedding)
        } else {
            // Keyword 経路 (embedding 不可)
            let scored = Self.keywordScore(question: question, articles: allArticles)
            let topResults = scored
                .sorted { $0.similarity > $1.similarity }
                .prefix(topK)
            return ChatRetrievalResult(articles: Array(topResults), mode: .keyword)
        }
    }

    /// embedding 用テキスト。essence 優先、なければ title。
    private func embeddingText(for article: Article) -> String? {
        if let essence = article.extractedKnowledge?.essence, !essence.isEmpty {
            return essence
        }
        let title = article.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    /// spec 040: 上位記事の entity 名から GraphNode を解決し、1-hop 近傍まで含めた dedupe 済 list を返す。
    /// graphTraversal が nil なら常に空配列。entity が無い記事はスキップ。
    private func resolveRelatedEntities(from articles: [Article]) -> [GraphNode] {
        guard let graphTraversal else { return [] }
        let entityNames: [String] = articles.flatMap { article -> [String] in
            guard let entities = article.extractedKnowledge?.entities else { return [] }
            return entities.map { $0.name }
        }
        guard !entityNames.isEmpty else { return [] }
        let resolved = graphTraversal.resolveNodes(entityNames: entityNames, categoryRaw: nil, in: context)
        var collected: [UUID: GraphNode] = [:]
        for node in resolved {
            collected[node.id] = node
            for neighbor in graphTraversal.neighbors(of: node) {
                collected[neighbor.id] = neighbor
            }
        }
        return Array(collected.values)
    }

    /// Foundation Models prompt 組立て (R5)。
    /// spec 033: contextMessages で multi-turn 対応 + inline link 形式の指示。
    /// spec 040: relatedEntities が非空なら「## 関連エンティティ」セクションを記事一覧の後に挿入。
    static func buildPrompt(question: String, articles: [Article], contextMessages: [ChatMessage] = [], relatedEntities: [GraphNode] = []) -> String {
        var prompt = """
        あなたは iKnow の AI アシスタントです。ユーザーが保存した記事を元に質問に答えます。

        ## ルール
        1. 必ず以下の【参考記事】の内容のみに基づいて回答してください。一般知識から推測してはいけません。
        2. 回答に使った記事の ID は citedArticleIDs フィールドにのみ含めてください (Article.id の UUID 文字列)。
        3. **回答本文 (answer フィールド) には UUID 文字列を絶対に書かないでください**。「[1] によれば」のような番号も避けます。
        4. 参考記事に言及するときは `[記事タイトル](article-id://UUID)` の形式で本文中にリンクを埋め込んでください。例: 「Swift 6 については [Swift 6 リリース記事](article-id://12345...) で詳しく説明されています」。
        5. 参考記事に答えがない場合は「分かりません。保存された記事の中に該当する情報が見つかりませんでした。」と回答し、citedArticleIDs を空配列にしてください。
        6. 簡潔に、3 段落以内で日本語で回答してください。
        7. 直近の会話があれば、文脈を踏まえて回答してください。「詳しく教えて」のような短い質問は直前の話題の深掘りとして扱ってください。

        """

        // spec 033: multi-turn 対応 — 直前の会話履歴
        if !contextMessages.isEmpty {
            prompt += "\n## 直近の会話\n"
            for msg in contextMessages {
                let role = msg.role == ChatMessageRole.user.rawValue ? "ユーザー" : "アシスタント"
                let truncated = msg.text.count > 200 ? String(msg.text.prefix(200)) + "…" : msg.text
                prompt += "\n\(role): \(truncated)"
            }
            prompt += "\n"
        }

        prompt += "\n## 参考記事"

        for (i, article) in articles.enumerated() {
            let essence = article.extractedKnowledge?.essence ?? ""
            let keyFacts = article.extractedKnowledge?.keyFacts?.prefix(3).map { $0.statement }.joined(separator: " / ") ?? ""
            prompt += """

            [\(i + 1)] ID: \(article.id.uuidString)
            タイトル: \(article.title)
            要点: \(essence)
            KeyFacts: \(keyFacts)
            """
        }

        // spec 040: 関連エンティティ (1-hop graph neighborhood)
        if !relatedEntities.isEmpty {
            prompt += "\n\n## 関連エンティティ (参考)\n"
            for node in relatedEntities.prefix(10) {
                let labeledOutgoing = (node.outgoingEdges ?? [])
                    .filter { $0.label != nil && $0.target?.isActive == true }
                    .sorted { $0.weight > $1.weight }
                    .prefix(2)
                let edgeSummary = labeledOutgoing.compactMap { edge -> String? in
                    guard let label = edge.label, let target = edge.target else { return nil }
                    return "\(label) → \(target.name)"
                }.joined(separator: " / ")
                if edgeSummary.isEmpty {
                    prompt += "- \(node.name)\n"
                } else {
                    prompt += "- \(node.name): \(edgeSummary)\n"
                }
            }
        }

        prompt += """

        ## ユーザーの質問
        \(question)
        """
        return prompt
    }

    /// 答え本文から UUID 文字列を除去 (LM が prompt に反して書いた場合の保険)。
    /// spec 033: inline link `[タイトル](article-id://UUID)` 形式は保護する。
    /// 単独で出てきた UUID (周囲が `article-id://` でない) のみ除去。
    static func stripUUIDsFromBody(_ text: String) -> String {
        // 1. まず inline link `(article-id://UUID)` をプレースホルダに退避
        let inlineLinkPattern = #"\(article-id://[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\)"#
        let placeholder = "\u{E000}INLINE_LINK_\u{E001}"  // 私用領域 Unicode で衝突回避
        var result = text
        var savedLinks: [String] = []
        if let regex = try? NSRegularExpression(pattern: inlineLinkPattern) {
            let nsText = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsText.length))
            for match in matches.reversed() {
                let matched = nsText.substring(with: match.range)
                savedLinks.insert(matched, at: 0)
                result = (result as NSString).replacingCharacters(in: match.range, with: placeholder)
            }
        }

        // 2. 単独 UUID (周囲が `[ID:...]` `(ID:...)` `「ID:...」` または裸) を除去
        let uuidPattern = #"[\[\(「【]*\s*(?:ID\s*[::]\s*)?[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\s*[\]\)」】]*"#
        result = result.replacingOccurrences(of: uuidPattern, with: "", options: .regularExpression)
        // 連続する空白 / カンマ / 句読点の前後の空白を整理
        result = result.replacingOccurrences(of: #"\s+([、。,.])"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // 3. 退避した inline link を復元
        for link in savedLinks {
            if let range = result.range(of: placeholder) {
                result.replaceSubrange(range, with: link)
            }
        }
        return result
    }

    /// Foundation Models 不可時の fallback。top-k 記事の essence + KeyFact を整形。
    private func persistAssistantFallback(
        in session: ChatSession,
        articles: [Article]
    ) throws -> ChatMessage {
        var text = "以下の記事が参考になります。\n\n"
        for (i, article) in articles.enumerated() {
            let essence = article.extractedKnowledge?.essence ?? article.title
            text += "\(i + 1). \(essence)\n"
            let facts = article.extractedKnowledge?.keyFacts?.prefix(2).map { "  ・\($0.statement)" } ?? []
            if !facts.isEmpty {
                text += facts.joined(separator: "\n") + "\n"
            }
        }
        let cited = articles.map { $0.id.uuidString }
        let assistantMessage = ChatMessage(
            session: session,
            role: ChatMessageRole.assistant.rawValue,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            citedArticleIDs: cited
        )
        context.insert(assistantMessage)
        session.lastMessageAt = .now
        try context.save()
        return assistantMessage
    }

    /// 「分かりません」message を永続化。
    /// spec 057: text の「分かりません」を hedge phrase に置換 (HedgePhraseFilter)。
    private func persistAssistantUnknown(in session: ChatSession) throws -> ChatMessage {
        let rawText = "保存された記事の中に該当する情報が見つかりませんでした。私の理解では、もう少し詳しい質問をいただけると、お手伝いできるかもしれません。"
        let filtered = HedgePhraseFilter.replace(rawText)
        let assistantMessage = ChatMessage(
            session: session,
            role: ChatMessageRole.assistant.rawValue,
            text: filtered,
            citedArticleIDs: []
        )
        context.insert(assistantMessage)
        session.lastMessageAt = .now
        try context.save()
        return assistantMessage
    }

    /// spec 057: 汎用 assistant message 永続化 (immediate / clarification / finalAnswer の共通 helper)。
    private func persistAssistant(
        text: String,
        citedIDs: [String],
        suggestions: [String],
        in session: ChatSession
    ) throws -> ChatMessage {
        let assistantMessage = ChatMessage(
            session: session,
            role: ChatMessageRole.assistant.rawValue,
            text: text,
            citedArticleIDs: citedIDs,
            clarificationSuggestions: suggestions
        )
        context.insert(assistantMessage)
        session.lastMessageAt = .now
        try context.save()
        return assistantMessage
    }

    /// keyword マッチによる簡易スコアリング。query の各単語が title / essence に含まれる回数の合計。
    static func keywordScore(question: String, articles: [Article]) -> [(article: Article, similarity: Float)] {
        let words = question
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count >= 2 }

        guard !words.isEmpty else {
            return articles.map { ($0, 0.0) }
        }

        return articles.map { article in
            let haystack = (article.title + " " + (article.extractedKnowledge?.essence ?? ""))
                .lowercased()
            let hits = words.reduce(0) { acc, word in
                acc + (haystack.contains(word) ? 1 : 0)
            }
            // 0 〜 1 にスケール (全単語マッチで 1.0)
            let score = Float(hits) / Float(words.count)
            return (article: article, similarity: score)
        }
    }
}

// MARK: - Errors

enum ChatServiceError: Error {
    case emptyQuestion
}

// MARK: - Retrieval Result (transient)

struct ChatRetrievalResult {
    let articles: [(article: Article, similarity: Float)]
    let mode: RetrievalMode

    enum RetrievalMode {
        case embedding
        case keyword
    }
}

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

/// チャット応答のモード。
enum ChatMode: Sendable {
    case quick   // ⚡ キーワード検索 + 短い回答（速度優先）
    case think   // 🧠 embedding RAG + 通常回答（精度優先、デフォルト）
}

@MainActor
protocol ChatServiceProtocol: AnyObject {
    /// 質問を送信、retrieval + 回答生成 + 永続化を行い、assistant ChatMessage を返す。
    /// chatMode: .quick = キーワード検索 + 短答、.think = embedding RAG + 通常答え (デフォルト)
    func send(question: String, in session: ChatSession, chatMode: ChatMode, contextMessages: [ChatMessage]) async throws -> ChatMessage
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
    /// 後方互換: chatMode なし呼び出し → .think デフォルト。
    func send(question: String, in session: ChatSession, contextMessages: [ChatMessage]) async throws -> ChatMessage {
        try await send(question: question, in: session, chatMode: .think, contextMessages: contextMessages)
    }
    /// 後方互換: single-turn。
    func send(question: String, in session: ChatSession) async throws -> ChatMessage {
        try await send(question: question, in: session, chatMode: .think, contextMessages: [])
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

    /// P2-2 (ハイブリッド検索): キーワードが強く一致した記事を cosine が低くても救済する閾値。
    /// keywordScore は「質問語のうち一致した割合」= 0〜1。0.5 = 質問語の半分以上が本文/タイトルに出現。
    private let keywordRescueThreshold: Float = 0.5

    /// spec 081: 回答文脈に使う Wiki/概念ページの retrieval 件数 (引用はしない、文脈のみ)。
    private let conceptTopK: Int = 2

    /// spec 081: Wiki/概念ページを文脈に採用する最低 cosine 閾値 (nearestConceptIDs と同値)。
    private let conceptMinSimilarity: Float = 0.5

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

    func send(question: String, in session: ChatSession, chatMode: ChatMode = .think, contextMessages: [ChatMessage] = []) async throws -> ChatMessage {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ChatServiceError.emptyQuestion
        }

        // spec 082: チャット応答中は裏の AI 処理 (概念まとめ生成) を一時停止し ANE をチャットに最優先で譲る
        AIPriorityCoordinator.shared.beginChat()
        defer { AIPriorityCoordinator.shared.endChat() }

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
                    // spec 082: 検索優先セーフティネット — 分類器が immediate でも、
                    // 関連する保存記事があれば引用回答に上書き (挨拶・雑談は retrieval 空で従来通り即答)。
                    let retrieval = await retrieve(question: trimmed, chatMode: chatMode)
                    let candidates = mergeArticleCandidates(retrieval: retrieval)
                    if !candidates.isEmpty {
                        return try await executeFullRAGAnswer(
                            originalQuestion: trimmed,
                            aboveThreshold: candidates,
                            conceptPages: retrieval.conceptPages.map { $0.page },
                            contextMessages: contextMessages,
                            chatMode: chatMode,
                            in: session
                        )
                    }
                    // spec 084: 「最近保存した記事の要点」等は一般回答でなく直近記事を要約
                    if let recent = recencyDigestCandidates(for: trimmed) {
                        return try await executeFullRAGAnswer(
                            originalQuestion: trimmed,
                            aboveThreshold: recent,
                            contextMessages: contextMessages,
                            chatMode: chatMode,
                            in: session
                        )
                    }
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
                    return try await executeRAG(originalQuestion: trimmed, searchQuestion: searchQuery, contextMessages: contextMessages, chatMode: chatMode, in: session)

                case .finalAnswer(let text, let ids):
                    let filtered = HedgePhraseFilter.replace(text)
                    let citedStrings = ids.map { $0.uuidString }
                    return try persistAssistant(text: filtered, citedIDs: citedStrings, suggestions: [], in: session)
                }
            }
        }

        // Fallback: 既存 RAG 経路
        return try await executeRAG(originalQuestion: trimmed, searchQuestion: trimmed, contextMessages: contextMessages, chatMode: chatMode, in: session)
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
        あなたは Knowledge Base の AI アシスタント。基本動作は「ユーザーが保存した記事 (ナレッジベース) から答える」こと。
        質問に対して、4 つの行動から 1 つを選ぶ:

        - searchArticles(query): 保存記事を検索する。**情報・知識・トピック・人物・出来事・技術・用語などを問う質問は、原則これを選ぶ (既定動作)**。
        - immediate(answer): 挨拶・雑談・アプリの使い方など、保存記事と無関係な場合のみ即答。
        - askClarification(question, suggestions): どう検索しても意図が複数に割れて手がかりが薄い時**だけ**聞き返す (本当に必要な時のみ、めったに使わない)。
        - finalAnswer(text, citedArticleIDs): 検索結果を統合した最終答え。

        ## 重要ルール
        - **迷ったら searchArticles を選ぶ**。知識・情報を問う質問はまず保存記事を検索する。「保存した記事」等のキーワードが無くても検索してよい。
        - **曖昧な質問でも、まず最善の解釈で検索する**。略語や短い語 (例「pm」) も、ありそうな意味に展開して検索する (例: query「pm プロダクトマネージャー プロジェクト管理」)。安易に askClarification しない。
        - searchArticles の query は **会話履歴を踏まえた「独立した検索クエリ」** にする。直前の会話の指示語・追質問・略語をすべて解決し、それ単体で検索できる語にする。
          例: 直前が「pm って何?」で今回「プロダクトマネージャー」→ query は「PM プロダクトマネージャー」。
          例: 「最近のAI関連の記事について教えて」→ query は「AI」。
        - 「テクノロジー」「経済」等の分野名や「最近」「今週」のキーワードがあれば、それも query に含めてよい (必須ではない)。
        - immediate は本当に保存記事と無関係な雑談だけ。情報を問う質問を一般知識で即答してはいけない。
        - 「分かりません」「答えられません」「情報がありません」「知りません」は絶対に出力しない。
        - askClarification の suggestions は厳密に 3 つ、各 30 字以内 (ユーザーはこの 3 つに加え自由入力もできる)。
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
        chatMode: ChatMode = .think,
        in session: ChatSession
    ) async throws -> ChatMessage {
        // spec 058 polish: Category 名キーワード検出 → category filter 経路
        // 例: 「テクノロジー分野で何があった?」 → テクノロジー Tag を持つ記事のみで answer 生成
        if let category = Self.detectCategoryKeyword(in: searchQuestion) {
            let categoryArticles = fetchArticlesInCategory(category)
            if !categoryArticles.isEmpty {
                logger.notice("ChatService: category filter hit, category=\(category, privacy: .public), articles=\(categoryArticles.count)")
                let aboveThreshold = categoryArticles.prefix(5).map { ($0, Float(1.0)) }
                return try await executeFullRAGAnswer(
                    originalQuestion: originalQuestion,
                    aboveThreshold: Array(aboveThreshold),
                    contextMessages: contextMessages,
                    chatMode: chatMode,
                    in: session
                )
            }
        }

        // 2. retrieval (記事 + spec 081: Wiki/概念ページ)
        let retrieval = await retrieve(question: searchQuestion, chatMode: chatMode)

        // 3. spec 081: 概念ページ由来の relatedArticles を引用候補に merge
        //    (記事単体では弱いが、まとめ経由で関連する記事も拾う)。
        var aboveThreshold = mergeArticleCandidates(retrieval: retrieval)
        var conceptPages = retrieval.conceptPages.map { $0.page }

        // spec 083: recall 補強 — standalone 検索クエリと元質問が異なる場合は元質問でも検索しマージ
        //   Quick モードはスキップ (1 回の keyword 検索で十分)。
        if chatMode == .think, searchQuestion != originalQuestion {
            let rawRetrieval = await retrieve(question: originalQuestion, chatMode: chatMode)
            let rawCandidates = mergeArticleCandidates(retrieval: rawRetrieval)
            var byID: [UUID: (article: Article, similarity: Float)] = [:]
            for candidate in aboveThreshold + rawCandidates {
                if let existing = byID[candidate.article.id], existing.similarity >= candidate.similarity { continue }
                byID[candidate.article.id] = candidate
            }
            aboveThreshold = byID.values
                .sorted { $0.similarity > $1.similarity }
                .prefix(topK)
                .map { (article: $0.article, similarity: $0.similarity) }
            var seenConcepts = Set(conceptPages.map { $0.id })
            for page in rawRetrieval.conceptPages.map({ $0.page }) where !seenConcepts.contains(page.id) {
                conceptPages.append(page)
                seenConcepts.insert(page.id)
            }
        }

        // 4. low-similarity 早期 return
        if aboveThreshold.isEmpty {
            // spec 084: recency/meta 質問 (「最近保存した記事の要点」等) は一般回答でなく直近記事を要約
            if let recent = recencyDigestCandidates(for: originalQuestion) {
                return try await executeFullRAGAnswer(
                    originalQuestion: originalQuestion,
                    aboveThreshold: recent,
                    contextMessages: contextMessages,
                    chatMode: chatMode,
                    in: session
                )
            }
            // KB ミス時は明示 disclaimer + 一般回答 (spec 081)
            return try await persistGeneralKnowledgeAnswer(question: originalQuestion, in: session)
        }

        // 5. 回答生成 (Wiki 文脈を渡す、引用は記事のみ)
        return try await executeFullRAGAnswer(
            originalQuestion: originalQuestion,
            aboveThreshold: aboveThreshold,
            conceptPages: conceptPages,
            contextMessages: contextMessages,
            chatMode: chatMode,
            in: session
        )
    }

    /// spec 081: 記事 cosine 候補 + 概念ページ由来 relatedArticles を merge し、
    /// threshold 以上を similarity desc で top-k 返す。概念由来記事は概念 similarity をスコアとして付与
    /// (強く一致した概念がその関連記事を引き上げる)。記事 id で dedupe、各記事は最大スコアを採用。
    private func mergeArticleCandidates(retrieval: ChatRetrievalResult) -> [(article: Article, similarity: Float)] {
        var byID: [UUID: (article: Article, similarity: Float)] = [:]
        for entry in retrieval.articles {
            byID[entry.article.id] = entry
        }
        for concept in retrieval.conceptPages {
            for article in (concept.page.relatedArticles ?? []) where FeedBuilder.isProcessingComplete(article) {
                if let existing = byID[article.id] {
                    if concept.similarity > existing.similarity {
                        byID[article.id] = (article, concept.similarity)
                    }
                } else {
                    byID[article.id] = (article, concept.similarity)
                }
            }
        }
        return byID.values
            .filter { $0.similarity >= minSimilarity }
            .sorted { $0.similarity > $1.similarity }
            .prefix(topK)
            .map { ($0.article, $0.similarity) }
    }

    /// spec 081: ナレッジベースに該当情報が無い時の一般回答。
    /// 明示 disclaimer を prepend + answeredFromGeneralKnowledge=true (『一般知識』バッジ)。
    /// AI 可なら一般知識答え (HedgePhraseFilter で raw「分かりません」を保険置換)、不可なら固定文。
    private func persistGeneralKnowledgeAnswer(question: String, in session: ChatSession) async throws -> ChatMessage {
        let disclaimer = String(localized: "chat.general.disclaimer")
        let body: String
        if availability.isAvailable, let answer = await tryGenerateFallbackAnswer(question: question) {
            body = HedgePhraseFilter.replace(answer)
        } else {
            body = String(localized: "chat.general.fallbackBody")
        }
        let text = disclaimer + "\n\n" + body
        return try persistAssistant(text: text, citedIDs: [], suggestions: [], generalKnowledge: true, in: session)
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

    /// spec 084: 「最近保存した記事の要点は?」等の recency/meta 質問判定。
    /// 特定トピックではなく「直近の保存記事の要約」を求める質問。recency 語 + meta 語の両方を含む。
    /// (トピック検索が成功する「最近のAI記事」は retrieval ヒット側で処理され、この判定には到達しない)
    static func isRecencyQuery(_ question: String) -> Bool {
        let recency = ["最近", "最新", "今週", "今月", "このごろ", "近頃", "さいきん", "直近"]
        let meta = ["記事", "保存", "まとめ", "要点", "サマリ", "読んだ", "クリップ", "ためた", "ため込", "何を"]
        let hasRecency = recency.contains { question.contains($0) }
        let hasMeta = meta.contains { question.contains($0) }
        return hasRecency && hasMeta
    }

    /// spec 084: 直近保存の (処理完了) 記事を savedAt desc で取得。
    private func fetchRecentArticles(limit: Int) -> [Article] {
        var descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 30
        let all = (try? context.fetch(descriptor)) ?? []
        return Array(all.filter { FeedBuilder.isProcessingComplete($0) }.prefix(limit))
    }

    /// spec 084: recency/meta 質問なら直近記事を引用候補として返す (それ以外は nil)。
    /// retrieval が空振った時の「一般回答」直前に呼び、直近記事の要約に切り替える。
    private func recencyDigestCandidates(for question: String) -> [(article: Article, similarity: Float)]? {
        guard Self.isRecencyQuery(question) else { return nil }
        let recent = fetchRecentArticles(limit: 6)
        guard !recent.isEmpty else { return nil }
        return recent.map { (article: $0, similarity: Float(1.0)) }
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
    /// spec 081: conceptPages は Wiki まとめ文脈 (引用しない、理解の助けのみ)。
    private func executeFullRAGAnswer(
        originalQuestion: String,
        aboveThreshold: [(article: Article, similarity: Float)],
        conceptPages: [ConceptPage] = [],
        contextMessages: [ChatMessage],
        chatMode: ChatMode = .think,
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
                    conceptPages: conceptPages,
                    contextMessages: contextMessages,
                    relatedEntities: relatedEntities,
                    chatMode: chatMode
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

        // 5. post-process
        let trimmedAnswer = answer.answer.trimmingCharacters(in: .whitespacesAndNewlines)

        // spec 083: 回答が空 = LM が「参考記事に答えがない場合は空」ルールに従った
        //   → 取得済み記事はあるが答えられない → 一般回答 + バッジ。
        if trimmedAnswer.isEmpty {
            return try await persistGeneralKnowledgeAnswer(question: trimmed, in: session)
        }

        // spec 083: 関連記事を取得済みで実質的な回答が生成されている場合は回答を活かす。
        //   LM が citedArticleIDs を空で返しても (= ID 列挙忘れ)、回答はその取得済み docs から
        //   生成されているので、上位記事を出典として補完する (grounded、バッジ無し)。
        let availableIDs = Set(aboveThreshold.map { $0.article.id.uuidString })
        var filteredCited = answer.citedArticleIDs.filter { availableIDs.contains($0) }
        if filteredCited.isEmpty {
            filteredCited = aboveThreshold.prefix(3).map { $0.article.id.uuidString }
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

    /// 質問 → top-k 関連記事。
    /// chatMode == .quick の場合は常に keyword 経路 (速度優先、embedding スキップ)。
    /// chatMode == .think の場合は embedding 可なら cosine、不可なら keyword マッチ。
    private func retrieve(question: String, chatMode: ChatMode = .think) async -> ChatRetrievalResult {
        let descriptor = FetchDescriptor<Article>()
        let allArticles = (try? context.fetch(descriptor)) ?? []

        if chatMode == .think, embeddingService.isAvailable, let queryVector = embeddingService.embed(question) {
            // Embedding 経路 + P2-2 ハイブリッド検索 (RRF)。
            // メインスレッドで external-storage embedding を取り出し (faulting)、
            // spec 086: cosine + sort はメインスレッド外で実行 (全記事スキャンは維持 = recall 不変)。
            let corpus: [(id: String, embedding: [Float])] = allArticles.compactMap { article in
                guard let data = article.essenceEmbedding else { return nil }
                return (id: article.id.uuidString, embedding: data.asFloatArray)
            }
            let byID = Dictionary(allArticles.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { a, _ in a })

            // 1. セマンティック: 全 corpus を cosine ランク (recall 不変)。
            let cosineRanked = await Self.rankByCosine(query: queryVector, corpus: corpus, k: corpus.count)
            let cosineSimByID = Dictionary(cosineRanked.map { ($0.id, $0.similarity) }, uniquingKeysWith: { a, _ in a })

            // 2. キーワード: 全記事の語一致スコア (embedding に埋もれる完全一致を拾う)。
            let keywordScored = Self.keywordScore(question: question, articles: allArticles).filter { $0.similarity > 0 }
            let keywordSimByID = Dictionary(
                keywordScored.map { ($0.article.id.uuidString, $0.similarity) },
                uniquingKeysWith: { max($0, $1) }
            )
            let keywordRanking = keywordScored.sorted { $0.similarity > $1.similarity }.map { $0.article.id.uuidString }

            // 3. RRF 融合で top-K の membership を決定 (順位ベースで頑健、スケール差に強い)。
            let fused = SearchService.reciprocalRankFusion(rankings: [cosineRanked.map(\.id), keywordRanking])
            let topResults: [(article: Article, similarity: Float)] = fused.prefix(topK).compactMap { id in
                guard let article = byID[id] else { return nil }
                let cosineSim = cosineSimByID[id] ?? 0
                let kwSim = keywordSimByID[id] ?? 0
                // キーワードが強く一致した記事は cosine が低くても閾値を通す (embedding に埋もれない)。
                let similarity: Float = kwSim >= keywordRescueThreshold ? max(cosineSim, minSimilarity) : cosineSim
                return (article: article, similarity: similarity)
            }
            // spec 081: 同じ query vector で Wiki/概念ページも検索 (文脈 + 引用候補の補完用)
            let topConcepts = await retrieveConcepts(queryVector: queryVector)
            return ChatRetrievalResult(articles: topResults, conceptPages: topConcepts, mode: .embedding)
        } else {
            // Keyword 経路 (embedding 不可、Wiki 文脈はスキップ)
            let scored = Self.keywordScore(question: question, articles: allArticles)
            let topResults = scored
                .sorted { $0.similarity > $1.similarity }
                .prefix(topK)
            return ChatRetrievalResult(articles: Array(topResults), conceptPages: [], mode: .keyword)
        }
    }

    /// spec 081: query vector に対し ConceptPage を cosine top-k で検索。
    /// `!isHidden`・embedding 非 nil・次元一致のみ、conceptMinSimilarity 以上を similarity desc で返す。
    /// spec 086: 有効ページの取り出しはメイン、cosine + sort はメインスレッド外。
    private func retrieveConcepts(queryVector: [Float]) async -> [(page: ConceptPage, similarity: Float)] {
        let descriptor = FetchDescriptor<ConceptPage>()
        let allConcepts = (try? context.fetch(descriptor)) ?? []
        // 次元一致 + 非 hidden の有効ページのみ corpus 化 (faulting はメインで)
        var byID: [String: ConceptPage] = [:]
        let corpus: [(id: String, embedding: [Float])] = allConcepts.compactMap { page in
            guard !page.isHidden, let data = page.embedding else { return nil }
            let vector = data.asFloatArray
            guard vector.count == queryVector.count else { return nil }
            let key = page.id.uuidString
            byID[key] = page
            return (id: key, embedding: vector)
        }
        // 全件ランク → threshold filter → top-k (現挙動と同一: 閾値通過の中から上位)
        let ranked = await Self.rankByCosine(query: queryVector, corpus: corpus, k: corpus.count)
        return ranked
            .filter { $0.similarity >= conceptMinSimilarity }
            .prefix(conceptTopK)
            .compactMap { entry in byID[entry.id].map { ($0, entry.similarity) } }
    }

    /// spec 086: cosine ランキングをメインスレッド外で実行 (純関数 EmbeddingService.topK)。
    /// 空 corpus は即 []。全記事スキャンの CPU をメインから退避しスクロール/入力の jank を防ぐ。
    nonisolated private static func rankByCosine(
        query: [Float],
        corpus: [(id: String, embedding: [Float])],
        k: Int
    ) async -> [(id: String, similarity: Float)] {
        guard !corpus.isEmpty, k > 0 else { return [] }
        return await Task.detached(priority: .userInitiated) {
            EmbeddingService.topK(query: query, corpus: corpus, k: k)
        }.value
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
    /// spec 033: contextMessages で multi-turn 対応。
    /// spec 040: relatedEntities が非空なら「## 関連エンティティ」セクションを記事一覧の後に挿入。
    /// spec 081: 番号引用契約 (本文に裸マーカー `(article-id://UUID)`) + Wiki まとめを文脈に注入 (引用不可)。
    static func buildPrompt(question: String, articles: [Article], conceptPages: [ConceptPage] = [], contextMessages: [ChatMessage] = [], relatedEntities: [GraphNode] = [], chatMode: ChatMode = .think) -> String {
        let quickConstraint = chatMode == .quick ? """

        ## Quick モード制約
        200 字以内で簡潔に答えること。出典は最も重要な 2 件のみ挙げること。
        """ : ""

        var prompt = """
        あなたは Knowledge Base の AI アシスタントです。ユーザーが保存した記事を元に質問に答えます。

        ## ルール
        1. 必ず以下の【参考記事】の内容のみに基づいて回答してください。一般知識から推測してはいけません。
        2. 根拠にした記事は、その根拠となる文の直後に `(article-id://UUID)` というマーカーだけを置いてください。記事タイトルや「[1]」のような番号は本文に書かないでください。例: 「Swift 6 では並行性が強化されました (article-id://12345...)。」
        3. 回答に使った記事の ID は citedArticleIDs フィールドにも列挙してください (Article.id の UUID 文字列)。
        4. 【補足文脈】の Wiki まとめは理解の助けに使ってよいですが、引用 (マーカー / citedArticleIDs) には含めないでください。引用できるのは【参考記事】だけです。
        5. 参考記事に答えがない場合は answer を空文字にし、citedArticleIDs を空配列にしてください。
        6. 簡潔に、3 段落以内で日本語で回答してください。
        7. 直近の会話があれば、文脈を踏まえて回答してください。「詳しく教えて」のような短い質問は直前の話題の深掘りとして扱ってください。
        \(quickConstraint)
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

        // spec 081: Wiki まとめ文脈 (引用しない、理解の助けのみ)。token 安全のため要点 prefix(2) のみ。
        if !conceptPages.isEmpty {
            prompt += "\n## 補足文脈 (Wiki まとめ・引用しない)\n"
            for page in conceptPages.prefix(2) {
                let insights = page.crossSourceInsights.prefix(2).joined(separator: " / ")
                let hint = insights.isEmpty ? page.summary : insights
                let trimmedHint = hint.count > 160 ? String(hint.prefix(160)) + "…" : hint
                prompt += "- \(page.name): \(trimmedHint)\n"
            }
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

    /// spec 057: 汎用 assistant message 永続化 (immediate / clarification / finalAnswer の共通 helper)。
    /// spec 081: generalKnowledge=true で『一般知識』バッジ用フラグを立てる。
    private func persistAssistant(
        text: String,
        citedIDs: [String],
        suggestions: [String],
        generalKnowledge: Bool = false,
        in session: ChatSession
    ) throws -> ChatMessage {
        let assistantMessage = ChatMessage(
            session: session,
            role: ChatMessageRole.assistant.rawValue,
            text: text,
            citedArticleIDs: citedIDs,
            clarificationSuggestions: suggestions,
            answeredFromGeneralKnowledge: generalKnowledge
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
    /// spec 081: 質問に関連する Wiki/概念ページ (文脈 + 引用候補補完用、Wiki 自体は引用しない)。
    var conceptPages: [(page: ConceptPage, similarity: Float)] = []
    let mode: RetrievalMode

    enum RetrievalMode {
        case embedding
        case keyword
    }
}

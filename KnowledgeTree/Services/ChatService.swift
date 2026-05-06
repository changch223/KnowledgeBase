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
    func send(question: String, in session: ChatSession) async throws -> ChatMessage
    /// 新セッション作成 (50 件超過なら最古を FIFO 削除)。
    func createSession() throws -> ChatSession
    /// 全セッション + メッセージ削除。
    func deleteAllSessions() throws
    /// 既存記事への embedding backfill (起動時 / 必要な時に呼び出す)。
    func backfillEmbeddings() async
}

@MainActor
final class ChatService: ChatServiceProtocol {

    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "chat")
    private let context: ModelContext
    private let embeddingService: EmbeddingService
    private let session: LanguageModelSessionProtocol
    private let availability: AvailabilityChecker

    /// 上位 k の retrieval 件数。
    private let topK: Int = 5

    /// 早期 return 用の最低 similarity 閾値。これ未満は「該当する情報が見つからない」と判定。
    private let minSimilarity: Float = 0.3

    /// 1 ユーザーあたりの最大セッション数 (FIFO で古いを削除)。
    private let maxSessions: Int = 50

    init(
        context: ModelContext,
        embeddingService: EmbeddingService,
        session: LanguageModelSessionProtocol,
        availability: AvailabilityChecker = SystemLanguageModelAvailabilityChecker()
    ) {
        self.context = context
        self.embeddingService = embeddingService
        self.session = session
        self.availability = availability
    }

    // MARK: - send

    func send(question: String, in session: ChatSession) async throws -> ChatMessage {
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

        // 2. retrieval
        let retrieval = await retrieve(question: trimmed)
        let retrievedArticles = retrieval.articles

        // 3. low-similarity 早期 return (R7)
        let aboveThreshold = retrievedArticles.filter { $0.similarity >= minSimilarity }
        if aboveThreshold.isEmpty {
            return try persistAssistantUnknown(in: session)
        }

        // 4. 回答生成
        let answer: ChatAnswerOutput
        if availability.isAvailable {
            do {
                let prompt = Self.buildPrompt(question: trimmed, articles: aboveThreshold.map { $0.article })
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

    /// Foundation Models prompt 組立て (R5)。
    static func buildPrompt(question: String, articles: [Article]) -> String {
        var prompt = """
        あなたは知積 (KnowledgeTree) の AI アシスタントです。ユーザーが保存した記事を元に質問に答えます。

        ## ルール
        1. 必ず以下の【参考記事】の内容のみに基づいて回答してください。一般知識から推測してはいけません。
        2. 回答に使った記事の ID は citedArticleIDs フィールドにのみ含めてください (Article.id の UUID 文字列)。
        3. **回答本文 (answer フィールド) には ID や UUID を絶対に書かないでください**。「[1] によれば」のような番号も避け、自然な日本語で要点を伝えてください。
        4. 参考記事に答えがない場合は「分かりません。保存された記事の中に該当する情報が見つかりませんでした。」と回答し、citedArticleIDs を空配列にしてください。
        5. 簡潔に、3 段落以内で日本語で回答してください。

        ## 参考記事
        """

        for (i, article) in articles.enumerated() {
            let essence = article.extractedKnowledge?.essence ?? ""
            let keyFacts = article.extractedKnowledge?.keyFacts.prefix(3).map { $0.statement }.joined(separator: " / ") ?? ""
            prompt += """

            [\(i + 1)] ID: \(article.id.uuidString)
            タイトル: \(article.title)
            要点: \(essence)
            KeyFacts: \(keyFacts)
            """
        }

        prompt += """

        ## ユーザーの質問
        \(question)
        """
        return prompt
    }

    /// 答え本文から UUID 文字列を除去 (LM が prompt に反して書いた場合の保険)。
    /// 標準的な UUID 8-4-4-4-12 形式に加え、それを囲む角括弧 / カッコ / 「ID:」プレフィックスも一緒に除去。
    static func stripUUIDsFromBody(_ text: String) -> String {
        // UUID v4 形式: 8-4-4-4-12 桁の hex
        // 周囲の `[ID: ...]` `(ID: ...)` `「ID: ...」` も同時にマッチ
        let uuidPattern = #"[\[\(「【]*\s*(?:ID\s*[::]\s*)?[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\s*[\]\)」】]*"#
        var result = text.replacingOccurrences(of: uuidPattern, with: "", options: .regularExpression)
        // 連続する空白 / カンマ / 句読点の前後の空白を整理
        result = result.replacingOccurrences(of: #"\s+([、。,.])"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
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
            let facts = article.extractedKnowledge?.keyFacts.prefix(2).map { "  ・\($0.statement)" } ?? []
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
    private func persistAssistantUnknown(in session: ChatSession) throws -> ChatMessage {
        let assistantMessage = ChatMessage(
            session: session,
            role: ChatMessageRole.assistant.rawValue,
            text: "分かりません。保存された記事の中に該当する情報が見つかりませんでした。",
            citedArticleIDs: []
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

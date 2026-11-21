//
//  DeepDiveChatService.swift
//  KnowledgeTree
//
//  spec 044 — 学習タブ「家庭教師」モード専用 chat service。
//
//  既存 ChatService (spec 021) は RAG (retrieval + 類似度閾値 + 「分かりません」guard) 設計のため
//  学習用 chat には合わず以下 2 つの bug を起こしていた:
//    (a) tutor prompt が user message として送信され画面に system prompt が露出
//    (b) tutor prompt は保存記事と類似度が低く early return で「分かりません」連発
//
//  DeepDiveChatService はそれらを根本的に避ける:
//    - LanguageModelSessionProtocol.generateTutorReply で Foundation Models を直接呼ぶ (retrieval なし)
//    - prompt は「instructions + context + 会話履歴 + 最新 user 入力」を毎回構築する stateless 単発
//    - ChatSession + ChatMessage は既存 schema 流用 (UI 表示そのまま)
//    - 初回 AI 発話は user_message を作らず、AI に最初の問いかけだけ生成させる
//    - openedChat 行動履歴は UnderstandingTrackerService 経由で記録
//

import Foundation
import SwiftData
import os

@MainActor
protocol DeepDiveChatServiceProtocol: AnyObject {
    /// 新 ChatSession を作成、家庭教師 prompt で AI の最初の問いかけを生成・永続化して session を返す。
    /// AI 失敗時は fallback メッセージで session を返す (UI 側はそのまま使える)。
    func startTutorSession(for card: UnderstandingCard) async throws -> ChatSession

    /// 既存 tutor session にユーザー発話を追加 + AI 応答を生成・永続化する。
    /// AI 失敗時は fallback メッセージを assistant_message として保存。
    func sendUserMessage(_ text: String, in session: ChatSession, card: UnderstandingCard) async throws -> ChatMessage
}

@MainActor
final class DefaultDeepDiveChatService: DeepDiveChatServiceProtocol {

    private let context: ModelContext
    private let languageSession: LanguageModelSessionProtocol
    private let availability: AvailabilityChecker
    private let tracker: UnderstandingTrackerServiceProtocol?
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "deepdive")

    /// chat 履歴 prompt に含める直近メッセージ数 (token 節約)。
    /// spec 051 spike: 6 → 4 / V3.0 polish: 4 → 2 (4096 token 超過 fix、直前 1 ペアのみ)。
    private let historyWindow: Int = 2

    init(
        context: ModelContext,
        session: LanguageModelSessionProtocol,
        availability: AvailabilityChecker,
        tracker: UnderstandingTrackerServiceProtocol? = nil
    ) {
        self.context = context
        self.languageSession = session
        self.availability = availability
        self.tracker = tracker
    }

    // MARK: - startTutorSession

    func startTutorSession(for card: UnderstandingCard) async throws -> ChatSession {
        let chatSession = ChatSession(title: card.deepDiveTitle, modeRaw: ChatSessionMode.deepDive.rawValue)
        context.insert(chatSession)
        try context.save()

        let replyText = await generateInitialQuestion(for: card)
        // spec 051 spike: cancellation 時は fallback を使う (初回 AI 発話ゼロだと UI が空っぽで困るため)
        let safeReply = replyText.isEmpty ? fallbackInitial(for: card) : replyText
        let assistantMessage = ChatMessage(
            session: chatSession,
            role: ChatMessageRole.assistant.rawValue,
            text: safeReply
        )
        context.insert(assistantMessage)
        chatSession.lastMessageAt = .now
        try context.save()

        // openedChat 履歴記録 (失敗しても session は返却)
        if let tracker {
            do {
                try await tracker.recordOpenedChat(card: card)
            } catch {
                logger.error("recordOpenedChat failed: \(String(describing: error), privacy: .public)")
            }
        }

        return chatSession
    }

    // MARK: - sendUserMessage

    func sendUserMessage(_ text: String, in session: ChatSession, card: UnderstandingCard) async throws -> ChatMessage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DeepDiveChatError.emptyInput
        }

        // 1. user message 永続化
        let userMessage = ChatMessage(
            session: session,
            role: ChatMessageRole.user.rawValue,
            text: trimmed
        )
        context.insert(userMessage)
        session.lastMessageAt = .now
        try context.save()

        // 2. 会話履歴を含む tutor prompt 構築
        let history = (session.messages ?? []).sorted { $0.timestamp < $1.timestamp }
        let prompt = Self.buildContinuationPrompt(card: card, history: history, historyWindow: historyWindow)

        // 3. AI 応答生成
        let replyText = await generateReply(prompt: prompt, fallbackHint: fallbackContinuation(for: card))

        // spec 051 spike: cancellation 時は empty 返却 → assistant message 永続化スキップ
        // (画面遷移で task cancel された場合、空 message を作らず user message だけ残す)
        guard !replyText.isEmpty else {
            throw DeepDiveChatError.cancelled
        }

        // 4. assistant message 永続化
        let assistantMessage = ChatMessage(
            session: session,
            role: ChatMessageRole.assistant.rawValue,
            text: replyText
        )
        context.insert(assistantMessage)
        session.lastMessageAt = .now
        try context.save()

        return assistantMessage
    }

    // MARK: - private: prompt builders

    /// 初回 AI 発話用 prompt — 「ユーザーがこれから何を学びたいか」を聞き出す質問 1 つを返す。
    /// i18n Phase B: 出力言語は `language` (既定 `PipelineLanguage.current`) に追従する。
    static func buildInitialPrompt(for card: UnderstandingCard, language: PipelineLanguage = .current) -> String {
        if !PromptLocalizer.usesJapaneseInstructions(language) {
            return """
            \(PromptLocalizer.outputLanguageHeaderGeneral(language))
            You are a warm, calm tutor. Help the student (the user) deeply understand "\(card.deepDiveTitleFormatArg)".

            [Your role]
            - Do not just state answers; draw out the student's questions and explain step by step
            - Use analogies when helpful and avoid abstract explanations
            - Do not talk long at once (2-4 short paragraphs of 1-3 sentences each)

            \(buildContextBlock(for: card, language: language))

            [Your response now]
            This is the first exchange with the student. First ask ONE short question: "what do you most want to know about this concept right now?"
            Reply with a single question, not an answer. No preamble or "Understood"; start with the question directly.

            \(PromptLocalizer.outputLanguageFooter(language))
            """
        }
        let context = buildContextBlock(for: card, language: language)
        return """
        あなたは温かく落ち着いた「家庭教師」です。生徒 (ユーザー) が「\(card.deepDiveTitleFormatArg)」を深く理解できるよう助けてください。
        出力言語: \(language.endonym)。スキーマの説明文が日本語でも、出力は必ず \(language.endonym) で書くこと。

        【あなたの役割】
        - 一方的に答えを述べるのではなく、生徒の疑問や知りたいことを引き出しながら少しずつ説明する
        - 必要なら例え話を使い、抽象的すぎる説明は避ける
        - 1 度に長く話さない (2-4 段落、各 50-150 字)

        \(context)

        【今すぐの応答】
        生徒との初めての対話です。まず「この概念について、今いちばん気になっていること」を 1 つだけ短く問いかけてください。
        答えではなく、質問を 1 つだけ返してください。前置きや「了解しました」等の応答は不要、いきなり質問を書き始めてください。
        \(language.outputInstruction)
        """
    }

    /// 継続 AI 発話用 prompt — 履歴 + 最新 user 入力に応じて家庭教師として応答。
    /// i18n Phase B: 出力言語は `language` (既定 `PipelineLanguage.current`) に追従する。
    static func buildContinuationPrompt(card: UnderstandingCard, history: [ChatMessage], historyWindow: Int = 2, language: PipelineLanguage = .current) -> String {
        let contextBlock = buildContextBlock(for: card, language: language)
        let historyBlock = formatHistory(history, window: historyWindow, language: language)
        if !PromptLocalizer.usesJapaneseInstructions(language) {
            return """
            \(PromptLocalizer.outputLanguageHeaderGeneral(language))
            You are a warm, calm tutor. Help the student (the user) deeply understand "\(card.deepDiveTitleFormatArg)".

            [Your role]
            - Beyond giving answers, use analogies and counter-questions so the student truly understands
            - Do not talk long at once (2-4 short paragraphs of 1-3 sentences each)
            - Use the supporting information, and general knowledge if needed (without exaggeration; state clearly where you are unsure)

            \(contextBlock)

            [Conversation so far]
            \(historyBlock)

            [Your response now]
            Reply to the student's latest message as a tutor. No preamble; start with the reply itself.

            \(PromptLocalizer.outputLanguageFooter(language))
            """
        }
        return """
        あなたは温かく落ち着いた「家庭教師」です。生徒 (ユーザー) が「\(card.deepDiveTitleFormatArg)」を深く理解できるよう助けてください。
        出力言語: \(language.endonym)。スキーマの説明文が日本語でも、出力は必ず \(language.endonym) で書くこと。

        【あなたの役割】
        - 答えだけでなく、生徒が腹落ちできるよう例え話や逆質問を使う
        - 1 度に長く話さない (2-4 段落、各 50-150 字)
        - 補助情報は参考にしつつ、必要なら一般知識も使ってよい (ただし誇張せず、確信が低い箇所は明示)

        \(contextBlock)

        【これまでの対話】
        \(historyBlock)

        【今すぐの応答】
        最新の生徒発言に対し、家庭教師として返答してください。前置き不要、いきなり本文を書き始めてください。
        \(language.outputInstruction)
        """
    }

    /// concept / saved answer の補助情報を block 化。
    /// V3.0 polish: 4096 token 連発 fix のため更に圧縮。
    /// summary 200→120, insight 80×2→60×1, 関連記事 60×2→50×1。
    static func buildContextBlock(for card: UnderstandingCard, language: PipelineLanguage = .current) -> String {
        if !PromptLocalizer.usesJapaneseInstructions(language) {
            switch card.kind {
            case .conceptPage(let page):
                var parts: [String] = []
                if !page.summary.isEmpty {
                    parts.append("[Concept summary]\n\(page.summary.prefix(120))")
                }
                if let first = page.crossSourceInsights.first {
                    parts.append("[Key insight]\n  \(first.prefix(60))")
                }
                if let latest = (page.relatedArticles ?? [])
                    .sorted(by: { $0.savedAt > $1.savedAt })
                    .first
                {
                    parts.append("[Reference article]\n  - \(latest.title.prefix(50))")
                }
                return parts.isEmpty ? "" : parts.joined(separator: "\n\n")
            case .savedAnswer(let answer):
                let q = answer.question.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)
                let a = answer.answer.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120)
                return """
                [Previous question]
                \(q)

                [Previous answer (excerpt)]
                \(a)
                """
            }
        }
        switch card.kind {
        case .conceptPage(let page):
            var parts: [String] = []
            if !page.summary.isEmpty {
                parts.append("【概念サマリ】\n\(page.summary.prefix(120))")
            }
            if let first = page.crossSourceInsights.first {
                parts.append("【主な知見】\n  \(first.prefix(60))")
            }
            if let latest = (page.relatedArticles ?? [])
                .sorted(by: { $0.savedAt > $1.savedAt })
                .first
            {
                parts.append("【参考記事】\n  - \(latest.title.prefix(50))")
            }
            return parts.isEmpty ? "" : parts.joined(separator: "\n\n")
        case .savedAnswer(let answer):
            // V3.0 polish: 120/180 → 80/120 に再圧縮
            let q = answer.question.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)
            let a = answer.answer.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120)
            return """
            【前回の質問】
            \(q)

            【前回の答え (抜粋)】
            \(a)
            """
        }
    }

    /// chat 履歴を「生徒:」「あなた:」形式の plain text に整形 (直近 historyWindow 件)。
    static func formatHistory(_ history: [ChatMessage], window: Int = 2, language: PipelineLanguage = .current) -> String {
        let recent = Array(history.suffix(window))
        let english = !PromptLocalizer.usesJapaneseInstructions(language)
        if recent.isEmpty {
            return english ? "(No conversation yet)" : "(まだ対話はありません)"
        }
        return recent.map { msg -> String in
            let isUser = msg.role == ChatMessageRole.user.rawValue
            let speaker = english ? (isUser ? "Student" : "You") : (isUser ? "生徒" : "あなた")
            return "\(speaker): \(msg.text)"
        }.joined(separator: "\n\n")
    }

    // MARK: - private: AI invocation

    private func generateInitialQuestion(for card: UnderstandingCard) async -> String {
        let prompt = Self.buildInitialPrompt(for: card)
        return await generateReply(prompt: prompt, fallbackHint: fallbackInitial(for: card))
    }

    /// Foundation Models を呼ぶ。availability 不可 / throws / 空応答時は fallback 文字列を返す。
    private func generateReply(prompt: String, fallbackHint: String) async -> String {
        guard availability.isAvailable else {
            logger.notice("Apple Intelligence unavailable, using fallback")
            return fallbackHint
        }
        do {
            let raw = try await languageSession.generateTutorReply(prompt: prompt)
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                logger.notice("empty tutor reply, using fallback")
                return fallbackHint
            }
            return trimmed
        } catch is CancellationError {
            // spec 051 spike: ユーザーが画面遷移 / app background で task が cancel されたケース
            // → silent (error log なし)、empty 文字列返却で UI は何も追加しない
            logger.notice("generateTutorReply cancelled (user navigated away)")
            return ""
        } catch {
            logger.error("generateTutorReply failed: \(String(describing: error), privacy: .public)")
            return fallbackHint
        }
    }

    // MARK: - fallback strings (Apple Intelligence 不可時)

    private func fallbackInitial(for card: UnderstandingCard) -> String {
        switch card.kind {
        case .conceptPage(let page):
            return String(format: String(localized: "deepdive.fallback.initial.concept"), page.name)
        case .savedAnswer:
            return String(localized: "deepdive.fallback.initial.saved")
        }
    }

    private func fallbackContinuation(for card: UnderstandingCard) -> String {
        switch card.kind {
        case .conceptPage(let page) where !page.summary.isEmpty:
            return String(format: String(localized: "deepdive.fallback.continuation.summary"), String(page.summary.prefix(300)))
        default:
            return String(localized: "deepdive.fallback.continuation.default")
        }
    }
}

// MARK: - Error

enum DeepDiveChatError: Error {
    case emptyInput
    /// spec 051 spike: ユーザーが画面遷移 / app background で AI 応答が cancel されたケース
    case cancelled
}

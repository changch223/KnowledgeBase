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
    private let historyWindow: Int = 6

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
        let chatSession = ChatSession(title: card.deepDiveTitle)
        context.insert(chatSession)
        try context.save()

        let replyText = await generateInitialQuestion(for: card)
        let assistantMessage = ChatMessage(
            session: chatSession,
            role: ChatMessageRole.assistant.rawValue,
            text: replyText
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
        let history = session.messages.sorted { $0.timestamp < $1.timestamp }
        let prompt = buildContinuationPrompt(card: card, history: history)

        // 3. AI 応答生成
        let replyText = await generateReply(prompt: prompt, fallbackHint: fallbackContinuation(for: card))

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
    private func buildInitialPrompt(for card: UnderstandingCard) -> String {
        let context = buildContextBlock(for: card)
        return """
        あなたは温かく落ち着いた「家庭教師」です。生徒 (ユーザー) が「\(card.deepDiveTitleFormatArg)」を深く理解できるよう助けてください。

        【あなたの役割】
        - 一方的に答えを述べるのではなく、生徒の疑問や知りたいことを引き出しながら少しずつ説明する
        - 必要なら例え話を使い、抽象的すぎる説明は避ける
        - 1 度に長く話さない (2-4 段落、各 50-150 字)

        \(context)

        【今すぐの応答】
        生徒との初めての対話です。まず「この概念について、今いちばん気になっていること」を 1 つだけ短く問いかけてください。
        答えではなく、質問を 1 つだけ返してください。前置きや「了解しました」等の応答は不要、いきなり質問を書き始めてください。
        """
    }

    /// 継続 AI 発話用 prompt — 履歴 + 最新 user 入力に応じて家庭教師として応答。
    private func buildContinuationPrompt(card: UnderstandingCard, history: [ChatMessage]) -> String {
        let contextBlock = buildContextBlock(for: card)
        let historyBlock = formatHistory(history)
        return """
        あなたは温かく落ち着いた「家庭教師」です。生徒 (ユーザー) が「\(card.deepDiveTitleFormatArg)」を深く理解できるよう助けてください。

        【あなたの役割】
        - 答えだけでなく、生徒が腹落ちできるよう例え話や逆質問を使う
        - 1 度に長く話さない (2-4 段落、各 50-150 字)
        - 補助情報は参考にしつつ、必要なら一般知識も使ってよい (ただし誇張せず、確信が低い箇所は明示)

        \(contextBlock)

        【これまでの対話】
        \(historyBlock)

        【今すぐの応答】
        最新の生徒発言に対し、家庭教師として返答してください。前置き不要、いきなり本文を書き始めてください。
        """
    }

    /// concept / saved answer の補助情報を block 化。
    private func buildContextBlock(for card: UnderstandingCard) -> String {
        switch card.kind {
        case .conceptPage(let page):
            var parts: [String] = []
            if !page.summary.isEmpty {
                parts.append("【概念サマリ】\n\(page.summary.prefix(400))")
            }
            if !page.crossSourceInsights.isEmpty {
                let bullets = page.crossSourceInsights
                    .prefix(3)
                    .enumerated()
                    .map { i, s in "  \(i + 1). \(s.prefix(150))" }
                    .joined(separator: "\n")
                parts.append("【主な知見】\n\(bullets)")
            }
            let articleTitles = page.relatedArticles
                .sorted { $0.savedAt > $1.savedAt }
                .prefix(3)
                .map { "  - \($0.title.prefix(80))" }
                .joined(separator: "\n")
            if !articleTitles.isEmpty {
                parts.append("【参考記事 (上位 3)】\n\(articleTitles)")
            }
            return parts.isEmpty ? "" : parts.joined(separator: "\n\n")
        case .savedAnswer(let answer):
            let q = answer.question.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200)
            let a = answer.answer.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300)
            return """
            【前回の質問】
            \(q)

            【前回の答え (抜粋)】
            \(a)
            """
        }
    }

    /// chat 履歴を「生徒:」「あなた:」形式の plain text に整形 (直近 historyWindow 件)。
    private func formatHistory(_ history: [ChatMessage]) -> String {
        let recent = Array(history.suffix(historyWindow))
        if recent.isEmpty {
            return "(まだ対話はありません)"
        }
        return recent.map { msg -> String in
            let speaker = msg.role == ChatMessageRole.user.rawValue ? "生徒" : "あなた"
            return "\(speaker): \(msg.text)"
        }.joined(separator: "\n\n")
    }

    // MARK: - private: AI invocation

    private func generateInitialQuestion(for card: UnderstandingCard) async -> String {
        let prompt = buildInitialPrompt(for: card)
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
        } catch {
            logger.error("generateTutorReply failed: \(String(describing: error), privacy: .public)")
            return fallbackHint
        }
    }

    // MARK: - fallback strings (Apple Intelligence 不可時)

    private func fallbackInitial(for card: UnderstandingCard) -> String {
        switch card.kind {
        case .conceptPage(let page):
            return "「\(page.name)」について、今いちばん気になっていることを教えてください。"
        case .savedAnswer:
            return "前回の答えについて、特にどの部分をもっと深く知りたいですか?"
        }
    }

    private func fallbackContinuation(for card: UnderstandingCard) -> String {
        switch card.kind {
        case .conceptPage(let page) where !page.summary.isEmpty:
            return "(AI が応答できないため、保存されているサマリの抜粋を共有します)\n\n\(page.summary.prefix(300))"
        default:
            return "申し訳ありません。今は AI が応答できません。少し時間をおいて再度お試しください。"
        }
    }
}

// MARK: - Error

enum DeepDiveChatError: Error {
    case emptyInput
}

//
//  DeepDiveChatStarter.swift
//  KnowledgeTree
//
//  spec 044 — 学習タブのカードタップで AI と「家庭教師」モードの対話を起動する wrapper service。
//
//  既存 spec 021 ChatService.createSession() + send() をそのまま使い、
//  prompt 先頭に「あなたは家庭教師として...」context を注入することで AI を逆質問モードに切り替える。
//
//  - chat session title はカード由来 (「{name} を深掘り」)
//  - 初期発話は AI 自動生成 (空 input ではなく tutor prompt として送信)
//  - 起動と同時に UnderstandingTrackerService.recordOpenedChat() で行動履歴を記録
//

import Foundation
import os

@MainActor
protocol DeepDiveChatStarterProtocol: AnyObject {
    /// カードを起点に新 ChatSession + 初期 AI 発話 + openedChat 履歴記録を行い、ChatSession を返す。
    /// AI 発話生成中の throws はそのまま伝播 (UI 側で fallback)。
    func startChat(for card: UnderstandingCard) async throws -> ChatSession
}

@MainActor
final class DefaultDeepDiveChatStarter: DeepDiveChatStarterProtocol {

    private let chatService: ChatServiceProtocol
    private let tracker: UnderstandingTrackerServiceProtocol
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "deepdive")

    init(chatService: ChatServiceProtocol, tracker: UnderstandingTrackerServiceProtocol) {
        self.chatService = chatService
        self.tracker = tracker
    }

    func startChat(for card: UnderstandingCard) async throws -> ChatSession {
        let session = try chatService.createSession()
        session.title = card.deepDiveTitle

        let context = buildTutorContext(for: card)
        do {
            _ = try await chatService.send(question: context, in: session, contextMessages: [])
        } catch {
            // AI 発話失敗時は session は残し、UI 側で再質問可能にする
            logger.error("deep dive initial ask failed: \(String(describing: error), privacy: .public)")
        }

        // openedChat 履歴記録 (失敗しても session は返却)
        do {
            try await tracker.recordOpenedChat(card: card)
        } catch {
            logger.error("recordOpenedChat failed: \(String(describing: error), privacy: .public)")
        }

        return session
    }

    // MARK: - tutor prompt builder

    private func buildTutorContext(for card: UnderstandingCard) -> String {
        let head = """
        あなたは家庭教師として、ユーザーが「\(card.deepDiveTitleFormatArg)」を腹落ちするまで助けてください。
        質問に答えるだけでなく、ユーザーの理解度を確認する逆質問や、関連する保存記事への参照を促してください。
        """

        let body: String
        switch card.kind {
        case .conceptPage(let page):
            var parts: [String] = []
            if !page.summary.isEmpty {
                parts.append("【現在の概念サマリ】\n\(page.summary.prefix(300))")
            }
            if !page.crossSourceInsights.isEmpty {
                let bullets = page.crossSourceInsights.prefix(3).map { "  - \($0.prefix(120))" }.joined(separator: "\n")
                parts.append("【主な知見】\n\(bullets)")
            }
            body = parts.joined(separator: "\n\n")
        case .savedAnswer(let answer):
            let q = answer.question.trimmingCharacters(in: .whitespacesAndNewlines)
            let a = answer.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            body = """
            【前回の質問】
            \(q.prefix(200))

            【前回の答え (抜粋)】
            \(a.prefix(200))
            """
        }

        let footer = """
        【最初の発話】
        ユーザーがこの内容について現時点で気になっていることは何かを 1 つ問いかけてください。
        答えではなく、質問を返してください。
        """

        if body.isEmpty {
            return [head, footer].joined(separator: "\n\n")
        }
        return [head, body, footer].joined(separator: "\n\n")
    }
}

//
//  ChatSession.swift
//  KnowledgeTree
//
//  spec 021 — AI Chat (RAG) のチャットセッション。
//  - messages: cascade delete で session 削除時に全 message も削除
//  - title: 最初の user message の先頭 30 文字 (空なら「新しいチャット」)
//  - 50 件 FIFO 制限は ChatService.createSession() で実施
//

import Foundation
import SwiftData

@Model
final class ChatSession {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var lastMessageAt: Date = Date.now
    var title: String = ""

    /// "general" (AI チャットタブ通常) / "deepDive" (学習カード経由の深掘り)。
    /// V3.0 polish (2026-05-24): 履歴で 2 種を区別表示するため追加。
    /// SwiftData lightweight migration: default "general" で既存 session を全て一般扱い。
    var modeRaw: String = "general"

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var messages: [ChatMessage]? = []

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        lastMessageAt: Date = .now,
        title: String = "",
        modeRaw: String = "general"
    ) {
        self.id = id
        self.createdAt = createdAt
        self.lastMessageAt = lastMessageAt
        self.title = title
        self.modeRaw = modeRaw
    }
}

/// ChatSession の用途分類。SwiftData 永続化は modeRaw (String) 経由。
enum ChatSessionMode: String {
    /// AI チャットタブで作成された通常 session。
    case general
    /// 学習カード「もっと深く」経由で DeepDiveChatService が作成した家庭教師 session。
    case deepDive
}

extension ChatSession {
    var mode: ChatSessionMode {
        ChatSessionMode(rawValue: modeRaw) ?? .general
    }
}

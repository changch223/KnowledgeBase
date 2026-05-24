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

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var messages: [ChatMessage] = []

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        lastMessageAt: Date = .now,
        title: String = ""
    ) {
        self.id = id
        self.createdAt = createdAt
        self.lastMessageAt = lastMessageAt
        self.title = title
    }
}

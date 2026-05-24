//
//  ChatMessage.swift
//  KnowledgeTree
//
//  spec 021 — AI Chat (RAG) の 1 メッセージ。
//  - role: "user" or "assistant" (enum 化は SwiftData 制約のため String)
//  - citedArticleIDs: Article.id (UUID 文字列) 配列、role == "assistant" 時のみ意味あり
//      Article への直接 @Relationship は使わない (R8):
//      - 履歴の不変性: 引用元 Article が削除されても会話履歴は残る
//      - 循環参照回避: Article ↔ ChatMessage 双方向 relationship を avoid
//

import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID = UUID()
    var session: ChatSession?
    var role: String = ""
    var text: String = ""
    var citedArticleIDs: [String] = []
    var timestamp: Date = Date.now

    init(
        id: UUID = UUID(),
        session: ChatSession?,
        role: String,
        text: String,
        citedArticleIDs: [String] = [],
        timestamp: Date = Date.now
    ) {
        self.id = id
        self.session = session
        self.role = role
        self.text = text
        self.citedArticleIDs = citedArticleIDs
        self.timestamp = timestamp
    }
}

/// `ChatMessage.role` の許容値。SwiftData @Attribute としては String を使うが、
/// アプリ内の比較は本 enum 経由で行う (typo 抑止)。
enum ChatMessageRole: String {
    case user
    case assistant
}

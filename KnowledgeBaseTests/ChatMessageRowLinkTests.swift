//
//  ChatMessageRowLinkTests.swift
//  KnowledgeTreeTests
//
//  spec 059 (P0-4) — 引用リンク `article-id://UUID` の UUID 抽出を検証。
//  ChatMessageRow.extractArticleID は OpenURLAction の遷移判定に使われる。
//

import Testing
import Foundation
@testable import KnowledgeBase

@MainActor
struct ChatMessageRowLinkTests {

    @Test func testExtractsValidArticleID() throws {
        let uuid = UUID()
        let url = try #require(URL(string: "article-id://\(uuid.uuidString)"))
        #expect(ChatMessageRow.extractArticleID(from: url) == uuid)
    }

    @Test func testRejectsNonArticleScheme() throws {
        let url = try #require(URL(string: "https://example.com/\(UUID().uuidString)"))
        #expect(ChatMessageRow.extractArticleID(from: url) == nil)
    }

    @Test func testRejectsMalformedUUID() throws {
        let url = try #require(URL(string: "article-id://not-a-uuid"))
        #expect(ChatMessageRow.extractArticleID(from: url) == nil)
    }
}

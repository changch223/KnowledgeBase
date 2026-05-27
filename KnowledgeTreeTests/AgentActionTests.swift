//
//  AgentActionTests.swift
//  KnowledgeTreeTests
//
//  spec 057 — AgentAction enum + AgentActionOutput → AgentAction 変換のテスト 10 ケース。
//

import Testing
import Foundation
@testable import KnowledgeTree

@MainActor
struct AgentActionTests {

    // MARK: - 1. immediate type 解析

    @Test func testImmediateActionType() {
        let output = AgentActionOutput(
            actionType: "immediate",
            text: "Tim Cook は Apple の CEO です。",
            suggestions: [],
            citedArticleIDs: []
        )
        let action = AgentAction(from: output)

        if case .immediate(let answer) = action {
            #expect(answer == "Tim Cook は Apple の CEO です。")
        } else {
            Issue.record("Expected .immediate but got \(action)")
        }
    }

    // MARK: - 2. askClarification type 解析

    @Test func testAskClarificationActionType() {
        let output = AgentActionOutput(
            actionType: "askClarification",
            text: "Apple について、どの面を知りたいですか?",
            suggestions: ["Tim Cook の経歴", "Vision Pro", "株価"],
            citedArticleIDs: []
        )
        let action = AgentAction(from: output)

        if case .askClarification(let q, let s) = action {
            #expect(q == "Apple について、どの面を知りたいですか?")
            #expect(s == ["Tim Cook の経歴", "Vision Pro", "株価"])
        } else {
            Issue.record("Expected .askClarification but got \(action)")
        }
    }

    // MARK: - 3. searchArticles type 解析

    @Test func testSearchArticlesActionType() {
        let output = AgentActionOutput(
            actionType: "searchArticles",
            text: "Tim Cook",
            suggestions: [],
            citedArticleIDs: []
        )
        let action = AgentAction(from: output)

        if case .searchArticles(let query) = action {
            #expect(query == "Tim Cook")
        } else {
            Issue.record("Expected .searchArticles but got \(action)")
        }
    }

    // MARK: - 4. finalAnswer type 解析 (UUID 変換)

    @Test func testFinalAnswerActionType() {
        let uuid1 = UUID()
        let uuid2 = UUID()
        let output = AgentActionOutput(
            actionType: "finalAnswer",
            text: "保存記事によると、Tim Cook は Apple の CEO です。",
            suggestions: [],
            citedArticleIDs: [uuid1.uuidString, uuid2.uuidString]
        )
        let action = AgentAction(from: output)

        if case .finalAnswer(let text, let ids) = action {
            #expect(text == "保存記事によると、Tim Cook は Apple の CEO です。")
            #expect(ids.count == 2)
            #expect(ids.contains(uuid1))
            #expect(ids.contains(uuid2))
        } else {
            Issue.record("Expected .finalAnswer but got \(action)")
        }
    }

    // MARK: - 5. actionType 大小文字無視

    @Test func testActionTypeCaseInsensitive() {
        let output = AgentActionOutput(
            actionType: "IMMEDIATE",  // 大文字
            text: "test",
            suggestions: [],
            citedArticleIDs: []
        )
        let action = AgentAction(from: output)

        if case .immediate = action {
            // OK
        } else {
            Issue.record("Expected .immediate")
        }
    }

    // MARK: - 6. snake_case actionType 対応

    @Test func testSnakeCaseActionType() {
        let output = AgentActionOutput(
            actionType: "ask_clarification",
            text: "聞き返し",
            suggestions: ["a", "b", "c"],
            citedArticleIDs: []
        )
        let action = AgentAction(from: output)

        if case .askClarification = action {
            // OK
        } else {
            Issue.record("Expected .askClarification")
        }
    }

    // MARK: - 7. 不正な actionType → .immediate fallback

    @Test func testUnknownActionTypeFallsBackToImmediate() {
        let output = AgentActionOutput(
            actionType: "weirdType",
            text: "fallback content",
            suggestions: [],
            citedArticleIDs: []
        )
        let action = AgentAction(from: output)

        if case .immediate(let answer) = action {
            #expect(answer == "fallback content")
        } else {
            Issue.record("Expected .immediate fallback")
        }
    }

    // MARK: - 8. askClarification の suggestions 3 件未満 → 空文字で埋めて 3 件

    @Test func testClarificationSuggestionsPaddedToThree() {
        let output = AgentActionOutput(
            actionType: "askClarification",
            text: "聞き返し",
            suggestions: ["1 つだけ"],
            citedArticleIDs: []
        )
        let action = AgentAction(from: output)

        if case .askClarification(_, let s) = action {
            #expect(s.count == 3)
            #expect(s[0] == "1 つだけ")
            #expect(s[1] == "")
            #expect(s[2] == "")
        } else {
            Issue.record("Expected .askClarification with 3 suggestions")
        }
    }

    // MARK: - 9. askClarification の suggestions 4 件以上 → 3 件 truncate

    @Test func testClarificationSuggestionsTruncatedToThree() {
        let output = AgentActionOutput(
            actionType: "askClarification",
            text: "聞き返し",
            suggestions: ["a", "b", "c", "d", "e"],
            citedArticleIDs: []
        )
        let action = AgentAction(from: output)

        if case .askClarification(_, let s) = action {
            #expect(s.count == 3)
            #expect(s == ["a", "b", "c"])
        } else {
            Issue.record("Expected .askClarification with 3 suggestions")
        }
    }

    // MARK: - 10. finalAnswer citedArticleIDs 5 件超過 → 5 件 truncate

    @Test func testFinalAnswerCitedIDsTruncatedToFive() {
        let uuids = (0..<7).map { _ in UUID() }
        let output = AgentActionOutput(
            actionType: "finalAnswer",
            text: "test",
            suggestions: [],
            citedArticleIDs: uuids.map { $0.uuidString }
        )
        let action = AgentAction(from: output)

        if case .finalAnswer(_, let ids) = action {
            #expect(ids.count == 5)
        } else {
            Issue.record("Expected .finalAnswer with 5 ids")
        }
    }

    // MARK: - 11. AgentAction.suggestions convenience

    @Test func testSuggestionsConvenience() {
        let clar = AgentAction.askClarification(question: "?", suggestions: ["a", "", "c"])
        #expect(clar.suggestions == ["a", "c"])  // 空文字は filter

        let imm = AgentAction.immediate(answer: "test")
        #expect(imm.suggestions.isEmpty)
    }

    // MARK: - 12. AgentAction.citedArticleIDs convenience

    @Test func testCitedArticleIDsConvenience() {
        let uuid = UUID()
        let final = AgentAction.finalAnswer(text: "test", citedArticleIDs: [uuid])
        #expect(final.citedArticleIDs == [uuid])

        let imm = AgentAction.immediate(answer: "test")
        #expect(imm.citedArticleIDs.isEmpty)
    }
}

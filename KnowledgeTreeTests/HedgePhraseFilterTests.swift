//
//  HedgePhraseFilterTests.swift
//  KnowledgeTreeTests
//
//  spec 057 — HedgePhraseFilter (banned phrase 排除) のテスト。
//

import Testing
@testable import KnowledgeTree

@MainActor
struct HedgePhraseFilterTests {

    @Test func testReplacesBannedPhrases() {
        let input = "それは分かりません。"
        let result = HedgePhraseFilter.replace(input, randomSource: { 0 })
        // "分かりません" → "私の理解では" 等に置換
        #expect(!result.contains("分かりません"))
        #expect(HedgePhraseFilter.hedgeReplacements.contains { result.contains($0) })
    }

    @Test func testReplacesMultipleBannedPhrases() {
        let input = "情報がありません。お答えできません。"
        let result = HedgePhraseFilter.replace(input, randomSource: { 0 })
        #expect(!result.contains("情報がありません"))
        #expect(!result.contains("お答えできません"))
    }

    @Test func testPreservesTextWithoutBannedPhrases() {
        let input = "Tim Cook は Apple の CEO です。"
        let result = HedgePhraseFilter.replace(input)
        #expect(result == input)
    }

    @Test func testContainsBannedReturnsTrue() {
        #expect(HedgePhraseFilter.containsBanned("これは知りません"))
        #expect(HedgePhraseFilter.containsBanned("回答できません"))
    }

    @Test func testContainsBannedReturnsFalse() {
        #expect(!HedgePhraseFilter.containsBanned("これは私の理解では"))
        #expect(!HedgePhraseFilter.containsBanned("Apple の CEO は Tim Cook"))
    }

    @Test func testDeterministicWithFixedRandom() {
        let input = "分かりません"
        let result = HedgePhraseFilter.replace(input, randomSource: { 0 })
        // 最初の hedgeReplacements を選ぶ
        #expect(result == HedgePhraseFilter.hedgeReplacements[0])
    }
}

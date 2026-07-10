//
//  ChineseScriptNormalizerTests.swift
//  KnowledgeTreeTests
//
//  i18n Phase B — ChineseScriptNormalizer.toSimplified 純関数のテスト。
//

import Testing
import Foundation
@testable import KnowledgeBase

struct ChineseScriptNormalizerTests {

    // MARK: - 1. 繁体字 → 簡体字

    @Test func testConvertsTraditionalToSimplified() {
        #expect(ChineseScriptNormalizer.toSimplified("資訊") == "资讯")
        #expect(ChineseScriptNormalizer.toSimplified("學術") == "学术")
    }

    // MARK: - 2. 既に簡体字なら素通り

    @Test func testSimplifiedTextPassesThrough() {
        #expect(ChineseScriptNormalizer.toSimplified("资讯") == "资讯")
        #expect(ChineseScriptNormalizer.toSimplified("学术") == "学术")
    }

    // MARK: - 3. 日本語 (仮名) / 英語は不変

    @Test func testJapaneseKanaAndEnglishAreUnchanged() {
        #expect(ChineseScriptNormalizer.toSimplified("これはテストです") == "これはテストです")
        #expect(ChineseScriptNormalizer.toSimplified("This is a test sentence.") == "This is a test sentence.")
    }

    // MARK: - 4. 空文字

    @Test func testEmptyStringReturnsEmpty() {
        #expect(ChineseScriptNormalizer.toSimplified("") == "")
    }
}

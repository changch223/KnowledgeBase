//
//  ConceptNameNormalizerTests.swift
//  KnowledgeTreeTests
//
//  spec 078 — 概念名 canonical 正規化 (全角半角 / かな / case / 空白) の検証。
//

import Testing
import Foundation
@testable import KnowledgeTree

@MainActor
struct ConceptNameNormalizerTests {

    @Test func foldsFullwidthAndCase() {
        #expect(ConceptNameNormalizer.canonical("ＡＰＰＬＥ") == "apple")  // 全角英字 → 半角小文字
        #expect(ConceptNameNormalizer.canonical("Apple") == "apple")
        #expect(ConceptNameNormalizer.canonical("  Apple  ") == "apple")  // trim
    }

    @Test func unifiesKana() {
        let kata = ConceptNameNormalizer.canonical("アップル")    // 全角カタカナ
        let hira = ConceptNameNormalizer.canonical("あっぷる")    // ひらがな
        let half = ConceptNameNormalizer.canonical("ｱｯﾌﾟﾙ")      // 半角カタカナ
        #expect(kata == hira)
        #expect(kata == half)
    }

    @Test func collapsesWhitespace() {
        #expect(ConceptNameNormalizer.canonical("Open  AI") == "open ai")   // 連続半角空白
        #expect(ConceptNameNormalizer.canonical("Open　AI") == "open ai")   // 全角空白
    }

    @Test func distinctNamesStayDistinct() {
        // 別物は別の canonical キー (過剰統合しない)
        #expect(ConceptNameNormalizer.canonical("Apple") != ConceptNameNormalizer.canonical("Apple Inc"))
        #expect(ConceptNameNormalizer.canonical("生成AI") != ConceptNameNormalizer.canonical("LLM"))
    }

    @Test func emptyAndWhitespaceOnly() {
        #expect(ConceptNameNormalizer.canonical("") == "")
        #expect(ConceptNameNormalizer.canonical("   ") == "")
    }
}

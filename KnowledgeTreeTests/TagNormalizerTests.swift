//
//  TagNormalizerTests.swift
//  KnowledgeTreeTests
//
//  spec 008 — TagNormalizer の正規化ロジック
//

import Testing
@testable import KnowledgeTree

@Suite("TagNormalizer")
struct TagNormalizerTests {

    @Test("空文字列は nil")
    func emptyReturnsNil() {
        #expect(TagNormalizer.normalize("") == nil)
    }

    @Test("空白のみは nil")
    func whitespaceOnlyReturnsNil() {
        #expect(TagNormalizer.normalize("   ") == nil)
        #expect(TagNormalizer.normalize("\n\t  \n") == nil)
    }

    @Test("trim + lowercase")
    func trimsAndLowercases() {
        #expect(TagNormalizer.normalize("  OAuth  ") == "oauth")
    }

    @Test("50 文字超は prefix")
    func truncatesTo50() {
        let long = String(repeating: "a", count: 60)
        let result = TagNormalizer.normalize(long)
        #expect(result?.count == 50)
    }

    @Test("絵文字は保持")
    func preservesEmoji() {
        let result = TagNormalizer.normalize("📚")
        #expect(result == "📚")
    }

    @Test("CJK 文字は保持")
    func preservesCJK() {
        let result = TagNormalizer.normalize("読み返したい")
        #expect(result == "読み返したい")
    }

    @Test("全角空白も trim 対象 (whitespacesAndNewlines)")
    func trimsFullwidthSpace() {
        // U+3000 IDEOGRAPHIC SPACE is whitespace
        let result = TagNormalizer.normalize("\u{3000}\u{3000}swift\u{3000}")
        #expect(result == "swift")
    }

    @Test("OAuth と oauth と OAUTH は同一")
    func sameTagDifferentCase() {
        #expect(TagNormalizer.normalize("OAuth") == "oauth")
        #expect(TagNormalizer.normalize("oauth") == "oauth")
        #expect(TagNormalizer.normalize("OAUTH") == "oauth")
    }

    @Test("trim 後 lowercase + max 50")
    func combined() {
        let raw = "  " + String(repeating: "ABC", count: 30) + "  "  // 90 文字 + spaces
        let result = TagNormalizer.normalize(raw)
        #expect(result?.count == 50)
        #expect(result?.allSatisfy { $0 == "a" || $0 == "b" || $0 == "c" } == true)
    }
}

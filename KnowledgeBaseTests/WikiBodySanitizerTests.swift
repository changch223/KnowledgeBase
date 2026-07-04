//
//  WikiBodySanitizerTests.swift
//  KnowledgeTreeTests
//
//  spec 079 — Wiki 本文の漏れた候補スキャフォールド除去の検証。
//

import Testing
import Foundation
@testable import KnowledgeBase

@MainActor
struct WikiBodySanitizerTests {

    @Test func stripsLeakedCandidateSection() {
        let md = """
        ## 概要
        AIエージェント構築の概要。

        ## 関連ページ候補
        - 言語モデル: concept-id://590277D9-EF67-4255-B383-08FB617B1720
        - RAG → concept-id://11111111-1111-1111-1111-111111111111
        """
        let out = WikiBodySanitizer.sanitize(md)
        #expect(out.contains("## 概要"))
        #expect(out.contains("AIエージェント構築の概要。"))
        #expect(!out.contains("関連ページ候補"))
        #expect(!out.localizedCaseInsensitiveContains("concept-id"))
        #expect(!out.contains("590277D9"))
    }

    @Test func keepsValidInlineLinks() {
        let md = "AIは [言語モデル](concept-id://590277D9-EF67-4255-B383-08FB617B1720) を使う。"
        #expect(WikiBodySanitizer.sanitize(md) == md)  // 正しいインラインリンクは保持
    }

    @Test func stripsMalformedConceptId() {
        // コロン欠け "concept-id//" も除去
        let md = "- 言語モデル: concept-id//590277D9-EF67-4255-B383-08FB617B1720"
        let out = WikiBodySanitizer.sanitize(md)
        #expect(!out.localizedCaseInsensitiveContains("concept-id"))
    }

    @Test func noConceptIdReturnsUnchanged() {
        let md = "## 概要\n通常の本文。\n- 箇条書き"
        #expect(WikiBodySanitizer.sanitize(md) == md)  // 早期 return で不変
    }

    @Test func keepsParagraphWithInlineLinkButStripsRawSibling() {
        let md = """
        ## 詳細
        本文中に [RAG](concept-id://11111111-1111-1111-1111-111111111111) を使う。
        - 言語モデル: concept-id://22222222-2222-2222-2222-222222222222
        """
        let out = WikiBodySanitizer.sanitize(md)
        #expect(out.contains("[RAG](concept-id://11111111-1111-1111-1111-111111111111)"))  // 正リンク保持
        #expect(!out.contains("22222222"))  // 生 concept-id 行は除去
    }

    // MARK: - P1-3: isValid (品質下限チェック)

    @Test func isValidAcceptsNormalBody() {
        let md = "## 概要\nこれは十分な長さのある通常の Wiki 本文で、見出しと段落を持ちます。"
        #expect(WikiBodySanitizer.isValid(md))
    }

    @Test func isValidRejectsTooShort() {
        #expect(!WikiBodySanitizer.isValid("短い"))
        #expect(!WikiBodySanitizer.isValid("   \n  "))
    }

    @Test func isValidRejectsLeakedScaffold() {
        // sanitize をすり抜けた (万一の) スキャフォールド残りを二重防御で弾く。
        let rawConceptID = String(repeating: "あ", count: 60) + "\n- 言語モデル: concept-id://33333333-3333-3333-3333-333333333333"
        #expect(!WikiBodySanitizer.isValid(rawConceptID))
        let candidateHeading = String(repeating: "い", count: 60) + "\n## 関連ページ候補"
        #expect(!WikiBodySanitizer.isValid(candidateHeading))
    }

    @Test func isValidAcceptsBodyWithValidInlineLink() {
        let md = "AIは [言語モデル](concept-id://590277D9-EF67-4255-B383-08FB617B1720) を用いる技術の総称で、幅広い応用がある。"
        #expect(WikiBodySanitizer.isValid(md))  // 正しいインラインリンクは concept-id を含んでも合格
    }
}

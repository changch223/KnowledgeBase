//
//  CorrectionDiffTests.swift
//  KnowledgeTreeTests
//
//  spec 096 — 訂正差分 (CorrectionDiff) の純関数テスト。
//

import Testing
@testable import KnowledgeTree

struct CorrectionDiffTests {

    // 同一テキストは変更なし。
    @Test func identicalTextHasNoChanges() {
        let r = CorrectionDiff.analyze(from: "今日は gloadcode を使った。", to: "今日は gloadcode を使った。")
        #expect(r.total == 0)
        #expect(r.changes.isEmpty)
        #expect(r.detailAvailable)
    }

    // 1 語の置換を before → after で取り出す。
    @Test func extractsSingleWordSubstitution() {
        let r = CorrectionDiff.analyze(from: "今日は gloadcode を使った。",
                                       to: "今日は Claude Code を使った。")
        #expect(r.total == 1)
        #expect(r.changes.count == 1)
        let c = r.changes[0]
        #expect(c.before == "gloadcode")
        #expect(c.after == "Claude Code")
        #expect(c.count == 1)
    }

    // 同じ誤りが複数あれば 1 件にまとめて count で数える。
    @Test func dedupesRepeatedSubstitution() {
        let r = CorrectionDiff.analyze(
            from: "macbown で書く。macbown は便利。最後も macbown。",
            to: "markdown で書く。markdown は便利。最後も markdown。"
        )
        #expect(r.total == 3)
        #expect(r.changes.count == 1)
        #expect(r.changes[0].before == "macbown")
        #expect(r.changes[0].after == "markdown")
        #expect(r.changes[0].count == 3)
    }

    // 別々の語の修正は別々の変更として残る。
    @Test func keepsDistinctSubstitutionsSeparate() {
        let r = CorrectionDiff.analyze(
            from: "gloadcode と macbown を使う。",
            to: "Claude Code と markdown を使う。"
        )
        #expect(r.total == 2)
        #expect(r.changes.count == 2)
        let befores = Set(r.changes.map(\.before))
        #expect(befores == ["gloadcode", "macbown"])
    }

    // 空白だけの違いは差分として拾わない (ノイズ除去)。
    @Test func ignoresWhitespaceOnlyDifference() {
        let r = CorrectionDiff.analyze(from: "テスト本文です。", to: "テスト本文です。 ")
        #expect(r.changes.isEmpty)
    }

    // トークナイザ: ASCII 識別子はまとめ、CJK は 1 文字ずつ。
    @Test func tokenizeGroupsIdentifiers() {
        let tokens = CorrectionDiff.tokenize("私は CLAUDE.md を読む")
        #expect(tokens.contains("CLAUDE.md"))
        #expect(tokens.contains("私"))
        #expect(tokens.contains("読"))
    }
}

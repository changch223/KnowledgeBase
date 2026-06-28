//
//  WindowOutputGuardTests.swift
//  KnowledgeTreeTests
//
//  spec 096 — window 補正の暴走出力ガード (acceptsWindowOutput) のテスト。
//

import Testing
@testable import KnowledgeBase

struct WindowOutputGuardTests {

    // 通常の語置換 (長さほぼ不変) は採用。
    @Test func acceptsNormalCorrection() {
        let original = "今日は gloadcode を使って CLAUDE.md を編集した。とても便利だった。"
        let output = "今日は Claude Code を使って CLAUDE.md を編集した。とても便利だった。"
        #expect(LLMTranscriptCorrectionService.acceptsWindowOutput(original: original, output: output))
    }

    // 空出力は不採用。
    @Test func rejectsEmpty() {
        #expect(!LLMTranscriptCorrectionService.acceptsWindowOutput(original: "本文です。", output: "   "))
    }

    // 用語羅列の暴走 (短い行が多数) は不採用。
    @Test func rejectsTermListRunaway() {
        let original = String(repeating: "これは長い日本語の本文です。", count: 30)  // 1 行の長文
        let output = """
        Claude code
        Claude code
        markdown
        pathsout
        pathsout
        samelink
        samelink
        URL
        Unicode
        Gitehub
        Agent
        gate
        """
        #expect(!LLMTranscriptCorrectionService.acceptsWindowOutput(original: original, output: output))
    }

    // 極端な短縮は不採用。
    @Test func rejectsExtremeShrink() {
        let original = String(repeating: "あ", count: 600)
        let output = "短い。"
        #expect(!LLMTranscriptCorrectionService.acceptsWindowOutput(original: original, output: output))
    }

    // 極端な膨張も不採用。
    @Test func rejectsExtremeExpansion() {
        let original = "短い本文。"
        let output = String(repeating: "膨張した出力。", count: 50)
        #expect(!LLMTranscriptCorrectionService.acceptsWindowOutput(original: original, output: output))
    }
}

//
//  ExtractionGuidanceTests.swift
//  KnowledgeTreeTests
//
//  spec 096 — カスタマイズ抽出: guidance がプロンプトに注入されるかの純関数テスト。
//

import Testing
@testable import KnowledgeBase

@MainActor
struct ExtractionGuidanceTests {

    // guidance なしでは方向性セクションを出さない。
    @Test func noGuidanceOmitsSection() {
        let prompt = KnowledgeExtractor.buildPrompt(text: "本文です。", guidance: nil)
        #expect(!prompt.contains("抽出の方向性"))
    }

    // guidance ありで方向性セクションと内容が入る。
    @Test func guidanceInjectedIntoPrompt() {
        let prompt = KnowledgeExtractor.buildPrompt(text: "本文です。", guidance: "技術的な詳細を重視")
        #expect(prompt.contains("抽出の方向性"))
        #expect(prompt.contains("技術的な詳細を重視"))
        #expect(prompt.contains("本文です。"))
    }

    // 空白だけの guidance はセクションを出さない。
    @Test func blankGuidanceOmitsSection() {
        let prompt = KnowledgeExtractor.buildPrompt(text: "本文です。", guidance: "   ")
        #expect(!prompt.contains("抽出の方向性"))
    }

    // チャンク / メタ要約のプロンプトにも注入される。
    @Test func guidanceInjectedIntoChunkAndMeta() {
        let chunk = KnowledgeExtractor.buildChunkPrompt(text: "一部です。", guidance: "結論を短く")
        #expect(chunk.contains("結論を短く"))
        let meta = KnowledgeExtractor.buildMetaSummaryPrompt(chunkEssences: ["要点1"], guidance: "関係を中心に")
        #expect(meta.contains("関係を中心に"))
    }

    // guidance は 200 字に丸める (token 暴走防止)。
    // 固定文に含まれない 'Z' で数える (ヘッダ文の文字と混ざらないように)。
    @Test func guidanceCappedTo200() {
        let long = String(repeating: "Z", count: 300)
        let clause = KnowledgeExtractor.guidanceClause(long)
        let countZ = clause.filter { $0 == "Z" }.count
        #expect(countZ == 200)
    }
}

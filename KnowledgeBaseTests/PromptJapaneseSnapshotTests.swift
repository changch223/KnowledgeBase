//
//  PromptJapaneseSnapshotTests.swift
//  KnowledgeTreeTests
//
//  spec 106 — 生成言語 = 日本語のときのプロンプトが、英語指示版の追加前後で一字一句変わらないことを
//  固定する。追加前のコードで算出した SHA-256 をゴールデン値として持つ (文字列全文を持たずに差分検知)。
//  プロンプトを意図的に変更したときはこのハッシュを更新する。
//

import Testing
import Foundation
import CryptoKit
@testable import KnowledgeBase

@MainActor
struct PromptJapaneseSnapshotTests {

    static func sha(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static let fixedDate = Date(timeIntervalSince1970: 1_768_478_400) // 2026-01-15 12:00 UTC
    private static let fixedID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    private func article() -> Article {
        Article(url: "https://example.com/a", title: "Text-to-SQL の最前線", savedAt: Self.fixedDate)
    }

    private func page() -> ConceptPage {
        ConceptPage(name: "生成AI", categoryRaw: "テクノロジー", summary: "既存の要約です。")
    }

    @Test func extractorPromptsJa() {
        #expect(Self.sha(KnowledgeExtractor.buildPrompt(text: "本文です。", guidance: nil, language: .ja)) == "a3f4f86524760a590d14510da13fe82ca513f08262d3ba9d2afdf22c3d8bd0b8")
        #expect(Self.sha(KnowledgeExtractor.buildPrompt(text: "本文です。", guidance: "技術を重視", language: .ja)) == "79043fc332dc3d1fb9f25f57778ab4636fd7dc15ad0fb915e9000a93ee9041a0")
        #expect(Self.sha(KnowledgeExtractor.buildChunkPrompt(text: "一部です。", guidance: nil, language: .ja)) == "bdca36adf4dc09e36e641e94c33268273a5ab57c42a394e5f78da5c5cd8945de")
        #expect(Self.sha(KnowledgeExtractor.buildChunkPrompt(text: "一部です。", guidance: "結論", language: .ja)) == "3419df03c9fc1debb207c10abf7c16bc1a02a17c51555bdb978a7337b84df3b8")
        #expect(Self.sha(KnowledgeExtractor.buildMetaSummaryPrompt(chunkEssences: ["要点1", "要点2"], guidance: nil, language: .ja)) == "78169752636aa44ab9502520c1719f3ef5285488f9e076f0ce730d6a1d2fbecc")
        #expect(Self.sha(KnowledgeExtractor.buildMetaSummaryPrompt(chunkEssences: ["要点1"], guidance: "関係", language: .ja)) == "c32036a0a54974adab169c44e2ce40e019974f9ff7623746d4200d3aac4145fc")
    }

    @Test func conceptPromptsJa() {
        let a = article()
        let p = page()
        #expect(Self.sha(FoundationModelsConceptSynthesisService.buildConceptHierarchyPrompt(article: a, language: .ja)) == "acc12c154ed4c24e3c75814d91c75359407bd99cae468bc37224711edd57e33c")
        #expect(Self.sha(FoundationModelsConceptSynthesisService.buildOneShotPrompt(conceptPage: p, articles: [a], language: .ja)) == "ebf9c8c948aab3a4dad8bdf11173659280caeefee22f7858d2a1a7bb3c40fcba")
        #expect(Self.sha(FoundationModelsConceptSynthesisService.buildBroadConceptPrompt(conceptPage: p, childNames: ["RAG", "Text-to-SQL"], articles: [a], language: .ja)) == "309c9ce2e52141688d9f6cadef740fb9f92b25fe832f92b275700f5761fa7f0f")
        #expect(Self.sha(FoundationModelsConceptSynthesisService.buildChunkPrompt(conceptPage: p, articles: [a], chunkIndex: 0, totalChunks: 2, language: .ja)) == "7d5b80ce36d4852049bfc60e4c9eab8d124676256d079c1b7ad196f7ae718fee")
        #expect(Self.sha(FoundationModelsConceptSynthesisService.buildMetaPrompt(conceptPage: p, chunkSummaries: ["要約A", "要約B"], totalArticles: 3, language: .ja)) == "a1af2a06cf0a9e76ee8a907848d9ae1fa149bfaea92704b8dd4bb74a35c4e731")
        #expect(Self.sha(FoundationModelsConceptSynthesisService.buildWikiBodyPrompt(conceptPage: p, articles: [a], linkCandidates: [(name: "RAG", id: Self.fixedID)], language: .ja)) == "ccbd27fc2bf9b7acf867338bbdfefbd6252a94914bac39b513ff6ed1b01739d7")
        #expect(Self.sha(FoundationModelsConceptSynthesisService.buildWikiBodyPrompt(conceptPage: p, articles: [a], language: .ja)) == "2faef0dc88fc0730b8512d442e863064ec97fde3bc6bd6f3859d7e957964df1a")
        #expect(Self.sha(FoundationModelsConceptSynthesisService.defaultHierarchyRules) == "dbabc784b0349a78d0c88cb5a9c30552c14cb9aae59da8433e8fb96c3202ecf9")
    }

    @Test func lintNamingPromptJa() {
        #expect(Self.sha(DefaultLintEngine.buildCategoryNamingPrompt(memberNames: ["住宅ローン", "賃貸契約"], existingCategoryNames: "テクノロジー / 経済", language: .ja)) == "ee143bc172d59289eda2f3ccdcd8060e531607950a5e4e95ed554fd4f47b58e8")
    }
}

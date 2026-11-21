//
//  PromptLocalizerTests.swift
//  KnowledgeTreeTests
//
//  spec 106 — 英語指示版プロンプト (ja 以外) の検証。日本語指示文が混ざらず、冒頭 + 末尾に出力言語指定が入る。
//  ja の一字一句不変は PromptJapaneseSnapshotTests が固定している。
//

import Testing
import Foundation
@testable import KnowledgeBase

@MainActor
struct PromptLocalizerTests {

    private let fixedID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private let japaneseInstructionPhrases = ["抽出してください", "厳守", "出力要件", "整理してください", "命名してください", "書いてください", "統合する役割"]

    private func article() -> Article {
        Article(url: "https://example.com/a", title: "Text-to-SQL", savedAt: Date(timeIntervalSince1970: 1_768_478_400))
    }

    private func page() -> ConceptPage {
        ConceptPage(name: "Generative AI", categoryRaw: "テクノロジー", summary: "Existing summary.")
    }

    private func expectEnglishInstructions(_ prompt: String, language: PipelineLanguage) {
        #expect(prompt.contains("Output language: \(language.englishName)"))
        #expect(prompt.contains(language.outputInstruction))
        // 冒頭にヘッダ、末尾に footer
        #expect(prompt.hasPrefix(PromptLocalizer.outputLanguageHeader(language)))
        #expect(prompt.hasSuffix(language.outputInstruction))
        for phrase in japaneseInstructionPhrases {
            #expect(!prompt.contains(phrase), "unexpected Japanese instruction: \(phrase)")
        }
    }

    @Test func extractorPromptsAreEnglishForNonJapanese() {
        for lang in [PipelineLanguage.en, .zhHant] {
            expectEnglishInstructions(KnowledgeExtractor.buildPrompt(text: "本文", language: lang), language: lang)
            expectEnglishInstructions(KnowledgeExtractor.buildChunkPrompt(text: "本文", language: lang), language: lang)
            expectEnglishInstructions(KnowledgeExtractor.buildMetaSummaryPrompt(chunkEssences: ["a", "b"], language: lang), language: lang)
        }
    }

    @Test func extractorPromptKeepsLimitsAndArticleText() {
        let prompt = KnowledgeExtractor.buildPrompt(text: "日本語の本文です。", language: .en)
        #expect(prompt.contains("日本語の本文です。"))
        #expect(prompt.contains("at most 10 key facts"))
        let chunk = KnowledgeExtractor.buildChunkPrompt(text: "一部", language: .en)
        #expect(chunk.contains("at most 4"))
    }

    @Test func guidanceIsEnglishForNonJapanese() {
        let prompt = KnowledgeExtractor.buildPrompt(text: "本文", guidance: "focus on cost", language: .en)
        #expect(prompt.contains("focus on cost"))
        #expect(!prompt.contains("抽出の方向性"))
    }

    @Test func conceptPromptsAreEnglishForNonJapanese() {
        let a = article()
        let p = page()
        for lang in [PipelineLanguage.en, .zhHant] {
            typealias S = FoundationModelsConceptSynthesisService
            expectEnglishInstructions(S.buildConceptHierarchyPrompt(article: a, language: lang), language: lang)
            expectEnglishInstructions(S.buildOneShotPrompt(conceptPage: p, articles: [a], language: lang), language: lang)
            expectEnglishInstructions(S.buildBroadConceptPrompt(conceptPage: p, childNames: ["RAG"], articles: [a], language: lang), language: lang)
            expectEnglishInstructions(S.buildChunkPrompt(conceptPage: p, articles: [a], chunkIndex: 0, totalChunks: 2, language: lang), language: lang)
            expectEnglishInstructions(S.buildMetaPrompt(conceptPage: p, chunkSummaries: ["s"], totalArticles: 2, language: lang), language: lang)
            expectEnglishInstructions(S.buildWikiBodyPrompt(conceptPage: p, articles: [a], linkCandidates: [(name: "RAG", id: fixedID)], language: lang), language: lang)
        }
    }

    @Test func hierarchyPromptDoesNotPassJapaneseSeedHint() {
        // テクノロジー記事でも日本語のシード辞書 (生成AI / LLM 等) を渡さない
        let a = article()
        let prompt = FoundationModelsConceptSynthesisService.buildConceptHierarchyPrompt(article: a, language: .en)
        #expect(!prompt.contains("広い概念の候補"))
        #expect(!prompt.contains("データエンジニアリング"))
        #expect(prompt.contains("Prefer a short field-level noun"))
        #expect(prompt.contains("at most 16 characters"))
    }

    @Test func jaHierarchyPromptKeepsKeyPhrases() {
        let prompt = FoundationModelsConceptSynthesisService.buildConceptHierarchyPrompt(article: article(), language: .ja)
        #expect(prompt.contains("次の記事を 2 階層の概念に整理してください"))
        #expect(prompt.contains("出力言語: 日本語"))
    }

    @Test func wikiPromptKeepsLinkRulesInEnglish() {
        let prompt = FoundationModelsConceptSynthesisService.buildWikiBodyPrompt(
            conceptPage: page(), articles: [], linkCandidates: [(name: "RAG", id: fixedID)], language: .en
        )
        #expect(prompt.contains("concept-id://11111111-2222-3333-4444-555555555555"))
        #expect(prompt.contains("Never invent UUIDs"))
    }

    @Test func lintNamingPromptIsEnglishForNonJapanese() {
        let prompt = DefaultLintEngine.buildCategoryNamingPrompt(
            memberNames: ["Mortgage", "Lease"], existingCategoryNames: "A / B", language: .zhHant
        )
        expectEnglishInstructions(prompt, language: .zhHant)
        #expect(prompt.contains("Mortgage, Lease"))
        #expect(prompt.contains("A / B"))
    }

    @Test func englishNamesCoverAllLanguages() {
        for lang in PipelineLanguage.allCases {
            #expect(!lang.englishName.isEmpty)
        }
        #expect(PipelineLanguage.zhHant.englishName == "Traditional Chinese")
        #expect(PromptLocalizer.usesJapaneseInstructions(.ja))
        #expect(!PromptLocalizer.usesJapaneseInstructions(.en))
    }
}

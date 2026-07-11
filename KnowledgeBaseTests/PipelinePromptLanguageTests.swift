//
//  PipelinePromptLanguageTests.swift
//  KnowledgeTreeTests
//
//  i18n Phase B — 代表的な prompt builder が `language` 引数 (既定 `PipelineLanguage.current`) に
//  応じて出力言語の指示を切り替えることを検証する。既定 (.ja) では従来通り「日本語」指示が
//  含まれることも合わせて確認し、既定挙動が不変であることを保証する。
//

import Testing
import Foundation
@testable import KnowledgeBase

// i18n Phase B: 一部テストは PipelineLanguage.current を暗黙参照する既定引数の挙動も検証するため、
// 他 suite (withPipelineLanguage で実プロセス状態を書き換えるもの) との並列実行を避けて直列化する。
@Suite(.serialized)
@MainActor
struct PipelinePromptLanguageTests {

    // MARK: - KnowledgeExtractor.buildPrompt

    @Test func testKnowledgeExtractorBuildPromptSwitchesOutputLanguage() {
        let jaPrompt = KnowledgeExtractor.buildPrompt(text: "本文です。", language: .ja)
        #expect(jaPrompt.contains("出力言語: 日本語"))
        #expect(jaPrompt.contains("すべて日本語で出力してください"))

        let zhPrompt = KnowledgeExtractor.buildPrompt(text: "本文です。", language: .zhHant)
        #expect(zhPrompt.contains("出力言語: 繁體中文"))
        #expect(zhPrompt.contains("請全部使用繁體中文輸出"))
        #expect(!zhPrompt.contains("すべて日本語で出力してください"))
    }

    @Test func testKnowledgeExtractorBuildPromptDefaultsToCurrentAndStaysJapanese() {
        // 既定引数省略時は PipelineLanguage.current (テスト環境は .ja) を参照する。
        let prompt = KnowledgeExtractor.buildPrompt(text: "本文です。")
        #expect(prompt.contains("日本語"))
    }

    // i18n Phase B (英語対応): 代表 builder 1 つで .en の出力言語ヘッダが入り、
    // ja 向けの出力指示文 (「すべて日本語で出力してください」) が入らないことを確認する
    // (prompt 本文の定型句自体は日本語で書かれている＝「日本語」という語自体は他言語 prompt にも
    //  含まれる。zh 系の既存テストと同じ検証対象=「日本語での出力指示」の有無で判定する)。
    @Test func testKnowledgeExtractorBuildPromptSwitchesToEnglish() {
        let enPrompt = KnowledgeExtractor.buildPrompt(text: "本文です。", language: .en)
        #expect(enPrompt.contains("出力言語: English"))
        #expect(enPrompt.contains("Write all output in English."))
        #expect(!enPrompt.contains("すべて日本語で出力してください"))
    }

    // i18n Phase C (韓国語/スペイン語/ドイツ語対応): 代表 builder 1 つで .ko/.es/.de の
    // 出力言語ヘッダ切替を検証する (他 builder への波及は既存の zh/en テストと同じ経路のため省略)。
    @Test func testKnowledgeExtractorBuildPromptSwitchesToKorean() {
        let koPrompt = KnowledgeExtractor.buildPrompt(text: "本文です。", language: .ko)
        #expect(koPrompt.contains("出力言語: 한국어"))
        #expect(koPrompt.contains("모든 출력은 한국어로 작성하세요."))
        #expect(!koPrompt.contains("すべて日本語で出力してください"))
    }

    @Test func testKnowledgeExtractorBuildPromptSwitchesToSpanish() {
        let esPrompt = KnowledgeExtractor.buildPrompt(text: "本文です。", language: .es)
        #expect(esPrompt.contains("出力言語: Español"))
        #expect(esPrompt.contains("Escribe toda la salida en español."))
        #expect(!esPrompt.contains("すべて日本語で出力してください"))
    }

    @Test func testKnowledgeExtractorBuildPromptSwitchesToGerman() {
        let dePrompt = KnowledgeExtractor.buildPrompt(text: "本文です。", language: .de)
        #expect(dePrompt.contains("出力言語: Deutsch"))
        #expect(dePrompt.contains("Schreibe die gesamte Ausgabe auf Deutsch."))
        #expect(!dePrompt.contains("すべて日本語で出力してください"))
    }

    // MARK: - ChatService.buildPrompt

    @Test func testChatServiceBuildPromptSwitchesOutputLanguage() {
        let article = Article(url: "https://example.com", title: "テスト")

        let jaPrompt = ChatService.buildPrompt(question: "Swift について", articles: [article], language: .ja)
        #expect(jaPrompt.contains("出力言語: 日本語"))

        let zhPrompt = ChatService.buildPrompt(question: "Swift について", articles: [article], language: .zhHans)
        #expect(zhPrompt.contains("出力言語: 简体中文"))
        #expect(!zhPrompt.contains("出力言語: 日本語"))
    }

    // MARK: - ConceptSynthesisService (buildWikiBodyPrompt)

    @Test func testBuildWikiBodyPromptSwitchesOutputLanguage() {
        let page = ConceptPage(name: "生成AI", categoryRaw: "テクノロジー", summary: "既存の要約")

        let jaPrompt = FoundationModelsConceptSynthesisService.buildWikiBodyPrompt(
            conceptPage: page, articles: [], language: .ja
        )
        #expect(jaPrompt.contains("出力言語: 日本語"))

        let zhPrompt = FoundationModelsConceptSynthesisService.buildWikiBodyPrompt(
            conceptPage: page, articles: [], language: .zhHant
        )
        #expect(zhPrompt.contains("出力言語: 繁體中文"))
        #expect(!zhPrompt.contains("出力言語: 日本語"))
    }

    // MARK: - ConflictDetectionService.buildPrompt

    @Test func testConflictDetectionBuildPromptSwitchesOutputLanguage() {
        let newArticle = Article(url: "https://example.com/new", title: "新記事")
        let oldArticle = Article(url: "https://example.com/old", title: "旧記事")

        let jaPrompt = ConflictDetectionService.buildPrompt(
            newArticle: newArticle, oldArticle: oldArticle, entityName: "Apple", language: .ja
        )
        #expect(jaPrompt.contains("出力言語: 日本語"))

        let zhPrompt = ConflictDetectionService.buildPrompt(
            newArticle: newArticle, oldArticle: oldArticle, entityName: "Apple", language: .zhHant
        )
        #expect(zhPrompt.contains("出力言語: 繁體中文"))
        #expect(!zhPrompt.contains("出力言語: 日本語"))
    }

    // MARK: - FoundationModelsKnowledgeDigestService.buildPrompt

    @Test func testKnowledgeDigestBuildPromptSwitchesOutputLanguage() {
        let jaPrompt = FoundationModelsKnowledgeDigestService.buildPrompt(
            articles: [], categoryName: "テクノロジー", language: .ja
        )
        #expect(jaPrompt.contains("出力言語: 日本語"))

        let zhPrompt = FoundationModelsKnowledgeDigestService.buildPrompt(
            articles: [], categoryName: "テクノロジー", language: .zhHans
        )
        #expect(zhPrompt.contains("出力言語: 简体中文"))
        #expect(!zhPrompt.contains("出力言語: 日本語"))
    }

    // MARK: - ChatService.buildAgentPrompt

    @Test func testChatServiceBuildAgentPromptSwitchesOutputLanguage() {
        let jaPrompt = ChatService.buildAgentPrompt(question: "Swift について", contextMessages: [], language: .ja)
        #expect(jaPrompt.contains("出力言語: 日本語"))

        let zhPrompt = ChatService.buildAgentPrompt(question: "Swift について", contextMessages: [], language: .zhHant)
        #expect(zhPrompt.contains("出力言語: 繁體中文"))
        #expect(!zhPrompt.contains("出力言語: 日本語"))
    }

    // MARK: - ChatService.buildFallbackPrompt (spec 081 一般知識回答 fallback)

    @Test func testChatServiceBuildFallbackPromptSwitchesOutputLanguage() {
        let jaPrompt = ChatService.buildFallbackPrompt(question: "Swift について", language: .ja)
        #expect(jaPrompt.contains("出力言語: 日本語"))

        let zhPrompt = ChatService.buildFallbackPrompt(question: "Swift について", language: .zhHant)
        #expect(zhPrompt.contains("出力言語: 繁體中文"))
        #expect(!zhPrompt.contains("出力言語: 日本語"))
    }

    /// tryGenerateFallbackAnswer の hedge 句言語追従 (qa Major #1)。
    /// zh パイプラインでは zh hedge が入り、ja hedge (「私の理解では」等) は入らないこと。
    @Test func testChatServiceBuildFallbackPromptUsesLanguageHedgeExamples() {
        let jaPrompt = ChatService.buildFallbackPrompt(question: "Swift について", language: .ja)
        #expect(jaPrompt.contains("私の理解では"))
        #expect(!jaPrompt.contains("据我理解"))

        let zhPrompt = ChatService.buildFallbackPrompt(question: "Swift について", language: .zhHans)
        #expect(zhPrompt.contains("据我理解"))
        #expect(!zhPrompt.contains("私の理解では"))
    }
}

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

    // MARK: - spec 107: 残りのプロンプト (チャット / 深掘り / ダイジェスト / 矛盾 / 最近 / 分類 / 文字起こし補正)

    private func articleWithKnowledge(title: String, essence: String) -> Article {
        let a = Article(id: UUID(uuidString: title == "Xcode 17" ? "22222222-3333-4444-5555-666666666666" : "33333333-4444-5555-6666-777777777777")!, url: "https://example.com/\(title)", title: title, savedAt: Self.fixedDate)
        let k = ExtractedKnowledge(article: a, status: .succeeded)
        k.essence = essence
        a.extractedKnowledge = k
        return a
    }

    private func chatMessages() -> [ChatMessage] {
        [
            ChatMessage(session: nil, role: ChatMessageRole.user.rawValue, text: "pm って何?"),
            ChatMessage(session: nil, role: ChatMessageRole.assistant.rawValue, text: "どの意味ですか?"),
        ]
    }

    /// 名前 → ja プロンプト。ゴールデン (追加前のコードで算出) と比較する。
    func remainingJaPrompts() -> [(name: String, prompt: String)] {
        let a1 = articleWithKnowledge(title: "Swift 6 の並行性", essence: "Swift 6 は並行性の安全性を強化した。")
        let a2 = articleWithKnowledge(title: "Xcode 17", essence: "Xcode 17 が公開された。")
        let msgs = chatMessages()
        let page = ConceptPage(name: "生成AI", categoryRaw: "テクノロジー", summary: "生成AIの概要です。")
        page.crossSourceInsights = ["LLM は文章を生成する", "RAG で精度が上がる"]
        let card = UnderstandingCard.fromConceptPage(page)
        let saved = SavedAnswer(question: "RAG とは何ですか?", answer: "検索拡張生成です。", citedArticles: [])
        let savedCard = UnderstandingCard.fromSavedAnswer(saved)
        var out: [(String, String)] = []
        out.append(("agent", ChatService.buildAgentPrompt(question: "最近のAI関連の記事について教えて", contextMessages: msgs, language: .ja)))
        out.append(("agentForce", ChatService.buildAgentPrompt(question: "pm", contextMessages: [], forceFinalAnswer: true, language: .ja)))
        out.append(("rag", ChatService.buildPrompt(question: "Swift 6 について", articles: [a1, a2], conceptPages: [page], contextMessages: msgs, language: .ja)))
        out.append(("ragQuick", ChatService.buildPrompt(question: "Swift 6 について", articles: [a1], chatMode: .quick, language: .ja)))
        out.append(("fallback", ChatService.buildFallbackPrompt(question: "天気は?", language: .ja)))
        out.append(("deepInitialConcept", DefaultDeepDiveChatService.buildInitialPrompt(for: card, language: .ja)))
        out.append(("deepInitialSaved", DefaultDeepDiveChatService.buildInitialPrompt(for: savedCard, language: .ja)))
        out.append(("deepContinuation", DefaultDeepDiveChatService.buildContinuationPrompt(card: card, history: msgs, language: .ja)))
        out.append(("deepContinuationEmpty", DefaultDeepDiveChatService.buildContinuationPrompt(card: savedCard, history: [], language: .ja)))
        out.append(("digest", FoundationModelsKnowledgeDigestService.buildPrompt(articles: [a1, a2], categoryName: "テクノロジー", language: .ja)))
        out.append(("digestGraph", FoundationModelsKnowledgeDigestService.buildPrompt(articles: [a1], categoryName: "テクノロジー", graphSection: "\n## このカテゴリーの主要エンティティと関係性\n・Swift (記事数 2)\n", language: .ja)))
        out.append(("conflict", ConflictDetectionService.buildPrompt(newArticle: a1, oldArticle: a2, entityName: "Swift", language: .ja)))
        out.append(("recent", RecentDigestService.buildPrompt(articles: [a1, a2], language: .ja)))
        out.append(("classify", FoundationModelsAutoCategoryClassifier.buildPrompt(tagName: "人工知能", context: "Swift 6 の記事", candidatesText: CategorySeed.seedDefinitions(for: .ja).map { "- \($0.name): \($0.definition)" }.joined(separator: "\n"), other: "その他", tieBreakers: CategorySeed.firstPassTieBreakers(for: .ja), exampleBlock: FoundationModelsAutoCategoryClassifier.buildExampleBlock([CategoryFewShot(tagName: "宇宙", correctCategory: "学術", wrongCategory: "ニュース")], language: .ja), language: .ja)))
        out.append(("classifyNoContext", FoundationModelsAutoCategoryClassifier.buildPrompt(tagName: "人工知能", context: nil, candidatesText: "- テクノロジー: IT", other: "その他", tieBreakers: "", exampleBlock: "", language: .ja)))
        out.append(("transcript", LLMTranscriptCorrectionService.buildPrompt(text: "クロードコードを使った。", terms: ["Claude Code", "Anthropic"], language: .ja)))
        out.append(("transcriptInstruction", LLMTranscriptCorrectionService.buildInstructionPrompt(text: "クロードコードを使った。", instruction: "Claude Code に直して", language: .ja)))
        return out
    }

    /// spec 107 追加前のコード (builder の static 化 / 抽出のみの機械的リファクタ後) で算出した SHA-256。
    private static let remainingJaGolden: [String: String] = [
        "agent": "b5f70b8efe58f42250e120e83c7b5fc352658a4b96d70531e0f8b206b28d7b2c",
        "agentForce": "56dec681c78c8abeac3f55288b58eefa586ce94363111a920fadf786abfc8f5c",
        "rag": "fa35fe29e8509453837efe0fb1ae686416c0a8275fb41fa081ee1d1fd8d557e0",
        "ragQuick": "16139d9de38d95471054a820b6b8119aebc5e6512a740d49f463a68d080d9d75",
        "fallback": "178f544f7847944aab50c92f4639700735a6d0a620333bcf00ffa423dc4cc682",
        "deepInitialConcept": "eae807c1f99ea43b8b27cb9a81d6692a44f28692b1030e56ee418d84e3860f5a",
        "deepInitialSaved": "c2d347b6ac8b499e3d5942d7687b3880785637a29052659a738ad64aa3e13242",
        "deepContinuation": "13acff27208345e7c2903af7bc8630185e8b4141ae3072b23cd0fc8c3696bda6",
        "deepContinuationEmpty": "906cd975ffbc11dcb062c39682997c6c6f5884a8f18f84d9498cb2176488564e",
        "digest": "542d0f8e9b561b52e04189729bc11f0f81176605e6d65303211d4a7f75e75488",
        "digestGraph": "c8e5f1b423266a7501485213087102d834240b41728d63eee95e261164d6ad45",
        "conflict": "e0ba2fbb800a47efd2e95df772c0c67a96c07f98b3efcf53ebf0cf20801a4edd",
        "recent": "fdc3a30d2df7a3f9dca8a7cd24d7110202214349e571cc1fcdc185c400ce9939",
        "classify": "334f50d253a45f22032cb950956c7f1da664f4406772f65d67f4ec5a981822c7",
        "classifyNoContext": "06b343270773660f011f1749098e9f737d74af94ce8bbc0db7ed47859dcef217",
        "transcript": "54e01c4f08151220c871a0c48105ee41190c3b45caeb5976631a7dfc02677774",
        "transcriptInstruction": "b52b8839882247f1d97cc4898d6243fdb086b26f9190fecb463d48ca5412d681",
    ]

    @Test func remainingPromptsJa() {
        let prompts = remainingJaPrompts()
        #expect(prompts.count == Self.remainingJaGolden.count)
        for (name, prompt) in prompts {
            #expect(Self.sha(prompt) == Self.remainingJaGolden[name], "ja prompt changed: \(name)")
        }
    }
}

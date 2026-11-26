//
//  PromptMultilingualTests.swift
//  KnowledgeTreeTests
//
//  spec 107 — 残りのプロンプト (チャット / 深掘り / ダイジェスト / 矛盾 / 最近 / 分類 / 文字起こし補正) の
//  英語指示版、分野ヒントの多言語解決、recency 質問の多言語判定。
//  ja の一字一句不変は PromptJapaneseSnapshotTests が固定している。
//

import Testing
import Foundation
@testable import KnowledgeBase

@MainActor
struct PromptMultilingualTests {

    private let japaneseInstructionPhrases = ["してください", "ください", "出力言語", "あなたは", "ルール", "絶対に", "こと。"]

    // ASCII だけの fixture (日本語の指示文が混ざっていないことを判定するため、データ部も英語)
    private func article(_ title: String, essence: String) -> Article {
        let a = Article(url: "https://example.com/\(title)", title: title, savedAt: Date(timeIntervalSince1970: 1_768_478_400))
        let k = ExtractedKnowledge(article: a, status: .succeeded)
        k.essence = essence
        a.extractedKnowledge = k
        return a
    }

    private func msgs() -> [ChatMessage] {
        [
            ChatMessage(session: nil, role: ChatMessageRole.user.rawValue, text: "what is pm?"),
            ChatMessage(session: nil, role: ChatMessageRole.assistant.rawValue, text: "Which meaning?"),
        ]
    }

    private func expectNoJapaneseInstructions(_ prompt: String, _ label: String) {
        for phrase in japaneseInstructionPhrases {
            #expect(!prompt.contains(phrase), "\(label): unexpected Japanese instruction '\(phrase)'")
        }
    }

    private func expectGeneralFrame(_ prompt: String, _ language: PipelineLanguage, _ label: String) {
        #expect(prompt.hasPrefix(PromptLocalizer.outputLanguageHeaderGeneral(language)), "\(label): header")
        #expect(prompt.hasSuffix(language.outputInstruction) || prompt.hasSuffix(language.outputInstruction + "\n"), "\(label): footer")
        expectNoJapaneseInstructions(prompt, label)
    }

    // MARK: - T1 CategoryPrompts

    @Test func categoryBlockResolvesInEveryLanguage() {
        #expect(CategoryPrompts.block(forCategoryRaw: "Technology", language: .en).contains("Focus for this field"))
        #expect(CategoryPrompts.block(forCategoryRaw: "科技", language: .zhHant).contains("Focus for this field"))
        #expect(CategoryPrompts.block(forCategoryRaw: "科技", language: .zhHans).contains("Focus for this field"))
        #expect(CategoryPrompts.block(forCategoryRaw: "Tecnología", language: .es).contains("Focus for this field"))
        #expect(CategoryPrompts.block(forCategoryRaw: "テクノロジー", language: .ja).contains("この分野での重視点"))
        // ja 生成言語なら外国語名でも日本語プロファイル
        #expect(CategoryPrompts.block(forCategoryRaw: "Technology", language: .ja).contains("この分野での重視点"))
    }

    @Test func categoryBlockEmptyForOtherAndUnknown() {
        for raw in ["Other", "その他", "其他", "Sonstiges", "Unknown Field", ""] {
            #expect(CategoryPrompts.block(forCategoryRaw: raw, language: .en).isEmpty, "\(raw)")
        }
        #expect(CategoryPrompts.block(forCategoryRaw: nil, language: .en).isEmpty)
    }

    @Test func everySeedInEveryLanguageResolvesToProfile() {
        for lang in PipelineLanguage.allCases {
            let seeds = CategorySeed.allSeeds(for: lang)
            for seed in seeds where seed.englishName != "Other" {
                #expect(!CategoryPrompts.block(forCategoryRaw: seed.name, language: lang).isEmpty, "\(lang) \(seed.name)")
            }
            #expect(CategoryPrompts.block(forCategoryRaw: CategorySeed.otherCategory(for: lang).name, language: lang).isEmpty)
        }
    }

    // MARK: - T2 英語指示版

    @Test func chatPromptsAreEnglishForNonJapanese() {
        let a1 = article("Swift 6", essence: "Swift 6 strengthens concurrency.")
        let page = ConceptPage(name: "Generative AI", categoryRaw: "Technology", summary: "Overview.")
        for lang in [PipelineLanguage.en, .zhHant] {
            let agent = ChatService.buildAgentPrompt(question: "recent AI articles", contextMessages: msgs(), language: lang)
            expectGeneralFrame(agent, lang, "agent \(lang)")
            for action in ["searchArticles", "immediate", "askClarification", "finalAnswer", "citedArticleIDs"] {
                #expect(agent.contains(action), "agent missing \(action)")
            }
            #expect(agent.contains("User: what is pm?"))

            let force = ChatService.buildAgentPrompt(question: "pm", contextMessages: [], forceFinalAnswer: true, language: lang)
            expectGeneralFrame(force, lang, "agentForce \(lang)")
            #expect(force.contains("forceFinalAnswer"))

            let rag = ChatService.buildPrompt(question: "About Swift 6", articles: [a1], conceptPages: [page], contextMessages: msgs(), language: lang)
            expectGeneralFrame(rag, lang, "rag \(lang)")
            #expect(rag.contains("(article-id://UUID)"))
            #expect(rag.contains("citedArticleIDs"))
            #expect(rag.contains("ID: \(a1.id.uuidString)"))
            #expect(rag.contains("Swift 6 strengthens concurrency."))

            let quick = ChatService.buildPrompt(question: "q", articles: [a1], chatMode: .quick, language: lang)
            expectGeneralFrame(quick, lang, "ragQuick \(lang)")
            #expect(quick.contains("Quick mode"))

            let fb = ChatService.buildFallbackPrompt(question: "weather?", language: lang)
            expectGeneralFrame(fb, lang, "fallback \(lang)")
            #expect(fb.contains(lang.bannedPhraseExamples[0]))
            #expect(fb.contains(lang.hedgePhraseExamples[0]))
        }
    }

    @Test func deepDivePromptsAreEnglishForNonJapanese() {
        let page = ConceptPage(name: "Generative AI", categoryRaw: "Technology", summary: "Overview of generative AI.")
        page.crossSourceInsights = ["LLMs generate text"]
        let card = UnderstandingCard.fromConceptPage(page)
        for lang in [PipelineLanguage.en, .zhHant] {
            let initial = DefaultDeepDiveChatService.buildInitialPrompt(for: card, language: lang)
            expectGeneralFrame(initial, lang, "deepInitial \(lang)")
            #expect(initial.contains("Generative AI"))
            #expect(initial.contains("[Concept summary]"))

            let cont = DefaultDeepDiveChatService.buildContinuationPrompt(card: card, history: msgs(), language: lang)
            expectGeneralFrame(cont, lang, "deepContinuation \(lang)")
            #expect(cont.contains("Student: what is pm?"))

            let empty = DefaultDeepDiveChatService.buildContinuationPrompt(card: card, history: [], language: lang)
            #expect(empty.contains("(No conversation yet)"))
            #expect(!empty.contains("まだ対話"))
        }
    }

    @Test func digestConflictRecentPromptsAreEnglishForNonJapanese() {
        let a1 = article("Swift 6", essence: "Swift 6 strengthens concurrency.")
        let a2 = article("Xcode 17", essence: "Xcode 17 was released.")
        for lang in [PipelineLanguage.en, .zhHant] {
            let digest = FoundationModelsKnowledgeDigestService.buildPrompt(articles: [a1, a2], categoryName: "Technology", language: lang)
            expectGeneralFrame(digest, lang, "digest \(lang)")
            #expect(digest.contains("sourceArticleIDs"))
            #expect(digest.contains("id=\(a1.id.uuidString)"))

            let conflict = ConflictDetectionService.buildPrompt(newArticle: a1, oldArticle: a2, entityName: "Swift", language: lang)
            expectGeneralFrame(conflict, lang, "conflict \(lang)")
            #expect(conflict.contains("hasConflict=true"))

            let recent = RecentDigestService.buildPrompt(articles: [a1, a2], language: lang)
            expectGeneralFrame(recent, lang, "recent \(lang)")
            #expect(recent.contains("paragraphs"))
            #expect(recent.contains("Swift 6"))
        }
    }

    @Test func classifierPromptIsEnglishAndKeepsParsedStrings() {
        let candidates = "- Technology: AI and IT\n- Economy: business"
        for lang in [PipelineLanguage.en, .zhHant] {
            let prompt = FoundationModelsAutoCategoryClassifier.buildPrompt(
                tagName: "AI", context: "an article about Swift", candidatesText: candidates,
                other: "Other", tieBreakers: "- AI -> Technology", exampleBlock: "", language: lang)
            #expect(prompt.contains("Output language: \(lang.englishName)"))
            #expect(prompt.hasSuffix(lang.outputInstruction))
            #expect(prompt.contains("Return exactly one name from the candidate list, using the exact spelling written there. Do not translate it."))
            #expect(prompt.contains("High / Medium / Low"))
            #expect(prompt.contains("- Technology: AI and IT"))
            #expect(prompt.contains("\"Other\""))
            #expect(prompt.contains("Context where this tag appeared:"))
            expectNoJapaneseInstructions(prompt, "classify \(lang)")
        }
        let example = FoundationModelsAutoCategoryClassifier.buildExampleBlock(
            [CategoryFewShot(tagName: "space", correctCategory: "Academic", wrongCategory: "News")], language: .en)
        #expect(example.contains("Past user corrections"))
        #expect(example.contains("(not \"News\")"))
        expectNoJapaneseInstructions(example, "exampleBlock")
    }

    @Test func transcriptPromptsKeepLanguageAndDoNotTranslate() {
        for lang in [PipelineLanguage.en, .zhHant] {
            let p = LLMTranscriptCorrectionService.buildPrompt(text: "I used cloud code.", terms: ["Claude Code", "Anthropic"], language: lang)
            #expect(p.contains("Keep the same language as the input text. Do not translate. Do not summarize."))
            #expect(p.contains("Glossary: Claude Code, Anthropic"))
            #expect(p.contains("I used cloud code."))
            // 生成言語で書かせるヘッダ/フッタは付けない (原語のまま補正するため)
            #expect(!p.contains("Output language:"))
            #expect(!p.contains(lang.outputInstruction))
            expectNoJapaneseInstructions(p, "transcript \(lang)")

            let i = LLMTranscriptCorrectionService.buildInstructionPrompt(text: "I used cloud code.", instruction: "It is Claude Code", language: lang)
            #expect(i.contains("Keep the same language as the input text. Do not translate."))
            #expect(i.contains("Instruction: It is Claude Code"))
            #expect(!i.contains("Output language:"))
            expectNoJapaneseInstructions(i, "transcriptInstruction \(lang)")
        }
    }

    // MARK: - T3 recency

    @Test func recencyQueryMultilingualTrue() {
        let positives = [
            // ja (既存)
            "最近保存した記事の要点は?",
            // en
            "What did I save recently?", "Summarize my latest saved articles", "Give me a summary of this week's articles",
            // zh-Hans / zh-Hant
            "最近保存了什么文章", "最近存了什麼文章", "本週的文章摘要", "本周读了哪些文章",
            // ko
            "최근에 저장한 기사 요약해줘", "이번 주 저장한 기사는?",
            // es
            "¿Qué artículos guardé recientemente?", "Resumen de los últimos artículos guardados", "artículos de esta semana",
            // de
            "Was habe ich kürzlich gespeichert? Zusammenfassung bitte", "Fasse die neuesten Artikel zusammen", "Artikel von dieser Woche",
        ]
        for q in positives {
            #expect(ChatService.isRecencyQuery(q), "should be recency: \(q)")
        }
    }

    @Test func recencyQueryFalsePositiveGuard() {
        let negatives = [
            "What is the latest iPhone?",       // recency のみ
            "Tell me about the thread model",   // 'read' が 'thread' に誤一致しない
            "Show me an article about Swift",   // meta のみ
            "最新のiPhoneは?",
            "Was ist Swift?",
            "What is RAG?",
        ]
        for q in negatives {
            #expect(!ChatService.isRecencyQuery(q), "should NOT be recency: \(q)")
        }
    }

    @Test func recencyQueryTopicStillTrueWhenBothWordsPresent() {
        // spec 084 の content-aware 配置: 「最近のAI文章」は meta (文章) を含むので true (トピック検索が先に走る)
        #expect(ChatService.isRecencyQuery("最近的AI文章"))
    }

    @Test func recencyQueryBoundaryAndNewWords() {
        let positives = [
            "What did I read this week?", "my saved articles from last week", "articles from the past few days",
            "Resumen del último artículo guardado", "Zusammenfassung der letzten Woche gespeicherte Artikel",
            "最近のarticleは?", "最近的AI文章", "Show recent readings summary",
            "¿Qué artículos guardé últimamente?", "My recent reads",
        ]
        for q in positives { #expect(ChatService.isRecencyQuery(q), "should be recency: \(q)") }
        let negatives = [
            "Is the latest build ready?",        // read ⊄ ready
            "the latest readings of the sensor", // 'readings' は meta ではない
            // ja の挙動は main と同じ: zh 固有の meta (文章 / 重点) はかなを含む質問には適用しない
            "最近の文章術は?", "最新の重点課題", "今週の摘要は?",
            "Letztendlich, was ist ein Artikel?", // letzte は語全体一致 (letztendlich に誤一致しない)
        ]
        for q in negatives { #expect(!ChatService.isRecencyQuery(q), "should NOT be recency: \(q)") }
    }

    // MARK: - ダイジェストの graph セクション

    @Test func graphSectionIsEnglishForNonJapaneseAndUnchangedForJapanese() {
        let entries = [(name: "Swift", mentionCount: 3, edges: "uses → Xcode"), (name: "Xcode", mentionCount: 2, edges: "")]
        let en = FoundationModelsKnowledgeDigestService.formatGraphSection(entries: entries, language: .en)
        #expect(en.contains("## Main entities and relations in this category"))
        #expect(en.contains("- Swift (3 articles): uses → Xcode"))
        #expect(en.contains("Write a narrative centered on the main entities."))
        expectNoJapaneseInstructions(en, "graphSection")
        #expect(!en.contains("記事数"))
        let ja = FoundationModelsKnowledgeDigestService.formatGraphSection(entries: entries, language: .ja)
        #expect(ja == "\n## このカテゴリーの主要エンティティと関係性\n・Swift (記事数 3): uses → Xcode\n・Xcode (記事数 2)\n\n主要エンティティを中心に物語る文章を生成してください。")
    }
}

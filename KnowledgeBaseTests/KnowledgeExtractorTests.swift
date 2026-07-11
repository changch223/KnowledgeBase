//
//  KnowledgeExtractorTests.swift
//  KnowledgeTreeTests
//
//  spec 004 — contracts/knowledge-extractor.md
//  Mock LanguageModelSession で決定論的に走る (実 Foundation Models 不使用)。
//

import Testing
import Foundation
@testable import KnowledgeBase

// i18n Phase B: withPipelineLanguage は PipelineLanguage.current の実プロセス状態
// (UserDefaults + static cache) を書き換える。他 suite との並列実行で読み書きが競合しないよう直列化する。
@Suite(.serialized)
@MainActor
struct KnowledgeExtractorTests {

    @Test func extractWithSuccessReturnsOutput() async throws {
        let session = MockLanguageModelSession()
        session.nextResult = .success(.fixture())
        let extractor = KnowledgeExtractor(session: session)

        let output = try await extractor.extract(extractedText: "記事本文 200 字以上のテキスト...")
        #expect(!output.essence.isEmpty)
        #expect(session.callCount == 1)
        #expect(session.lastPrompt?.contains("記事本文 200 字以上のテキスト...") == true)
    }

    @Test func extractIncludesStrictInstructionsInPrompt() async throws {
        let session = MockLanguageModelSession()
        session.nextResult = .success(.fixture())
        let extractor = KnowledgeExtractor(session: session)

        _ = try await extractor.extract(extractedText: "テスト本文")
        let prompt = session.lastPrompt ?? ""
        #expect(prompt.contains("元記事に明示されている内容のみ"))
        #expect(prompt.contains("推測・補完"))
        #expect(prompt.contains("矛盾しない"))
        #expect(prompt.contains("日本語"))
    }

    @Test func extractPropagatesError() async {
        let session = MockLanguageModelSession()
        session.nextResult = .failure(MockLanguageModelError.safetyFiltered)
        let extractor = KnowledgeExtractor(session: session)

        await #expect(throws: MockLanguageModelError.self) {
            _ = try await extractor.extract(extractedText: "本文")
        }
    }

    @Test func extractReturnsEmptyOutputWhenModelReturnsEmpty() async throws {
        let session = MockLanguageModelSession()
        session.nextResult = .success(ExtractedKnowledgeOutput(
            essence: "",
            summary: "",
            keyFacts: [],
            entities: []
        ))
        let extractor = KnowledgeExtractor(session: session)

        let output = try await extractor.extract(extractedText: "本文")
        #expect(output.essence.isEmpty)
        #expect(output.summary.isEmpty)
        #expect((output.keyFacts ?? []).isEmpty)
        #expect((output.entities ?? []).isEmpty)
    }

    @Test func extractReturnsPartialOutput() async throws {
        let session = MockLanguageModelSession()
        session.nextResult = .success(ExtractedKnowledgeOutput(
            essence: "Apple は WWDC で iOS 26 を発表した。",
            summary: "Apple は WWDC で iOS 26 を発表した。",
            keyFacts: [],
            entities: []
        ))
        let extractor = KnowledgeExtractor(session: session)

        let output = try await extractor.extract(extractedText: "本文")
        #expect(!output.essence.isEmpty)
        #expect(!output.summary.isEmpty)
        #expect((output.keyFacts ?? []).isEmpty)
        #expect((output.entities ?? []).isEmpty)
    }

    @Test func buildPromptIncludesText() {
        let prompt = KnowledgeExtractor.buildPrompt(text: "ABC 元記事")
        #expect(prompt.contains("ABC 元記事"))
        #expect(prompt.contains("# 抽出ルール"))
        #expect(prompt.contains("# 元記事本文"))
    }

    @Test func buildPromptIncludesKeyFactsCapAndCodeRule() {
        let prompt = KnowledgeExtractor.buildPrompt(text: "本文")
        #expect(prompt.contains("最大 10 件"))
        #expect(prompt.contains("コード"))
    }

    // MARK: - V3.0 polish: コードブロックを抽出 prompt に流さない

    @Test func stripCodeBlocksRemovesFencedBlock() {
        let input = """
        前段の説明文です。

        ```swift
        let value = 42
        print(value)
        ```

        後段の説明文です。
        """
        let result = KnowledgeExtractor.stripCodeBlocks(from: input)
        #expect(result.contains("前段の説明文"))
        #expect(result.contains("後段の説明文"))
        #expect(!result.contains("let value = 42"))
        #expect(!result.contains("```"))
    }

    @Test func stripCodeBlocksRemovesIndentedBlock() {
        let input = """
        概要を述べます。
            indented = code_block
            another_line()
        本文に戻ります。
        """
        let result = KnowledgeExtractor.stripCodeBlocks(from: input)
        #expect(result.contains("概要"))
        #expect(result.contains("本文に戻ります"))
        #expect(!result.contains("indented = code_block"))
        #expect(!result.contains("another_line"))
    }

    @Test func stripCodeBlocksRemovesInlineCode() {
        let input = "API は `fetch(url:)` を呼びます。戻り値は Response 型です。"
        let result = KnowledgeExtractor.stripCodeBlocks(from: input)
        #expect(result.contains("API は"))
        #expect(result.contains("戻り値"))
        #expect(!result.contains("fetch(url:)"))
        #expect(!result.contains("`"))
    }

    @Test func stripCodeBlocksKeepsPlainText() {
        let input = "コードを含まない普通の文章。改行も含む。\n\n2 段落目。"
        let result = KnowledgeExtractor.stripCodeBlocks(from: input)
        #expect(result.contains("普通の文章"))
        #expect(result.contains("2 段落目"))
    }

    // MARK: - spec 042: 翻訳前処理

    /// 日本語入力 → 翻訳 call は呼ばれない、既存挙動を維持
    @Test func extractSkipsTranslationForJapanese() async throws {
        let session = MockLanguageModelSession()
        session.nextResult = .success(.fixture())
        let extractor = KnowledgeExtractor(session: session)

        let japaneseText = """
        Swift 6 のリリースについて。Apple は新しい strict concurrency 機能を発表し、
        既存の async/await モデルをさらに堅牢化しました。開発者は migration mode を使って
        段階的に対応できます。
        """
        _ = try await extractor.extract(extractedText: japaneseText)

        #expect(session.translationCallCount == 0)
        #expect(session.callCount == 1)
        // 抽出 prompt に元の日本語本文がそのまま入っている
        #expect(session.lastPrompt?.contains("Swift 6 のリリースについて") == true)
    }

    /// 英語入力 → 翻訳 call が呼ばれ、訳出テキストで抽出される
    @Test func extractInvokesTranslationForEnglish() async throws {
        let session = MockLanguageModelSession()
        session.nextResult = .success(.fixture())
        session.nextTranslationResult = .success(
            "Apple は WWDC で新しい Foundation Models フレームワークを発表しました。" +
            "このフレームワークは on-device 言語モデルを公開し、開発者が SwiftUI アプリに" +
            "structured output と RAG 機能を追加できるようになります。"
        )
        let extractor = KnowledgeExtractor(session: session)

        let englishText = """
        Apple announced a new framework called Foundation Models at WWDC. The on-device
        language model exposes structured output via the @Generable macro, enabling
        developers to add RAG features to their SwiftUI apps without external servers.
        """
        _ = try await extractor.extract(extractedText: englishText)

        #expect(session.translationCallCount == 1)
        #expect(session.lastTranslationText?.contains("announced a new framework") == true)
        // 抽出 prompt は翻訳後の日本語テキストを含む
        #expect(session.lastPrompt?.contains("Foundation Models フレームワーク") == true)
        // 元の英文は抽出 prompt に流れない
        #expect(session.lastPrompt?.contains("announced a new framework") == false)
    }

    /// spec 093: 中国語入力 (日本語以外) → 翻訳 call が呼ばれ、訳出テキストで抽出される
    @Test func extractInvokesTranslationForChinese() async throws {
        let session = MockLanguageModelSession()
        session.nextResult = .success(.fixture())
        session.nextTranslationResult = .success(
            "Apple は WWDC で新しい Foundation Models フレームワークを発表しました。" +
            "端末内の言語モデルを公開し、開発者が外部サーバーなしで structured output を" +
            "利用できるようになります。"
        )
        let extractor = KnowledgeExtractor(session: session)

        let chineseText = """
        苹果在全球开发者大会上发布了一个名为基础模型的全新框架。这个设备端的语言模型
        通过宏公开了结构化输出，使开发者无需依赖外部服务器即可为应用程序添加检索增强生成功能。
        """
        _ = try await extractor.extract(extractedText: chineseText)

        // 日本語以外なので翻訳が呼ばれる
        #expect(session.translationCallCount == 1)
        // 抽出 prompt は翻訳後の日本語テキストを含む
        #expect(session.lastPrompt?.contains("Foundation Models フレームワーク") == true)
        // 元の中国語は抽出 prompt に流れない
        #expect(session.lastPrompt?.contains("苹果在全球开发者大会") == false)
    }

    /// 翻訳 throws → 英語のまま抽出 (silent fallback)
    @Test func extractFallsBackToRawTextWhenTranslationFails() async throws {
        let session = MockLanguageModelSession()
        session.nextResult = .success(.fixture())
        session.nextTranslationResult = .failure(MockLanguageModelError.safetyFiltered)
        let extractor = KnowledgeExtractor(session: session)

        let englishText = """
        Apple announced a new framework called Foundation Models at WWDC. The on-device
        language model exposes structured output via the @Generable macro, enabling
        developers to add RAG features without external servers.
        """
        _ = try await extractor.extract(extractedText: englishText)

        // 翻訳は試みた
        #expect(session.translationCallCount == 1)
        // 失敗したので抽出は元の英文で進む (throw しない)
        #expect(session.callCount == 1)
        #expect(session.lastPrompt?.contains("announced a new framework") == true)
    }

    /// spec 101: 翻訳が notInstalled で失敗した言語は、以後の抽出で翻訳をスキップする
    /// (同じ言語の chunk を何度も翻訳して translationd をクラッシュさせるのを防ぐ)。
    @MainActor
    @Test func skipsTranslationForLanguageAfterNotInstalled() async throws {
        let session = MockLanguageModelSession()
        session.nextResult = .success(.fixture())
        session.nextTranslationResult = .failure(FakeNotInstalledTranslateError())
        let cache = TranslationCache()
        let extractor = KnowledgeExtractor(session: session, translationCache: cache)

        let english = """
        Apple announced a new framework called Foundation Models at WWDC. The on-device
        language model exposes structured output, enabling RAG features for SwiftUI apps.
        """
        // 1 回目: 翻訳が notInstalled で失敗 → en を unavailable 記録 + 英語のまま抽出
        _ = try await extractor.extract(extractedText: english)
        #expect(session.translationCallCount == 1)
        #expect(cache.isUnavailable(source: "en"))

        // 2 回目: en は unavailable → 翻訳をスキップ (call 数は増えない)
        _ = try await extractor.extract(extractedText: english + " Additional English sentence to extract.")
        #expect(session.translationCallCount == 1)
    }

    /// spec 1xx: コード片/記号混在等で低信頼な言語判定 (.other("pl") 等) が出ても、
    /// 翻訳対応言語集合の外なら翻訳を試みず raw のまま抽出へ進む (誤検知で例外を浪費しない)。
    @Test func prepareForExtractionSkipsTranslationForUnsupportedOtherLanguage() async {
        let session = MockLanguageModelSession()
        let extractor = KnowledgeExtractor(session: session)
        let text = "func foo() -> Int { return 42 } // 記号混在チャンクが pl 等に誤検知されるケースを模す"

        let prepared = await extractor.prepareForExtraction(text, override: .other("pl"))

        #expect(prepared == text)
        #expect(session.translationCallCount == 0)
    }

    // MARK: - i18n Phase B: zh パイプラインでの prepareForExtraction 一般化

    /// zh パイプラインでは日本語記事もパイプライン言語 (zh) と一致しないため翻訳経路に入る。
    @Test func extractInvokesTranslationForJapaneseWhenPipelineIsChinese() async throws {
        try await withPipelineLanguage(.zhHans) {
            let session = MockLanguageModelSession()
            session.nextResult = .success(.fixture())
            session.nextTranslationResult = .success(
                "苹果在 WWDC 上宣布了新的 Foundation Models 框架，公开了设备端语言模型的结构化输出能力。"
            )
            let extractor = KnowledgeExtractor(session: session)

            let japaneseText = """
            Swift 6 のリリースについて。Apple は新しい strict concurrency 機能を発表し、
            既存の async/await モデルをさらに堅牢化しました。開発者は migration mode を使って
            段階的に対応できます。
            """
            _ = try await extractor.extract(extractedText: japaneseText)

            #expect(session.translationCallCount == 1)
            // 抽出 prompt は翻訳後の中国語テキストを含む
            #expect(session.lastPrompt?.contains("苹果在 WWDC") == true)
            // 元の日本語本文は抽出 prompt に流れない
            #expect(session.lastPrompt?.contains("Swift 6 のリリースについて") == false)
        }
    }

    /// zh パイプラインでは中国語記事はパイプライン言語と一致するため翻訳をスキップする。
    @Test func extractSkipsTranslationForChineseWhenPipelineIsChinese() async throws {
        try await withPipelineLanguage(.zhHans) {
            let session = MockLanguageModelSession()
            session.nextResult = .success(.fixture())
            let extractor = KnowledgeExtractor(session: session)

            let chineseText = """
            苹果在全球开发者大会上发布了一个名为基础模型的全新框架。这个设备端的语言模型
            通过宏公开了结构化输出，使开发者无需依赖外部服务器即可为应用程序添加检索增强生成功能。
            """
            _ = try await extractor.extract(extractedText: chineseText)

            #expect(session.translationCallCount == 0)
            #expect(session.callCount == 1)
            #expect(session.lastPrompt?.contains("苹果在全球开发者大会") == true)
        }
    }

    // MARK: - 英語対応 (i18n Phase B): en パイプラインでの prepareForExtraction

    /// en パイプラインでは日本語記事もパイプライン言語 (en) と一致しないため翻訳経路に入る。
    @Test func extractInvokesTranslationForJapaneseWhenPipelineIsEnglish() async throws {
        try await withPipelineLanguage(.en) {
            let session = MockLanguageModelSession()
            session.nextResult = .success(.fixture())
            session.nextTranslationResult = .success(
                "Apple announced a new Foundation Models framework at WWDC, exposing structured " +
                "output from an on-device language model."
            )
            let extractor = KnowledgeExtractor(session: session)

            let japaneseText = """
            Swift 6 のリリースについて。Apple は新しい strict concurrency 機能を発表し、
            既存の async/await モデルをさらに堅牢化しました。開発者は migration mode を使って
            段階的に対応できます。
            """
            _ = try await extractor.extract(extractedText: japaneseText)

            #expect(session.translationCallCount == 1)
            // 抽出 prompt は翻訳後の英語テキストを含む
            #expect(session.lastPrompt?.contains("Apple announced a new Foundation Models framework") == true)
            // 元の日本語本文は抽出 prompt に流れない
            #expect(session.lastPrompt?.contains("Swift 6 のリリースについて") == false)
        }
    }

    /// en パイプラインでは英語記事はパイプライン言語と一致するため翻訳をスキップする。
    @Test func extractSkipsTranslationForEnglishWhenPipelineIsEnglish() async throws {
        try await withPipelineLanguage(.en) {
            let session = MockLanguageModelSession()
            session.nextResult = .success(.fixture())
            let extractor = KnowledgeExtractor(session: session)

            let englishText = """
            Apple announced a new framework called Foundation Models at WWDC. The on-device
            language model exposes structured output via the @Generable macro, enabling
            developers to add RAG features without external servers.
            """
            _ = try await extractor.extract(extractedText: englishText)

            #expect(session.translationCallCount == 0)
            #expect(session.callCount == 1)
            #expect(session.lastPrompt?.contains("announced a new framework") == true)
        }
    }
}

/// i18n Phase B: `PipelineLanguage.current` が参照する実 UserDefaults (App Group or .standard) を
/// テスト中だけ書き換え、終了後に元の値へ厳密に復元するヘルパ (実ストレージを汚染しない)。
@MainActor
func withPipelineLanguage<T>(_ language: PipelineLanguage, _ body: () async throws -> T) async rethrows -> T {
    let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    let originalRaw = defaults.string(forKey: PipelineLanguage.userDefaultsKey)
    defaults.set(language.rawValue, forKey: PipelineLanguage.userDefaultsKey)
    PipelineLanguage._resetForTesting()
    defer {
        if let originalRaw {
            defaults.set(originalRaw, forKey: PipelineLanguage.userDefaultsKey)
        } else {
            defaults.removeObject(forKey: PipelineLanguage.userDefaultsKey)
        }
        PipelineLanguage._resetForTesting()
    }
    return try await body()
}

/// spec 101: String(describing:) に "notInstalled" を含む擬似翻訳エラー。
private struct FakeNotInstalledTranslateError: Error, CustomStringConvertible {
    var description: String { "TranslationError(cause: Translation.TranslationError.Cause.notInstalled)" }
}

// MARK: - Mock

@MainActor
final class MockLanguageModelSession: LanguageModelSessionProtocol, @unchecked Sendable {
    var nextResult: Result<ExtractedKnowledgeOutput, Error> = .success(.fixture())
    var callCount = 0
    var lastPrompt: String?

    /// spec 018: Digest 用 mock 出力 (デフォルトは空 cards)
    var nextDigestResult: Result<DigestOutput, Error> = .success(DigestOutput(cards: []))
    var digestCallCount = 0
    var lastDigestPrompt: String?

    /// spec 021: ChatAnswer 用 mock 出力 (デフォルトは空回答 + 空 cited)
    var nextChatAnswerResult: Result<ChatAnswerOutput, Error> = .success(ChatAnswerOutput(answer: "", citedArticleIDs: []))
    var chatAnswerCallCount = 0
    var lastChatAnswerPrompt: String?

    /// spec 035: RecentDigest 用 mock 出力 (デフォルトは空 paragraphs)
    var nextRecentDigestResult: Result<RecentDigestOutput, Error> = .success(RecentDigestOutput(paragraphs: []))
    var recentDigestCallCount = 0
    var lastRecentDigestPrompt: String?

    /// spec 037: ConflictDetection 用 mock 出力 (デフォルトは矛盾なし)
    var nextConflictDetectionResult: Result<ConflictDetectionOutput, Error> = .success(
        ConflictDetectionOutput(hasConflict: false, conflictDescription: "", newFact: "", oldFact: "")
    )
    var conflictDetectionCallCount = 0
    var lastConflictDetectionPrompt: String?

    /// spec 036: TopicName 用 mock 出力 (デフォルトは "新トピック")
    var nextTopicNameResult: Result<TopicNameOutput, Error> = .success(TopicNameOutput(name: "新トピック"))
    var topicNameCallCount = 0
    var lastTopicNamePrompt: String?

    /// spec 040: GraphTriples 用 mock 出力 (デフォルトは空)
    var nextGraphTriplesResult: Result<GraphTripleOutput, Error> = .success(GraphTripleOutput(triples: []))
    var graphTriplesCallCount = 0
    var lastGraphTriplesPrompt: String?

    /// spec 042: Translation 用 mock 出力 (デフォルトは空文字列)
    var nextTranslationResult: Result<String, Error> = .success("")
    var translationCallCount = 0
    var lastTranslationText: String?

    /// spec 042: ConceptSynthesis 用 mock 出力 (デフォルトは empty summary + empty insights)
    var nextConceptSynthesisResult: Result<ConceptSynthesisOutput, Error> = .success(
        ConceptSynthesisOutput(summary: "", crossSourceInsights: [])
    )
    var conceptSynthesisCallCount = 0
    var lastConceptSynthesisPrompt: String?

    /// spec 080拡張: compact 再試行用 mock。デフォルトは空。
    var nextConceptSynthesisCompactResult: Result<ConceptSynthesisCompactOutput, Error> = .success(
        ConceptSynthesisCompactOutput(summary: "", crossSourceInsights: [])
    )
    var conceptSynthesisCompactCallCount = 0

    /// spec 042: ConceptSummaryChunk 用 mock 出力 (hierarchical パス用)
    var nextConceptSummaryChunkResult: Result<ConceptSummaryChunk, Error> = .success(
        ConceptSummaryChunk(chunkSummary: "")
    )
    var conceptSummaryChunkCallCount = 0
    var lastConceptSummaryChunkPrompt: String?

    /// spec 044: 学習タブ家庭教師用 mock 応答
    var nextTutorReplyResult: Result<String, Error> = .success("これは家庭教師 mock 応答です。")
    var tutorReplyCallCount = 0
    var lastTutorReplyPrompt: String?

    /// spec 057: Agentic Chat 用 AgentAction sequence (FIFO で消費)。
    /// nextAgentActions が空のとき、`defaultAgentAction` を返す。
    var nextAgentActions: [AgentAction] = []
    var defaultAgentAction: AgentAction = .immediate(answer: "Mock default agent answer")
    var agentActionCallCount = 0
    var lastAgentActionPrompt: String?
    var agentActionError: Error?

    func generateKnowledge(prompt: String) async throws -> ExtractedKnowledgeOutput {
        callCount += 1
        lastPrompt = prompt
        switch nextResult {
        case .success(let output): return output
        case .failure(let error): throw error
        }
    }

    /// 案A: chunk 抽出用小型スキーマ。デフォルトは nextResult から essence/keyFacts/entities を流用。
    var nextChunkResult: Result<ChunkKnowledgeOutput, Error>?
    private(set) var chunkCallCount = 0
    func generateChunkKnowledge(prompt: String) async throws -> ChunkKnowledgeOutput {
        chunkCallCount += 1
        lastPrompt = prompt
        if let nextChunkResult {
            switch nextChunkResult {
            case .success(let output): return output
            case .failure(let error): throw error
            }
        }
        // デフォルト: nextResult (ExtractedKnowledgeOutput) があれば中身を流用、無ければ fixture
        switch nextResult {
        case .success(let o):
            return ChunkKnowledgeOutput(essence: o.essence, keyFacts: o.keyFacts, entities: o.entities)
        case .failure(let error):
            throw error
        }
    }

    func generateDigest(prompt: String) async throws -> DigestOutput {
        digestCallCount += 1
        lastDigestPrompt = prompt
        switch nextDigestResult {
        case .success(let output): return output
        case .failure(let error): throw error
        }
    }

    func generateChatAnswer(prompt: String) async throws -> ChatAnswerOutput {
        chatAnswerCallCount += 1
        lastChatAnswerPrompt = prompt
        switch nextChatAnswerResult {
        case .success(let output): return output
        case .failure(let error): throw error
        }
    }

    func generateRecentDigest(prompt: String) async throws -> RecentDigestOutput {
        recentDigestCallCount += 1
        lastRecentDigestPrompt = prompt
        switch nextRecentDigestResult {
        case .success(let output): return output
        case .failure(let error): throw error
        }
    }

    func generateConflictDetection(prompt: String) async throws -> ConflictDetectionOutput {
        conflictDetectionCallCount += 1
        lastConflictDetectionPrompt = prompt
        switch nextConflictDetectionResult {
        case .success(let output): return output
        case .failure(let error): throw error
        }
    }

    func generateTopicName(prompt: String) async throws -> TopicNameOutput {
        topicNameCallCount += 1
        lastTopicNamePrompt = prompt
        switch nextTopicNameResult {
        case .success(let output): return output
        case .failure(let error): throw error
        }
    }

    func generateGraphTriples(prompt: String) async throws -> GraphTripleOutput {
        graphTriplesCallCount += 1
        lastGraphTriplesPrompt = prompt
        switch nextGraphTriplesResult {
        case .success(let output): return output
        case .failure(let error): throw error
        }
    }

    func translate(text: String) async throws -> String {
        translationCallCount += 1
        lastTranslationText = text
        switch nextTranslationResult {
        case .success(let output): return output
        case .failure(let error): throw error
        }
    }

    func generateConceptSynthesis(prompt: String) async throws -> ConceptSynthesisOutput {
        conceptSynthesisCallCount += 1
        lastConceptSynthesisPrompt = prompt
        switch nextConceptSynthesisResult {
        case .success(let output): return output
        case .failure(let error): throw error
        }
    }

    func generateConceptSynthesisCompact(prompt: String) async throws -> ConceptSynthesisCompactOutput {
        conceptSynthesisCompactCallCount += 1
        switch nextConceptSynthesisCompactResult {
        case .success(let output): return output
        case .failure(let error): throw error
        }
    }

    func generateConceptSummaryChunk(prompt: String) async throws -> ConceptSummaryChunk {
        conceptSummaryChunkCallCount += 1
        lastConceptSummaryChunkPrompt = prompt
        switch nextConceptSummaryChunkResult {
        case .success(let output): return output
        case .failure(let error): throw error
        }
    }

    func generateTutorReply(prompt: String) async throws -> String {
        tutorReplyCallCount += 1
        lastTutorReplyPrompt = prompt
        switch nextTutorReplyResult {
        case .success(let output): return output
        case .failure(let error): throw error
        }
    }

    // spec 063 (LLM Wiki): Wiki 本文 plain string 生成
    var nextWikiBodyResult: Result<String, Error>?
    private(set) var wikiBodyCallCount = 0
    func generateWikiBody(prompt: String) async throws -> String {
        wikiBodyCallCount += 1
        if let result = nextWikiBodyResult {
            switch result {
            case .success(let s): return s
            case .failure(let e): throw e
            }
        }
        return "## 概要\nダミー Wiki 本文。\n\n- 要点 1\n- 要点 2"
    }

    func generateAgentAction(prompt: String) async throws -> AgentAction {
        agentActionCallCount += 1
        lastAgentActionPrompt = prompt
        if let error = agentActionError {
            agentActionError = nil
            throw error
        }
        if !nextAgentActions.isEmpty {
            return nextAgentActions.removeFirst()
        }
        return defaultAgentAction
    }

    // spec 074 (概念階層): 広い概念 + 具体概念の抽出
    var nextConceptHierarchyResult: Result<ConceptHierarchyOutput, Error> = .success(
        ConceptHierarchyOutput(broadConcept: "", specificConcepts: [])
    )
    private(set) var conceptHierarchyCallCount = 0
    var lastConceptHierarchyPrompt: String?
    func generateConceptHierarchy(prompt: String) async throws -> ConceptHierarchyOutput {
        conceptHierarchyCallCount += 1
        lastConceptHierarchyPrompt = prompt
        switch nextConceptHierarchyResult {
        case .success(let output): return output
        case .failure(let error): throw error
        }
    }
}

enum MockLanguageModelError: Error {
    case safetyFiltered
    case contextExceeded
    case timeout
}

// MARK: - Fixture

extension ExtractedKnowledgeOutput {
    static func fixture(
        essence: String = "Apple は WWDC で iOS 26 を発表した。",
        summary: String = "Apple は 2025 年の WWDC で iOS 26 を発表し、Foundation Models を公開した。Tim Cook 氏は AI のオンデバイス実行を強調した。",
        keyFacts: [KeyFactOutput] = [
            KeyFactOutput(statement: "WWDC 2025 が開催された", type: .event),
            KeyFactOutput(statement: "iOS 26 が発表された", type: .event),
            KeyFactOutput(statement: "Foundation Models は on-device で動作する", type: .claim),
        ],
        entities: [KnowledgeEntityOutput] = [
            KnowledgeEntityOutput(name: "Apple", type: .organization, salience: 5),
            KnowledgeEntityOutput(name: "iOS 26", type: .product, salience: 5),
            KnowledgeEntityOutput(name: "WWDC", type: .concept, salience: 4),
            KnowledgeEntityOutput(name: "Tim Cook", type: .person, salience: 4),
            KnowledgeEntityOutput(name: "Foundation Models", type: .product, salience: 5),
        ]
    ) -> Self {
        Self(essence: essence, summary: summary, keyFacts: keyFacts, entities: entities)
    }
}

//
//  DirectReadExtractionTests.swift
//  KnowledgeTreeTests
//
//  spec 106 — KnowledgeExtractor の直接読み / 逆向き fallback / 出力言語ガード。
//

import Testing
import Foundation
@testable import KnowledgeBase

@Suite(.serialized)
@MainActor
struct DirectReadExtractionTests {
    private let japaneseText = """
    Swift 6 のリリースについて。Apple は新しい strict concurrency 機能を発表し、
    既存の async/await モデルをさらに堅牢化しました。開発者は migration mode を使って
    段階的に対応できます。
    """

    private let englishEssence = "Apple announced new strict concurrency features in Swift 6 for developers."
    private let translated = "About the Swift 6 release. Apple announced new strict concurrency features and " +
        "further hardened the async/await model. Developers can adopt it gradually."

    private func englishOutput() -> ExtractedKnowledgeOutput {
        .fixture(essence: englishEssence)
    }

    @Test func japaneseArticleIsReadDirectlyWithEnglishPipeline() async throws {
        try await withPipelineLanguage(.en) {
            let session = MockLanguageModelSession()
            session.nextResult = .success(englishOutput())
            let extractor = KnowledgeExtractor(session: session, preferTranslateFirst: { false })
            _ = try await extractor.extract(extractedText: japaneseText)

            #expect(session.translationCallCount == 0)
            #expect(session.callCount == 1)
            #expect(session.lastPrompt?.contains("Swift 6 のリリースについて") == true)
            #expect(session.lastPrompt?.contains("Output language: English") == true)
        }
    }

    @Test func switchOnRestoresTranslateFirst() async throws {
        try await withPipelineLanguage(.en) {
            let session = MockLanguageModelSession()
            session.nextResult = .success(englishOutput())
            session.nextTranslationResult = .success(translated)
            let extractor = KnowledgeExtractor(session: session, preferTranslateFirst: { true })
            _ = try await extractor.extract(extractedText: japaneseText)

            #expect(session.translationCallCount == 1)
            #expect(session.lastPrompt?.contains("About the Swift 6 release") == true)
        }
    }

    @Test func directReadFailingWithUnsupportedLanguageRetriesOnceWithTranslation() async throws {
        try await withPipelineLanguage(.en) {
            let session = MockLanguageModelSession()
            session.nextTranslationResult = .success(translated)
            session.knowledgeResultQueue = [
                .failure(FakeGenerationError(description: "unsupportedLanguageOrLocale(Unsupported language.)")),
                .success(englishOutput()),
            ]
            let extractor = KnowledgeExtractor(session: session, preferTranslateFirst: { false })
            _ = try await extractor.extract(extractedText: japaneseText)

            #expect(session.callCount == 2)
            #expect(session.translationCallCount == 1)
            #expect(session.lastPrompt?.contains("About the Swift 6 release") == true)
        }
    }

    @Test func directReadRetryDoesNotLoopWhenTranslatedAlsoFails() async throws {
        await withPipelineLanguage(.en) {
            let session = MockLanguageModelSession()
            session.nextTranslationResult = .success(translated)
            session.knowledgeResultQueue = [
                .failure(FakeGenerationError(description: "unsupportedLanguageOrLocale(x)")),
                .failure(FakeGenerationError(description: "unsupportedLanguageOrLocale(x)")),
                .success(englishOutput()),
            ]
            let extractor = KnowledgeExtractor(session: session, preferTranslateFirst: { false })
            await #expect(throws: (any Error).self) {
                _ = try await extractor.extract(extractedText: japaneseText)
            }
            #expect(session.callCount == 2)
            #expect(session.translationCallCount == 1)
        }
    }

    @Test func chunkDirectReadFailureRetriesOnceWithTranslation() async throws {
        await withPipelineLanguage(.en) {
            let session = MockLanguageModelSession()
            session.nextTranslationResult = .success(translated)
            session.chunkResultQueue = [
                .failure(FakeGenerationError(description: "unsupportedLanguageOrLocale(x)")),
                .success(ChunkKnowledgeOutput(essence: "ok", keyFacts: [], entities: [])),
            ]
            let extractor = KnowledgeExtractor(session: session, preferTranslateFirst: { false })
            let result = await extractor.extractFromChunk(Chunk(index: 0, total: 1, text: japaneseText))

            #expect(result.error == nil)
            #expect(session.chunkCallCount == 2)
            #expect(session.chunkPrompts.last?.contains("About the Swift 6 release") == true)
        }
    }

    @Test func wrongLanguageEssenceTriggersOneTranslationRetry() async throws {
        try await withPipelineLanguage(.en) {
            let session = MockLanguageModelSession()
            session.nextTranslationResult = .success(translated)
            session.knowledgeResultQueue = [
                // 生成言語 English なのに日本語の essence が返った
                .success(.fixture(essence: "開発者は新しい並行処理の機能を使って、段階的に移行できるようになった。")),
                .success(englishOutput()),
            ]
            let extractor = KnowledgeExtractor(session: session, preferTranslateFirst: { false })
            let output = try await extractor.extract(extractedText: japaneseText)

            #expect(session.callCount == 2)
            #expect(session.translationCallCount == 1)
            #expect(output.essence == englishEssence)
        }
    }

    @Test func languageGuardDoesNotRetryWhenEssenceMatches() async throws {
        try await withPipelineLanguage(.en) {
            let session = MockLanguageModelSession()
            session.nextResult = .success(englishOutput())
            let extractor = KnowledgeExtractor(session: session, preferTranslateFirst: { false })
            _ = try await extractor.extract(extractedText: japaneseText)
            #expect(session.callCount == 1)
            #expect(session.translationCallCount == 0)
        }
    }

    @Test func languageGuardDoesNotRetryAfterTranslation() async throws {
        try await withPipelineLanguage(.en) {
            let session = MockLanguageModelSession()
            session.nextTranslationResult = .success(translated)
            session.nextResult = .success(.fixture(essence: "開発者は新しい並行処理の機能を使って、段階的に移行できるようになった。"))
            let extractor = KnowledgeExtractor(session: session, preferTranslateFirst: { true })
            _ = try await extractor.extract(extractedText: japaneseText)
            #expect(session.callCount == 1)
            #expect(session.translationCallCount == 1)
        }
    }

    @Test func outputLanguageMismatchIsPureAndSkipsShortText() {
        #expect(KnowledgeExtractor.outputLanguageMismatch(essence: "短い", pipeline: .en) == nil)
        #expect(KnowledgeExtractor.outputLanguageMismatch(essence: englishEssence, pipeline: .en) == nil)
        #expect(KnowledgeExtractor.outputLanguageMismatch(essence: "開発者は新しい並行処理の機能を使って、段階的に移行できるようになった。", pipeline: .en) != nil)
    }

    @Test func kanaEssenceIsNeverFlaggedForJapanesePipeline() {
        // 英単語だらけでも、かなを含む essence は日本語として扱う
        #expect(KnowledgeExtractor.outputLanguageMismatch(essence: "Apple は WWDC で iOS 26 と Foundation Models を発表した。", pipeline: .ja) == nil)
    }

    // MARK: - QA 修正: 翻訳を試みて失敗した場合は再翻訳しない

    private let englishText = """
    Apple announced a new framework called Foundation Models at WWDC. The on-device
    language model exposes structured output via the @Generable macro, enabling
    developers to add RAG features without external servers.
    """

    @Test func jaPipelineTranslationFailureDoesNotTranslateAgainEvenIfEssenceIsEnglish() async throws {
        try await withPipelineLanguage(.ja) {
            let session = MockLanguageModelSession()
            session.nextTranslationResult = .failure(MockLanguageModelError.safetyFiltered)
            session.nextResult = .success(.fixture(essence: englishEssence))
            let extractor = KnowledgeExtractor(session: session)
            _ = try await extractor.extract(extractedText: englishText)
            #expect(session.translationCallCount == 1)
            #expect(session.callCount == 1)
        }
    }

    @Test func jaPipelineTranslationFailureThenUnsupportedLanguageThrowsWithoutRetranslation() async throws {
        await withPipelineLanguage(.ja) {
            let session = MockLanguageModelSession()
            session.nextTranslationResult = .failure(MockLanguageModelError.safetyFiltered)
            session.nextResult = .failure(FakeGenerationError(description: "unsupportedLanguageOrLocale(x)"))
            let extractor = KnowledgeExtractor(session: session)
            await #expect(throws: (any Error).self) {
                _ = try await extractor.extract(extractedText: englishText)
            }
            #expect(session.translationCallCount == 1)
            #expect(session.callCount == 1)
        }
    }

    @Test func switchOnTranslationFailureDoesNotTranslateAgain() async throws {
        try await withPipelineLanguage(.en) {
            let session = MockLanguageModelSession()
            session.nextTranslationResult = .failure(MockLanguageModelError.safetyFiltered)
            session.nextResult = .success(.fixture(essence: "開発者は新しい並行処理の機能を使って、段階的に移行できるようになった。"))
            let extractor = KnowledgeExtractor(session: session, preferTranslateFirst: { true })
            _ = try await extractor.extract(extractedText: japaneseText)
            #expect(session.translationCallCount == 1)
            #expect(session.callCount == 1)
        }
    }

    @Test func chunkTranslationFailureDoesNotTranslateAgain() async throws {
        await withPipelineLanguage(.ja) {
            let session = MockLanguageModelSession()
            session.nextTranslationResult = .failure(MockLanguageModelError.safetyFiltered)
            session.chunkResultQueue = [.failure(FakeGenerationError(description: "unsupportedLanguageOrLocale(x)"))]
            let extractor = KnowledgeExtractor(session: session)
            let result = await extractor.extractFromChunk(Chunk(index: 0, total: 1, text: englishText))
            #expect(result.error != nil)
            #expect(session.translationCallCount == 1)
            #expect(session.chunkCallCount == 1)
        }
    }

    @Test func zhShortcutTreatsHanOnlyEssenceAsMatching() {
        let zh = "蘋果在 WWDC 發表了 Foundation Models 框架，供開發者使用。"
        #expect(KnowledgeExtractor.outputLanguageMismatch(essence: zh, pipeline: .zhHant) == nil)
        #expect(KnowledgeExtractor.outputLanguageMismatch(essence: zh, pipeline: .zhHans) == nil)
        #expect(KnowledgeExtractor.outputLanguageMismatch(essence: "開発者は新しい並行処理の機能を使って、段階的に移行できるようになった。", pipeline: .zhHant) != nil)
    }
}

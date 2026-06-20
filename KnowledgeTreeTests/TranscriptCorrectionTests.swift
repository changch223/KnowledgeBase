//
//  TranscriptCorrectionTests.swift
//  KnowledgeTreeTests
//
//  spec 094 — 文字起こし用語補正の純関数部分を検証。
//  LLM 呼び出し部分は実機 Foundation Models 依存のため protocol 化のみ (実機検証で担保)。
//

import Testing
import Foundation
@testable import KnowledgeTree

@MainActor
struct TranscriptCorrectionTests {

    // (1) 用語集が空なら原文をそのまま返す (LLM を呼ばない)
    @Test func emptyGlossaryReturnsOriginal() async {
        let service = LLMTranscriptCorrectionService(session: NoopCorrectionSession())
        let input = "これはテストの文字起こしです。固有名詞があります。"
        let result = await service.correct(input, glossary: [])
        #expect(result == input)
    }

    // (2) 短すぎる入力は補正しない
    @Test func tooShortReturnsOriginal() async {
        let service = LLMTranscriptCorrectionService(session: NoopCorrectionSession())
        let input = "短い"
        let result = await service.correct(input, glossary: ["Claude Code"])
        #expect(result == input)
    }

    // (3) window 分割: size 以下は 1 つ、超過は複数に割れる
    @Test func splitIntoWindows() {
        let short = "一文だけ。"
        #expect(LLMTranscriptCorrectionService.splitIntoWindows(short, size: 100).count == 1)

        let sentence = String(repeating: "あ", count: 30) + "。"
        let long = String(repeating: sentence, count: 10)  // ~310 字
        let windows = LLMTranscriptCorrectionService.splitIntoWindows(long, size: 100)
        #expect(windows.count > 1)
        // 再結合すると元に戻る (取りこぼしなし)
        #expect(windows.joined() == long)
    }

    // (4) プロンプトに用語集と本文が含まれる
    @Test func promptContainsTermsAndText() {
        let prompt = LLMTranscriptCorrectionService.buildPrompt(
            text: "クロードコードを使った。",
            terms: ["Claude Code", "Anthropic"]
        )
        #expect(prompt.contains("Claude Code"))
        #expect(prompt.contains("Anthropic"))
        #expect(prompt.contains("クロードコードを使った。"))
    }

    // (5) spec 095: 訂正指示プロンプトに指示と本文が含まれる
    @Test func instructionPromptContainsInstructionAndText() {
        let prompt = LLMTranscriptCorrectionService.buildInstructionPrompt(
            text: "cloudecod を使った。",
            instruction: "cloudecod ではなく Claude Code です"
        )
        #expect(prompt.contains("cloudecod ではなく Claude Code です"))
        #expect(prompt.contains("cloudecod を使った。"))
        // 指示完全一致だけでなく、音・つづりが近い表記ゆれも漏れなく直すよう指示している。
        #expect(prompt.contains("表記ゆれ"))
        #expect(prompt.contains("一箇所も残さず"))
    }

    // (6) spec 095: 指示が空なら原文をそのまま返す (LLM を呼ばない)
    @Test func emptyInstructionReturnsOriginal() async {
        let service = LLMTranscriptCorrectionService(session: NoopCorrectionSession())
        let input = "cloudecod を使った。これは本文です。"
        let result = await service.applyInstruction(input, instruction: "   ")
        #expect(result == input)
    }
}

/// LLM を呼ばないダミー (空用語集・短文パスで LLM 経路に入らないことの確認用)。
private final class NoopCorrectionSession: LanguageModelSessionProtocol, @unchecked Sendable {
    func generateKnowledge(prompt: String) async throws -> ExtractedKnowledgeOutput { .fixture() }
    func generateChunkKnowledge(prompt: String) async throws -> ChunkKnowledgeOutput { throw Err.unused }
    func generateDigest(prompt: String) async throws -> DigestOutput { throw Err.unused }
    func generateChatAnswer(prompt: String) async throws -> ChatAnswerOutput { throw Err.unused }
    func generateRecentDigest(prompt: String) async throws -> RecentDigestOutput { throw Err.unused }
    func generateConflictDetection(prompt: String) async throws -> ConflictDetectionOutput { throw Err.unused }
    func generateTopicName(prompt: String) async throws -> TopicNameOutput { throw Err.unused }
    func generateGraphTriples(prompt: String) async throws -> GraphTripleOutput { throw Err.unused }
    func generateConceptSynthesis(prompt: String) async throws -> ConceptSynthesisOutput { throw Err.unused }
    func generateConceptSummaryChunk(prompt: String) async throws -> ConceptSummaryChunk { throw Err.unused }
    func generateConceptSynthesisCompact(prompt: String) async throws -> ConceptSynthesisCompactOutput { throw Err.unused }
    func generateConceptHierarchy(prompt: String) async throws -> ConceptHierarchyOutput { throw Err.unused }
    func translate(text: String) async throws -> String { text }
    func generateTutorReply(prompt: String) async throws -> String { "" }
    func generateWikiBody(prompt: String) async throws -> String { "" }
    func generateAgentAction(prompt: String) async throws -> AgentAction { throw Err.unused }

    enum Err: Error { case unused }
}

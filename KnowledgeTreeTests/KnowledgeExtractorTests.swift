//
//  KnowledgeExtractorTests.swift
//  KnowledgeTreeTests
//
//  spec 004 — contracts/knowledge-extractor.md
//  Mock LanguageModelSession で決定論的に走る (実 Foundation Models 不使用)。
//

import Testing
import Foundation
@testable import KnowledgeTree

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
        #expect(output.keyFacts.isEmpty)
        #expect(output.entities.isEmpty)
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
        #expect(output.keyFacts.isEmpty)
        #expect(output.entities.isEmpty)
    }

    @Test func buildPromptIncludesText() {
        let prompt = KnowledgeExtractor.buildPrompt(text: "ABC 元記事")
        #expect(prompt.contains("ABC 元記事"))
        #expect(prompt.contains("# 抽出ルール"))
        #expect(prompt.contains("# 元記事本文"))
    }
}

// MARK: - Mock

@MainActor
final class MockLanguageModelSession: LanguageModelSessionProtocol, @unchecked Sendable {
    var nextResult: Result<ExtractedKnowledgeOutput, Error> = .success(.fixture())
    var callCount = 0
    var lastPrompt: String?

    func generateKnowledge(prompt: String) async throws -> ExtractedKnowledgeOutput {
        callCount += 1
        lastPrompt = prompt
        switch nextResult {
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

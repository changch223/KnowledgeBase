//
//  ConceptLinkingTests.swift
//  KnowledgeTreeTests
//
//  spec 064 (LLM Wiki) — 関係発見 (embedding 近傍) + 相互リンク (sanitize / URL 解析) の純関数テスト。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

@MainActor
struct ConceptLinkingTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    private func makeService(_ container: ModelContainer) -> FoundationModelsConceptSynthesisService {
        let context = container.mainContext
        return FoundationModelsConceptSynthesisService(
            session: MockLanguageModelSession(),
            availability: MockAvailabilityChecker(),
            fallback: FallbackConceptSynthesisService(context: context),
            context: context
        )
    }

    /// L2 正規化済みの単位ベクトルを Data 化 (cosineSimilarity = dot product 前提)。
    private func vec(_ floats: [Float]) -> Data {
        floats.asEmbeddingData
    }

    @discardableResult
    private func insertPage(
        _ context: ModelContext,
        name: String,
        embedding: [Float]?,
        isHidden: Bool = false
    ) -> ConceptPage {
        let p = ConceptPage(name: name, categoryRaw: "tech")
        if let embedding { p.embedding = embedding.asEmbeddingData }
        p.isHidden = isHidden
        context.insert(p)
        return p
    }

    // MARK: - nearestConceptIDs

    @Test func nearestExcludesSelfAndLowSimilarityAndHidden() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let service = makeService(container)

        let target = insertPage(ctx, name: "Target", embedding: [1, 0, 0])
        let close = insertPage(ctx, name: "Close", embedding: [1, 0, 0])           // sim 1.0 → 含む
        let mid = insertPage(ctx, name: "Mid", embedding: [0.8, 0.6, 0])           // sim 0.8 → 含む
        insertPage(ctx, name: "Orthogonal", embedding: [0, 1, 0])                  // sim 0.0 < 0.5 → 除外
        let hidden = insertPage(ctx, name: "Hidden", embedding: [1, 0, 0], isHidden: true) // 除外

        let result = service.nearestConceptIDs(for: target, in: ctx)

        #expect(result.contains(close.id))
        #expect(result.contains(mid.id))
        #expect(!result.contains(target.id))     // self 除外
        #expect(!result.contains(hidden.id))     // isHidden 除外
        #expect(result.count == 2)               // orthogonal も除外
    }

    @Test func nearestReturnsEmptyWhenNoEmbedding() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let service = makeService(container)

        let target = insertPage(ctx, name: "NoEmbed", embedding: nil)
        insertPage(ctx, name: "Other", embedding: [1, 0, 0])

        #expect(service.nearestConceptIDs(for: target, in: ctx).isEmpty)
    }

    @Test func nearestCapsAtLimit() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let service = makeService(container)

        let target = insertPage(ctx, name: "Target", embedding: [1, 0, 0])
        for i in 0..<12 {
            insertPage(ctx, name: "P\(i)", embedding: [1, 0, 0])  // 全部 sim 1.0
        }

        let result = service.nearestConceptIDs(for: target, in: ctx)
        #expect(result.count == FoundationModelsConceptSynthesisService.relatedConceptLimit)
    }

    // MARK: - sanitizeConceptLinks

    @Test func sanitizePreservesValidLink() {
        let id = UUID()
        let md = "詳細は [Swift](concept-id://\(id.uuidString)) を参照。"
        let out = FoundationModelsConceptSynthesisService.sanitizeConceptLinks(in: md, validIDs: [id])
        #expect(out == md)
    }

    @Test func sanitizeStripsInvalidLink() {
        let valid = UUID()
        let bogus = UUID()
        let md = "[Swift](concept-id://\(bogus.uuidString)) は良い。"
        let out = FoundationModelsConceptSynthesisService.sanitizeConceptLinks(in: md, validIDs: [valid])
        #expect(out == "Swift は良い。")
        #expect(!out.contains("concept-id://"))
    }

    @Test func sanitizeMixedKeepsValidStripsInvalid() {
        let valid = UUID()
        let bogus = UUID()
        let md = "[A](concept-id://\(valid.uuidString)) と [B](concept-id://\(bogus.uuidString))。"
        let out = FoundationModelsConceptSynthesisService.sanitizeConceptLinks(in: md, validIDs: [valid])
        #expect(out.contains("[A](concept-id://\(valid.uuidString))"))
        #expect(out.contains("B"))
        #expect(!out.contains(bogus.uuidString))
    }

    @Test func sanitizeNoLinksUnchanged() {
        let md = "リンクのない普通の本文です。"
        let out = FoundationModelsConceptSynthesisService.sanitizeConceptLinks(in: md, validIDs: [UUID()])
        #expect(out == md)
    }

    // MARK: - extractConceptID

    @Test func extractParsesConceptScheme() {
        let id = UUID()
        let url = URL(string: "concept-id://\(id.uuidString)")!
        #expect(ConceptPageDetailView.extractConceptID(from: url) == id)
    }

    @Test func extractRejectsOtherScheme() {
        let url = URL(string: "article-id://\(UUID().uuidString)")!
        #expect(ConceptPageDetailView.extractConceptID(from: url) == nil)
    }
}

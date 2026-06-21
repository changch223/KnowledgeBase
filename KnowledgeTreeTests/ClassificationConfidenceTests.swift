//
//  ClassificationConfidenceTests.swift
//  KnowledgeTreeTests
//
//  spec 097 Phase 1 — 分類の確信度パース + 第1段特例 + InMemory mock の確信度。
//

import Testing
@testable import KnowledgeTree

@MainActor
struct ClassificationConfidenceTests {

    // LM 出力文字列を寛容にパース (不明は安全側で medium)。
    @Test func parsesConfidenceLeniently() {
        #expect(ClassificationConfidence.parse("High") == .high)
        #expect(ClassificationConfidence.parse(" low ") == .low)
        #expect(ClassificationConfidence.parse("Medium") == .medium)
        #expect(ClassificationConfidence.parse("なんか変な値") == .medium)
        #expect(ClassificationConfidence.parse("") == .medium)
    }

    // 第1段特例に主要分野が1行ずつ入っている (IT 偏重の是正)。
    @Test func firstPassTieBreakersCoverMainFields() {
        let t = CategorySeed.firstPassTieBreakers
        #expect(t.contains("テクノロジー"))
        #expect(t.contains("健康"))
        #expect(t.contains("経済"))
        #expect(t.contains("スポーツ"))
        #expect(t.contains("ニュース"))
    }

    // InMemory mock は category + confidence を返す。
    @Test func inMemoryReturnsConfidence() async {
        let classifier = InMemoryAutoCategoryClassifier(
            mapping: ["ai": "テクノロジー", "腸内細菌": "健康"],
            confidenceMapping: ["ai": .high, "腸内細菌": .medium]
        )
        let ai = await classifier.classifyDetailed(tagName: "AI", context: nil)
        #expect(ai.category == "テクノロジー")
        #expect(ai.confidence == .high)
        let gut = await classifier.classifyDetailed(tagName: "腸内細菌", context: nil)
        #expect(gut.confidence == .medium)
        // 互換: 文字列版はカテゴリのみ。
        let s = await classifier.classify(tagName: "AI")
        #expect(s == "テクノロジー")
    }
}

//
//  ConceptShelfPolicyTests.swift
//  KnowledgeTreeTests
//
//  spec 105 — 書架判定 / 新しい要点の差分判定 (純関数)。
//

import Testing
import Foundation
@testable import KnowledgeBase

struct ConceptShelfPolicyTests {
    @Test func broadManyArticlesWithChildrenIsShelf() {
        #expect(ConceptShelfPolicy.isShelf(level: .broad, articleCount: 31, childCount: 4))
    }

    @Test func broadWithoutChildrenIsNotShelf() {
        #expect(!ConceptShelfPolicy.isShelf(level: .broad, articleCount: 31, childCount: 0))
    }

    @Test func thresholdBoundaryIsExclusive() {
        #expect(!ConceptShelfPolicy.isShelf(level: .broad, articleCount: ConceptShelfPolicy.articleThreshold, childCount: 4))
        #expect(ConceptShelfPolicy.isShelf(level: .broad, articleCount: ConceptShelfPolicy.articleThreshold + 1, childCount: 4))
    }

    @Test func specificIsNeverShelf() {
        #expect(!ConceptShelfPolicy.isShelf(level: .specific, articleCount: 40, childCount: 3))
    }

    @Test func newInsightsEmptySeenIsEmpty() {
        #expect(ConceptShelfPolicy.newInsights(current: ["a", "b", "c"], seen: []).isEmpty)
    }

    @Test func newInsightsReturnsAddedOnly() {
        #expect(ConceptShelfPolicy.newInsights(current: ["a", "b", "c"], seen: ["a", "b"]) == ["c"])
    }

    @Test func newInsightsSameIsEmpty() {
        #expect(ConceptShelfPolicy.newInsights(current: ["a", "b"], seen: ["a", "b"]).isEmpty)
    }

    @Test func newInsightsTreatsParaphraseAsKnown() {
        let seen = ["RAG は検索と生成を組み合わせる手法です。"]
        let current = ["RAG は検索と生成を組み合わせる手法。"]
        #expect(ConceptShelfPolicy.newInsights(current: current, seen: seen).isEmpty)
    }

    @Test func newInsightsDetectsDifferentContent() {
        let seen = ["RAG は検索と生成を組み合わせる手法です。"]
        let current = ["ベクトルDBの選定ではインデックス方式が重要になる。"]
        #expect(ConceptShelfPolicy.newInsights(current: current, seen: seen) == ["ベクトルDBの選定ではインデックス方式が重要になる。"])
    }
}

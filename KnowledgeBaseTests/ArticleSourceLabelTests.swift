//
//  ArticleSourceLabelTests.swift
//  KnowledgeTreeTests
//
//  spec 103 — ArticleSourceLabel 純関数。
//

import Testing
import Foundation
@testable import KnowledgeBase

struct ArticleSourceLabelTests {
    @Test func domainStripsWww() {
        #expect(ArticleSourceLabel.label(for: "https://www.nikkei.com/x") == .domain("nikkei.com"))
    }

    @Test func noteIntake() {
        #expect(ArticleSourceLabel.label(for: "knowledgebase://note/abc") == .intake(.note))
    }

    @Test func audioIntake() {
        #expect(ArticleSourceLabel.label(for: "knowledgebase://audio/abc") == .intake(.audio))
    }

    @Test func invalidIsUnknown() {
        #expect(ArticleSourceLabel.label(for: "not a url") == .unknown)
        #expect(ArticleSourceLabel.Kind.unknown.localizedText.isEmpty)
    }
}

//
//  IntakeInputClassifierTests.swift
//  KnowledgeTreeTests
//
//  spec 103 — IntakeInputClassifier 純関数。
//

import Testing
import Foundation
@testable import KnowledgeBase

struct IntakeInputClassifierTests {
    @Test func plainURL() {
        #expect(IntakeInputClassifier.classify("https://a.com/x") == .url(URL(string: "https://a.com/x")!))
    }

    @Test func urlWithSurroundingWhitespace() {
        #expect(IntakeInputClassifier.classify("  https://a.com  ") == .url(URL(string: "https://a.com")!))
    }

    @Test func wwwGetsHttps() {
        #expect(IntakeInputClassifier.classify("www.a.com") == .url(URL(string: "https://www.a.com")!))
    }

    @Test func urlInsideSentenceIsNote() {
        let text = "これは https://a.com のメモ"
        #expect(IntakeInputClassifier.classify(text) == .note(text))
    }

    @Test func ftpIsNote() {
        #expect(IntakeInputClassifier.classify("ftp://a.com") == .note("ftp://a.com"))
    }

    @Test func emptyIsEmpty() {
        #expect(IntakeInputClassifier.classify("") == .empty)
        #expect(IntakeInputClassifier.classify("  \n ") == .empty)
    }
}

//
//  LanguageDetectorTests.swift
//  KnowledgeTreeTests
//
//  spec 042 — LanguageDetector 純関数 3 ケース。
//

import Testing
import Foundation
@testable import KnowledgeTree

struct LanguageDetectorTests {

    // MARK: - 1. 日本語本文 → .japanese

    @Test func testDetectJapanese() {
        let text = """
        SwiftUI で SwiftData を組み合わせて知識グラフを構築する方法について考察します。
        Foundation Models を使って entity を抽出し、Category 内で関係性を集約することで、
        ユーザーが保存した記事から体系化された知識を蓄積できます。
        """
        #expect(LanguageDetector.detect(text) == .japanese)
    }

    // MARK: - 2. 英語本文 → .english

    @Test func testDetectEnglish() {
        let text = """
        Apple announced a new framework called Foundation Models at WWDC. The on-device
        language model supports structured output via the @Generable macro, enabling
        applications to build knowledge graphs and conversational features without
        sending data to external servers.
        """
        #expect(LanguageDetector.detect(text) == .english)
    }

    // MARK: - 3. 短すぎる / 判定不能 → .unknown

    @Test func testDetectUnknownForShortInput() {
        #expect(LanguageDetector.detect("Hi") == .unknown)
        #expect(LanguageDetector.detect("   ") == .unknown)
        #expect(LanguageDetector.detect("") == .unknown)
    }
}

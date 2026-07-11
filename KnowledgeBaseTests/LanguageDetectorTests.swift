//
//  LanguageDetectorTests.swift
//  KnowledgeTreeTests
//
//  spec 042 — LanguageDetector 純関数 3 ケース。
//

import Testing
import Foundation
@testable import KnowledgeBase

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

    // MARK: - 4. 翻訳対応言語の判定 (誤検知ガード)

    /// ja / en / zh (Hans/Hant/bare のどの表記でも) / ko は翻訳対応言語として扱う。
    @Test func testIsTranslationSupportedForKnownLanguages() {
        #expect(LanguageDetector.isTranslationSupported("ja"))
        #expect(LanguageDetector.isTranslationSupported("en"))
        #expect(LanguageDetector.isTranslationSupported("zh-Hans"))
        #expect(LanguageDetector.isTranslationSupported("zh-Hant"))
        #expect(LanguageDetector.isTranslationSupported("zh"))
        #expect(LanguageDetector.isTranslationSupported("KO"))  // 大文字小文字を無視
    }

    /// コード片/記号混在チャンク等で誤検知されがちな低信頼な言語コード (pl 等) は非対応。
    @Test func testIsTranslationSupportedRejectsUnsupportedLanguage() {
        #expect(!LanguageDetector.isTranslationSupported("pl"))
        #expect(!LanguageDetector.isTranslationSupported("id"))
        #expect(!LanguageDetector.isTranslationSupported("nl"))
    }
}

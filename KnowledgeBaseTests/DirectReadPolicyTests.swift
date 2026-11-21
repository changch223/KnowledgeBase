//
//  DirectReadPolicyTests.swift
//  KnowledgeTreeTests
//
//  spec 106 — 翻訳せず原文を直接読むか / 翻訳してから抽出するかの判定 (純関数)。
//

import Testing
import Foundation
@testable import KnowledgeBase

@MainActor
struct DirectReadPolicyTests {

    @Test func japaneseArticleWithEnglishPipelineIsReadDirectly() {
        #expect(!DirectReadPolicy.shouldTranslateFirst(detected: .japanese, pipeline: .en, preferTranslate: false))
    }

    @Test func unreadableLanguageIsTranslated() {
        #expect(DirectReadPolicy.shouldTranslateFirst(detected: .other("pl"), pipeline: .en, preferTranslate: false))
    }

    @Test func sameLanguageIsNeverTranslated() {
        #expect(!DirectReadPolicy.shouldTranslateFirst(detected: .japanese, pipeline: .ja, preferTranslate: false))
        #expect(!DirectReadPolicy.shouldTranslateFirst(detected: .japanese, pipeline: .ja, preferTranslate: true))
    }

    /// 日本語パイプラインは従来どおり非日本語記事を翻訳してから抽出する (設定に関係なく)。
    @Test func japanesePipelineKeepsTranslateFirst() {
        #expect(DirectReadPolicy.shouldTranslateFirst(detected: .english, pipeline: .ja, preferTranslate: false))
        #expect(DirectReadPolicy.shouldTranslateFirst(detected: .other("zh-Hans"), pipeline: .ja, preferTranslate: false))
    }

    @Test func preferTranslateRestoresLegacyBehavior() {
        #expect(DirectReadPolicy.shouldTranslateFirst(detected: .japanese, pipeline: .en, preferTranslate: true))
    }

    @Test func traditionalChineseIsReadDirectly() {
        #expect(!DirectReadPolicy.shouldTranslateFirst(detected: .other("zh-Hant"), pipeline: .en, preferTranslate: false))
        #expect(DirectReadPolicy.canReadDirectly(.other("zh-Hant")))
    }

    @Test func unknownIsNeverTranslated() {
        #expect(!DirectReadPolicy.shouldTranslateFirst(detected: .unknown, pipeline: .en, preferTranslate: false))
        #expect(!DirectReadPolicy.shouldTranslateFirst(detected: .unknown, pipeline: .en, preferTranslate: true))
    }
}

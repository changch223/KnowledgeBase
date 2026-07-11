//
//  PipelineLanguageTests.swift
//  KnowledgeTreeTests
//
//  多言語対応 Phase A — PipelineLanguage 純関数群のテスト。
//  `resolve(defaults:preferredLanguages:)` / `fromPreferredLanguages(_:)` は引数を全て
//  受け取る純関数なので、実 UserDefaults / 実 Locale に依存せず決定論的にテストできる。
//

import Testing
import Foundation
@testable import KnowledgeBase

struct PipelineLanguageTests {

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "pipelineLanguage.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - resolve: 保存値優先

    @Test func testResolvePrefersStoredValueOverDeviceLanguage() {
        let defaults = makeIsolatedDefaults()
        defaults.set("zh-Hant", forKey: PipelineLanguage.userDefaultsKey)

        let resolved = PipelineLanguage.resolve(defaults: defaults, preferredLanguages: ["ja-JP"])

        #expect(resolved == .zhHant)
    }

    // MARK: - resolve: 未設定 → 端末言語 fallback

    @Test func testResolveFallsBackToDeviceLanguageWhenUnset() {
        let defaults = makeIsolatedDefaults()

        #expect(PipelineLanguage.resolve(defaults: defaults, preferredLanguages: ["ja-JP"]) == .ja)
        #expect(PipelineLanguage.resolve(defaults: defaults, preferredLanguages: ["zh-Hans-CN"]) == .zhHans)
        // i18n Phase B: en は .en に解決する (Phase A では ja にフォールバックしていたが英語対応を追加)。
        #expect(PipelineLanguage.resolve(defaults: defaults, preferredLanguages: ["en-US"]) == .en)
        // ja / zh / en 以外は ja にフォールバック。
        #expect(PipelineLanguage.resolve(defaults: defaults, preferredLanguages: ["fr-FR"]) == .ja)
        // 優先言語が空リストのときも安全に ja へ。
        #expect(PipelineLanguage.resolve(defaults: defaults, preferredLanguages: []) == .ja)
    }

    // MARK: - fromPreferredLanguages: zh-TW 等の繁体字判定

    @Test func testFromPreferredLanguagesMapsTraditionalChineseVariants() {
        #expect(PipelineLanguage.fromPreferredLanguages(["zh-TW"]) == .zhHant)
        #expect(PipelineLanguage.fromPreferredLanguages(["zh-Hant-TW"]) == .zhHant)
        #expect(PipelineLanguage.fromPreferredLanguages(["zh-HK"]) == .zhHant)
        #expect(PipelineLanguage.fromPreferredLanguages(["zh-MO"]) == .zhHant)
    }

    @Test func testFromPreferredLanguagesMapsSimplifiedChineseVariants() {
        #expect(PipelineLanguage.fromPreferredLanguages(["zh-Hans-CN"]) == .zhHans)
        #expect(PipelineLanguage.fromPreferredLanguages(["zh-CN"]) == .zhHans)
        // 地域指定のない bare "zh" は簡体字扱い (繁体字マーカーなし)。
        #expect(PipelineLanguage.fromPreferredLanguages(["zh"]) == .zhHans)
    }

    // MARK: - fromPreferredLanguages: en 系

    @Test func testFromPreferredLanguagesMapsEnglishVariants() {
        #expect(PipelineLanguage.fromPreferredLanguages(["en-US"]) == .en)
        #expect(PipelineLanguage.fromPreferredLanguages(["en-GB"]) == .en)
        #expect(PipelineLanguage.fromPreferredLanguages(["en"]) == .en)
        // zh / en 以外 (例: フランス語) は ja にフォールバック。
        #expect(PipelineLanguage.fromPreferredLanguages(["fr-FR"]) == .ja)
    }

    // MARK: - endonym

    @Test func testEndonym() {
        #expect(PipelineLanguage.ja.endonym == "日本語")
        #expect(PipelineLanguage.zhHans.endonym == "简体中文")
        #expect(PipelineLanguage.zhHant.endonym == "繁體中文")
        #expect(PipelineLanguage.en.endonym == "English")
    }

    // MARK: - outputInstruction

    @Test func testOutputInstructionIsInTargetLanguage() {
        #expect(PipelineLanguage.ja.outputInstruction.contains("日本語"))
        #expect(PipelineLanguage.zhHans.outputInstruction.contains("简体中文"))
        #expect(PipelineLanguage.zhHant.outputInstruction.contains("繁體中文"))
        #expect(PipelineLanguage.en.outputInstruction.contains("English"))
    }

    // MARK: - translationTargetBCP47

    @Test func testTranslationTargetBCP47MatchesRawValue() {
        #expect(PipelineLanguage.ja.translationTargetBCP47 == "ja")
        #expect(PipelineLanguage.zhHans.translationTargetBCP47 == "zh-Hans")
        #expect(PipelineLanguage.zhHant.translationTargetBCP47 == "zh-Hant")
        #expect(PipelineLanguage.en.translationTargetBCP47 == "en")
    }

    // MARK: - matches(detected:)

    @Test func testMatchesJapanese() {
        #expect(PipelineLanguage.ja.matches(detected: .japanese))
        #expect(!PipelineLanguage.ja.matches(detected: .english))
        #expect(!PipelineLanguage.ja.matches(detected: .other("zh-Hans")))
        #expect(!PipelineLanguage.ja.matches(detected: .unknown))
    }

    @Test func testMatchesChineseAcceptsEitherHansOrHantDetection() {
        // zh パイプラインは Hans/Hant どちらの検知結果でも一致する (簡体/繁体は Phase A では区別しない)。
        #expect(PipelineLanguage.zhHans.matches(detected: .other("zh-Hans")))
        #expect(PipelineLanguage.zhHans.matches(detected: .other("zh-Hant")))
        #expect(PipelineLanguage.zhHant.matches(detected: .other("zh-Hans")))
        #expect(PipelineLanguage.zhHant.matches(detected: .other("zh-Hant")))

        #expect(!PipelineLanguage.zhHans.matches(detected: .japanese))
        #expect(!PipelineLanguage.zhHans.matches(detected: .english))
        #expect(!PipelineLanguage.zhHant.matches(detected: .other("en")))
    }

    @Test func testMatchesEnglish() {
        #expect(PipelineLanguage.en.matches(detected: .english))
        #expect(!PipelineLanguage.en.matches(detected: .japanese))
        #expect(!PipelineLanguage.en.matches(detected: .other("zh-Hans")))
        #expect(!PipelineLanguage.en.matches(detected: .unknown))
    }
}

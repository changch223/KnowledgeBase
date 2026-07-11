//
//  LanguageMismatchDetectorTests.swift
//  KnowledgeTreeTests
//
//  多言語対応 — LanguageMismatchDetector の純関数 + InMemoryLanguageMismatchNotificationStore のテスト。
//

import Testing
import Foundation
@testable import KnowledgeBase

// `markResolved(...)` は main app target の default-isolation=MainActor により暗黙に
// @MainActor 化される (`LanguageMismatchNotificationStore` 準拠クラスも同様)。
// test target にはそのフラグが無いため、LintEngineTests と同じ規約でスイート全体を
// @MainActor にして呼び出しコンテキストを揃える。
@MainActor
struct LanguageMismatchDetectorTests {

    // MARK: - shouldShowBanner: 一致

    @Test func testNoBannerWhenDeviceAndPipelineMatch() {
        let result = LanguageMismatchDetector.shouldShowBanner(
            devicePreferred: ["ja-JP"],
            pipeline: .ja,
            lastNotifiedCombo: nil
        )
        #expect(result == false)
    }

    // MARK: - shouldShowBanner: ズレ → 表示

    @Test func testShowsBannerWhenDeviceAndPipelineDiffer() {
        let result = LanguageMismatchDetector.shouldShowBanner(
            devicePreferred: ["en-US"],
            pipeline: .zhHant,
            lastNotifiedCombo: nil
        )
        #expect(result == true)
    }

    // MARK: - shouldShowBanner: 同 combo 記録済み → 表示しない

    @Test func testNoBannerWhenSameComboAlreadyNotified() {
        let combo = LanguageMismatchDetector.comboKey(device: .en, pipeline: .zhHant)
        let result = LanguageMismatchDetector.shouldShowBanner(
            devicePreferred: ["en-US"],
            pipeline: .zhHant,
            lastNotifiedCombo: combo
        )
        #expect(result == false)
    }

    // MARK: - shouldShowBanner: combo 変化 → 再び表示

    @Test func testShowsBannerAgainWhenComboChanges() {
        // 前回案内したのは en|zhHant の組。今回は端末言語 (en) は変わらず生成言語が変わって
        // en|ja の新しいズレになった。
        let previousCombo = LanguageMismatchDetector.comboKey(device: .en, pipeline: .zhHant)
        let result = LanguageMismatchDetector.shouldShowBanner(
            devicePreferred: ["en-US"],
            pipeline: .ja,
            lastNotifiedCombo: previousCombo
        )
        #expect(result == true)
    }

    // MARK: - shouldShowBanner: 未対応言語端末で fallback が一致 → 表示しない

    @Test func testNoBannerWhenUnsupportedDeviceLanguageFallsBackToMatchingPipeline() {
        // fr (フランス語) は未対応言語なので fromPreferredLanguages は ja にフォールバックする。
        // 生成言語も ja なら「今初回起動したら選ばれる言語」と現在の生成言語が一致するのでズレなし。
        let result = LanguageMismatchDetector.shouldShowBanner(
            devicePreferred: ["fr-FR"],
            pipeline: .ja,
            lastNotifiedCombo: nil
        )
        #expect(result == false)
    }

    // MARK: - comboKey: 形式

    @Test func testComboKeyFormat() {
        #expect(LanguageMismatchDetector.comboKey(device: .en, pipeline: .zhHant) == "en|zh-Hant")
        #expect(LanguageMismatchDetector.comboKey(device: .ja, pipeline: .ja) == "ja|ja")
    }

    // MARK: - markResolved (qa 裁定 修正1): 意図的な変更後は false-positive を抑止する

    @Test func testMarkResolvedRecordsComboAndSuppressesFutureBanner() {
        // en 端末で意図的に en → ja へ変更したシナリオ。変更後の組み合わせ (en|ja) を記録すれば、
        // 次回起動の shouldShowBanner はこの本人には出ない (対象は端末言語を変えた別のズレのみ)。
        let store = InMemoryLanguageMismatchNotificationStore()

        LanguageMismatchDetector.markResolved(devicePreferred: ["en-US"], pipeline: .ja, store: store)

        #expect(store.lastNotifiedCombo == "en|ja")
        let shouldShow = LanguageMismatchDetector.shouldShowBanner(
            devicePreferred: ["en-US"],
            pipeline: .ja,
            lastNotifiedCombo: store.lastNotifiedCombo
        )
        #expect(shouldShow == false)
    }

    // MARK: - markResolved (qa 裁定 修正2): 書き込み時点の値を使う想定の再計算

    @Test func testMarkResolvedOverwritesStaleComboWithCurrentValue() {
        // バナー表示開始時 (旧 pipeline) に一度 markResolved された後、シート内で更に変更が起き
        // 新しい pipeline で再度 markResolved が呼ばれた場合、最終的に記録されるのは新しい組み合わせ
        // (LanguageMismatchBannerHost.markNotified が PipelineLanguage.current を読み直す動機の検証)。
        let store = InMemoryLanguageMismatchNotificationStore()
        LanguageMismatchDetector.markResolved(devicePreferred: ["en-US"], pipeline: .zhHant, store: store)
        #expect(store.lastNotifiedCombo == "en|zh-Hant")

        LanguageMismatchDetector.markResolved(devicePreferred: ["en-US"], pipeline: .ja, store: store)

        #expect(store.lastNotifiedCombo == "en|ja")
    }

    // MARK: - InMemoryLanguageMismatchNotificationStore

    @Test func testInMemoryStoreDefaultsToNilAndCanBeUpdated() {
        let store = InMemoryLanguageMismatchNotificationStore()
        #expect(store.lastNotifiedCombo == nil)

        store.lastNotifiedCombo = "en|zh-Hant"
        #expect(store.lastNotifiedCombo == "en|zh-Hant")
    }

    // MARK: - UserDefaultsLanguageMismatchNotificationStore

    @Test func testUserDefaultsStorePersistsAndClearsCombo() {
        let suiteName = "langMismatch.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = UserDefaultsLanguageMismatchNotificationStore(defaults: defaults)

        #expect(store.lastNotifiedCombo == nil)

        store.lastNotifiedCombo = "en|zh-Hant"
        #expect(store.lastNotifiedCombo == "en|zh-Hant")

        store.lastNotifiedCombo = nil
        #expect(store.lastNotifiedCombo == nil)
    }
}

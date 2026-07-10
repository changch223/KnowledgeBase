//
//  LanguageSettingsStoreTests.swift
//  KnowledgeTreeTests
//
//  多言語対応 Phase A — LanguageSettingsStore の 2 実装 (UserDefaults / InMemory) のテスト。
//  BackfillFlagStoreTests 相当の規約 (production 実装は isolated UserDefaults suite で副作用隔離)。
//

import Testing
import Foundation
@testable import KnowledgeBase

struct LanguageSettingsStoreTests {

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "languageSettingsStore.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - UserDefaultsLanguageSettingsStore

    @Test func testLockIfFirstLaunchWritesDeviceLanguageWhenUnset() {
        let defaults = makeIsolatedDefaults()
        let store = UserDefaultsLanguageSettingsStore(
            defaults: defaults,
            preferredLanguagesProvider: { ["zh-Hans-CN"] }
        )

        store.lockIfFirstLaunch()

        #expect(defaults.string(forKey: PipelineLanguage.userDefaultsKey) == "zh-Hans")
        #expect(store.currentLanguage() == .zhHans)
    }

    @Test func testLockIfFirstLaunchIsANoOpWhenAlreadySet() {
        let defaults = makeIsolatedDefaults()
        defaults.set("ja", forKey: PipelineLanguage.userDefaultsKey)
        let store = UserDefaultsLanguageSettingsStore(
            defaults: defaults,
            // 端末言語が後から変わっても、既存ユーザーの保存値は上書きされない (1 回性)。
            preferredLanguagesProvider: { ["zh-Hant-TW"] }
        )

        store.lockIfFirstLaunch()

        #expect(defaults.string(forKey: PipelineLanguage.userDefaultsKey) == "ja")
        #expect(store.currentLanguage() == .ja)
    }

    @Test func testChangeOverwritesStoredValue() {
        let defaults = makeIsolatedDefaults()
        let store = UserDefaultsLanguageSettingsStore(
            defaults: defaults,
            preferredLanguagesProvider: { ["ja-JP"] }
        )
        store.lockIfFirstLaunch()
        #expect(store.currentLanguage() == .ja)

        store.change(to: .zhHant)

        #expect(defaults.string(forKey: PipelineLanguage.userDefaultsKey) == "zh-Hant")
        #expect(store.currentLanguage() == .zhHant)
    }

    @Test func testCurrentLanguageWithoutLockingFallsBackToDeviceLanguage() {
        let defaults = makeIsolatedDefaults()
        let store = UserDefaultsLanguageSettingsStore(
            defaults: defaults,
            preferredLanguagesProvider: { ["zh-TW"] }
        )

        // lockIfFirstLaunch を呼ばなくても currentLanguage() 自体は端末言語 fallback を返す
        // (書き込みはしない = 保存値は依然として nil)。
        #expect(store.currentLanguage() == .zhHant)
        #expect(defaults.string(forKey: PipelineLanguage.userDefaultsKey) == nil)
    }

    // MARK: - InMemoryLanguageSettingsStore

    @Test func testInMemoryDefaultsToJapanese() {
        let store = InMemoryLanguageSettingsStore()
        #expect(store.currentLanguage() == .ja)
    }

    @Test func testInMemoryLockIfFirstLaunchOnlyAppliesOnce() {
        let store = InMemoryLanguageSettingsStore(stored: nil, deviceLanguage: .zhHans)
        store.lockIfFirstLaunch()
        #expect(store.currentLanguage() == .zhHans)

        // 既に stored があるので、2 回目の lock は無視される (deviceLanguage が変わっても不変)。
        store.change(to: .ja)
        store.lockIfFirstLaunch()
        #expect(store.currentLanguage() == .ja)
    }

    @Test func testInMemoryChangeReflectsImmediately() {
        let store = InMemoryLanguageSettingsStore()
        store.change(to: .zhHant)
        #expect(store.currentLanguage() == .zhHant)
    }
}

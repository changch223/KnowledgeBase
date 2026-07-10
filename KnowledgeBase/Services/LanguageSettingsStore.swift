//
//  LanguageSettingsStore.swift
//  KnowledgeTree
//
//  多言語対応 Phase A — pipeline 言語 (PipelineLanguage) の永続化を抽象化する protocol。
//  production: App Group UserDefaults、test: in-memory で副作用隔離。
//  BackfillFlagStore (spec 013) と同じ規約 (protocol + UserDefaults 実装 + InMemory 実装)。
//
//  - `lockIfFirstLaunch()`: 保存値が無ければ端末の優先言語から解決して保存する。
//    起動 1 回だけ呼ぶ想定 (KnowledgeTreeApp.bootstrap 冒頭)。既存ユーザーは端末言語 = ja のまま
//    ロックされる (今まで通り日本語で生成され続ける、移行不要)。
//  - `change(to:)`: 設定画面からの明示的な変更。
//

import Foundation

protocol LanguageSettingsStore {
    /// 現在の pipeline 言語。保存値があればそれ、無ければ端末の優先言語から解決した値 (書き込みはしない)。
    func currentLanguage() -> PipelineLanguage
    /// 保存値が無ければ端末の優先言語から解決して保存する (初回起動時に 1 度だけ呼ぶ想定)。
    func lockIfFirstLaunch()
    /// 設定画面からの明示的な変更。書き込み + `PipelineLanguage` のプロセスキャッシュ無効化。
    func change(to language: PipelineLanguage)
}

/// production 用。App Group UserDefaults (`PipelineLanguage.current` と同じ suite + key) に永続化。
final class UserDefaultsLanguageSettingsStore: LanguageSettingsStore {
    private let defaults: UserDefaults
    private let preferredLanguagesProvider: () -> [String]

    init(
        defaults: UserDefaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard,
        preferredLanguagesProvider: @escaping () -> [String] = { Locale.preferredLanguages }
    ) {
        self.defaults = defaults
        self.preferredLanguagesProvider = preferredLanguagesProvider
    }

    func currentLanguage() -> PipelineLanguage {
        PipelineLanguage.resolve(defaults: defaults, preferredLanguages: preferredLanguagesProvider())
    }

    func lockIfFirstLaunch() {
        guard defaults.string(forKey: PipelineLanguage.userDefaultsKey) == nil else { return }
        let resolved = PipelineLanguage.fromPreferredLanguages(preferredLanguagesProvider())
        defaults.set(resolved.rawValue, forKey: PipelineLanguage.userDefaultsKey)
        PipelineLanguage._resetForTesting()
    }

    func change(to language: PipelineLanguage) {
        defaults.set(language.rawValue, forKey: PipelineLanguage.userDefaultsKey)
        PipelineLanguage._resetForTesting()
    }
}

/// test 用。プロセス state (UserDefaults / PipelineLanguage キャッシュ) を汚染しない in-memory 実装。
final class InMemoryLanguageSettingsStore: LanguageSettingsStore {
    private var stored: PipelineLanguage?
    private let deviceLanguage: PipelineLanguage

    /// - Parameters:
    ///   - stored: 保存済み状態を模す初期値 (nil = 未設定)。
    ///   - deviceLanguage: 「端末の優先言語から解決した値」を模す固定値 (実 Locale には依存しない)。
    init(stored: PipelineLanguage? = nil, deviceLanguage: PipelineLanguage = .ja) {
        self.stored = stored
        self.deviceLanguage = deviceLanguage
    }

    func currentLanguage() -> PipelineLanguage {
        stored ?? deviceLanguage
    }

    func lockIfFirstLaunch() {
        guard stored == nil else { return }
        stored = deviceLanguage
    }

    func change(to language: PipelineLanguage) {
        stored = language
    }
}

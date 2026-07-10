//
//  PipelineLanguage.swift
//  KnowledgeTree
//
//  多言語対応 Phase A — 「AI が生成する知識の言語 (パイプライン言語)」を表す。
//  UI 表示言語 (端末の Localizable.xcstrings 解決) とは独立した概念で、
//  ユーザーごとに 1 つに固定される (docs/HANDOFF.md §2-2 の設計判断)。
//
//  - 保存値は App Group UserDefaults (`userDefaultsKey`) に "ja" / "zh-Hans" / "zh-Hant" で永続化。
//  - 未設定 (初回起動、既存ユーザー含む) は端末の優先言語から解決する (`fromPreferredLanguages`)。
//  - `current` はプロセス内キャッシュ付き (毎回 UserDefaults / Locale を読まない)。
//  - 実際の read/write は `LanguageSettingsStore` (protocol + UserDefaults/InMemory 実装) が担う。
//    本 enum は「値の意味」(表示名・prompt 指示文・embedding 言語・翻訳スキップ判定) を持つ。
//

import Foundation
import NaturalLanguage

enum PipelineLanguage: String, Sendable, CaseIterable {
    case ja
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"

    /// App Group UserDefaults に保存する際のキー。`LanguageSettingsStore` も同じキーを使う (DRY)。
    static let userDefaultsKey = "settings.pipelineLanguage"

    /// プロセス内キャッシュ (毎回 UserDefaults / Locale を読まないため)。
    private static var cachedValue: PipelineLanguage?

    /// 現在の pipeline 言語。保存値優先、未設定なら端末の優先言語から解決する。
    static var current: PipelineLanguage {
        if let cachedValue { return cachedValue }
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        let resolved = resolve(defaults: defaults, preferredLanguages: Locale.preferredLanguages)
        cachedValue = resolved
        return resolved
    }

    /// `current` の実体。UserDefaults / preferredLanguages を引数で受け取る純関数 (テスト容易化)。
    static func resolve(defaults: UserDefaults, preferredLanguages: [String]) -> PipelineLanguage {
        if let raw = defaults.string(forKey: userDefaultsKey), let stored = PipelineLanguage(rawValue: raw) {
            return stored
        }
        return fromPreferredLanguages(preferredLanguages)
    }

    /// 端末の優先言語リスト (`Locale.preferredLanguages` 形式) から解決する純関数。
    /// 先頭言語コードのみ見る。zh 系は繁体字判定 (Hant / TW / HK / MO) 以外を簡体字扱いにする。
    /// ja / zh 以外は全て ja にフォールバックする (Phase A は日中 2 言語のみ対応)。
    static func fromPreferredLanguages(_ preferredLanguages: [String]) -> PipelineLanguage {
        guard let first = preferredLanguages.first?.lowercased() else { return .ja }
        guard first.hasPrefix("zh") else { return .ja }
        if first.contains("hant") || first.contains("-tw") || first.contains("-hk") || first.contains("-mo") {
            return .zhHant
        }
        return .zhHans
    }

    /// テスト / 設定変更後にプロセスキャッシュを無効化する。
    /// `LanguageSettingsStore.change(to:)` からも呼ばれる (変更を即座に `current` へ反映するため)。
    static func _resetForTesting() {
        cachedValue = nil
    }

    // MARK: - 表示・prompt 用の値

    /// その言語自身での呼び名 (自言語表記)。
    var endonym: String {
        switch self {
        case .ja: return "日本語"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        }
    }

    /// prompt 末尾に付ける「すべて◯◯で出力してください」相当の指示文。各言語で書く。
    var outputInstruction: String {
        switch self {
        case .ja: return "すべて日本語で出力してください。"
        case .zhHans: return "请全部使用简体中文输出。"
        case .zhHant: return "請全部使用繁體中文輸出。"
        }
    }

    /// Translation framework (`TranslationSession`) に渡す BCP-47 ターゲット言語コード。
    var translationTargetBCP47: String {
        rawValue
    }

    /// `NLEmbedding.sentenceEmbedding(for:)` に渡す言語。
    /// zh-Hant も簡体字モデルを使う (Phase B で繁体字→簡体字正規化を足す想定)。
    var nlEmbeddingLanguage: NLLanguage {
        switch self {
        case .ja: return .japanese
        case .zhHans, .zhHant: return .simplifiedChinese
        }
    }

    /// 検知された入力言語 (`LanguageDetector.detect` の戻り値) が、この pipeline 言語と
    /// 「翻訳不要」とみなせるほど一致するか。ja パイプラインは `.japanese` のみ一致、
    /// zh パイプライン (Hans/Hant どちらでも) は検知が zh-Hans/zh-Hant いずれでも一致する。
    func matches(detected: DetectedLanguage) -> Bool {
        switch (self, detected) {
        case (.ja, .japanese):
            return true
        case (.zhHans, .other(let raw)), (.zhHant, .other(let raw)):
            return raw.lowercased().hasPrefix("zh")
        default:
            return false
        }
    }
}

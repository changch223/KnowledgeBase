//
//  PipelineLanguage.swift
//  KnowledgeTree
//
//  多言語対応 Phase A — 「AI が生成する知識の言語 (パイプライン言語)」を表す。
//  UI 表示言語 (端末の Localizable.xcstrings 解決) とは独立した概念で、
//  ユーザーごとに 1 つに固定される (docs/HANDOFF.md §2-2 の設計判断)。
//
//  - 保存値は App Group UserDefaults (`userDefaultsKey`) に "ja" / "zh-Hans" / "zh-Hant" / "en" で永続化。
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
    case en

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
    /// ja / zh / en 以外は全て ja にフォールバックする (Phase A/B は日中英 3 言語のみ対応)。
    static func fromPreferredLanguages(_ preferredLanguages: [String]) -> PipelineLanguage {
        guard let first = preferredLanguages.first?.lowercased() else { return .ja }
        if first.hasPrefix("zh") {
            if first.contains("hant") || first.contains("-tw") || first.contains("-hk") || first.contains("-mo") {
                return .zhHant
            }
            return .zhHans
        }
        if first.hasPrefix("en") { return .en }
        return .ja
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
        case .en: return "English"
        }
    }

    /// prompt 末尾に付ける「すべて◯◯で出力してください」相当の指示文。各言語で書く。
    var outputInstruction: String {
        switch self {
        case .ja: return "すべて日本語で出力してください。"
        case .zhHans: return "请全部使用简体中文输出。"
        case .zhHant: return "請全部使用繁體中文輸出。"
        case .en: return "Write all output in English."
        }
    }

    /// i18n Phase B: 一般知識で答える際に使う hedge phrase の例 (言語別)。
    /// `ChatService.buildFallbackPrompt` / `buildAgentPrompt` の
    /// 「情報不足ならこれらの言い回しを使うこと」指示に埋め込む。
    /// (post-process の `HedgePhraseFilter` は日本語専用、こちらは prompt 指示側)。
    var hedgePhraseExamples: [String] {
        switch self {
        case .ja: return ["私の理解では", "一般的には", "あくまで概要として"]
        case .zhHans: return ["据我理解", "一般来说", "仅供参考"]
        case .zhHant: return ["據我理解", "一般來說", "僅供參考"]
        case .en: return ["As far as I understand", "Generally speaking", "For reference only"]
        }
    }

    /// i18n Phase B: 出力してはいけない禁止句の例 (言語別)。
    /// `ChatService.buildFallbackPrompt` / `buildAgentPrompt` の
    /// 「これらの言い回しは絶対に出力しないこと」指示に埋め込む。
    var bannedPhraseExamples: [String] {
        switch self {
        case .ja: return ["分かりません", "答えられません", "情報がありません", "知りません"]
        case .zhHans: return ["不知道", "无法回答", "没有相关信息", "不清楚"]
        case .zhHant: return ["不知道", "無法回答", "沒有相關資訊", "不清楚"]
        case .en: return ["I don't know", "I cannot answer", "No information available", "I'm not sure"]
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
        case .en: return .english
        }
    }

    /// 検知された入力言語 (`LanguageDetector.detect` の戻り値) が、この pipeline 言語と
    /// 「翻訳不要」とみなせるほど一致するか。ja パイプラインは `.japanese` のみ一致、
    /// zh パイプライン (Hans/Hant どちらでも) は検知が zh-Hans/zh-Hant いずれでも一致する。
    /// en パイプラインは `.english` のみ一致する。
    func matches(detected: DetectedLanguage) -> Bool {
        switch (self, detected) {
        case (.ja, .japanese):
            return true
        case (.zhHans, .other(let raw)), (.zhHant, .other(let raw)):
            return raw.lowercased().hasPrefix("zh")
        case (.en, .english):
            return true
        default:
            return false
        }
    }
}

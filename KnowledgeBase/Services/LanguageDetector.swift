//
//  LanguageDetector.swift
//  KnowledgeTree
//
//  spec 042 — 入力テキストの言語判定 (英語 / 日本語 / その他)。
//
//  KnowledgeExtractor が抽出前に呼び出し、英語なら翻訳前処理を挟む経路を決める。
//  純関数 (Sendable / 状態なし) なので test しやすい。
//

import Foundation
import NaturalLanguage

enum DetectedLanguage: Equatable {
    case japanese
    case english
    case other(String)  // BCP-47 raw value
    case unknown        // 判定不能 (短すぎ / 文字種混在 / nil)
}

enum LanguageDetector {

    /// 言語判定に使う prefix 長 (本文全体だと長い + 末尾ノイズに引きずられる)
    static let prefixLength: Int = 1500

    /// dominantLanguage 判定の最低テキスト長。これ未満は .unknown を返す。
    static let minTextLength: Int = 20

    /// テキスト先頭を見て主言語を判定する。
    /// - Note: 空白を除いた長さで minTextLength 判定するため、改行ノイズで弾かれない。
    static func detect(_ text: String) -> DetectedLanguage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minTextLength else { return .unknown }

        let sample = String(trimmed.prefix(prefixLength))
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        guard let language = recognizer.dominantLanguage else {
            return .unknown
        }

        switch language {
        case .japanese:
            return .japanese
        case .english:
            return .english
        default:
            return .other(language.rawValue)
        }
    }

    /// spec 1xx: 翻訳エンジンが対応する言語コード集合 (小文字比較)。`.other(raw)` がこの集合の外
    /// なら、コード片・記号混在チャンク等の低信頼な誤検知の可能性が高いため、翻訳を試みるべきでない。
    /// ja/en は `DetectedLanguage` の専用 case で扱われるため通常ここには来ないが、将来 `.other`
    /// 経由で来ても弾かれないよう含めておく。ko は既存の翻訳対応 (AudioTranscriptionService の
    /// 候補 locale) と整合させている。zh は `PipelineLanguage.matches(detected:)` と同じ
    /// `hasPrefix("zh")` 判定を別途行う (rawValue が "zh" / "zh-Hans" / "zh-Hant" のどれで
    /// 来ても弾かないため、専用チェックにしている)。
    static let translationSupportedLanguageCodes: Set<String> = ["ja", "en", "ko"]

    /// `.other(raw)` の raw (NLLanguage.rawValue 相当、BCP-47) が翻訳対応言語かどうかを判定する。
    static func isTranslationSupported(_ raw: String) -> Bool {
        let lower = raw.lowercased()
        if lower.hasPrefix("zh") { return true }
        return translationSupportedLanguageCodes.contains(lower)
    }
}

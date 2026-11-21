//
//  PromptLocalizer.swift
//  KnowledgeTree
//
//  spec 106 — 生成プロンプトの「指示文の言語」を決める純関数群。
//  日本語パイプラインは従来の日本語指示文 (一字も変えない)、それ以外は英語の指示文を使い、
//  冒頭と末尾の両方で出力言語を指定する。小さいモデルは指示文の言語に引っ張られるため、
//  7 言語 × 全 prompt を書く代わりに「日本語版 / 英語指示版」の 2 系統に畳む。
//

import Foundation

enum PromptLocalizer {

    /// true のとき従来の日本語プロンプトを使う。
    static func usesJapaneseInstructions(_ language: PipelineLanguage) -> Bool {
        language == .ja
    }

    /// 英語指示版プロンプトの冒頭に置く出力言語指定。
    static func outputLanguageHeader(_ language: PipelineLanguage) -> String {
        "Output language: \(language.englishName). Write every field in \(language.englishName), even though the schema descriptions are in Japanese. Translate concept names and key points into \(language.englishName). Keep product, company and person names in their original spelling."
    }

    /// 英語指示版プロンプトの末尾に置く、目標言語での出力指示 (既存の outputInstruction)。
    static func outputLanguageFooter(_ language: PipelineLanguage) -> String {
        language.outputInstruction
    }
}

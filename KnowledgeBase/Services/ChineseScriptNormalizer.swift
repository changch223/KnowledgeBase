//
//  ChineseScriptNormalizer.swift
//  KnowledgeTree
//
//  i18n Phase B — 繁体字 → 簡体字への正規化。
//
//  `NLEmbedding.sentenceEmbedding(for:)` は簡体字中国語 (`.simplifiedChinese`) モデルしか提供しない
//  (Phase A の `PipelineLanguage.nlEmbeddingLanguage` 参照)。zh-Hant パイプラインの記事/質問文を
//  そのまま embed すると語彙が実質簡体字モデル未知語になり類似度計算の質が落ちるため、
//  embed 直前に繁体字を簡体字へ変換して一貫させる (corpus 側・query 側の両方が同じ変換を経由する)。
//  純関数 (Sendable / 状態なし) なので単体テストしやすい。
//

import Foundation

enum ChineseScriptNormalizer {

    /// 繁体字を含むテキストを簡体字へ変換する。変換に失敗した場合は原文をそのまま返す (silent fallback)。
    /// 簡体字 / 日本語 / 英語など変換不要なテキストは `applyingTransform` がほぼ無変化で返す。
    static func toSimplified(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        guard let converted = text.applyingTransform(StringTransform("Hant-Hans"), reverse: false) else {
            return text
        }
        return converted
    }
}

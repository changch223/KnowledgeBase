//
//  ConceptNameNormalizer.swift
//  KnowledgeTree
//
//  spec 078 — 概念ページの重複統合のための canonical 名キー生成 (純関数、AI 不要)。
//  同じものが表記ゆれ (全角/半角・ひらがな/カタカナ・大文字小文字・空白) で別ページに
//  分裂するのを入口 (upsert マッチ) で防ぐ。
//
//  正規化レシピ:
//   1. trim
//   2. NFKC (precomposedStringWithCompatibilityMapping): 全角ＡＰＰＬＥ→APPLE、半角ｶﾅ→全角カナ、① → 1 等
//   3. ひらがな → カタカナ (カナ表記ゆれ統一: あっぷる ↔ アップル)
//   4. lowercased (ASCII のみ実効、かな/漢字は不変)
//   5. 連続空白を単一スペースに圧縮
//  例: "ＡＰＰＬＥ" / "apple" / "Apple " → "apple" ・ "アップル" / "あっぷる" / "ｱｯﾌﾟﾙ" → "アップル"
//

import Foundation

enum ConceptNameNormalizer {
    static func canonical(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return "" }
        // NFKC: 全角 ASCII → 半角、半角カナ → 全角カナ、互換文字を分解 (全/半幅の差を吸収)
        s = s.precomposedStringWithCompatibilityMapping
        // かな統一: ひらがな → カタカナ
        s = s.applyingTransform(.hiraganaToKatakana, reverse: false) ?? s
        // ASCII 大文字小文字統一 (かな/漢字は不変)
        s = s.lowercased()
        // 連続空白 (NFKC で全角空白も半角化済) を単一スペースに圧縮
        return s.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// ConceptPage の name + nameAliases を canonical 化した配列。upsert マッチ用。
    /// (ConceptPage は extension とも共有するため、この helper は app target 側に置く。)
    static func canonicalNames(of page: ConceptPage) -> [String] {
        ([page.name] + page.nameAliases).map { canonical($0) }
    }
}

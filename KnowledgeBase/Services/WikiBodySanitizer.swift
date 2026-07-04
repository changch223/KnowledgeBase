//
//  WikiBodySanitizer.swift
//  KnowledgeTree
//
//  spec 079 — Wiki 本文 (bodyMarkdown) の表示前/保存前クリーンアップ。
//
//  spec 064 の相互リンクで、AI が prompt の「関連ページ候補」指示ブロックを本文へ丸写しし、
//  生の `concept-id://UUID` (タップ不可) や「## 関連ページ候補」見出しが本文に漏れる事故を除去。
//  正しいインラインリンク `[名前](concept-id://UUID)` は保持する。
//  生成時 (ConceptSynthesisService) と表示時 (WikiBodyView) の両方で適用 → 既存の壊れた本文も即修正。
//

import Foundation

enum WikiBodySanitizer {
    /// 漏れた候補スキャフォールド (見出し「関連ページ候補」/ 生 concept-id 行) を除去。
    /// 行内に正しい `[名前](concept-id://UUID)` を含む行は保持。
    static func sanitize(_ markdown: String) -> String {
        guard markdown.localizedCaseInsensitiveContains("concept-id")
            || markdown.contains("関連ページ候補") else { return markdown }

        let kept = markdown.components(separatedBy: "\n").filter { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            // 「関連ページ候補」見出しを除去
            if t.hasPrefix("#"), t.contains("関連ページ候補") { return false }
            // 生の concept-id 行 (正しい [名前](concept-id://UUID) リンクでない) を除去。
            // 正しいリンクは "](concept-id" を含む。malformed な "concept-id//" もここで落ちる。
            if t.localizedCaseInsensitiveContains("concept-id"), !t.contains("](concept-id") {
                return false
            }
            return true
        }

        return collapseBlankLines(kept)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// LLM Best Practices P1-3: sanitize 後の本文が Wiki 本文として妥当かを判定。
    /// plain string 生成 (spec 063) は @Generable の形式制約が無いため、稀に
    /// 「短すぎる」「見出しが無い」「候補スキャフォールドの漏れが残る」出力が起きる。
    /// 不合格なら caller は summary から fallback 本文を合成する (品質下限を担保)。
    ///
    /// 合格条件 (すべて満たす):
    ///   - 本文が最低 minChars 字ある (空/空白/単語だけの断片でない。正当な短い本文は通す)
    ///   - 生の concept-id:// / 「関連ページ候補」スキャフォールドが残っていない
    static func isValid(_ markdown: String, minChars: Int = 20) -> Bool {
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minChars else { return false }
        // sanitize を通っていれば消えているはずだが、二重防御で禁止パターンを再チェック。
        if trimmed.contains("関連ページ候補") { return false }
        // 正しいインラインリンク "](concept-id" 以外の生 concept-id が残っていれば不合格。
        if trimmed.localizedCaseInsensitiveContains("concept-id") {
            let hasRawConceptID = trimmed
                .components(separatedBy: "\n")
                .contains { line in
                    line.localizedCaseInsensitiveContains("concept-id") && !line.contains("](concept-id")
                }
            if hasRawConceptID { return false }
        }
        return true
    }

    /// 連続する空行を 1 行に圧縮 (候補セクション除去後の穴埋め)。
    private static func collapseBlankLines(_ lines: [String]) -> [String] {
        var out: [String] = []
        for line in lines {
            let isBlank = line.trimmingCharacters(in: .whitespaces).isEmpty
            if isBlank, out.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { continue }
            out.append(line)
        }
        return out
    }
}

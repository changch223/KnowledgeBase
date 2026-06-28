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

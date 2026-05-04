//
//  TagNormalizer.swift
//  KnowledgeTree
//
//  spec 008 — タグ名の正規化を行う純粋関数。
//  Tag インスタンス生成 / 保存前に必ず通す。
//
//  正規化:
//   1. 前後の whitespacesAndNewlines を trim
//   2. lowercased() (Locale.current 不変)
//   3. 50 文字超は prefix 50
//   4. 結果が空なら nil 返却
//
//  絵文字 / CJK / 全角は touch しない (現代の日本語ユーザーが使うため restrictive にしない)
//

import Foundation

enum TagNormalizer {
    static let maxLength = 50

    /// raw 文字列を正規化済 tag 名に変換。空文字 / 空白のみは nil。
    static func normalize(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        s = s.lowercased()
        if s.count > maxLength {
            s = String(s.prefix(maxLength))
        }
        // trim 後再度空チェック (理論上は到達しないが防御的)
        return s.isEmpty ? nil : s
    }
}

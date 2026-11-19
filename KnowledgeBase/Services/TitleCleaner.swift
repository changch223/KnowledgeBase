//
//  TitleCleaner.swift
//  KnowledgeTree
//
//  spec 103 — 表示用にタイトル末尾のサイト名を除去する純関数。
//  保存データ (Article.title) は書き換えない。保守的: サイト名と判定できたときだけ 1 回除去。
//

import Foundation

nonisolated enum TitleCleaner {
    private static let separators = [" | ", " - ", " – ", " — ", "｜", " :: "]

    static func clean(_ title: String, host: String?) -> String {
        guard let host, !host.isEmpty else { return title }
        let core = coreName(of: host)
        guard !core.isEmpty else { return title }

        // 最も後ろにある区切りで末尾セグメントを取り出す
        var best: (range: Range<String.Index>, sep: String)?
        for sep in separators {
            if let r = title.range(of: sep, options: .backwards),
               best == nil || r.lowerBound > best!.range.lowerBound {
                best = (r, sep)
            }
        }
        guard let found = best else { return title }

        let tail = String(title[found.range.upperBound...])
        let normalizedTail = normalize(tail)
        guard !normalizedTail.isEmpty,
              normalizedTail.contains(core) || core.contains(normalizedTail) else { return title }

        let head = String(title[..<found.range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard head.count >= 5 else { return title }
        return head
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased().filter { !$0.isWhitespace }
    }

    /// `www.` と TLD を除いた最初のラベル (nikkei.com → nikkei)。
    private static func coreName(of host: String) -> String {
        var h = host.lowercased()
        if h.hasPrefix("www.") { h = String(h.dropFirst(4)) }
        return h.split(separator: ".").first.map(String.init) ?? ""
    }
}

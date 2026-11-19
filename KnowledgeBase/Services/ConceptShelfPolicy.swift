//
//  ConceptShelfPolicy.swift
//  KnowledgeTree
//
//  spec 105 — 記事が多い広いトピックを「書架」(子トピックをまとめる見出し) として扱う判定と、
//  「前回から増えた要点」の差分判定。純関数 (テスト可)。
//

import Foundation

nonisolated enum ConceptShelfPolicy {
    /// 書架になる関連記事数の閾値 (この値「超」)。実機で 10 / 15 / 20 を比べて確定する。
    /// 値を変えるときはこの定数だけを変える。
    static let articleThreshold = 15

    /// 書架 = broad かつ 関連記事数 > articleThreshold かつ 子トピック 1 件以上。
    static func isShelf(level: ConceptLevel, articleCount: Int, childCount: Int) -> Bool {
        level == .broad && articleCount > articleThreshold && childCount >= 1
    }

    /// 前回見たときに無かった要点。seen が空 (初めて見るページ) は全部「新しい」にしない。
    static func newInsights(current: [String], seen: [String]) -> Set<String> {
        guard !seen.isEmpty else { return [] }
        let seenGrams = seen
            .map { bigrams(of: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        var result = Set<String>()
        for item in current {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let grams = bigrams(of: trimmed)
            let known = seenGrams.contains { jaccard(grams, $0) >= similarityThreshold }
            if !known { result.insert(trimmed) }
        }
        return result
    }

    /// 言い換え (句読点・語尾の違い) を既知とみなす文字 bigram Jaccard 類似度の閾値。
    static let similarityThreshold = 0.5

    private static func bigrams(of text: String) -> Set<String> {
        let chars = Array(text.filter { !$0.isWhitespace })
        guard chars.count >= 2 else { return chars.isEmpty ? [] : [String(chars)] }
        return Set((0..<(chars.count - 1)).map { String(chars[$0...$0 + 1]) })
    }

    private static func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        let union = a.union(b).count
        guard union > 0 else { return 0 }
        return Double(a.intersection(b).count) / Double(union)
    }
}

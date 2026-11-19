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
        let seenSet = Set(seen)
        return Set(current.filter { !seenSet.contains($0) })
    }
}

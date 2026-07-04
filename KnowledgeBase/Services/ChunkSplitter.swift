//
//  ChunkSplitter.swift
//  KnowledgeTree
//
//  spec 006 — 長文記事の chunked summarization の入口となる純粋関数。
//  本文を 1000 文字単位 (句点 graceful split) で最大 10 chunk に分割する。
//  Foundation Models / SwiftData 等の外部依存なし、テスト容易。
//

import Foundation

struct Chunk: Equatable, Sendable {
    let index: Int       // 0..<total
    let total: Int       // 配列の長さ
    let text: String     // 1..maxChars 文字
}

enum ChunkSplitter {
    /// 本文を最大 maxChars 文字、最大 maxChunks 個の chunk に分割する。
    /// 境界判定 (LLM Best Practices P2-3、セマンティック境界優先): 各 chunk の冒頭 maxChars 文字以内で
    ///   1. 段落境界 (`\n\n`) → 2. 句点 (`。`) → 3. 改行 (`\n`) の順に、最後に出現する境界で切る。
    /// いずれも範囲内に無ければ maxChars 文字で hard cut。maxChunks 到達後は残り (skipped tail) を捨てる。
    /// maxChars は不変 (=chunk 数・LLM 呼び出し数は据え置き)。より自然な意味単位で区切ることだけを狙う。
    static func split(
        text: String,
        maxChars: Int = 1000,
        maxChunks: Int = 10
    ) -> (chunks: [Chunk], skippedTailChars: Int) {
        precondition(maxChars >= 1)
        precondition(maxChunks >= 1)

        guard !text.isEmpty else {
            return ([], 0)
        }

        var rawChunks: [String] = []
        var remaining = text[...]

        while !remaining.isEmpty, rawChunks.count < maxChunks {
            // 候補境界: 残りが maxChars 以下なら全て採用
            if remaining.count <= maxChars {
                rawChunks.append(String(remaining))
                remaining = remaining[remaining.endIndex...]
                break
            }

            // 残り > maxChars: 冒頭 maxChars 内で最も自然な境界を探す (段落 > 句点 > 改行)。
            let headEnd = remaining.index(remaining.startIndex, offsetBy: maxChars)
            let head = remaining[..<headEnd]
            if let boundary = lastSemanticBoundary(in: head) {
                let inclusiveEnd = remaining.index(after: boundary)
                rawChunks.append(String(remaining[..<inclusiveEnd]))
                remaining = remaining[inclusiveEnd...]
            } else {
                // hard cut
                rawChunks.append(String(head))
                remaining = remaining[headEnd...]
            }
        }

        let totalChars = rawChunks.reduce(0) { $0 + $1.count }
        let skippedTail = max(0, text.count - totalChars)
        let total = rawChunks.count
        let chunks = rawChunks.enumerated().map { i, raw in
            Chunk(index: i, total: total, text: raw)
        }
        return (chunks, skippedTail)
    }

    /// head 内で最も自然な区切り位置 (含める最後の文字の index) を返す。
    /// 優先度: 段落境界 (`\n\n` の 2 つ目の `\n`) > 句点 `。` > 改行 `\n`。いずれも無ければ nil (→ hard cut)。
    /// 段落を単一改行/句点より優先することで、chunk が段落の途中で割れないようにする (抽出品質向上)。
    private static func lastSemanticBoundary(in head: Substring) -> Substring.Index? {
        // 1. 段落境界: 最後の "\n\n" の 2 つ目の \n を境界に (空行の直後で切る)。
        if let range = head.range(of: "\n\n", options: .backwards) {
            return head.index(before: range.upperBound)
        }
        // 2. 句点
        if let idx = head.lastIndex(of: "。") { return idx }
        // 3. 改行
        if let idx = head.lastIndex(of: "\n") { return idx }
        return nil
    }
}

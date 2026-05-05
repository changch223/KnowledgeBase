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
    /// 境界判定: 各 chunk の冒頭 maxChars 文字以内で最後の `。` または `\n` を境界とする。
    /// 句点・改行が範囲内に無ければ maxChars 文字で hard cut。maxChunks 到達後は残り (skipped tail) を捨てる。
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

            // 残り > maxChars: 冒頭 maxChars 内で最後の `。` または `\n` を探す
            let headEnd = remaining.index(remaining.startIndex, offsetBy: maxChars)
            let head = remaining[..<headEnd]
            if let cutIndex = head.lastIndex(where: { $0 == "。" || $0 == "\n" }) {
                let inclusiveEnd = remaining.index(after: cutIndex)
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
}

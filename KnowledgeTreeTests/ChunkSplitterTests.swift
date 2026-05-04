//
//  ChunkSplitterTests.swift
//  KnowledgeTreeTests
//
//  spec 006 — ChunkSplitter の不変条件と境界条件
//

import Testing
@testable import KnowledgeTree

@Suite("ChunkSplitter")
struct ChunkSplitterTests {

    @Test("空文字列は空配列を返す")
    func emptyText() {
        let result = ChunkSplitter.split(text: "")
        #expect(result.chunks.isEmpty)
        #expect(result.skippedTailChars == 0)
    }

    @Test("1 文字でも 1 chunk")
    func singleChar() {
        let result = ChunkSplitter.split(text: "a")
        #expect(result.chunks.count == 1)
        #expect(result.chunks[0].text == "a")
        #expect(result.chunks[0].index == 0)
        #expect(result.chunks[0].total == 1)
        #expect(result.skippedTailChars == 0)
    }

    @Test("999 文字は 1 chunk")
    func nineNineNine() {
        let text = String(repeating: "あ", count: 999)
        let result = ChunkSplitter.split(text: text, maxChars: 1000)
        #expect(result.chunks.count == 1)
        #expect(result.chunks[0].text.count == 999)
        #expect(result.skippedTailChars == 0)
    }

    @Test("1000 文字ちょうどは 1 chunk")
    func exactBoundary() {
        let text = String(repeating: "あ", count: 1000)
        let result = ChunkSplitter.split(text: text, maxChars: 1000)
        #expect(result.chunks.count == 1)
        #expect(result.chunks[0].text.count == 1000)
        #expect(result.skippedTailChars == 0)
    }

    @Test("1001 文字は 2 chunk")
    func justOverBoundary() {
        let text = String(repeating: "あ", count: 1001)
        let result = ChunkSplitter.split(text: text, maxChars: 1000)
        #expect(result.chunks.count == 2)
        #expect(result.chunks[0].total == 2)
        #expect(result.chunks[0].text.count == 1000)
        #expect(result.chunks[1].text.count == 1)
        #expect(result.skippedTailChars == 0)
    }

    @Test("5000 文字は 5 chunk")
    func fiveThousand() {
        let text = String(repeating: "あ", count: 5000)
        let result = ChunkSplitter.split(text: text, maxChars: 1000)
        #expect(result.chunks.count == 5)
        for c in result.chunks {
            #expect(c.text.count == 1000)
            #expect(c.total == 5)
        }
        #expect(result.skippedTailChars == 0)
    }

    @Test("10000 文字は 10 chunk")
    func tenThousand() {
        let text = String(repeating: "あ", count: 10_000)
        let result = ChunkSplitter.split(text: text, maxChars: 1000, maxChunks: 10)
        #expect(result.chunks.count == 10)
        #expect(result.skippedTailChars == 0)
    }

    @Test("10001 文字は 10 chunk + skippedTail 1")
    func skipsTailOverMaxChunks() {
        let text = String(repeating: "あ", count: 10_001)
        let result = ChunkSplitter.split(text: text, maxChars: 1000, maxChunks: 10)
        #expect(result.chunks.count == 10)
        #expect(result.skippedTailChars == 1)
    }

    @Test("15000 文字は 10 chunk + skippedTail 5000")
    func skipsLargeTail() {
        let text = String(repeating: "あ", count: 15_000)
        let result = ChunkSplitter.split(text: text, maxChars: 1000, maxChunks: 10)
        #expect(result.chunks.count == 10)
        #expect(result.skippedTailChars == 5000)
    }

    @Test("句点で graceful split")
    func gracefulSplitAtFullStop() {
        // 850 文字目に句点、1500 文字
        var text = String(repeating: "あ", count: 849) + "。"
        text += String(repeating: "い", count: 650)
        let result = ChunkSplitter.split(text: text, maxChars: 1000)
        #expect(result.chunks.count == 2)
        #expect(result.chunks[0].text.hasSuffix("。"))
        #expect(result.chunks[0].text.count == 850)
        #expect(result.chunks[1].text.count == 650)
    }

    @Test("改行で graceful split")
    func gracefulSplitAtNewline() {
        let text = String(repeating: "あ", count: 800) + "\n" + String(repeating: "い", count: 700)
        let result = ChunkSplitter.split(text: text, maxChars: 1000)
        #expect(result.chunks.count == 2)
        #expect(result.chunks[0].text.hasSuffix("\n"))
    }

    @Test("句点なし改行なしは hard cut")
    func hardCutFallback() {
        let text = String(repeating: "a", count: 1500)
        let result = ChunkSplitter.split(text: text, maxChars: 1000)
        #expect(result.chunks.count == 2)
        #expect(result.chunks[0].text.count == 1000)
        #expect(result.chunks[1].text.count == 500)
    }

    @Test("各 chunk の index と total は不変条件を満たす")
    func chunkInvariants() {
        let text = String(repeating: "あ", count: 3500)
        let result = ChunkSplitter.split(text: text, maxChars: 1000)
        for (i, c) in result.chunks.enumerated() {
            #expect(c.index == i)
            #expect(c.total == result.chunks.count)
            #expect(c.text.count >= 1)
            #expect(c.text.count <= 1000)
        }
    }

    @Test("chunk 連結は元 text の prefix と一致")
    func concatenationMatchesPrefix() {
        let text = String(repeating: "あ", count: 4321)
        let result = ChunkSplitter.split(text: text, maxChars: 1000, maxChunks: 10)
        let joined = result.chunks.map(\.text).joined()
        let totalChars = joined.count
        #expect(joined == String(text.prefix(totalChars)))
    }
}

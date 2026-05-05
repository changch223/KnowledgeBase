# Contract: ChunkSplitter

**File**: `KnowledgeTree/Services/ChunkSplitter.swift` (新規)

## 責務

本文文字列を固定サイズの chunk に分割する純粋関数群。Foundation Models / SwiftData 等の外部依存を持たない。

## API

```swift
struct ChunkSplitter {
    /// 本文を最大 maxChars 文字、最大 maxChunks 個の chunk に分割する。
    ///
    /// 境界判定:
    /// - 各 chunk は冒頭 maxChars 文字までで最後に出現する `。` または `\n` で切る
    /// - 句点・改行が範囲内に無ければ maxChars 文字で hard cut
    /// - chunk index は 0..<min(maxChunks, ceil(text.count / maxChars))
    /// - maxChunks に達したら残りの本文 (skipped tail) は捨てる
    ///
    /// - Parameters:
    ///   - text: 分割対象の本文
    ///   - maxChars: 1 chunk の最大文字数 (default 1000)
    ///   - maxChunks: 上限 chunk 数 (default 10)
    /// - Returns:
    ///   - chunks: 分割結果の Chunk 配列 (各 Chunk.total は配列長と一致)
    ///   - skippedTailChars: 上限超過で捨てた末尾文字数 (常に >= 0)
    static func split(
        text: String,
        maxChars: Int = 1000,
        maxChunks: Int = 10
    ) -> (chunks: [Chunk], skippedTailChars: Int)
}

struct Chunk: Equatable, Sendable {
    let index: Int       // 0..<total
    let total: Int       // 配列の長さ (>=1, <=maxChunks)
    let text: String     // 1..maxChars 文字
}
```

## 不変条件 (Invariants)

1. `chunks` が空配列なら `text` は空文字列
2. `chunks[i].index == i` (連続)
3. `chunks[i].total == chunks.count` (全 chunk で同じ)
4. `chunks[i].text.count >= 1 && chunks[i].text.count <= maxChars`
5. `chunks.map(\.text).joined() == text.prefix(chunksTotalChars)` (chunk の連結 = 元 text の冒頭部分)
6. `skippedTailChars == max(0, text.count - chunks.totalChars)` (chunks.totalChars = chunks.map(\.text.count).sum)
7. `chunks.count <= maxChunks`

## ボーダーケース

| 入力 text 文字数 | maxChars | maxChunks | 期待 chunk 数 | 期待 skippedTail |
|---|---|---|---|---|
| 0 | 1000 | 10 | 0 | 0 |
| 1 | 1000 | 10 | 1 (text 1 文字) | 0 |
| 999 | 1000 | 10 | 1 | 0 |
| 1000 | 1000 | 10 | 1 | 0 |
| 1001 | 1000 | 10 | 2 | 0 |
| 5000 | 1000 | 10 | 5 | 0 |
| 10000 | 1000 | 10 | 10 | 0 |
| 10001 | 1000 | 10 | 10 | 1 |
| 15000 | 1000 | 10 | 10 | 5000 |

## 境界判定の詳細

text = `"これは文1。これは文2。これは文3..."` (1500 文字、句点が 850 文字目と 1100 文字目に存在)、maxChars = 1000:
- chunk 0: text の冒頭 1000 文字内で最後の句点 (850 文字目) で切る → text[0..<851] (851 文字、`。` 含む)
- chunk 1: text[851..<min(text.count, 851+1000)] で同様に句点探索

text = `"abcdefg..."` (1500 文字、句点なし、改行なし)、maxChars = 1000:
- chunk 0: hard cut text[0..<1000]
- chunk 1: text[1000..<1500] (500 文字)

## テストケース (`ChunkSplitterTests.swift`)

```swift
@Test("空文字列は空配列を返す")
func emptyText()

@Test("1000 文字ちょうどは 1 chunk")
func exactBoundary()

@Test("1001 文字は 2 chunk に分割")
func justOverBoundary()

@Test("句点で graceful split")
func gracefulSplitAtFullStop()

@Test("改行で graceful split")
func gracefulSplitAtNewline()

@Test("句点なし改行なしは hard cut")
func hardCutFallback()

@Test("10001 文字は skippedTail 1 を返す")
func skipsTailOverMaxChunks()

@Test("15000 文字は冒頭 10 chunk + skippedTail 5000")
func skipsLargeTail()

@Test("各 chunk の index と total は不変条件を満たす")
func chunkInvariants()

@Test("chunk 連結は元 text の prefix と一致")
func concatenationMatchesPrefix()
```

## エラーケース

純粋関数なのでエラーは投げない。不正入力 (`maxChars < 1`, `maxChunks < 1`) は precondition 違反として `precondition(maxChars >= 1)` `precondition(maxChunks >= 1)` で fatal 扱い (App レベルから呼ばれることはない、テストで担保)。

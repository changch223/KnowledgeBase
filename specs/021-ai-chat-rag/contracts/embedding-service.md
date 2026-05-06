# Contract — EmbeddingService

**spec**: 021 / **file**: `KnowledgeTree/Services/EmbeddingService.swift` (new)

## 役割

NLEmbedding.sentenceEmbedding ベースで文章 embedding を生成し、cosine similarity を計算する Service。

## API

```swift
@MainActor
final class EmbeddingService {
    /// 起動時に NLEmbedding をロード、cache。nil = 不可端末 (R10)。
    let dimension: Int?
    let isAvailable: Bool

    init()

    /// 文章 → L2 正規化済み embedding。不可端末 / 失敗時は nil。
    func embed(_ text: String) -> [Float]?

    /// L2 正規化前提の dot product = cosine similarity。
    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float

    /// query × corpus → top-k インデックス + similarity 降順。
    /// query, corpus どちらも L2 正規化済み前提。
    static func topK(query: [Float], corpus: [(id: String, embedding: [Float])], k: Int) -> [(id: String, similarity: Float)]
}
```

## 不変条件

1. `embed()` 戻り値は L2 norm = 1.0 (正規化済み)、または nil
2. `cosineSimilarity` は両入力同次元前提、precondition で違反検出
3. `topK` は similarity 降順、k 件未満なら全件返す
4. `embed("")` (空文字) は nil

## エラーハンドリング

- NLEmbedding ロード失敗 → `isAvailable = false` で初期化、以降 `embed()` は常時 nil
- Foundation Models 等への副作用なし、純関数 (static)

## Test cases (T007)

| # | 入力 | 期待 |
|---|---|---|
| 1 | `embed("Swift 6 のこと")` | non-nil [Float] (L2=1.0) |
| 2 | `embed("")` | nil |
| 3 | `cosineSimilarity([1,0,0], [1,0,0])` | 1.0 |
| 4 | `cosineSimilarity([1,0,0], [0,1,0])` | 0.0 |
| 5 | `topK(query, corpus(10), k=3)` | 3 件、similarity 降順 |

## Constitution

- I (privacy): on-device、外部送信ゼロ
- IV (iOS 実現可能性): NaturalLanguage iOS 14+ 確立 API
- VI (architecture): MainActor + static helpers でテスト可能

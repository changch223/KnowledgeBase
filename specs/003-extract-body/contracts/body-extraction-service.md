# Contract: BodyExtractionService Protocol

**Layer**: Orchestration boundary (Constitution Principle VI)
**Used by**: `ArticleEnrichmentService` (enrichment 成功時に呼ぶ)、`KnowledgeTreeApp` (起動時 backfill キックオフ)

## Purpose

enrichment 成功した Article の rawHTML から `BodyExtractor` で本文を抽出し、`ArticleBodyStore` に永続化する。enrichment service と body service を疎結合に保つため、本 service は「抽出 + 保存」のみを行い、enrichment ロジックには関与しない。

## Protocol

```swift
protocol BodyExtractionServiceProtocol: Sendable {
    /// 指定された Article の rawHTML から本文抽出 → ArticleBody 保存。
    /// rawHTML が nil ならば no-op (ArticleBody は作成しない)。
    /// 既に ArticleBody.status == .succeeded ならば no-op (idempotent)。
    func extract(article: Article) async

    /// 起動時 backfill 用: ArticleBody を持たない & rawHTML 有り の Article を全件処理。
    func backfillAll() async

    /// 進行中の全ジョブをキャンセル。
    func cancelAll()
}
```

## Behavior

### `extract(article:)`

1. `article.body?.status` が `.succeeded` または `.permanentlyFailed` なら no-op (冪等性)。
2. `article.enrichment?.rawHTML` が nil なら no-op (ArticleBody 作成しない)。
3. なければ `ArticleBodyStore.upsert(article:, status: .extracting, ...)` でステータス更新。
4. `Task.detached(priority: .utility)` で `BodyExtractor.extract(html:)` を実行 (research.md / R5)。
5. 結果の `ParsedBody.extractedText`:
   - `nil` または < 100 文字 → `ArticleBodyStore.upsert(article:, status: .failed, extractedText: nil, ...)`。
   - 値あり → `ArticleBodyStore.upsert(article:, status: .succeeded, extractedText:, lastExtractedAt: Date(), ...)`。

### `backfillAll()`

1. `ArticleBodyStore.fetchPendingArticles()` で「ArticleBody 不在 & rawHTML あり」の Article を列挙 (上限 1000 件)。
2. 各 Article に対して `await extract(article:)` を順次実行 (並列度 1)。
3. 全件処理完了で return。

### `cancelAll()`

1. `Task` ハンドルをすべて cancel。
2. `Task.detached` の HTML パース処理が cancel respect で即停止する。

## Error model

`BodyExtractionError`:
- `.persistenceFailure(underlying: Error)` — `ArticleBodyStore` 書き込み失敗。
- `.cancelled` — Task cancellation。

エラーは UI に伝播せず、status enum (`.failed`) として吸収される (Principle V)。

## Threading

- protocol 自体は `Sendable`。
- HTML パースは detached `Task` (priority: `.utility`) — main thread 占有ゼロ。
- `ArticleBodyStore` 書き込みは `@MainActor`。

## Dependency injection

- spec 002 の `ArticleEnrichmentService` に `bodyExtractionService: BodyExtractionServiceProtocol?` を inject (optional)。
- enrichment service が status を `.succeeded` に更新した直後に `bodyExtractionService?.extract(article:)` を await せずに `Task { await ... }` で起動。
- enrichment service と body service の依存は片方向 (enrichment → body)、循環なし。

## Tests (KnowledgeTreeTests / `BodyExtractionServiceTests`)

最低限のテストケース (`MockBodyExtractor` + `MockArticleBodyStore` で実行):

| ケース | 入力 | 期待 |
|---|---|---|
| 通常成功 | rawHTML あり、Extractor が text 返す | `ArticleBodyStore.upsert(.succeeded, extractedText:)` 1 回呼ばれる |
| rawHTML nil | enrichment.rawHTML が nil | no-op、Store は呼ばれない |
| Extractor が nil text 返却 | extractor が ParsedBody(text: nil) | `Store.upsert(.failed, text: nil)` |
| 既に .succeeded | article.body?.status == .succeeded | no-op |
| backfill 複数件 | rawHTML 有 Article 3 件、ArticleBody 不在 | 順次 extract が 3 回呼ばれる |
| cancel | extract 中に cancelAll | Task が cancel、Store の `.failed` 書き込みもしない |
| 短すぎる結果 | extractor が "短い文字列" 返す (50 文字) | `Store.upsert(.failed, text: nil)` |
| persistence 例外 | Mock Store throw | `ArticleBody.status` は `.extracting` のまま (rollback はせず、次回 backfill で再試行可能) |

すべて Mock 経由で決定論的 (実 SwiftData / 実 HTML 解析なし)。

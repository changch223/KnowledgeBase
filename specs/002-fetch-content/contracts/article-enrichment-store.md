# Contract: ArticleEnrichmentStore Protocol

**Layer**: Persistence boundary (Constitution Principle VI)
**Used by**: `ArticleEnrichmentService`、`ArticleListView` (relationship 経由の自動 reload)

## Purpose

`ArticleEnrichment` の永続化操作を抽象化する protocol。SwiftData 実装と Mock 実装の差し替えを可能にし、Service 層のテストを容易にする。

## Protocol

```swift
protocol ArticleEnrichmentStoreProtocol {
    /// 指定 Article の enrichment を upsert (create or update)。
    /// Article.enrichment が nil なら作成、存在すればフィールドを上書き。
    func upsert(
        article: Article,
        status: EnrichmentStatus,
        canonicalTitle: String?,
        summary: String?,
        ogImageURL: String?,
        rawHTML: String?,
        retryCount: Int
    ) throws

    /// enrichment が無い (nil) または .pending / .failed の Article を全件取得。
    /// 起動時 backfill 用。fetchLimit は内部で 1000 程度に上限化 (大量データ対策)。
    func fetchPendingArticles() throws -> [Article]

    /// テスト / デバッグ用: 全 enrichment 削除。
    func deleteAll() throws
}
```

## Implementations

### `SwiftDataArticleEnrichmentStore` (production)

- 内部に `ModelContext` を保持。
- `upsert` は `article.enrichment` の有無で create / update を分岐。
- `fetchPendingArticles` は `FetchDescriptor<Article>` + predicate `enrichment == nil OR enrichment.statusRaw IN ["pending", "failed"]`。
- 全 SwiftData 操作は `@MainActor` 上で実行。

### `MockArticleEnrichmentStore` (testing)

- 内部に `[ArticleEnrichment]` を保持する in-memory 実装。
- Service 層 unit test 用。throw 注入も可能 (`shouldThrowOnUpsert: Bool`)。

## Error model

`ArticleEnrichmentStoreError`:
- `.persistenceFailure(underlying: Error)` — SwiftData の context.save / fetch が throw した場合。
- メッセージは UI 層で日本語に変換 (Principle VII)。

## Threading

- `ArticleEnrichmentStoreProtocol` 実装は `@MainActor` で動作 (SwiftData の主スレッド要件)。
- Service 側は `await store.upsert(...)` のように呼ぶ (`@MainActor` への hop が発生)。

## Tests (KnowledgeTreeTests / `SwiftDataArticleEnrichmentStoreTests`)

最低限以下のケース:

| ケース | 期待 |
|---|---|
| upsert (新規) | Article.enrichment が nil から ArticleEnrichment が紐づく |
| upsert (更新) | 既存 ArticleEnrichment のフィールドが更新、id は不変 |
| fetchPendingArticles (空) | enrichment 全件 succeeded → 空配列 |
| fetchPendingArticles (混在) | succeeded + nil + pending + failed → nil/pending/failed の Article のみ返却 |
| Article 削除 → cascade | Article 削除後に enrichment も削除されている |
| deleteAll | 全 enrichment 削除、Article は残る (`enrichment` は nil に) |

すべて `ModelConfiguration(isStoredInMemoryOnly: true)` の `ModelContainer` で実行 (Constitution テストゲート)。

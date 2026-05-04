# Contract: ArticleBodyStore Protocol

**Layer**: Persistence boundary (Constitution Principle VI)
**Used by**: `BodyExtractionService`、`ArticleListView` (relationship 経由の自動 reload)

## Purpose

`ArticleBody` の永続化操作を抽象化する protocol。SwiftData 実装と Mock 実装の差し替えを可能にし、Service 層のテストを容易にする。

## Protocol

```swift
protocol ArticleBodyStoreProtocol {
    /// 指定 Article の body を upsert (create or update)。
    /// Article.body が nil なら作成、存在すればフィールドを上書き。
    func upsert(
        article: Article,
        status: BodyExtractionStatus,
        extractedText: String?,
        extractionVersion: Int,
        lastExtractedAt: Date?
    ) throws

    /// ArticleBody が無い & rawHTML 有り の Article を全件取得。
    /// 起動時 backfill 用。fetchLimit は内部で 1000 程度に上限化。
    func fetchPendingArticles() throws -> [Article]

    /// テスト / デバッグ用: 全 ArticleBody 削除。
    func deleteAll() throws
}
```

## Implementations

### `SwiftDataArticleBodyStore` (production)

- 内部に `ModelContext` を保持。
- `upsert` は `article.body` の有無で create / update を分岐。
- `fetchPendingArticles` は `FetchDescriptor<Article>` + predicate `body == nil AND enrichment != nil AND enrichment.rawHTML != nil`。
- 全 SwiftData 操作は `@MainActor`。

### `MockArticleBodyStore` (testing)

- 内部に `[ArticleBody]` を保持する in-memory 実装。
- Service 層 unit test 用。throw 注入も可能 (`shouldThrowOnUpsert: Bool`)。

## Error model

`ArticleBodyStoreError`:
- `.persistenceFailure(underlying: Error)` — SwiftData の context.save / fetch が throw した場合。
- メッセージは UI 層で日本語に変換 (Principle VII)。

## Threading

- `ArticleBodyStoreProtocol` 実装は `@MainActor`。
- Service 側は `await store.upsert(...)` で `@MainActor` への hop が発生。

## Tests (KnowledgeTreeTests / `SwiftDataArticleBodyStoreTests`)

最低限以下のケース:

| ケース | 期待 |
|---|---|
| upsert (新規) | Article.body が nil から ArticleBody が紐づく |
| upsert (更新) | 既存 ArticleBody のフィールドが更新、id 不変 |
| fetchPendingArticles (空) | body 全件 succeeded → 空配列 |
| fetchPendingArticles (rawHTML なし除外) | rawHTML nil の Article は対象外 |
| fetchPendingArticles (混在) | body nil & rawHTML 有り のみ返却 |
| Article 削除 → cascade | Article 削除後に body も削除されている |
| deleteAll | 全 body 削除、Article は残る (`body` は nil に) |

すべて `ModelConfiguration(isStoredInMemoryOnly: true)` の `ModelContainer` で実行 (Constitution テストゲート)。

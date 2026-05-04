# Contract: ArticleStore Protocol

**Layer**: Persistence boundary (Constitution Principle VI)
**Used by**: `ArticleSavingService`、`ArticleListView` の `@Query` (実装上は SwiftData 直接、protocol 経由のテストは Service 層で行う)

## Purpose

`Article` の永続化操作を抽象化する protocol。SwiftData 実装と mock 実装の差し替えを可能にし、`ArticleSavingService` のユニットテストを容易にする。

## Protocol

```swift
protocol ArticleStoreProtocol: Sendable {
    /// URL に完全一致する Article が存在するか判定する。
    /// fetchLimit = 1 で実装され、データ規模に対して O(log n) 程度を想定。
    func exists(url: String) throws -> Bool

    /// Article を 1 件挿入する。重複チェックは呼び出し側 (Service) の責務。
    func insert(_ article: Article) throws

    /// Article を 1 件削除する。
    func delete(_ article: Article) throws

    /// 全 Article を保存日時の新しい順に取得する。
    /// 一覧 View では SwiftData の @Query を直接使うため、本メソッドは
    /// Share Extension 側のデバッグや将来のエクスポート機能で使用。
    func fetchAllSortedBySavedAt() throws -> [Article]
}
```

## Implementations

### `SwiftDataArticleStore` (production)

- 内部に `ModelContext` を保持。
- `exists(url:)` は `FetchDescriptor<Article>` + `#Predicate { $0.url == url }` + `fetchLimit = 1` で実装。
- `insert` / `delete` は `context.insert` / `context.delete` + `context.save()`。

### `MockArticleStore` (testing)

- 内部に `[Article]` を保持する in-memory 実装。
- 単体テストで `ArticleSavingService` の重複検出ロジックを検証する用途。

## Error model

`ArticleStoreError`:
- `.persistenceFailure(underlying: Error)` — SwiftData の `context.save` / `context.fetch` が throw した場合のラップ。
- メッセージは UI 層で日本語に変換 (Principle VII)。

## Threading

- `ArticleStoreProtocol` は `Sendable`。実装は `actor` または `@MainActor` のいずれかで、`ModelContext` のスレッドルールに従う。
- 具体的なスレッド戦略は実装フェーズ (tasks.md) で詳細化。

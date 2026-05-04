# Contract: ArticleEnrichmentService Protocol

**Layer**: Orchestration boundary (Constitution Principle VI)
**Used by**: `KnowledgeTreeApp` (起動時 backfill キックオフ)、`ArticleListView` (新 Article 挿入の observe → enqueue) 、または 単一の `EnrichmentCoordinator` から呼ばれる

## Purpose

新規 / pending / failed の `Article` を 1 件ずつ取り出し、HTTPS GET → HTML パース → `ArticleEnrichment` 保存 を非同期で行う。retry / backoff / cancellation を内包する。

## Protocol

```swift
protocol ArticleEnrichmentServiceProtocol: Sendable {
    /// 指定された Article を 1 件 enrichment する (キャッシュ済みなら no-op)。
    /// retry / backoff / cancellation を含む。
    func enrich(article: Article) async

    /// 起動時 backfill 用: 全 Article から enrichment 未完了 (nil または .pending / .failed) を
    /// 取り出し順次キューイング。
    func backfillAll() async

    /// 進行中の全ジョブをキャンセル (アプリ終了 / ユーザー設定変更等)。
    func cancelAll()
}
```

## Behavior

### `enrich(article:)`

1. `article.enrichment` が `.succeeded` または `.permanentlyFailed` なら no-op (no-op 判定で Service の冪等性を担保)。
2. なければ `ArticleEnrichmentStore.upsert(article:, status: .fetching)` でステータス更新。
3. `URLSessionProtocol.data(for: URLRequest(url: article.url, headers: 固定 User-Agent + Accept))` を呼ぶ。
4. 例外 (timeout / network error / non-2xx) なら `retry()` 経由で backoff スケジュール (R3)。
5. 成功時、`MetadataParser.parse(html: response.body, baseURL: url)` を呼びメタデータ抽出。
6. rawHTML を 2 MB チェック後、`ArticleEnrichmentStore.upsert(article:, ..., status: .succeeded)`。
7. `permanentlyFailed` 到達時は `Logger` に記録 (URL / タイトル等の機微は出力せず status と generic error type のみ、FR-014)。

### `backfillAll()`

1. `ArticleEnrichmentStore.fetchPendingArticles()` で対象を列挙。
2. 各 Article に対して `await enrich(article:)` を順次実行 (並列度 1、設計上の決定)。
3. 全件処理完了で return。

### `cancelAll()`

1. `Task` ハンドルを cancel。
2. `Task.sleep` 中の backoff も即解除される。

## Error model

`ArticleEnrichmentError`:
- `.network(URLError)` — fetch 失敗 (timeout / DNS 等)
- `.invalidStatus(Int)` — non-2xx
- `.tooLarge(Int)` — Content-Length 超過 (5 MB)
- `.invalidScheme(String)` — http/https 以外 (通常発生しないが安全網)
- `.parsingFailed` — HTML パース完全失敗
- `.cancelled` — Task cancellation

エラーは UI には伝播せず、status enum (`.failed` / `.permanentlyFailed`) として吸収される (Principle V — UI 安定)。

## Threading

- protocol 自体は `Sendable` 必須。
- `URLSession` background config 経由のため I/O は OS スレッド。HTML パースは detached `Task` で main 以外。
- `ArticleEnrichmentStore` への書き込みは `@MainActor` (SwiftData の主スレッド要件)。

## Tests (KnowledgeTreeTests / `ArticleEnrichmentServiceTests`)

| ケース | 入力 | 期待 |
|---|---|---|
| 成功フロー | 200 OK + 正常 HTML | `succeeded`、canonicalTitle / summary / ogImageURL 設定 |
| 404 → backoff → 成功 | 1 回目 404、2 回目 200 | retryCount 1、最終 `succeeded` |
| 連続失敗 → permanentlyFailed | 3 回 timeout | retryCount 3、`permanentlyFailed` |
| 5 MB 超 | 巨大 HTML | `failed` または `permanentlyFailed`、エラー `.tooLarge` |
| HTTP scheme | URL が http://... | `permanentlyFailed`、エラー `.invalidScheme` |
| HTML 不正 | 壊れた HTML | parser が部分抽出。1 つでもメタデータ取れたら `succeeded`、全滅なら `failed` |
| キャンセル | enrich 中に cancelAll | `Task.sleep` が即解除、status は変更されないかロールバック |
| no-op (succeeded) | 既に succeeded の Article | no HTTP fetch、no DB write |
| no-op (permanentlyFailed) | 既に permanentlyFailed | no HTTP fetch |

すべて `MockURLSession` + `MockArticleEnrichmentStore` で実行 (実 HTTP / 実 DB なし、決定論的)。

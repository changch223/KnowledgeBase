# Data Model: マルチページ記事の自動追跡 (Phase 1)

**Feature**: spec 007
**Date**: 2026-05-05

## 1. 永続化エンティティ (@Model)

### 1.1 ArticleEnrichment (既存 + 列追加)

| 既存列 | 型 | 概要 |
|---|---|---|
| `id` | `UUID` | 主キー |
| `article` | `Article` | 元記事への非 optional 参照 |
| `statusRaw` | `String` | EnrichmentStatus raw value |
| `canonicalTitle` | `String?` | 1 ページ目の `<title>` |
| `summary` | `String?` | 1 ページ目の meta description / og:description |
| `ogImageURL` | `String?` | 1 ページ目の og:image |
| `rawHTML` | `String?` | 連結済 HTML (2MB 上限超過時 nil) |
| `lastFetchedAt` | `Date?` | 最終 fetch 完了日時 |
| `retryCount` | `Int` | 1 ページ目の retry 回数 (spec 002 既存) |

| 新規列 | 型 | デフォルト | 概要 |
|---|---|---|---|
| `pageCountFetched` | `Int` | 1 | 実取得ページ数 (>=1) |
| `pageCountSkipped` | `Int` | 0 | 上限到達 / エラーで打ち切ったページ数 (>=0) |

**バリデーション**:
- `pageCountFetched >= 1`
- `pageCountSkipped >= 0`
- `pageCountFetched <= 5` (FR-006: 最大 5 ページ)

**migration**: SwiftData lightweight migration で新列追加 (default 値 1, 0 で既存レコードに自動入る)。spec 005 / 006 の column 追加と同じパターン。

### 1.2 Article (既存、変更なし)

`Article.url` は **1 ページ目の URL** を保持 (spec 001 既存)。マルチページでも Article は 1 件のまま。

---

## 2. Transient エンティティ

### 2.1 PaginationLink

```swift
struct PaginationLink: Equatable, Sendable {
    let url: URL                    // 解決済 absolute URL
    let detectedBy: DetectionRule   // どのルールで検出されたか
    let confidence: Confidence
}

enum DetectionRule: String, Sendable {
    case linkRelNext     // <link rel="next">
    case anchorRelNext   // <a rel="next">
    case anchorClassNext // <a class="next">
    case urlPattern      // ?page=N+1 等
}

enum Confidence: Int, Sendable {
    case high = 100   // rel=next
    case medium = 70  // class=next
    case low = 40     // URL pattern
}
```

**生成元**: `PaginationDetector.detect(html:currentURL:)` -> `PaginationLink?`
**用途**: 次ページの URL とその信頼度を Crawler に渡す
**永続化**: 無し

### 2.2 PageCrawlSession

```swift
struct PageCrawlSession: Sendable {
    var visitedNormalizedURLs: Set<String>   // URL 正規化済 string
    var pageHTMLs: [String]                  // 各ページの decode 済 HTML
    var pageURLs: [URL]                      // 各ページの実 URL (Article.url 含む)
    var stopReason: StopReason?
}

enum StopReason: String, Sendable {
    case noNextPageFound
    case maxPagesReached
    case loopDetected
    case crossDomain
    case fetchFailed
    case rawHTMLLimitExceeded
}
```

**用途**: 1 つの crawl ジョブ内で actor が保持する状態
**永続化**: 無し (crawl 完了後は破棄)

### 2.3 CrawlResult

```swift
struct CrawlResult: Sendable {
    let firstPageMetadata: MetadataParser.ParsedMetadata  // 1 ページ目のみ
    let combinedHTML: String?                              // nil if rawHTML limit exceeded
    let pageCountFetched: Int
    let pageCountSkipped: Int
    let stopReason: StopReason
}
```

**生成元**: `MultiPageCrawler.crawl(initialURL:session:userAgent:) async throws -> CrawlResult`
**用途**: Service が SwiftData に upsert する直前の中間表現
**永続化**: 無し

---

## 3. State Transition (EnrichmentStatus)

spec 002 の既存 status enum はそのまま流用。マルチページパスでも同じ遷移:

```text
.pending
   │
   ▼ enrich(article:) 呼び出し
.fetching                        ← MultiPageCrawler.crawl 実行中
   │
   ├──── 1 ページ目 fetch 失敗 (3 retry も失敗) ──▶ .permanentlyFailed
   ├──── 2 ページ目以降のみ失敗 ────────────────▶ .succeeded (打ち切り、得られたページのみ保存)
   ├──── 全ページ取得成功 ──────────────────────▶ .succeeded
   ├──── 連結 HTML 2MB 超過 ────────────────────▶ .succeeded (rawHTML nil で保存)
   └──── invalidScheme (https 以外) ───────────▶ .permanentlyFailed (spec 002 既存)
```

---

## 4. 既存型との互換性

| 型 | 変更 | 理由 |
|---|---|---|
| `ArticleEnrichment` | 列 2 追加 | pageCount{Fetched,Skipped} 永続化 |
| `Article` | 変更なし | 1 ページ目 URL のみ保持で十分 |
| `EnrichmentStatus` | 変更なし | 既存 case で表現可能 |
| `MetadataParser.ParsedMetadata` | 変更なし | 1 ページ目のみ採用、既存 API |
| `URLSessionProtocol` | 変更なし | Mock 拡張は test 側のみ |
| `ProcessingMonitor.ActiveTask` | spec 006 で追加した progressIndex/Total を流用 | 新規変更なし |

---

## 5. 生成 → 永続化のフロー

```text
1. ArticleEnrichmentService.enrich(article:) 呼び出し
2. activeTasks 既存 → 待機 → return (重複抑止 spec 005)
3. URL https チェック → 失敗時 .permanentlyFailed
4. crawler = MultiPageCrawler(session: urlSession, userAgent: ..., delaySeconds: 1)
5. monitor.start(.enrichment, articleID, title, progressIndex: 0, progressTotal: 5)
6. result = await crawler.crawl(initialURL: url) {
       - 1 ページ目 fetch (spec 002 既存 retry 適用)
       - parsed = MetadataParser.parse(html)
       - link = PaginationDetector.detect(html, currentURL)
       - while link != nil && pages < 5 && !visited.contains(link.url.normalized()):
           - sleep 1s
           - monitor.updateProgress(articleID, index: pages + 1)
           - fetch link.url (1 回試行のみ)
           - decode html, append to pageHTMLs
           - link = PaginationDetector.detect(html, link.url)
       - combine HTMLs with comment markers
       - return CrawlResult
   }
7. if result.combinedHTML != nil:
       store.upsert(article: ..., status: .succeeded,
                    canonicalTitle: result.firstPageMetadata.canonicalTitle,
                    summary: result.firstPageMetadata.summary,
                    ogImageURL: result.firstPageMetadata.ogImageURL,
                    rawHTML: result.combinedHTML.count <= rawHTMLCacheLimit ? result.combinedHTML : nil,
                    retryCount: 0,
                    pageCountFetched: result.pageCountFetched,
                    pageCountSkipped: result.pageCountSkipped)
   else:
       store.upsert(... rawHTML: nil, ...)
8. monitor.finish(articleID)
9. fire-and-forget body extraction service (spec 003 既存)
```

`store.upsert` の signature に新引数 2 つ追加 (default 値 1, 0 で既存呼び出しは無修正可能)。

---

## 6. テスト用 fixture (HTML)

`KnowledgeTreeTests/Fixtures/PaginationHTML.swift` (新規):

| Fixture | 内容 | 期待検出 |
|---|---|---|
| `linkRelNextHTML` | `<head><link rel="next" href="page2.html">` | rule 1 hit |
| `anchorRelNextHTML` | `<a rel="next" href="?page=2">次のページ</a>` | rule 2 hit |
| `anchorClassNextHTML` | `<a class="pagination-next" href="/page/2">Next</a>` | rule 3 hit |
| `urlPatternHTML` | 一般的な `<a href="?page=2">` 多数 + 現在 URL `/article` | rule 4 hit |
| `noPaginationHTML` | 通常記事 (rel=next 等なし) | nil |
| `crossDomainHTML` | `<link rel="next" href="https://other.com/page2">` | nil (rejected) |
| `selfLoopHTML` | `<link rel="next" href="https://example.com/article">` (current と同じ) | nil (loop) |
| `relativeURLHTML` | `<link rel="next" href="page2">` (相対 URL) | rule 1 hit、解決済 absolute |

各 fixture は `String` プロパティとして提供。

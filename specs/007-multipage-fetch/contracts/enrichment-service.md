# Contract: ArticleEnrichmentService (multipage extension)

**File**: `KnowledgeTree/Services/ArticleEnrichmentService.swift` (既存に拡張)

## 責務

spec 002 で実装済の enrichment service を、`MultiPageCrawler` 経由で呼ぶように修正。1 ページ目の retry / charset 検出 / metadata parse は既存挙動を Crawler 内に移譲。Service は処理オーケストレーション (重複抑止 / monitor 通知 / store 保存 / fire-and-forget body extraction) のみ担当。

## API (変更なし、内部実装のみ修正)

```swift
@MainActor
final class DefaultArticleEnrichmentService: ArticleEnrichmentServiceProtocol {
    // 既存 init を拡張
    init(
        session: URLSessionProtocol,
        store: ArticleEnrichmentStoreProtocol,
        bodyExtractionService: BodyExtractionServiceProtocol? = nil,
        processingMonitor: ProcessingMonitor? = nil,
        userAgent: String = "KnowledgeTree/1.0 (iOS)",
        maxDownloadBytes: Int = 5 * 1024 * 1024,
        rawHTMLCacheLimit: Int = 2 * 1024 * 1024,
        backoffSchedule: [Duration] = [.seconds(30), .seconds(120), .seconds(600)],
        maxPages: Int = 5,                              // 新規 (spec 007)
        delayBetweenPages: Duration = .seconds(1)       // 新規 (spec 007)
    )

    // 既存 API (変更なし)
    func enrich(article: Article) async
    func backfillAll() async
    func cancelAll()
}
```

## 内部実装の変更点

### performEnrichment (内部 method、既存)

```swift
private func performEnrichment(article: Article, url: URL) async {
    let articleID = article.id
    let articleTitle = article.title
    processingMonitor?.start(.enrichment, articleID: articleID, title: articleTitle)
    defer { processingMonitor?.finish(articleID: articleID) }

    try? store.upsert(article: ..., status: .fetching, ...)

    let crawler = MultiPageCrawler(
        session: session,
        userAgent: userAgent,
        maxPages: maxPages,
        delayBetweenPages: delayBetweenPages,
        maxDownloadBytes: maxDownloadBytes,
        firstPageRetrySchedule: backoffSchedule
    )

    let result = await crawler.crawl(initialURL: url) { [weak self] pageIndex, _ in
        // 進捗通知 (page 完了ごと)
        Task { @MainActor [weak self] in
            self?.processingMonitor?.updateProgress(
                articleID: articleID,
                index: pageIndex
            )
        }
    }

    switch result.stopReason {
    case .firstPageFailed:
        // spec 002 既存の retry 後 .permanentlyFailed
        try? store.upsert(article: ..., status: .permanentlyFailed, ...)
        return

    case .completed, .maxPagesReached, .loopDetected, .crossDomainBlocked, .fetchFailed:
        // 1 ページ目以上 fetched している
        let metadata = result.firstPageMetadata!
        let rawHTML: String? = (result.combinedHTML?.count ?? 0) <= rawHTMLCacheLimit
            ? result.combinedHTML
            : nil
        try? store.upsert(
            article: article,
            status: .succeeded,
            canonicalTitle: metadata.canonicalTitle,
            summary: metadata.summary,
            ogImageURL: metadata.ogImageURL?.absoluteString,
            rawHTML: rawHTML,
            retryCount: result.firstPageRetryCount,
            pageCountFetched: result.pageCountFetched,
            pageCountSkipped: result.pageCountSkipped
        )

    case .rawHTMLLimitWillExceed:
        // 早期打ち切り (MVP では発火しないが branch を用意)
        // 同上の処理
    }

    if let bodyExtractionService {
        Task {
            await bodyExtractionService.extract(article: article)
        }
    }
}
```

### Store API 拡張

```swift
protocol ArticleEnrichmentStoreProtocol {
    // 既存 + 新規引数 2 つ
    func upsert(
        article: Article,
        status: EnrichmentStatus,
        canonicalTitle: String?,
        summary: String?,
        ogImageURL: String?,
        rawHTML: String?,
        retryCount: Int,
        pageCountFetched: Int = 1,        // 新規 (default 1 で既存呼び出し互換)
        pageCountSkipped: Int = 0         // 新規 (default 0 で既存呼び出し互換)
    ) throws
}
```

`SwiftDataArticleEnrichmentStore` 内で `existing.pageCountFetched = pageCountFetched` / `existing.pageCountSkipped = pageCountSkipped` を実行 (新列に書き込み)。

## ProcessingMonitor の拡張 (spec 006 の API を流用 + start で総数指定)

```swift
extension ProcessingMonitor {
    // spec 007 用: enrichment フェーズで total を最初から指定する
    func start(
        _ phase: Phase,
        articleID: UUID,
        title: String,
        progressIndex: Int? = nil,
        progressTotal: Int? = nil
    ) {
        let task = ActiveTask(
            id: articleID,
            articleTitle: title,
            phase: phase,
            startedAt: Date(),
            progressIndex: progressIndex,
            progressTotal: progressTotal
        )
        tasksByArticle[articleID] = task
    }
}
```

enrichment 開始時に `progressIndex: 0, progressTotal: 5` を渡す (M=5 固定、research.md R7 参照)。

## 後方互換性

### 既存テストへの影響

`ArticleEnrichmentServiceTests` の既存 4 ケース (`enrichWithHTTPSchemeMarksPermanentlyFailed`, `enrichSkipsAlreadySucceededArticle`, `enrichWithSuccessfulFetchUpdatesStoreToSucceeded`, `enrichTriggersBodyExtractionOnSuccess`) は **無修正で pass** すること。

理由:
- これらのテストは Mock URLSessionProtocol が単一 fetch (rel=next 無し HTML) を返すケース → `MultiPageCrawler` が 1 ページのみ取得して .completed で終了 → 既存挙動と同じ store.upsert 呼び出しになる
- store.upsert の新引数 2 つは default 値あり → Mock store が ignore して問題なし

### 新規テストケース

```swift
@Test("3 ページ記事を 1 件として保存")
func enrichWithThreePages()

@Test("5 ページ上限到達時 pageCountSkipped > 0")
func enrichReachesMaxPages()

@Test("循環 pagination で停止")
func enrichDetectsLoop()

@Test("クロスドメイン rel=next を拒否")
func enrichRejectsCrossDomain()

@Test("巨大連結 HTML で rawHTML nil 保存")
func enrichRawHTMLLimitExceeded()

@Test("各ページ完了で monitor.updateProgress")
func enrichUpdatesProgressPerPage()

@Test("1 ページ目 retry 後 multi-page 成功")
func enrichFirstPageRetrySucceeds()
```

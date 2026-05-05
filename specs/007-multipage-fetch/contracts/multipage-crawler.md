# Contract: MultiPageCrawler

**File**: `KnowledgeTree/Services/MultiPageCrawler.swift` (新規)

## 責務

initialURL から始めて pagination を最大 N ページ追跡する actor。1 ページ目の fetch (retry 含む) → pagination 検出 → 2 ページ目以降を逐次 fetch (retry なし、1 秒遅延) → 連結 HTML を返す。

## API

```swift
actor MultiPageCrawler {
    let session: URLSessionProtocol
    let userAgent: String
    let maxPages: Int                    // default 5
    let delayBetweenPages: Duration      // default .seconds(1)
    let maxDownloadBytes: Int            // default 5 * 1024 * 1024 (per page)
    let firstPageRetrySchedule: [Duration] // default [30s, 120s, 600s] (spec 002 と同じ)

    init(
        session: URLSessionProtocol,
        userAgent: String,
        maxPages: Int = 5,
        delayBetweenPages: Duration = .seconds(1),
        maxDownloadBytes: Int = 5 * 1024 * 1024,
        firstPageRetrySchedule: [Duration] = [.seconds(30), .seconds(120), .seconds(600)]
    )

    /// initialURL から始めて pagination を辿り、全ページの HTML を連結して返す。
    /// 進捗は progressCallback で通知 (each page 完了時)。
    func crawl(
        initialURL: URL,
        progressCallback: ((Int, StopReason?) -> Void)? = nil
    ) async -> CrawlResult
}

struct CrawlResult: Sendable {
    let firstPageMetadata: MetadataParser.ParsedMetadata?  // 1 ページ目失敗時 nil
    let combinedHTML: String?                              // 連結済 HTML (失敗時 nil)
    let pageCountFetched: Int                              // >=0 (1 ページ目失敗時 0)
    let pageCountSkipped: Int                              // >=0
    let stopReason: StopReason
    let firstPageRetryCount: Int                           // spec 002 既存挙動
}

enum StopReason: String, Sendable {
    case completed             // 全 pagination 追跡完了 (or 検出失敗で正常終了)
    case maxPagesReached       // 上限到達
    case loopDetected          // 訪問済 URL 再訪検出
    case crossDomainBlocked    // クロスドメイン拒否
    case fetchFailed           // 2 ページ目以降の fetch 失敗
    case firstPageFailed       // 1 ページ目失敗 (retry 全敗)
    case rawHTMLLimitWillExceed // 連結予定で 2MB 超過予測 → 早期打ち切り (optional optimization、MVP 不要)
}
```

## 動作詳細

### Crawl flow

```text
1. visited = Set<String>(); pages = []; urls = []
2. currentURL = initialURL
3. (1 ページ目) firstPageHTML = fetchWithRetry(currentURL, retrySchedule)
4. if firstPageHTML == nil:
       return CrawlResult(stopReason: .firstPageFailed, pageCountFetched: 0, ...)
5. pages.append(firstPageHTML); urls.append(currentURL)
6. visited.insert(currentURL.normalized())
7. firstPageMetadata = MetadataParser.parse(firstPageHTML)
8. progressCallback?(1, nil)
9. while pages.count < maxPages:
       link = PaginationDetector.detect(html: pages.last!, currentURL: urls.last!)
       guard let link else { break (stopReason = .completed) }
       guard !visited.contains(link.url.normalized()) else { break (.loopDetected) }
       guard sameHost(link.url, urls.first!) else { break (.crossDomainBlocked) }
       try? await Task.sleep(for: delayBetweenPages)
       html = fetchOnce(link.url)
       guard let html else { break (.fetchFailed) }
       pages.append(html); urls.append(link.url)
       visited.insert(link.url.normalized())
       progressCallback?(pages.count, nil)
   if pages.count == maxPages && link != nil { stopReason = .maxPagesReached }
10. combinedHTML = pages.enumerated().map { (i, html) in
        "\(html)\n\n<!-- KnowledgeTree.PageBoundary index=\"\(i+1)\" url=\"\(urls[i].absoluteString)\" -->"
    }.joined(separator: "\n\n")
11. pageCountSkipped = (estimated remaining if stopReason == .maxPagesReached else 0)
12. return CrawlResult(...)
```

### sameHost 判定

```swift
func sameHost(_ a: URL, _ b: URL) -> Bool {
    let normHost = { (host: String?) in
        host?.lowercased().replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression)
    }
    return normHost(a.host) == normHost(b.host)
}
```

### URL 正規化 (normalized)

`URL.normalized()` 拡張 (`Services/URLNormalization.swift`、新規) で実装 (research.md R2 参照)。

## 不変条件

1. `result.pageCountFetched <= maxPages`
2. `result.pageCountFetched >= 0` (firstPageFailed なら 0)
3. `result.firstPageMetadata != nil` ⟺ `result.pageCountFetched >= 1`
4. `result.combinedHTML != nil` ⟺ `result.pageCountFetched >= 1`
5. `result.stopReason == .firstPageFailed` ⟺ `result.pageCountFetched == 0`
6. progressCallback は各ページ完了 (含む 1 ページ目) で 1 回ずつ呼ばれる

## ボーダーケース

| シナリオ | 期待結果 |
|---|---|
| 1 ページ記事 (rel=next なし) | pageCountFetched=1, stopReason=.completed, pageCountSkipped=0 |
| 3 ページ記事 (3 ページ目で rel=next なし) | pageCountFetched=3, stopReason=.completed |
| 5 ページ記事 (5 ページ目で rel=next なし、6 ページ目を指す rel=next が無い) | pageCountFetched=5, stopReason=.completed |
| 7 ページ記事 (5 ページ目時点で rel=next がまだ続く) | pageCountFetched=5, stopReason=.maxPagesReached, pageCountSkipped >= 1 |
| 循環 (3 ページ目の rel=next が 1 ページ目を指す) | pageCountFetched=3, stopReason=.loopDetected |
| クロスドメイン (3 ページ目の rel=next が他ドメイン) | pageCountFetched=3, stopReason=.crossDomainBlocked |
| 4 ページ目 fetch で 404 | pageCountFetched=3, stopReason=.fetchFailed |
| 1 ページ目で 3 retry 全敗 | pageCountFetched=0, stopReason=.firstPageFailed |
| 1 ページ目 retry 1 回後成功 | pageCountFetched=1+, firstPageRetryCount=1 |

## テストケース (`MultiPageCrawlerTests.swift`)

```swift
@Test("単一ページ記事は 1 ページのみ取得して .completed")
func singlePageArticle()

@Test("3 ページ記事を全 3 ページ取得して .completed")
func threePageArticle()

@Test("5 ページ上限に到達したら .maxPagesReached")
func fivePageMaxReached()

@Test("循環 pagination で .loopDetected")
func loopDetected()

@Test("クロスドメイン rel=next で .crossDomainBlocked")
func crossDomainBlocked()

@Test("途中 fetch 失敗で .fetchFailed")
func midFetchFailed()

@Test("1 ページ目 retry 失敗で .firstPageFailed")
func firstPageFailed()

@Test("1 ページ目 retry 成功後 multipage")
func firstPageRetrySucceeds()

@Test("各ページ完了で progressCallback 呼ばれる")
func progressCallbackCalled()

@Test("ページ間 delay が 1 秒")
func delayBetweenPages()  // モック clock で検証

@Test("連結 HTML に PageBoundary コメントが含まれる")
func combinedHTMLHasBoundaryComments()

@Test("HTML 大きすぎ (個別 5MB 超え) で fetch 失敗扱い")
func tooLargeIndividualPage()
```

## エラーケース

actor のメソッドは throw しない (CrawlResult.stopReason で結果を表現)。例外: `Task.sleep` の `CancellationError` は伝播 (上位の `ArticleEnrichmentService.cancelAll` で呼ばれた場合に使う)。

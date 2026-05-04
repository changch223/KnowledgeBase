//
//  MultiPageCrawler.swift
//  KnowledgeTree
//
//  spec 007 — initialURL を起点に pagination を最大 N ページ追跡する actor。
//  各ページの HTML を順次取得し、連結して 1 つの combinedHTML として返す。
//
//  - 1 ページ目: spec 002 既存の retry / charset / HTTPS / 5MB 上限を適用
//  - 2 ページ目以降: 1 回試行のみ、失敗で打ち切り
//  - ページ間 1 秒遅延 (rate limit 配慮)
//  - 訪問済 URL set で循環ループ防止
//  - クロスドメイン拒否 (PaginationDetector で既に判定済だが二重確認)
//

import Foundation

actor MultiPageCrawler {
    enum StopReason: String, Sendable {
        case completed             // 全 pagination 追跡完了 (検出失敗で正常終了)
        case maxPagesReached       // 上限到達
        case loopDetected          // 訪問済 URL 再訪検出
        case crossDomainBlocked    // クロスドメイン拒否
        case fetchFailed           // 2 ページ目以降の fetch 失敗
        case firstPageFailed       // 1 ページ目失敗 (retry 全敗)
    }

    struct CrawlResult: Sendable {
        let firstPageMetadata: MetadataParser.ParsedMetadata?
        let combinedHTML: String?
        let pageCountFetched: Int
        let pageCountSkipped: Int
        let stopReason: StopReason
        let firstPageRetryCount: Int
    }

    enum CrawlError: Error {
        case httpError(Int)
        case tooLarge
        case decodingFailed
        case network(URLError)
        case invalidResponse
    }

    private let session: URLSessionProtocol
    private let userAgent: String
    private let maxPages: Int
    private let delayBetweenPages: Duration
    private let maxDownloadBytes: Int
    private let firstPageRetrySchedule: [Duration]

    init(
        session: URLSessionProtocol,
        userAgent: String,
        maxPages: Int = 5,
        delayBetweenPages: Duration = .seconds(1),
        maxDownloadBytes: Int = 5 * 1024 * 1024,
        firstPageRetrySchedule: [Duration] = [.seconds(30), .seconds(120), .seconds(600)]
    ) {
        self.session = session
        self.userAgent = userAgent
        self.maxPages = maxPages
        self.delayBetweenPages = delayBetweenPages
        self.maxDownloadBytes = maxDownloadBytes
        self.firstPageRetrySchedule = firstPageRetrySchedule
    }

    /// initialURL から始めて pagination を辿り、全ページの HTML を連結して返す。
    /// progressCallback: 各ページ完了 (1 ページ目成功時 含む) で 1 回呼ばれる
    func crawl(
        initialURL: URL,
        progressCallback: (@Sendable (Int) async -> Void)? = nil
    ) async -> CrawlResult {
        var visited: Set<String> = []
        var pageHTMLs: [String] = []
        var pageURLs: [URL] = []
        var firstPageMetadata: MetadataParser.ParsedMetadata?

        // 1 ページ目 fetch (retry 付き)
        var firstRetryCount = 0
        var firstHTML: String?
        for attempt in 0...firstPageRetrySchedule.count {
            if Task.isCancelled {
                return CrawlResult(
                    firstPageMetadata: nil, combinedHTML: nil,
                    pageCountFetched: 0, pageCountSkipped: 0,
                    stopReason: .firstPageFailed, firstPageRetryCount: attempt
                )
            }
            do {
                let html = try await fetch(url: initialURL)
                firstHTML = html
                firstRetryCount = attempt
                break
            } catch {
                firstRetryCount = attempt + 1
                if attempt < firstPageRetrySchedule.count {
                    let wait = firstPageRetrySchedule[attempt]
                    try? await Task.sleep(for: wait)
                    if Task.isCancelled { break }
                }
            }
        }
        guard let html1 = firstHTML else {
            return CrawlResult(
                firstPageMetadata: nil, combinedHTML: nil,
                pageCountFetched: 0, pageCountSkipped: 0,
                stopReason: .firstPageFailed, firstPageRetryCount: firstRetryCount
            )
        }

        pageHTMLs.append(html1)
        pageURLs.append(initialURL)
        visited.insert(initialURL.normalized())
        firstPageMetadata = MetadataParser.parse(html: html1, baseURL: initialURL)
        await progressCallback?(1)

        // 2 ページ目以降のループ
        var stopReason: StopReason = .completed
        while pageHTMLs.count < maxPages {
            if Task.isCancelled { break }
            guard let lastHTML = pageHTMLs.last, let lastURL = pageURLs.last else { break }
            guard let link = PaginationDetector.detect(html: lastHTML, currentURL: lastURL) else {
                stopReason = .completed
                break
            }
            // クロスドメイン (Detector で既に弾いているはずだが二重確認)
            guard URL.sameHost(link.url, initialURL) else {
                stopReason = .crossDomainBlocked
                break
            }
            // 循環チェック
            let normalized = link.url.normalized()
            guard !visited.contains(normalized) else {
                stopReason = .loopDetected
                break
            }

            // ページ間 delay
            try? await Task.sleep(for: delayBetweenPages)
            if Task.isCancelled { break }

            // 2 ページ目以降は 1 回試行のみ
            let nextHTML: String
            do {
                nextHTML = try await fetch(url: link.url)
            } catch {
                stopReason = .fetchFailed
                break
            }

            pageHTMLs.append(nextHTML)
            pageURLs.append(link.url)
            visited.insert(normalized)
            await progressCallback?(pageHTMLs.count)
        }

        if pageHTMLs.count >= maxPages, stopReason == .completed {
            // 上限到達: 次ページがまだあるかを最終ページで確認
            if let lastHTML = pageHTMLs.last, let lastURL = pageURLs.last,
               PaginationDetector.detect(html: lastHTML, currentURL: lastURL) != nil {
                stopReason = .maxPagesReached
            }
        }

        // 連結 HTML 構築 (PageBoundary コメント区切り)
        let combinedHTML = pageHTMLs.enumerated().map { (i, html) in
            "\(html)\n\n<!-- KnowledgeTree.PageBoundary index=\"\(i + 1)\" url=\"\(pageURLs[i].absoluteString)\" -->"
        }.joined(separator: "\n\n")

        // pageCountSkipped: 上限到達なら 1 (次ページ存在のみ確認)、その他理由は 0
        let skipped: Int = stopReason == .maxPagesReached ? 1 : 0

        return CrawlResult(
            firstPageMetadata: firstPageMetadata,
            combinedHTML: combinedHTML,
            pageCountFetched: pageHTMLs.count,
            pageCountSkipped: skipped,
            stopReason: stopReason,
            firstPageRetryCount: firstRetryCount
        )
    }

    // MARK: - Single page fetch (spec 002 既存ロジックを actor 内に移植)

    private func fetch(url: URL) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw CrawlError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw CrawlError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CrawlError.httpError(http.statusCode)
        }
        guard data.count <= maxDownloadBytes else {
            throw CrawlError.tooLarge
        }
        let contentType = http.value(forHTTPHeaderField: "Content-Type")
        guard let html = MetadataParser.decodeHTML(data: data, contentType: contentType) else {
            throw CrawlError.decodingFailed
        }
        return html
    }
}

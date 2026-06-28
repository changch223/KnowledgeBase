//
//  MultiPageCrawlerTests.swift
//  KnowledgeTreeTests
//
//  spec 007 — MultiPageCrawler の各シナリオ (Mock URLSession で URL ごとに異なる HTML を返す)
//

import Testing
import Foundation
@testable import KnowledgeBase

@Suite("MultiPageCrawler")
struct MultiPageCrawlerTests {

    @Test("単一ページ記事は 1 ページのみ取得して .completed")
    func singlePageArticle() async {
        let session = MultiPageMockURLSession(responses: [
            "https://example.com/p1": .success(html: "<title>Article</title><p>Single page.</p>"),
        ])
        let crawler = MultiPageCrawler(
            session: session,
            userAgent: "test",
            maxPages: 5,
            delayBetweenPages: .nanoseconds(1),
            firstPageRetrySchedule: []
        )
        let result = await crawler.crawl(initialURL: URL(string: "https://example.com/p1")!)
        #expect(result.pageCountFetched == 1)
        #expect(result.pageCountSkipped == 0)
        #expect(result.stopReason == .completed)
        #expect(result.firstPageMetadata?.canonicalTitle == "Article")
    }

    @Test("3 ページ記事を全 3 ページ取得して .completed")
    func threePageArticle() async {
        let session = MultiPageMockURLSession(responses: [
            "https://example.com/p1": .success(html: #"<title>Article</title><link rel="next" href="https://example.com/p2">"#),
            "https://example.com/p2": .success(html: #"<link rel="next" href="https://example.com/p3"><p>page 2 content</p>"#),
            "https://example.com/p3": .success(html: "<p>page 3 final content</p>"),
        ])
        let crawler = MultiPageCrawler(
            session: session,
            userAgent: "test",
            maxPages: 5,
            delayBetweenPages: .nanoseconds(1),
            firstPageRetrySchedule: []
        )
        let result = await crawler.crawl(initialURL: URL(string: "https://example.com/p1")!)
        #expect(result.pageCountFetched == 3)
        #expect(result.stopReason == .completed)
        #expect(result.combinedHTML?.contains("page 2 content") == true)
        #expect(result.combinedHTML?.contains("page 3 final content") == true)
        #expect(result.combinedHTML?.contains("KnowledgeTree.PageBoundary") == true)
    }

    @Test("5 ページ上限に到達したら .maxPagesReached")
    func fivePageMaxReached() async {
        let session = MultiPageMockURLSession(responses: [
            "https://example.com/p1": .success(html: #"<link rel="next" href="https://example.com/p2">"#),
            "https://example.com/p2": .success(html: #"<link rel="next" href="https://example.com/p3">"#),
            "https://example.com/p3": .success(html: #"<link rel="next" href="https://example.com/p4">"#),
            "https://example.com/p4": .success(html: #"<link rel="next" href="https://example.com/p5">"#),
            "https://example.com/p5": .success(html: #"<link rel="next" href="https://example.com/p6">"#),  // p6 がまだ存在
        ])
        let crawler = MultiPageCrawler(
            session: session,
            userAgent: "test",
            maxPages: 5,
            delayBetweenPages: .nanoseconds(1),
            firstPageRetrySchedule: []
        )
        let result = await crawler.crawl(initialURL: URL(string: "https://example.com/p1")!)
        #expect(result.pageCountFetched == 5)
        #expect(result.stopReason == .maxPagesReached)
        #expect(result.pageCountSkipped >= 1)
    }

    @Test("循環 pagination で .loopDetected")
    func loopDetected() async {
        let session = MultiPageMockURLSession(responses: [
            "https://example.com/p1": .success(html: #"<link rel="next" href="https://example.com/p2">"#),
            "https://example.com/p2": .success(html: #"<link rel="next" href="https://example.com/p1">"#),  // p1 へループ
        ])
        let crawler = MultiPageCrawler(
            session: session,
            userAgent: "test",
            maxPages: 5,
            delayBetweenPages: .nanoseconds(1),
            firstPageRetrySchedule: []
        )
        let result = await crawler.crawl(initialURL: URL(string: "https://example.com/p1")!)
        #expect(result.pageCountFetched == 2)
        #expect(result.stopReason == .loopDetected)
    }

    @Test("途中 fetch 失敗で .fetchFailed")
    func midFetchFailed() async {
        let session = MultiPageMockURLSession(responses: [
            "https://example.com/p1": .success(html: #"<link rel="next" href="https://example.com/p2">"#),
            "https://example.com/p2": .failure(URLError(.networkConnectionLost)),
        ])
        let crawler = MultiPageCrawler(
            session: session,
            userAgent: "test",
            maxPages: 5,
            delayBetweenPages: .nanoseconds(1),
            firstPageRetrySchedule: []  // 2 ページ目以降は retry なしの仕様
        )
        let result = await crawler.crawl(initialURL: URL(string: "https://example.com/p1")!)
        #expect(result.pageCountFetched == 1)
        #expect(result.stopReason == .fetchFailed)
    }

    @Test("1 ページ目で失敗 (retry なし) → .firstPageFailed")
    func firstPageFailed() async {
        let session = MultiPageMockURLSession(responses: [
            "https://example.com/p1": .failure(URLError(.networkConnectionLost)),
        ])
        let crawler = MultiPageCrawler(
            session: session,
            userAgent: "test",
            maxPages: 5,
            delayBetweenPages: .nanoseconds(1),
            firstPageRetrySchedule: []
        )
        let result = await crawler.crawl(initialURL: URL(string: "https://example.com/p1")!)
        #expect(result.pageCountFetched == 0)
        #expect(result.stopReason == .firstPageFailed)
        #expect(result.firstPageMetadata == nil)
        #expect(result.combinedHTML == nil)
    }

    @Test("各ページ完了で progressCallback 呼ばれる")
    func progressCallbackCalled() async {
        let session = MultiPageMockURLSession(responses: [
            "https://example.com/p1": .success(html: #"<link rel="next" href="https://example.com/p2">"#),
            "https://example.com/p2": .success(html: "<p>final</p>"),
        ])
        let crawler = MultiPageCrawler(
            session: session,
            userAgent: "test",
            maxPages: 5,
            delayBetweenPages: .nanoseconds(1),
            firstPageRetrySchedule: []
        )
        let counter = ProgressCounter()
        _ = await crawler.crawl(initialURL: URL(string: "https://example.com/p1")!) { index in
            await counter.add(index)
        }
        let collected = await counter.indices
        #expect(collected == [1, 2])
    }
}

// MARK: - Mocks

actor ProgressCounter {
    var indices: [Int] = []
    func add(_ i: Int) { indices.append(i) }
}

final class MultiPageMockURLSession: URLSessionProtocol, @unchecked Sendable {
    enum MockResponse {
        case success(html: String, status: Int = 200)
        case failure(Error)
    }

    private let responses: [String: MockResponse]

    init(responses: [String: MockResponse]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url else {
            throw URLError(.badURL)
        }
        let key = url.absoluteString
        guard let resp = responses[key] else {
            throw URLError(.badURL)
        }
        switch resp {
        case .success(let html, let status):
            let data = html.data(using: .utf8) ?? Data()
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (data, response)
        case .failure(let error):
            throw error
        }
    }
}

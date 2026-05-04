//
//  PaginationDetectorTests.swift
//  KnowledgeTreeTests
//
//  spec 007 — PaginationDetector の検出ルール / 拒否条件 / 相対 URL 解決
//

import Testing
import Foundation
@testable import KnowledgeTree

@Suite("PaginationDetector")
struct PaginationDetectorTests {

    private let baseURL = URL(string: "https://example.com/article")!

    @Test("rule 1: link rel=next 検出 (絶対 URL)")
    func detectsLinkRelNext() {
        let html = #"<head><link rel="next" href="https://example.com/article/page2"></head>"#
        let result = PaginationDetector.detect(html: html, currentURL: baseURL)
        #expect(result?.detectedBy == .linkRelNext)
        #expect(result?.url.absoluteString == "https://example.com/article/page2")
    }

    @Test("rule 2: a rel=next 検出")
    func detectsAnchorRelNext() {
        let html = #"<a rel="next" href="https://example.com/p2">次のページ</a>"#
        let result = PaginationDetector.detect(html: html, currentURL: baseURL)
        #expect(result?.detectedBy == .anchorRelNext)
    }

    @Test("rule 3: a class=next 検出 (word boundary)")
    func detectsAnchorClassNext() {
        let html = #"<a class="pagination-next button" href="https://example.com/p2">Next</a>"#
        let result = PaginationDetector.detect(html: html, currentURL: baseURL)
        #expect(result?.detectedBy == .anchorClassNext)
    }

    @Test("rule 3: class=nextstep は word boundary 不一致 (rule 3 で hit しない)")
    func ignoresClassNextstep() {
        let html = #"<a class="nextstep button" href="https://example.com/p2">x</a>"#
        let result = PaginationDetector.detect(html: html, currentURL: baseURL)
        // nextstep には \bnext\b マッチしない (next の後に step が続く)
        // → rule 3 では hit しない。rule 4 (URL パターン) でも /article/page2 ではないので nil
        #expect(result == nil)
    }

    @Test("優先順位: rule 1 が rule 2 より先")
    func priorityRule1OverRule2() {
        let html = """
        <link rel="next" href="https://example.com/link-version">
        <a rel="next" href="https://example.com/anchor-version">x</a>
        """
        let result = PaginationDetector.detect(html: html, currentURL: baseURL)
        #expect(result?.detectedBy == .linkRelNext)
        #expect(result?.url.absoluteString == "https://example.com/link-version")
    }

    @Test("クロスドメイン拒否")
    func rejectsCrossDomain() {
        let html = #"<link rel="next" href="https://other.com/page2">"#
        let result = PaginationDetector.detect(html: html, currentURL: baseURL)
        #expect(result == nil)
    }

    @Test("http 拒否 (https 強制)")
    func rejectsHTTP() {
        let html = #"<link rel="next" href="http://example.com/page2">"#
        let result = PaginationDetector.detect(html: html, currentURL: baseURL)
        #expect(result == nil)
    }

    @Test("自己ループ拒否")
    func rejectsSelfLoop() {
        let html = #"<link rel="next" href="https://example.com/article">"#
        let result = PaginationDetector.detect(html: html, currentURL: baseURL)
        #expect(result == nil)
    }

    @Test("空 href 拒否")
    func rejectsEmptyHref() {
        let html = #"<link rel="next" href="">"#
        let result = PaginationDetector.detect(html: html, currentURL: baseURL)
        #expect(result == nil)
    }

    @Test("javascript: scheme 拒否")
    func rejectsJavascriptScheme() {
        let html = #"<a rel="next" href="javascript:void(0)">x</a>"#
        let result = PaginationDetector.detect(html: html, currentURL: baseURL)
        #expect(result == nil)
    }

    @Test("相対 URL の絶対化")
    func resolvesRelativeURL() {
        let html = #"<link rel="next" href="page2">"#
        let result = PaginationDetector.detect(html: html, currentURL: baseURL)
        #expect(result?.url.absoluteString == "https://example.com/page2")
    }

    @Test("www 違いは同一ホスト扱い")
    func wwwSameHost() {
        let url = URL(string: "https://www.example.com/article")!
        let html = #"<link rel="next" href="https://example.com/page2">"#
        let result = PaginationDetector.detect(html: html, currentURL: url)
        #expect(result?.url.absoluteString == "https://example.com/page2")
    }

    @Test("通常記事 (pagination 無し) は nil")
    func returnsNilWhenNoPagination() {
        let html = "<title>Plain Article</title><p>Content here.</p>"
        let result = PaginationDetector.detect(html: html, currentURL: baseURL)
        #expect(result == nil)
    }

    @Test("rule 4: ?page=1 → ?page=2 候補が a href に存在")
    func detectsURLPatternQueryParam() {
        let url = URL(string: "https://example.com/article?page=1")!
        let html = #"<a href="https://example.com/article?page=2">Next</a>"#
        let result = PaginationDetector.detect(html: html, currentURL: url)
        #expect(result?.detectedBy == .urlPattern)
        #expect(result?.url.absoluteString == "https://example.com/article?page=2")
    }
}

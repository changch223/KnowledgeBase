//
//  MetadataParserTests.swift
//  KnowledgeTreeTests
//
//  spec 002 — contracts/metadata-parser.md Tests 表
//

import Testing
import Foundation
@testable import KnowledgeTree

struct MetadataParserTests {

    private let baseURL = URL(string: "https://example.com/post")!

    @Test func extractsTitleDescriptionAndOGImageFromCompleteHTML() {
        let html = """
        <html><head>
        <title>Sample Title</title>
        <meta name="description" content="Sample description text">
        <meta property="og:image" content="https://example.com/og.jpg">
        </head><body>...</body></html>
        """
        let result = MetadataParser.parse(html: html, baseURL: baseURL)
        #expect(result.canonicalTitle == "Sample Title")
        #expect(result.summary == "Sample description text")
        #expect(result.ogImageURL?.absoluteString == "https://example.com/og.jpg")
    }

    @Test func returnsTitleOnlyWhenDescriptionAndOGImageAbsent() {
        let html = "<html><head><title>Just Title</title></head></html>"
        let result = MetadataParser.parse(html: html, baseURL: baseURL)
        #expect(result.canonicalTitle == "Just Title")
        #expect(result.summary == nil)
        #expect(result.ogImageURL == nil)
    }

    @Test func returnsAllNilForEmptyHTML() {
        let result = MetadataParser.parse(html: "", baseURL: baseURL)
        #expect(result.canonicalTitle == nil)
        #expect(result.summary == nil)
        #expect(result.ogImageURL == nil)
    }

    @Test func decodesHTMLEntitiesInTitle() {
        let html = "<title>Foo &amp; Bar &#39;quoted&#39;</title>"
        let result = MetadataParser.parse(html: html, baseURL: baseURL)
        #expect(result.canonicalTitle == "Foo & Bar 'quoted'")
    }

    @Test func truncatesOverlyLongTitle() {
        let longTitle = String(repeating: "あ", count: 1500)
        let html = "<title>\(longTitle)</title>"
        let result = MetadataParser.parse(html: html, baseURL: baseURL)
        #expect(result.canonicalTitle?.count == 200)
    }

    @Test func resolvesRelativeOGImageWithBaseURL() {
        let html = #"<meta property="og:image" content="/og.jpg">"#
        let result = MetadataParser.parse(html: html, baseURL: baseURL)
        #expect(result.ogImageURL?.absoluteString == "https://example.com/og.jpg")
    }

    @Test func prefersOGImageSecureURL() {
        let html = """
        <meta property="og:image" content="https://insecure.example.com/og.jpg">
        <meta property="og:image:secure_url" content="https://secure.example.com/og.jpg">
        """
        let result = MetadataParser.parse(html: html, baseURL: baseURL)
        #expect(result.ogImageURL?.absoluteString == "https://secure.example.com/og.jpg")
    }

    @Test func promotesHTTPOGImageToHTTPS() {
        let html = #"<meta property="og:image" content="http://example.com/og.jpg">"#
        let result = MetadataParser.parse(html: html, baseURL: baseURL)
        #expect(result.ogImageURL?.scheme == "https")
        #expect(result.ogImageURL?.host == "example.com")
    }

    @Test func extractsBestEffortFromBrokenHTML() {
        let html = "<title>Truncated"
        let result = MetadataParser.parse(html: html, baseURL: baseURL)
        // closing tag が無いため title 抽出失敗 (nil でも OK)
        #expect(result.canonicalTitle == nil || result.canonicalTitle == "Truncated")
    }

    @Test func fallsBackToOGDescriptionWhenMetaDescriptionAbsent() {
        let html = #"<meta property="og:description" content="OG description">"#
        let result = MetadataParser.parse(html: html, baseURL: baseURL)
        #expect(result.summary == "OG description")
    }

    @Test func extractsCaseInsensitiveMETATag() {
        let html = #"<META NAME="DESCRIPTION" CONTENT="upper case">"#
        let result = MetadataParser.parse(html: html, baseURL: baseURL)
        #expect(result.summary == "upper case")
    }

    @Test func extractsSingleQuotedMetaContent() {
        let html = "<meta name='description' content='single quoted'>"
        let result = MetadataParser.parse(html: html, baseURL: baseURL)
        #expect(result.summary == "single quoted")
    }

    @Test func usesFirstWhenMultipleDescriptionsExist() {
        let html = """
        <meta name="description" content="first">
        <meta name="description" content="second">
        """
        let result = MetadataParser.parse(html: html, baseURL: baseURL)
        #expect(result.summary == "first")
    }
}

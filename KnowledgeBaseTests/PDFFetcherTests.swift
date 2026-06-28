//
//  PDFFetcherTests.swift
//  KnowledgeTreeTests
//
//  spec 034 — PDFFetcher 5 ケース。
//  in-memory PDF data を programmatic に生成して parse 動作を検証。
//

import Testing
import Foundation
import PDFKit
import UIKit
@testable import KnowledgeBase

struct PDFFetcherTests {

    // MARK: - Helpers

    /// PDF data を programmatic に生成 (UIGraphicsPDFRenderer で metadata + 本文を描画)。
    /// title / author / subject は CGPDFContext キー経由で設定、PDFKit 読み込み時に
    /// documentAttributes に反映される。
    private static func makePDFData(
        title: String? = nil,
        author: String? = nil,
        subject: String? = nil,
        body: String,
        pageCount: Int = 1
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let format = UIGraphicsPDFRendererFormat()
        var docInfo: [String: Any] = [:]
        if let title { docInfo[kCGPDFContextTitle as String] = title }
        if let author { docInfo[kCGPDFContextAuthor as String] = author }
        if let subject { docInfo[kCGPDFContextSubject as String] = subject }
        format.documentInfo = docInfo

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        return renderer.pdfData { context in
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14)
            ]
            for i in 0..<pageCount {
                context.beginPage()
                let pageContent = pageCount == 1 ? body : "\(body) [page \(i + 1)]"
                let attributedString = NSAttributedString(string: pageContent, attributes: attributes)
                attributedString.draw(in: pageRect.insetBy(dx: 50, dy: 50))
            }
        }
    }

    private static let sourceURL = URL(string: "https://example.com/papers/research-2024.pdf")!

    // MARK: - 1. internal title metadata 優先

    @Test func testParseUsesInternalTitleMetadata() {
        let data = Self.makePDFData(
            title: "PDF 内部 Title",
            body: "本文のテキスト"
        )
        let parsed = PDFFetcher.parse(data: data, sourceURL: Self.sourceURL)
        #expect(parsed != nil)
        #expect(parsed?.title == "PDF 内部 Title")
    }

    // MARK: - 2. internal title 無しの場合は filename から推測

    @Test func testParseFallsBackToFilenameWhenNoTitleMetadata() {
        let data = Self.makePDFData(body: "本文のテキスト")
        let parsed = PDFFetcher.parse(data: data, sourceURL: Self.sourceURL)
        // "research-2024.pdf" → "research 2024"
        #expect(parsed?.title == "research 2024")
    }

    // MARK: - 3. subject metadata は summary になる

    @Test func testParseUsesSubjectAsSummary() {
        let data = Self.makePDFData(
            title: "Title",
            subject: "これは論文の概要です",
            body: "本文..."
        )
        let parsed = PDFFetcher.parse(data: data, sourceURL: Self.sourceURL)
        #expect(parsed?.summary == "これは論文の概要です")
    }

    // MARK: - 4. subject 無しの場合は本文冒頭 200 字

    @Test func testParseFallsBackToBodyExcerptForSummary() {
        let bodyLong = String(repeating: "本文の段落が続きます。", count: 50)
        let data = Self.makePDFData(title: "Title", body: bodyLong)
        let parsed = PDFFetcher.parse(data: data, sourceURL: Self.sourceURL)
        let summary = parsed?.summary ?? ""
        #expect(!summary.isEmpty)
        #expect(summary.count <= 200)
        #expect(summary.contains("本文の段落"))
    }

    // MARK: - 5. pseudoHTML が <article> 経路で extractable

    @Test func testPseudoHTMLContainsArticleTagAndBody() {
        let data = Self.makePDFData(
            title: "Title",
            body: "段落 1 のテキスト。十分な文字数を含む段落です。これは本文抽出のテストフィクスチャです。"
        )
        let parsed = PDFFetcher.parse(data: data, sourceURL: Self.sourceURL)
        let html = parsed?.pseudoHTML ?? ""
        #expect(html.contains("<article>"))
        #expect(html.contains("</article>"))
        #expect(html.contains("<title>Title</title>"))
        #expect(html.contains("段落 1 のテキスト"))
    }

    // MARK: - 6. titleFromFilename — 各種フォーマット

    @Test func testTitleFromFilenameDecodesHyphensAndUnderscores() {
        let url1 = URL(string: "https://example.com/foo/my-paper-2024.pdf")!
        #expect(PDFFetcher.titleFromFilename(url: url1) == "my paper 2024")

        let url2 = URL(string: "https://example.com/research_notes_v2.pdf")!
        #expect(PDFFetcher.titleFromFilename(url: url2) == "research notes v2")
    }

    @Test func testTitleFromFilenameHandlesPercentEncoding() {
        // "%E8%AB%96%E6%96%87.pdf" = "論文.pdf"
        let url = URL(string: "https://example.com/%E8%AB%96%E6%96%87.pdf")!
        #expect(PDFFetcher.titleFromFilename(url: url) == "論文")
    }

    // MARK: - 7. isPDF — Content-Type / extension 判定

    @Test func testIsPDFDetectsContentType() {
        let url = URL(string: "https://example.com/dynamic")!
        #expect(PDFFetcher.isPDF(contentType: "application/pdf", url: url))
        #expect(PDFFetcher.isPDF(contentType: "application/pdf; charset=binary", url: url))
        #expect(!PDFFetcher.isPDF(contentType: "text/html", url: url))
    }

    @Test func testIsPDFDetectsURLExtension() {
        let pdfURL = URL(string: "https://example.com/papers/foo.pdf")!
        #expect(PDFFetcher.isPDF(contentType: nil, url: pdfURL))
        #expect(PDFFetcher.isPDF(contentType: "text/html", url: pdfURL))  // URL 優先

        let htmlURL = URL(string: "https://example.com/article")!
        #expect(!PDFFetcher.isPDF(contentType: nil, url: htmlURL))
    }

    // MARK: - 8. 不正な data → nil

    @Test func testParseReturnsNilForInvalidData() {
        let bogus = Data("not a pdf".utf8)
        let parsed = PDFFetcher.parse(data: bogus, sourceURL: Self.sourceURL)
        #expect(parsed == nil)
    }
}

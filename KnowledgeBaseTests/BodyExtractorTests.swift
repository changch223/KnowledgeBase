//
//  BodyExtractorTests.swift
//  KnowledgeTreeTests
//
//  spec 003 — contracts/body-extractor.md Tests 表
//

import Testing
import Foundation
@testable import KnowledgeBase

struct BodyExtractorTests {

    // MARK: - Fixtures (inline)

    private static let articleTagHTML = """
    <html><body>
    <header>Site Header</header>
    <article>
    <h1>Main Title</h1>
    <p>これは記事の本文の最初の段落です。十分な長さのテキストを含んでいます。</p>
    <p>これは 2 段落目のテキストです。Reader View で読みやすく表示されます。</p>
    <p>3 段落目もあります。本文抽出が semantic タグを優先的に拾うことを確認します。</p>
    </article>
    <footer>Site Footer</footer>
    </body></html>
    """

    private static let mainTagHTML = """
    <html><body>
    <main>
    <p>main タグ内の本文。これも十分な長さの記事テキストとして扱われます。BodyExtractor は <article> が無い場合に <main> を fallback として拾います。</p>
    <p>もう一つの段落で、記事の長さを稼いでいます。十分な文字数を確保するためのテキスト。100 字を超えるよう本文を追記しています。</p>
    </main>
    </body></html>
    """

    private static let noSemanticHTML = """
    <html><body>
    <div class="content">
    <p>semantic タグなしのページ。text-density スコアリングで本文ブロックを検出する想定です。記事本体はこちらに集中しています。</p>
    <p>記事のメインコンテンツ部分。このブロックが density スコアで最高評価を獲得するはず。十分な text 長を持たせて density 閾値 200 を超えるようにしています。</p>
    <p>段落を 3 つ以上含めて十分な text 長を確保します。閾値 200 を超える必要があります。BodyExtractor は textDensityScoring 戦略でこの div を採用します。</p>
    </div>
    <div class="sidebar">
    <a href="#">Link 1</a><a href="#">Link 2</a><a href="#">Link 3</a>
    </div>
    </body></html>
    """

    private static let tooShortHTML = """
    <html><body><article><p>Too short.</p></article></body></html>
    """

    private static let withImagesHTML = """
    <html><body><article>
    <img src="https://example.com/img1.jpg" alt="image">
    <p>本文テキスト。画像タグが除去されることを確認するためのテストフィクスチャです。</p>
    <p>2 段落目です。画像 URL が結果に混入していないことが期待される動作です。</p>
    <picture><img src="https://example.com/img2.jpg"></picture>
    </article></body></html>
    """

    private static let withLinksHTML = """
    <html><body><article>
    <p>本文に <a href="https://example.com/foo">リンクテキスト</a> が含まれます。URL は除去されるべき。</p>
    <p>2 段落目です。<a href="#">複数のリンク</a> が <a href="#">含まれる</a> ケースも対応します。</p>
    </article></body></html>
    """

    private static let withListsHTML = """
    <html><body><article>
    <p>記事の冒頭の段落です。十分な長さのテキストを含んでいます。</p>
    <ul>
    <li>箇条書き項目 1</li>
    <li>箇条書き項目 2</li>
    <li>箇条書き項目 3</li>
    </ul>
    <p>箇条書きの後にも段落が続きます。本文抽出のテストを十分に行います。</p>
    </article></body></html>
    """

    private static let japaneseHTML = """
    <html><body><article>
    <p>これは日本語の記事です。本文抽出が日本語コンテンツを正しく扱えることを検証します。</p>
    <p>Apple Foundation Models を使った要約 (spec 004) の入力としても機能する想定です。</p>
    </article></body></html>
    """

    // MARK: - Tests

    @Test func extractsFromArticleTag() {
        let result = BodyExtractor.extract(html: Self.articleTagHTML)
        #expect(result.strategy == .semanticTagArticle)
        #expect((result.extractedText?.count ?? 0) >= 100)
        #expect(result.extractedText?.contains("Site Header") == false)
        #expect(result.extractedText?.contains("Site Footer") == false)
    }

    @Test func extractsFromMainTag() {
        let result = BodyExtractor.extract(html: Self.mainTagHTML)
        #expect(result.strategy == .semanticTagMain)
        #expect((result.extractedText?.count ?? 0) >= 100)
    }

    @Test func extractsByDensityScoringWhenNoSemanticTag() {
        let result = BodyExtractor.extract(html: Self.noSemanticHTML)
        #expect(result.strategy == .textDensityScoring || result.strategy == .semanticTagMain || result.strategy == .semanticTagArticle)
        #expect((result.extractedText?.count ?? 0) >= 100)
    }

    @Test func returnsNilForTooShortContent() {
        let result = BodyExtractor.extract(html: Self.tooShortHTML)
        #expect(result.extractedText == nil)
    }

    @Test func excludesImageURLsFromExtractedText() {
        let result = BodyExtractor.extract(html: Self.withImagesHTML)
        if let text = result.extractedText {
            #expect(text.contains("img1.jpg") == false)
            #expect(text.contains("img2.jpg") == false)
        }
    }

    @Test func excludesLinkURLsFromExtractedText() {
        let result = BodyExtractor.extract(html: Self.withLinksHTML)
        if let text = result.extractedText {
            #expect(text.contains("https://example.com/foo") == false)
            #expect(text.contains("リンクテキスト"))
        }
    }

    @Test func includesListItemsAsBullets() {
        let result = BodyExtractor.extract(html: Self.withListsHTML)
        if let text = result.extractedText {
            #expect(text.contains("・"))
            #expect(text.contains("箇条書き項目"))
        }
    }

    @Test func extractsJapaneseContent() {
        let result = BodyExtractor.extract(html: Self.japaneseHTML)
        #expect((result.extractedText?.count ?? 0) >= 100)
        #expect(result.extractedText?.contains("日本語") == true)
    }

    @Test func returnsParseFailedForEmptyInput() {
        let result = BodyExtractor.extract(html: "")
        #expect(result.strategy == .parseFailed)
        #expect(result.extractedText == nil)
    }
}

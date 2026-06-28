//
//  PDFFetcher.swift
//  KnowledgeTree
//
//  spec 034 — PDF サポート (2026-05-06)
//
//  Content-Type "application/pdf" の URL を fetch した時、PDFKit で内部 metadata
//  (Title / Subject / Author) と全 page テキストを抽出し、擬似 HTML に整形する。
//  整形後の HTML は既存 MultiPageCrawler / MetadataParser / BodyExtractor /
//  KnowledgeExtractor のフローに乗るため、AI Auto-Tag / KeyFact / entities /
//  AI Chat retrieval すべてが PDF でも動作する。
//

import Foundation
import PDFKit

struct PDFFetcher {

    struct ParsedPDF: Equatable {
        let title: String
        let summary: String?
        let author: String?
        /// 既存 MetadataParser / BodyExtractor が parse できる擬似 HTML。
        /// `<title>` `<meta name="description">` `<article>` `<p>` を含む。
        let pseudoHTML: String
        let pageCount: Int
        /// spec 091: 全ページ連結のプレーンテキスト。
        /// RawArticleIntake で `ArticleBody.extractedText` に直接投入する用途。
        var fullText: String = ""
    }

    /// PDF data → 擬似 HTML + metadata。decode 失敗時は nil。
    static func parse(data: Data, sourceURL: URL) -> ParsedPDF? {
        guard let document = PDFDocument(data: data) else { return nil }

        let attrs = document.documentAttributes

        // Title: PDF 内部 metadata 優先、なければ URL filename から推測
        let internalTitle = (attrs?[PDFDocumentAttribute.titleAttribute] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title: String = (internalTitle?.isEmpty == false ? internalTitle : nil)
            ?? titleFromFilename(url: sourceURL)

        // 全ページテキスト連結
        var pageTexts: [String] = []
        for i in 0..<document.pageCount {
            if let pageText = document.page(at: i)?.string?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !pageText.isEmpty {
                pageTexts.append(pageText)
            }
        }
        let fullText = pageTexts.joined(separator: "\n\n")

        // Summary: PDF Subject metadata 優先、なければ冒頭 200 字
        let internalSubject = (attrs?[PDFDocumentAttribute.subjectAttribute] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let summary: String? = {
            if let s = internalSubject, !s.isEmpty { return s }
            let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return String(trimmed.prefix(200))
        }()

        let author = (attrs?[PDFDocumentAttribute.authorAttribute] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 擬似 HTML: <article> + <p> 段落列 → BodyExtractor の semanticTagArticle 経路に乗る
        let paragraphs = fullText
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let paragraphsHTML = paragraphs
            .map { "<p>\(escapeHTML($0))</p>" }
            .joined(separator: "\n")

        var headExtras = ""
        if let summary, !summary.isEmpty {
            headExtras += "<meta name=\"description\" content=\"\(escapeHTML(summary))\">"
        }
        if let author, !author.isEmpty {
            headExtras += "<meta name=\"author\" content=\"\(escapeHTML(author))\">"
        }

        let pseudoHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>\(escapeHTML(title))</title>
        \(headExtras)
        </head>
        <body>
        <article>
        <h1>\(escapeHTML(title))</h1>
        \(paragraphsHTML)
        </article>
        </body>
        </html>
        """

        return ParsedPDF(
            title: title,
            summary: summary,
            author: author,
            pseudoHTML: pseudoHTML,
            pageCount: document.pageCount,
            fullText: fullText
        )
    }

    /// URL filename から人間可読な title を推測。
    /// 例: "https://example.com/papers/research-2024.pdf" → "research 2024"
    static func titleFromFilename(url: URL) -> String {
        let filename = url.lastPathComponent
        let base = (filename as NSString).deletingPathExtension
        let decoded = base.removingPercentEncoding ?? base
        let humanized = decoded
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return humanized.isEmpty ? filename : humanized
    }

    /// URL / Content-Type が PDF を示すか判定。
    static func isPDF(contentType: String?, url: URL) -> Bool {
        if let ct = contentType?.lowercased(), ct.contains("application/pdf") {
            return true
        }
        if url.pathExtension.lowercased() == "pdf" {
            return true
        }
        return false
    }

    private static func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

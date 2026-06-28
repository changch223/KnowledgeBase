//
//  BodyExtractor.swift
//  KnowledgeTree
//
//  spec 003 — contracts/body-extractor.md
//  Foundation 標準のみ、サードパーティ禁止 (Constitution Additional Constraints)
//

import Foundation

struct BodyExtractor {
    struct ParsedBody: Equatable, Sendable {
        let extractedText: String?
        let strategy: ExtractionStrategy
    }

    enum ExtractionStrategy: String, Sendable {
        case semanticTagArticle
        case semanticTagMain
        case textDensityScoring
        case noBodyFound
        case parseFailed
    }

    /// 100 文字以上の本文が抽出できれば extractedText に設定。それ未満は nil を返却。
    static func extract(html: String) -> ParsedBody {
        guard !html.isEmpty else {
            return ParsedBody(extractedText: nil, strategy: .parseFailed)
        }

        // 1. <article>
        if let block = extractTagContent(html, tagName: "article") {
            let text = htmlToText(block)
            if text.count >= 100 {
                return ParsedBody(extractedText: text, strategy: .semanticTagArticle)
            }
        }

        // 2. <main>
        if let block = extractTagContent(html, tagName: "main") {
            let text = htmlToText(block)
            if text.count >= 100 {
                return ParsedBody(extractedText: text, strategy: .semanticTagMain)
            }
        }

        // 3. role="main"
        if let block = extractRoleMain(html) {
            let text = htmlToText(block)
            if text.count >= 100 {
                return ParsedBody(extractedText: text, strategy: .semanticTagMain)
            }
        }

        // 4. text-density スコアリング fallback
        if let block = extractByDensity(html) {
            let text = htmlToText(block)
            if text.count >= 100 {
                return ParsedBody(extractedText: text, strategy: .textDensityScoring)
            }
        }

        return ParsedBody(extractedText: nil, strategy: .noBodyFound)
    }

    // MARK: - Block extraction

    private static func extractTagContent(_ html: String, tagName: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: tagName)
        let pattern = #"<"# + escaped + #"[^>]*>([\s\S]*?)</"# + escaped + #">"#
        return firstCapture(in: html, pattern: pattern)
    }

    private static func extractRoleMain(_ html: String) -> String? {
        let pattern = #"<(?:div|section)[^>]*role\s*=\s*["']main["'][^>]*>([\s\S]*?)</(?:div|section)>"#
        return firstCapture(in: html, pattern: pattern)
    }

    /// 簡易 text-density スコアリング: 最も text-rich な <div> / <section> を採用
    private static func extractByDensity(_ html: String) -> String? {
        let pattern = #"<(div|section)[^>]*>([\s\S]*?)</\1>"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: range)

        var best: (text: String, score: Double)?
        for match in matches {
            guard let captureRange = Range(match.range(at: 2), in: html) else { continue }
            let content = String(html[captureRange])
            let textLen = htmlToText(content).count
            let tagCount = content.split(separator: "<").count
            let linkLen = totalLinkTextLength(content)
            let score = Double(textLen) - Double(linkLen) * 2.0 - Double(tagCount) * 5.0
            if score > 200, best == nil || score > best!.score {
                best = (content, score)
            }
        }
        return best?.text
    }

    private static func totalLinkTextLength(_ html: String) -> Int {
        let pattern = #"<a[^>]*>([\s\S]*?)</a>"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return 0 }
        let range = NSRange(html.startIndex..., in: html)
        var total = 0
        for match in regex.matches(in: html, options: [], range: range) {
            guard let r = Range(match.range(at: 1), in: html) else { continue }
            total += htmlToText(String(html[r])).count
        }
        return total
    }

    private static func firstCapture(in html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[captureRange])
    }

    // MARK: - HTML → plain text

    private static func htmlToText(_ html: String) -> String {
        var text = html

        // boilerplate (script/style/nav/aside/footer/header/form/noscript) を完全除去
        let boilerplate = ["script", "style", "nav", "aside", "footer", "header", "form", "noscript"]
        for tag in boilerplate {
            let pattern = #"<"# + tag + #"[^>]*>[\s\S]*?</"# + tag + #">"#
            text = text.replacingOccurrences(
                of: pattern, with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        // メディアタグ完全除去 (FR-009)
        let media = ["img", "video", "iframe", "picture", "canvas", "source", "embed", "object"]
        for tag in media {
            let selfClosing = #"<"# + tag + #"[^>]*/?>"#
            text = text.replacingOccurrences(
                of: selfClosing, with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
            let withClose = #"<"# + tag + #"[^>]*>[\s\S]*?</"# + tag + #">"#
            text = text.replacingOccurrences(
                of: withClose, with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        // ブロック要素の閉じタグ → 段落区切り
        text = text.replacingOccurrences(
            of: #"</(?:p|div|h[1-6]|li|blockquote|pre|tr|table|section|article)\s*>"#,
            with: "\n\n",
            options: [.regularExpression, .caseInsensitive]
        )
        text = text.replacingOccurrences(
            of: #"<br\s*/?>"#, with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )
        text = text.replacingOccurrences(
            of: #"<li[^>]*>"#, with: "・",
            options: [.regularExpression, .caseInsensitive]
        )
        text = text.replacingOccurrences(
            of: #"<td[^>]*>"#, with: "\t",
            options: [.regularExpression, .caseInsensitive]
        )
        text = text.replacingOccurrences(
            of: #"<blockquote[^>]*>"#, with: "> ",
            options: [.regularExpression, .caseInsensitive]
        )

        // <a href="...">text</a> → text のみ (URL を捨てる、研究 R2)
        text = text.replacingOccurrences(
            of: #"<a[^>]*>"#, with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // 残り全タグを除去
        text = text.replacingOccurrences(
            of: #"<[^>]+>"#, with: "",
            options: [.regularExpression]
        )

        // HTML エンティティ decode
        text = decodeEntities(text)

        // 空白 / 改行を正規化
        text = text.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\n[ \t]+"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }

    private static func decodeEntities(_ s: String) -> String {
        var r = s
        r = r.replacingOccurrences(of: "&amp;", with: "&")
        r = r.replacingOccurrences(of: "&lt;", with: "<")
        r = r.replacingOccurrences(of: "&gt;", with: ">")
        r = r.replacingOccurrences(of: "&quot;", with: "\"")
        r = r.replacingOccurrences(of: "&apos;", with: "'")
        r = r.replacingOccurrences(of: "&#39;", with: "'")
        r = r.replacingOccurrences(of: "&nbsp;", with: " ")
        return r
    }
}

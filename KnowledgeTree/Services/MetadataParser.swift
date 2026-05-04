//
//  MetadataParser.swift
//  KnowledgeTree
//
//  spec 002 — contracts/metadata-parser.md
//  + encoding 検出 (Shift-JIS / EUC-JP / ISO-2022-JP / UTF-8 自動)
//

import Foundation

struct MetadataParser {
    struct ParsedMetadata: Equatable, Sendable {
        let canonicalTitle: String?
        let summary: String?
        let ogImageURL: URL?
    }

    /// HTTP response の Data から HTML 文字列を encoding 自動検出でデコードする。
    /// 検出順: HTTP `Content-Type: charset=xxx` → HTML `<meta charset="xxx">` →
    ///        HTML `<meta http-equiv="Content-Type" content="...; charset=xxx">` →
    ///        UTF-8 fallback。
    static func decodeHTML(data: Data, contentType: String?) -> String? {
        // 1. HTTP Content-Type ヘッダから charset
        if let ct = contentType, let charset = extractCharsetFromContentType(ct),
           let encoding = stringEncoding(forCharsetName: charset),
           let html = String(data: data, encoding: encoding) {
            return html
        }

        // 2. HTML 先頭 4KB を ASCII で読んで <meta charset> を探す
        let prefixData = data.prefix(4096)
        if let asciiHead = String(data: prefixData, encoding: .ascii)
            ?? String(data: prefixData, encoding: .isoLatin1) {
            if let charset = extractCharsetFromHTML(asciiHead),
               let encoding = stringEncoding(forCharsetName: charset),
               let html = String(data: data, encoding: encoding) {
                return html
            }
        }

        // 3. UTF-8 fallback (大半の現代サイト)
        if let html = String(data: data, encoding: .utf8) {
            return html
        }

        // 4. 最終 fallback: Shift-JIS (日本語サイトに多い) → EUC-JP
        if let html = String(data: data, encoding: .shiftJIS) {
            return html
        }
        if let html = String(data: data, encoding: .japaneseEUC) {
            return html
        }
        return nil
    }

    static func parse(html: String, baseURL: URL?) -> ParsedMetadata {
        let title = extractTitle(html)
        let summary = extractDescription(html) ?? extractOGDescription(html)
        let ogImage = extractOGImage(html, baseURL: baseURL)
        return ParsedMetadata(canonicalTitle: title, summary: summary, ogImageURL: ogImage)
    }

    // MARK: - Charset detection

    private static func extractCharsetFromContentType(_ ct: String) -> String? {
        // 例: "text/html; charset=Shift_JIS"
        guard let range = ct.range(of: #"charset\s*=\s*([A-Za-z0-9_\-\.]+)"#,
                                    options: [.regularExpression, .caseInsensitive])
        else { return nil }
        let matched = String(ct[range])
        guard let eq = matched.firstIndex(of: "=") else { return nil }
        let value = matched[matched.index(after: eq)...].trimmingCharacters(in: .whitespaces)
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    private static func extractCharsetFromHTML(_ html: String) -> String? {
        // <meta charset="..."> 形式
        if let captured = firstCapture(in: html,
            pattern: #"<meta[^>]*charset\s*=\s*["']?([A-Za-z0-9_\-\.]+)"#) {
            return captured
        }
        // <meta http-equiv="Content-Type" content="...; charset=..."> 形式
        if let captured = firstCapture(in: html,
            pattern: #"<meta[^>]*http-equiv\s*=\s*["']content-type["'][^>]*content\s*=\s*["'][^"']*charset\s*=\s*([A-Za-z0-9_\-\.]+)"#) {
            return captured
        }
        return nil
    }

    private static func stringEncoding(forCharsetName name: String) -> String.Encoding? {
        let normalized = name.lowercased().replacingOccurrences(of: "_", with: "-")
        switch normalized {
        case "utf-8", "utf8":
            return .utf8
        case "shift-jis", "shift-jis", "shift_jis", "shift-jis", "x-sjis", "sjis", "ms_kanji", "windows-31j", "cp932":
            return .shiftJIS
        case "euc-jp", "eucjp", "x-euc-jp", "x-euc":
            return .japaneseEUC
        case "iso-2022-jp", "iso2022-jp", "csiso2022jp":
            return .iso2022JP
        case "iso-8859-1", "iso8859-1", "latin1":
            return .isoLatin1
        case "windows-1252", "cp1252":
            return .windowsCP1252
        case "us-ascii", "ascii":
            return .ascii
        default:
            // CFString に問い合わせる fallback
            let cfName = name as CFString
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(cfName)
            if cfEncoding != kCFStringEncodingInvalidId {
                let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
                return String.Encoding(rawValue: nsEncoding)
            }
            return nil
        }
    }

    // MARK: - Title

    private static func extractTitle(_ html: String) -> String? {
        guard let raw = firstCapture(in: html, pattern: #"<title[^>]*>([\s\S]*?)</title>"#) else {
            return nil
        }
        return trimmedString(raw, max: 200)
    }

    // MARK: - Description

    private static func extractDescription(_ html: String) -> String? {
        guard let raw = extractMetaContent(html, attrName: "name", attrValue: "description") else {
            return nil
        }
        return trimmedString(raw, max: 300)
    }

    private static func extractOGDescription(_ html: String) -> String? {
        guard let raw = extractMetaContent(html, attrName: "property", attrValue: "og:description") else {
            return nil
        }
        return trimmedString(raw, max: 300)
    }

    // MARK: - OG Image

    private static func extractOGImage(_ html: String, baseURL: URL?) -> URL? {
        let secure = extractMetaContent(html, attrName: "property", attrValue: "og:image:secure_url")
        let image = extractMetaContent(html, attrName: "property", attrValue: "og:image")
        guard let raw = secure ?? image, !raw.isEmpty else { return nil }

        let absolute: URL?
        if let parsed = URL(string: raw), parsed.scheme != nil {
            absolute = parsed
        } else if let baseURL {
            absolute = URL(string: raw, relativeTo: baseURL)?.absoluteURL
        } else {
            absolute = nil
        }

        guard var finalURL = absolute else { return nil }
        if finalURL.scheme == "http" {
            var components = URLComponents(url: finalURL, resolvingAgainstBaseURL: false)
            components?.scheme = "https"
            if let promoted = components?.url {
                finalURL = promoted
            }
        }
        return finalURL.scheme == "https" ? finalURL : nil
    }

    // MARK: - Helpers

    private static func extractMetaContent(_ html: String, attrName: String, attrValue: String) -> String? {
        let escAttr = NSRegularExpression.escapedPattern(for: attrName)
        let escValue = NSRegularExpression.escapedPattern(for: attrValue)
        let pattern1 = #"<meta\s+[^>]*"# + escAttr + #"\s*=\s*["']"# + escValue + #"["'][^>]*content\s*=\s*["']([^"']*)["']"#
        if let captured = firstCapture(in: html, pattern: pattern1) { return captured }
        let pattern2 = #"<meta\s+[^>]*content\s*=\s*["']([^"']*)["'][^>]*"# + escAttr + #"\s*=\s*["']"# + escValue + #"["']"#
        return firstCapture(in: html, pattern: pattern2)
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

    private static func trimmedString(_ s: String, max: Int) -> String? {
        let decoded = decodeHTMLEntities(s).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !decoded.isEmpty else { return nil }
        return String(decoded.prefix(max))
    }

    private static func decodeHTMLEntities(_ s: String) -> String {
        var r = s
        r = r.replacingOccurrences(of: "&amp;", with: "&")
        r = r.replacingOccurrences(of: "&lt;", with: "<")
        r = r.replacingOccurrences(of: "&gt;", with: ">")
        r = r.replacingOccurrences(of: "&quot;", with: "\"")
        r = r.replacingOccurrences(of: "&#34;", with: "\"")
        r = r.replacingOccurrences(of: "&apos;", with: "'")
        r = r.replacingOccurrences(of: "&#39;", with: "'")
        r = r.replacingOccurrences(of: "&nbsp;", with: " ")
        return decodeNumericEntities(r)
    }

    private static func decodeNumericEntities(_ s: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"&#(x[0-9a-fA-F]+|[0-9]+);"#,
            options: []
        ) else { return s }
        let mutable = NSMutableString(string: s)
        let range = NSRange(location: 0, length: mutable.length)
        let matches = regex.matches(in: s, options: [], range: range).reversed()
        for match in matches {
            guard let codeRange = Range(match.range(at: 1), in: s) else { continue }
            let codeStr = String(s[codeRange])
            let code: Int?
            if codeStr.hasPrefix("x") || codeStr.hasPrefix("X") {
                code = Int(codeStr.dropFirst(), radix: 16)
            } else {
                code = Int(codeStr)
            }
            if let code, let scalar = Unicode.Scalar(code) {
                mutable.replaceCharacters(in: match.range, with: String(Character(scalar)))
            }
        }
        return mutable as String
    }
}

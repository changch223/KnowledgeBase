//
//  PaginationDetector.swift
//  KnowledgeTree
//
//  spec 007 — HTML 内の「次のページ」候補を 1 つだけ検出する純粋関数。
//  検出ルール優先順位 (research.md R1):
//    1. <link rel="next" href="...">
//    2. <a rel="next" href="...">
//    3. <a class="...next..." href="..."> (word boundary 一致、大文字小文字無視)
//    4. URL パターン推測 (?page=N+1, /page/N+1, &page=N+1, /?p=N+1)
//
//  クロスドメイン拒否 / 自己ループ拒否 / 相対 URL 解決はここで実施。
//  https 以外は拒否 (spec 002 の制約継承)。
//

import Foundation

struct PaginationLink: Equatable, Sendable {
    let url: URL
    let detectedBy: DetectionRule
}

enum DetectionRule: String, Sendable {
    case linkRelNext
    case anchorRelNext
    case anchorClassNext
    case urlPattern
}

enum PaginationDetector {
    /// HTML 内の pagination 候補を検出して 1 件返す。検出失敗 / 拒否時は nil。
    static func detect(html: String, currentURL: URL) -> PaginationLink? {
        // Rule 1: <link rel="next">
        if let url = matchLinkRelNext(html: html, currentURL: currentURL) {
            return PaginationLink(url: url, detectedBy: .linkRelNext)
        }
        // Rule 2: <a rel="next">
        if let url = matchAnchorRelNext(html: html, currentURL: currentURL) {
            return PaginationLink(url: url, detectedBy: .anchorRelNext)
        }
        // Rule 3: <a class="next">
        if let url = matchAnchorClassNext(html: html, currentURL: currentURL) {
            return PaginationLink(url: url, detectedBy: .anchorClassNext)
        }
        // Rule 4: URL パターン推測
        if let url = matchURLPattern(html: html, currentURL: currentURL) {
            return PaginationLink(url: url, detectedBy: .urlPattern)
        }
        return nil
    }

    // MARK: - Rule 1

    private static func matchLinkRelNext(html: String, currentURL: URL) -> URL? {
        let patterns = [
            #"<link\s+[^>]*rel\s*=\s*["']next["'][^>]*href\s*=\s*["']([^"']+)["'][^>]*>"#,
            #"<link\s+[^>]*href\s*=\s*["']([^"']+)["'][^>]*rel\s*=\s*["']next["'][^>]*>"#
        ]
        for pattern in patterns {
            if let raw = firstCapture(html, pattern: pattern), let url = resolve(raw, base: currentURL) {
                return url
            }
        }
        return nil
    }

    // MARK: - Rule 2

    private static func matchAnchorRelNext(html: String, currentURL: URL) -> URL? {
        let patterns = [
            #"<a\s+[^>]*rel\s*=\s*["']next["'][^>]*href\s*=\s*["']([^"']+)["'][^>]*>"#,
            #"<a\s+[^>]*href\s*=\s*["']([^"']+)["'][^>]*rel\s*=\s*["']next["'][^>]*>"#
        ]
        for pattern in patterns {
            if let raw = firstCapture(html, pattern: pattern), let url = resolve(raw, base: currentURL) {
                return url
            }
        }
        return nil
    }

    // MARK: - Rule 3

    private static func matchAnchorClassNext(html: String, currentURL: URL) -> URL? {
        // class 属性に "next" word が含まれる a タグ。\bnext\b で word boundary 一致 (case-insensitive)
        let patterns = [
            #"<a\s+[^>]*class\s*=\s*["'][^"']*\bnext\b[^"']*["'][^>]*href\s*=\s*["']([^"']+)["'][^>]*>"#,
            #"<a\s+[^>]*href\s*=\s*["']([^"']+)["'][^>]*class\s*=\s*["'][^"']*\bnext\b[^"']*["'][^>]*>"#
        ]
        for pattern in patterns {
            if let raw = firstCapture(html, pattern: pattern), let url = resolve(raw, base: currentURL) {
                return url
            }
        }
        return nil
    }

    // MARK: - Rule 4

    private static func matchURLPattern(html: String, currentURL: URL) -> URL? {
        guard let candidates = nextPageCandidates(from: currentURL), !candidates.isEmpty else {
            return nil
        }
        // candidate URL の絶対形 / 相対形いずれが a href として存在するかを確認
        for candidate in candidates {
            let absolute = candidate.absoluteString
            // URL 全体で正規表現 escape 必要なので literal エスケープ済 string で contains
            if html.range(of: #"<a [^>]*href\s*=\s*["']\#(escapeRegex(absolute))["']"#, options: .regularExpression) != nil {
                if let url = resolve(absolute, base: currentURL) { return url }
            }
            // 相対パス検出 (path + query)
            if let path = relativePath(of: candidate, base: currentURL) {
                if html.range(of: #"<a [^>]*href\s*=\s*["']\#(escapeRegex(path))["']"#, options: .regularExpression) != nil {
                    if let url = resolve(path, base: currentURL) { return url }
                }
            }
        }
        return nil
    }

    private static func nextPageCandidates(from url: URL) -> [URL]? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var candidates: [URL] = []

        // Pattern A: ?page=N → ?page=N+1, &page=N → &page=N+1
        if let items = components.queryItems {
            for paramName in ["page", "p"] {
                if let pageItem = items.first(where: { $0.name.lowercased() == paramName }),
                   let value = pageItem.value, let n = Int(value) {
                    var newItems = items
                    if let idx = newItems.firstIndex(where: { $0.name.lowercased() == paramName }) {
                        newItems[idx] = URLQueryItem(name: pageItem.name, value: "\(n + 1)")
                        var c = components
                        c.queryItems = newItems
                        if let u = c.url { candidates.append(u) }
                    }
                }
            }
        }

        // Pattern B: /page/N → /page/N+1
        let path = components.path
        if let regex = try? NSRegularExpression(pattern: #"/page/(\d+)/?$"#) {
            let range = NSRange(path.startIndex..., in: path)
            if let match = regex.firstMatch(in: path, options: [], range: range),
               let numRange = Range(match.range(at: 1), in: path),
               let n = Int(path[numRange]) {
                let newPath = path.replacingOccurrences(
                    of: #"/page/\d+/?$"#,
                    with: "/page/\(n + 1)",
                    options: .regularExpression
                )
                var c = components
                c.path = newPath
                if let u = c.url { candidates.append(u) }
            }
        }

        return candidates
    }

    private static func relativePath(of candidate: URL, base: URL) -> String? {
        // candidate と base が同 host / scheme なら path + query を相対形として返す
        guard candidate.host == base.host, candidate.scheme == base.scheme else { return nil }
        var rel = candidate.path
        if let q = candidate.query, !q.isEmpty {
            rel += "?\(q)"
        }
        return rel.isEmpty ? nil : rel
    }

    private static func escapeRegex(_ s: String) -> String {
        // 正規表現メタ文字を escape
        let metaChars = #"\.*+?^$()[]{}|"#
        var escaped = ""
        for ch in s {
            if metaChars.contains(ch) {
                escaped += "\\\(ch)"
            } else {
                escaped += String(ch)
            }
        }
        return escaped
    }

    // MARK: - URL 解決と検証

    /// 相対 URL を currentURL に対する絶対 URL に解決し、各種拒否ルールを適用する。
    /// - 戻り値が non-nil なら: scheme=https, host=同一, normalized 比較で currentURL と異なる
    private static func resolve(_ raw: String, base currentURL: URL) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // javascript: / mailto: 等を拒否 (URL.scheme で判定)
        let absolute: URL?
        if trimmed.contains("://") {
            absolute = URL(string: trimmed)
        } else {
            absolute = URL(string: trimmed, relativeTo: currentURL)?.absoluteURL
        }
        guard let url = absolute else { return nil }

        // scheme は https のみ
        guard url.scheme?.lowercased() == "https" else { return nil }

        // host が同一 (www. 違いは同一視)
        guard URL.sameHost(url, currentURL) else { return nil }

        // 自己ループ拒否
        guard url.normalized() != currentURL.normalized() else { return nil }

        return url
    }

    private static func firstCapture(_ html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: html)
        else { return nil }
        return String(html[captureRange])
    }
}

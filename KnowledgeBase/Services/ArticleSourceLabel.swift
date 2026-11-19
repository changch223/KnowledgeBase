//
//  ArticleSourceLabel.swift
//  KnowledgeTree
//
//  spec 103 — 記事の保存元表示用ラベル (純関数)。
//  http(s) → ドメイン / RawArticleIntake の合成 URL → 入力種別 / それ以外 → unknown。
//

import Foundation

nonisolated enum ArticleSourceLabel {
    enum Kind: Equatable {
        case domain(String)
        case intake(RawArticleIntake.Source)
        case unknown

        /// 表示用文字列。unknown は空文字。
        var localizedText: String {
            switch self {
            case .domain(let host):
                return host
            case .intake(let source):
                switch source {
                case .note:       return String(localized: "article.source.note")
                case .sharedText: return String(localized: "article.source.sharedText")
                case .file:       return String(localized: "article.source.file")
                case .image:      return String(localized: "article.source.image")
                case .audio:      return String(localized: "article.source.audio")
                }
            case .unknown:
                return ""
            }
        }
    }

    static func label(for urlString: String) -> Kind {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased() else { return .unknown }
        if scheme == "knowledgebase" {
            if let host = url.host, let source = RawArticleIntake.Source(rawValue: host) {
                return .intake(source)
            }
            return .unknown
        }
        if scheme == "http" || scheme == "https", var host = url.host, !host.isEmpty {
            if host.lowercased().hasPrefix("www.") { host = String(host.dropFirst(4)) }
            return .domain(host)
        }
        return .unknown
    }
}

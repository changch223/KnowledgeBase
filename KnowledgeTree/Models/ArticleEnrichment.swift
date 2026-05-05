//
//  ArticleEnrichment.swift
//  KnowledgeTree
//
//  spec 002 — 本文取得・メタデータエンリッチメント
//

import Foundation
import SwiftData

@Model
final class ArticleEnrichment {
    @Attribute(.unique) var id: UUID
    var article: Article
    var statusRaw: String
    var canonicalTitle: String?
    var summary: String?
    var ogImageURL: String?
    var rawHTML: String?
    var lastFetchedAt: Date?
    var retryCount: Int

    /// spec 007: 実際に取得したページ数 (1 = 単一ページ、2-5 = マルチページ追跡)。
    var pageCountFetched: Int
    /// spec 007: 上限到達 / fetch エラーで打ち切ったページの推定残数。
    var pageCountSkipped: Int

    init(
        id: UUID = UUID(),
        article: Article,
        status: EnrichmentStatus = .pending,
        canonicalTitle: String? = nil,
        summary: String? = nil,
        ogImageURL: String? = nil,
        rawHTML: String? = nil,
        lastFetchedAt: Date? = nil,
        retryCount: Int = 0,
        pageCountFetched: Int = 1,
        pageCountSkipped: Int = 0
    ) {
        self.id = id
        self.article = article
        self.statusRaw = status.rawValue
        self.canonicalTitle = canonicalTitle
        self.summary = summary
        self.ogImageURL = ogImageURL
        self.rawHTML = rawHTML
        self.lastFetchedAt = lastFetchedAt
        self.retryCount = retryCount
        self.pageCountFetched = pageCountFetched
        self.pageCountSkipped = pageCountSkipped
    }
}

enum EnrichmentStatus: String, Codable, Sendable {
    case pending
    case fetching
    case succeeded
    case failed
    case permanentlyFailed
}

extension ArticleEnrichment {
    var status: EnrichmentStatus {
        get { EnrichmentStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}

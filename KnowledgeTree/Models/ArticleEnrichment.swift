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

    init(
        id: UUID = UUID(),
        article: Article,
        status: EnrichmentStatus = .pending,
        canonicalTitle: String? = nil,
        summary: String? = nil,
        ogImageURL: String? = nil,
        rawHTML: String? = nil,
        lastFetchedAt: Date? = nil,
        retryCount: Int = 0
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

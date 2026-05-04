//
//  ArticleBody.swift
//  KnowledgeTree
//
//  spec 003 — 本文抽出 (Reader View)
//

import Foundation
import SwiftData

@Model
final class ArticleBody {
    @Attribute(.unique) var id: UUID
    var article: Article
    var statusRaw: String
    var extractedText: String?
    var extractionVersion: Int
    var lastExtractedAt: Date?

    init(
        id: UUID = UUID(),
        article: Article,
        status: BodyExtractionStatus = .pending,
        extractedText: String? = nil,
        extractionVersion: Int = 1,
        lastExtractedAt: Date? = nil
    ) {
        self.id = id
        self.article = article
        self.statusRaw = status.rawValue
        self.extractedText = extractedText
        self.extractionVersion = extractionVersion
        self.lastExtractedAt = lastExtractedAt
    }
}

enum BodyExtractionStatus: String, Codable, Sendable {
    case pending
    case extracting
    case succeeded
    case failed
    case permanentlyFailed
}

extension ArticleBody {
    var status: BodyExtractionStatus {
        get { BodyExtractionStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}

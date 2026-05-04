//
//  ArticleBodyStore.swift
//  KnowledgeTree
//
//  spec 003 — contracts/article-body-store.md
//

import Foundation
import SwiftData

protocol ArticleBodyStoreProtocol {
    func upsert(
        article: Article,
        status: BodyExtractionStatus,
        extractedText: String?,
        extractionVersion: Int,
        lastExtractedAt: Date?
    ) throws

    func fetchPendingArticles() throws -> [Article]
    func deleteAll() throws
}

enum ArticleBodyStoreError: Error {
    case persistenceFailure(underlying: Error)
}

@MainActor
final class SwiftDataArticleBodyStore: ArticleBodyStoreProtocol {
    private let context: ModelContext
    private let refreshTrigger: RefreshTrigger?

    init(context: ModelContext, refreshTrigger: RefreshTrigger? = nil) {
        self.context = context
        self.refreshTrigger = refreshTrigger
    }

    func upsert(
        article: Article,
        status: BodyExtractionStatus,
        extractedText: String?,
        extractionVersion: Int,
        lastExtractedAt: Date?
    ) throws {
        if let existing = article.body {
            existing.status = status
            existing.extractedText = extractedText
            existing.extractionVersion = extractionVersion
            existing.lastExtractedAt = lastExtractedAt
        } else {
            let new = ArticleBody(
                article: article,
                status: status,
                extractedText: extractedText,
                extractionVersion: extractionVersion,
                lastExtractedAt: lastExtractedAt
            )
            context.insert(new)
            article.body = new
        }
        do {
            try context.save()
            refreshTrigger?.bump()
        } catch {
            throw ArticleBodyStoreError.persistenceFailure(underlying: error)
        }
    }

    func fetchPendingArticles() throws -> [Article] {
        do {
            // body 不在 & enrichment.rawHTML 有り
            var descriptor = FetchDescriptor<Article>(
                predicate: #Predicate<Article> {
                    $0.body == nil && $0.enrichment != nil && $0.enrichment?.rawHTML != nil
                }
            )
            descriptor.fetchLimit = 1000
            return try context.fetch(descriptor)
        } catch {
            throw ArticleBodyStoreError.persistenceFailure(underlying: error)
        }
    }

    func deleteAll() throws {
        do {
            try context.delete(model: ArticleBody.self)
            try context.save()
        } catch {
            throw ArticleBodyStoreError.persistenceFailure(underlying: error)
        }
    }
}

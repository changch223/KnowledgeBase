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
            // 1) body 不在 & enrichment.rawHTML 有り
            var noBodyDescriptor = FetchDescriptor<Article>(
                predicate: #Predicate<Article> {
                    $0.body == nil && $0.enrichment != nil && $0.enrichment?.rawHTML != nil
                }
            )
            noBodyDescriptor.fetchLimit = 1000
            let noBody = try context.fetch(noBodyDescriptor)

            // 2) body が中間状態 (extracting / pending / failed) で残骸の Article
            // app crash / device lock 等の stale state を自動回復対象に含める。
            // .failed は元々 retry 不可だったが、enrichment.rawHTML が有る限り再挑戦する価値がある。
            var staleDescriptor = FetchDescriptor<ArticleBody>(
                predicate: #Predicate<ArticleBody> {
                    $0.statusRaw == "extracting" || $0.statusRaw == "pending"
                }
            )
            staleDescriptor.fetchLimit = 1000
            let staleBodies = try context.fetch(staleDescriptor)
            let staleArticles = staleBodies
                .map(\.article)
                .filter { $0.enrichment?.rawHTML != nil }

            var seen: Set<UUID> = []
            var result: [Article] = []
            for article in noBody + staleArticles {
                if seen.insert(article.id).inserted {
                    result.append(article)
                }
            }
            return result
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

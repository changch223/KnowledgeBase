//
//  ArticleEnrichmentStore.swift
//  KnowledgeTree
//
//  spec 002 — contracts/article-enrichment-store.md
//

import Foundation
import SwiftData

protocol ArticleEnrichmentStoreProtocol {
    func upsert(
        article: Article,
        status: EnrichmentStatus,
        canonicalTitle: String?,
        summary: String?,
        ogImageURL: String?,
        rawHTML: String?,
        retryCount: Int,
        pageCountFetched: Int,
        pageCountSkipped: Int
    ) throws

    func fetchPendingArticles() throws -> [Article]
    func deleteAll() throws
}

extension ArticleEnrichmentStoreProtocol {
    /// spec 002 互換: pageCount 引数を 1/0 (default 単一ページ) に固定する便利オーバーロード。
    func upsert(
        article: Article,
        status: EnrichmentStatus,
        canonicalTitle: String?,
        summary: String?,
        ogImageURL: String?,
        rawHTML: String?,
        retryCount: Int
    ) throws {
        try upsert(
            article: article,
            status: status,
            canonicalTitle: canonicalTitle,
            summary: summary,
            ogImageURL: ogImageURL,
            rawHTML: rawHTML,
            retryCount: retryCount,
            pageCountFetched: 1,
            pageCountSkipped: 0
        )
    }
}

enum ArticleEnrichmentStoreError: Error {
    case persistenceFailure(underlying: Error)
}

@MainActor
final class SwiftDataArticleEnrichmentStore: ArticleEnrichmentStoreProtocol {
    private let context: ModelContext
    private let refreshTrigger: RefreshTrigger?

    init(context: ModelContext, refreshTrigger: RefreshTrigger? = nil) {
        self.context = context
        self.refreshTrigger = refreshTrigger
    }

    func upsert(
        article: Article,
        status: EnrichmentStatus,
        canonicalTitle: String?,
        summary: String?,
        ogImageURL: String?,
        rawHTML: String?,
        retryCount: Int,
        pageCountFetched: Int,
        pageCountSkipped: Int
    ) throws {
        if let existing = article.enrichment {
            existing.status = status
            existing.canonicalTitle = canonicalTitle
            existing.summary = summary
            existing.ogImageURL = ogImageURL
            existing.rawHTML = rawHTML
            existing.retryCount = retryCount
            existing.lastFetchedAt = Date()
            existing.pageCountFetched = pageCountFetched
            existing.pageCountSkipped = pageCountSkipped
        } else {
            let new = ArticleEnrichment(
                article: article,
                status: status,
                canonicalTitle: canonicalTitle,
                summary: summary,
                ogImageURL: ogImageURL,
                rawHTML: rawHTML,
                lastFetchedAt: Date(),
                retryCount: retryCount,
                pageCountFetched: pageCountFetched,
                pageCountSkipped: pageCountSkipped
            )
            context.insert(new)
            article.enrichment = new
        }
        do {
            try context.save()
            refreshTrigger?.bump()
        } catch {
            throw ArticleEnrichmentStoreError.persistenceFailure(underlying: error)
        }
    }

    func fetchPendingArticles() throws -> [Article] {
        do {
            // 1) enrichment 不在の Article
            var noEnrichmentDescriptor = FetchDescriptor<Article>(
                predicate: #Predicate<Article> { $0.enrichment == nil }
            )
            noEnrichmentDescriptor.fetchLimit = 1000
            let noEnrichment = try context.fetch(noEnrichmentDescriptor)

            // 2) status .pending / .failed / .fetching の enrichment を持つ Article
            // .fetching は app crash / device lock 等で stale state になっている可能性 (spec 008+)
            var pendingDescriptor = FetchDescriptor<ArticleEnrichment>(
                predicate: #Predicate<ArticleEnrichment> {
                    $0.statusRaw == "pending"
                        || $0.statusRaw == "failed"
                        || $0.statusRaw == "fetching"
                }
            )
            pendingDescriptor.fetchLimit = 1000
            let pendingEnrichments = try context.fetch(pendingDescriptor)
            let pendingArticles = pendingEnrichments.map(\.article)

            // 重複排除
            var seen = Set<UUID>()
            var result: [Article] = []
            for article in noEnrichment + pendingArticles {
                if seen.insert(article.id).inserted {
                    result.append(article)
                }
            }
            return result
        } catch {
            throw ArticleEnrichmentStoreError.persistenceFailure(underlying: error)
        }
    }

    func deleteAll() throws {
        do {
            try context.delete(model: ArticleEnrichment.self)
            try context.save()
        } catch {
            throw ArticleEnrichmentStoreError.persistenceFailure(underlying: error)
        }
    }
}

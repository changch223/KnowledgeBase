//
//  ArticleStore.swift
//  KnowledgeTree
//
//  spec 001 / contracts/article-store.md
//

import Foundation
import SwiftData

protocol ArticleStoreProtocol {
    func exists(url: String) throws -> Bool
    func insert(_ article: Article) throws
    func delete(_ article: Article) throws
    func fetchAllSortedBySavedAt() throws -> [Article]
}

enum ArticleStoreError: Error {
    case persistenceFailure(underlying: Error)
}

@MainActor
final class SwiftDataArticleStore: ArticleStoreProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func exists(url: String) throws -> Bool {
        var descriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { $0.url == url }
        )
        descriptor.fetchLimit = 1
        do {
            return try !context.fetch(descriptor).isEmpty
        } catch {
            throw ArticleStoreError.persistenceFailure(underlying: error)
        }
    }

    func insert(_ article: Article) throws {
        context.insert(article)
        do {
            try context.save()
        } catch {
            throw ArticleStoreError.persistenceFailure(underlying: error)
        }
    }

    func delete(_ article: Article) throws {
        context.delete(article)
        do {
            try context.save()
        } catch {
            throw ArticleStoreError.persistenceFailure(underlying: error)
        }
    }

    func fetchAllSortedBySavedAt() throws -> [Article] {
        let descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            throw ArticleStoreError.persistenceFailure(underlying: error)
        }
    }
}

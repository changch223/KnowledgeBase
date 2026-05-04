//
//  ArticleSavingService.swift
//  KnowledgeTree
//
//  spec 001 / contracts/article-saving-service.md
//

import Foundation

protocol ArticleSavingServiceProtocol {
    func save(url: URL?, suppliedTitle: String?) async -> SaveResult
}

enum SaveResult: Equatable {
    case saved(Article)
    case duplicate
    case missingURL
    case unsupportedScheme
    case persistenceFailure(String)

    static func == (lhs: SaveResult, rhs: SaveResult) -> Bool {
        switch (lhs, rhs) {
        case (.duplicate, .duplicate): return true
        case (.missingURL, .missingURL): return true
        case (.unsupportedScheme, .unsupportedScheme): return true
        case let (.persistenceFailure(l), .persistenceFailure(r)): return l == r
        case let (.saved(l), .saved(r)): return l.id == r.id
        default: return false
        }
    }
}

@MainActor
final class DefaultArticleSavingService: ArticleSavingServiceProtocol {
    private let store: ArticleStoreProtocol

    init(store: ArticleStoreProtocol) {
        self.store = store
    }

    func save(url: URL?, suppliedTitle: String?) async -> SaveResult {
        guard let url else {
            return .missingURL
        }
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return .unsupportedScheme
        }
        let urlString = url.absoluteString
        do {
            if try store.exists(url: urlString) {
                return .duplicate
            }
        } catch {
            return .persistenceFailure(String(describing: error))
        }
        let title: String
        if let supplied = suppliedTitle, !supplied.isEmpty {
            title = supplied
        } else if let host = url.host, !host.isEmpty {
            title = host
        } else {
            title = urlString
        }
        let article = Article(url: urlString, title: title)
        do {
            try store.insert(article)
            return .saved(article)
        } catch {
            return .persistenceFailure(String(describing: error))
        }
    }
}

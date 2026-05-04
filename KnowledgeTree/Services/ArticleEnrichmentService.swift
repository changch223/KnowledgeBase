//
//  ArticleEnrichmentService.swift
//  KnowledgeTree
//
//  spec 002 — contracts/article-enrichment-service.md (+ retry / backoff / NWPath)
//  spec 003 hook: bodyExtractionService inject
//

import Foundation
import Network

protocol ArticleEnrichmentServiceProtocol: Sendable {
    func enrich(article: Article) async
    func backfillAll() async
    func cancelAll()
}

enum ArticleEnrichmentError: Error, Equatable {
    case invalidScheme
    case tooLarge
    case decodingFailed
    case httpError(Int)
    case network(URLError)

    static func == (lhs: ArticleEnrichmentError, rhs: ArticleEnrichmentError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidScheme, .invalidScheme): return true
        case (.tooLarge, .tooLarge): return true
        case (.decodingFailed, .decodingFailed): return true
        case let (.httpError(l), .httpError(r)): return l == r
        case let (.network(l), .network(r)): return l.code == r.code
        default: return false
        }
    }
}

@MainActor
final class DefaultArticleEnrichmentService: ArticleEnrichmentServiceProtocol {
    private let session: URLSessionProtocol
    private let store: ArticleEnrichmentStoreProtocol
    private let bodyExtractionService: BodyExtractionServiceProtocol?
    private let processingMonitor: ProcessingMonitor?
    private let userAgent: String
    private let maxDownloadBytes: Int
    private let rawHTMLCacheLimit: Int
    private let backoffSchedule: [Duration]

    private let pathMonitor: NWPathMonitor
    private var isOnline: Bool = true
    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    init(
        session: URLSessionProtocol,
        store: ArticleEnrichmentStoreProtocol,
        bodyExtractionService: BodyExtractionServiceProtocol? = nil,
        processingMonitor: ProcessingMonitor? = nil,
        userAgent: String = "KnowledgeTree/1.0 (iOS)",
        maxDownloadBytes: Int = 5 * 1024 * 1024,
        rawHTMLCacheLimit: Int = 2 * 1024 * 1024,
        backoffSchedule: [Duration] = [.seconds(30), .seconds(120), .seconds(600)]
    ) {
        self.session = session
        self.store = store
        self.bodyExtractionService = bodyExtractionService
        self.processingMonitor = processingMonitor
        self.userAgent = userAgent
        self.maxDownloadBytes = maxDownloadBytes
        self.rawHTMLCacheLimit = rawHTMLCacheLimit
        self.backoffSchedule = backoffSchedule
        self.pathMonitor = NWPathMonitor()
        startPathMonitoring()
    }

    deinit {
        pathMonitor.cancel()
    }

    private func startPathMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isOnline = (path.status == .satisfied)
            }
        }
        pathMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    func enrich(article: Article) async {
        let articleID = article.id

        // 同 article で既に走っているタスクがあれば、その結果を待つだけ (重複抑止)
        if let existing = activeTasks[articleID] {
            await existing.value
            return
        }

        guard let url = URL(string: article.url),
              url.scheme?.lowercased() == "https" else {
            try? store.upsert(
                article: article,
                status: .permanentlyFailed,
                canonicalTitle: nil,
                summary: nil,
                ogImageURL: nil,
                rawHTML: nil,
                retryCount: article.enrichment?.retryCount ?? 0
            )
            return
        }

        if let existing = article.enrichment,
           existing.status == .succeeded || existing.status == .permanentlyFailed {
            return
        }

        let task = Task { [weak self] in
            await self?.performEnrichment(article: article, url: url)
            await self?.removeTask(id: articleID)
        }
        activeTasks[articleID] = task
        await task.value
    }

    private func removeTask(id: UUID) {
        activeTasks.removeValue(forKey: id)
    }

    private func performEnrichment(article: Article, url: URL) async {
        let articleID = article.id
        let articleTitle = article.title
        processingMonitor?.start(.enrichment, articleID: articleID, title: articleTitle)
        defer { processingMonitor?.finish(articleID: articleID) }

        var attempt = article.enrichment?.retryCount ?? 0

        while attempt <= backoffSchedule.count {
            // Wait for online
            while !isOnline {
                if Task.isCancelled { return }
                try? await Task.sleep(for: .seconds(5))
            }
            if Task.isCancelled { return }

            try? store.upsert(
                article: article, status: .fetching,
                canonicalTitle: article.enrichment?.canonicalTitle,
                summary: article.enrichment?.summary,
                ogImageURL: article.enrichment?.ogImageURL,
                rawHTML: article.enrichment?.rawHTML,
                retryCount: attempt
            )

            do {
                let (parsed, rawHTML) = try await fetchAndParse(url: url)
                try store.upsert(
                    article: article,
                    status: .succeeded,
                    canonicalTitle: parsed.canonicalTitle,
                    summary: parsed.summary,
                    ogImageURL: parsed.ogImageURL?.absoluteString,
                    rawHTML: rawHTML,
                    retryCount: attempt
                )
                if let bodyExtractionService {
                    Task {
                        await bodyExtractionService.extract(article: article)
                    }
                }
                return
            } catch {
                attempt += 1
                if attempt > backoffSchedule.count {
                    try? store.upsert(
                        article: article, status: .permanentlyFailed,
                        canonicalTitle: nil, summary: nil, ogImageURL: nil, rawHTML: nil,
                        retryCount: attempt
                    )
                    return
                }
                try? store.upsert(
                    article: article, status: .failed,
                    canonicalTitle: article.enrichment?.canonicalTitle,
                    summary: article.enrichment?.summary,
                    ogImageURL: article.enrichment?.ogImageURL,
                    rawHTML: article.enrichment?.rawHTML,
                    retryCount: attempt
                )
                let waitDuration = backoffSchedule[attempt - 1]
                try? await Task.sleep(for: waitDuration)
                if Task.isCancelled { return }
            }
        }
    }

    private func fetchAndParse(url: URL) async throws -> (MetadataParser.ParsedMetadata, String?) {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw ArticleEnrichmentError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ArticleEnrichmentError.network(URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ArticleEnrichmentError.httpError(http.statusCode)
        }
        guard data.count <= maxDownloadBytes else {
            throw ArticleEnrichmentError.tooLarge
        }
        let contentType = http.value(forHTTPHeaderField: "Content-Type")
        guard let html = MetadataParser.decodeHTML(data: data, contentType: contentType) else {
            throw ArticleEnrichmentError.decodingFailed
        }

        let parsed = MetadataParser.parse(html: html, baseURL: url)
        let rawHTML: String? = data.count <= rawHTMLCacheLimit ? html : nil
        return (parsed, rawHTML)
    }

    func backfillAll() async {
        do {
            let pending = try store.fetchPendingArticles()
            for article in pending {
                if Task.isCancelled { return }
                await enrich(article: article)
            }
        } catch {
            // log only — UI 上は何も出さない (Principle V)
        }
    }

    func cancelAll() {
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }
}

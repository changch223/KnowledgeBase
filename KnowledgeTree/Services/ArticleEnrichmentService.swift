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
    /// spec 007: マルチページ追跡の上限。
    private let maxPages: Int
    /// spec 007: ページ間の遅延。
    private let delayBetweenPages: Duration

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
        backoffSchedule: [Duration] = [.seconds(30), .seconds(120), .seconds(600)],
        maxPages: Int = 5,
        delayBetweenPages: Duration = .seconds(1)
    ) {
        self.session = session
        self.store = store
        self.bodyExtractionService = bodyExtractionService
        self.processingMonitor = processingMonitor
        self.userAgent = userAgent
        self.maxDownloadBytes = maxDownloadBytes
        self.rawHTMLCacheLimit = rawHTMLCacheLimit
        self.backoffSchedule = backoffSchedule
        self.maxPages = maxPages
        self.delayBetweenPages = delayBetweenPages
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
        processingMonitor?.start(
            .enrichment,
            articleID: articleID,
            title: articleTitle,
            progressIndex: 0,
            progressTotal: maxPages
        )
        defer { processingMonitor?.finish(articleID: articleID) }

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
            retryCount: article.enrichment?.retryCount ?? 0,
            pageCountFetched: article.enrichment?.pageCountFetched ?? 1,
            pageCountSkipped: article.enrichment?.pageCountSkipped ?? 0
        )

        let crawler = MultiPageCrawler(
            session: session,
            userAgent: userAgent,
            maxPages: maxPages,
            delayBetweenPages: delayBetweenPages,
            maxDownloadBytes: maxDownloadBytes,
            firstPageRetrySchedule: backoffSchedule
        )

        let result = await crawler.crawl(initialURL: url) { [weak self] pageIndex in
            await MainActor.run { [weak self] in
                self?.processingMonitor?.updateProgress(
                    articleID: articleID,
                    index: pageIndex
                )
            }
        }

        if Task.isCancelled { return }

        switch result.stopReason {
        case .firstPageFailed:
            try? store.upsert(
                article: article, status: .permanentlyFailed,
                canonicalTitle: nil, summary: nil, ogImageURL: nil, rawHTML: nil,
                retryCount: result.firstPageRetryCount,
                pageCountFetched: 0,
                pageCountSkipped: 0
            )
            return

        case .completed, .maxPagesReached, .loopDetected, .crossDomainBlocked, .fetchFailed:
            // 1 ページ目以上 fetched: succeeded で保存
            let metadata = result.firstPageMetadata
            // 連結 HTML が rawHTMLCacheLimit を超えるなら nil
            let rawHTML: String?
            if let combined = result.combinedHTML, combined.count <= rawHTMLCacheLimit {
                rawHTML = combined
            } else {
                rawHTML = nil
            }
            try? store.upsert(
                article: article,
                status: .succeeded,
                canonicalTitle: metadata?.canonicalTitle,
                summary: metadata?.summary,
                ogImageURL: metadata?.ogImageURL?.absoluteString,
                rawHTML: rawHTML,
                retryCount: result.firstPageRetryCount,
                pageCountFetched: result.pageCountFetched,
                pageCountSkipped: result.pageCountSkipped
            )

            if let bodyExtractionService {
                Task {
                    await bodyExtractionService.extract(article: article)
                }
            }
        }
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

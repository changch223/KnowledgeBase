//
//  BodyExtractionService.swift
//  KnowledgeTree
//
//  spec 003 — contracts/body-extraction-service.md
//  spec 004 hook: knowledgeExtractionService inject + ArticleBody .succeeded で trigger
//

import Foundation

protocol BodyExtractionServiceProtocol: Sendable {
    func extract(article: Article) async
    func backfillAll() async
    func cancelAll()
}

@MainActor
final class DefaultBodyExtractionService: BodyExtractionServiceProtocol {
    private let store: ArticleBodyStoreProtocol
    private let knowledgeExtractionService: KnowledgeExtractionServiceProtocol?
    private let processingMonitor: ProcessingMonitor?
    private let minimumBodyLength: Int
    private let extractionVersion: Int
    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    init(
        store: ArticleBodyStoreProtocol,
        knowledgeExtractionService: KnowledgeExtractionServiceProtocol? = nil,
        processingMonitor: ProcessingMonitor? = nil,
        minimumBodyLength: Int = 100,
        extractionVersion: Int = 1
    ) {
        self.store = store
        self.knowledgeExtractionService = knowledgeExtractionService
        self.processingMonitor = processingMonitor
        self.minimumBodyLength = minimumBodyLength
        self.extractionVersion = extractionVersion
    }

    func extract(article: Article) async {
        let articleID = article.id

        // 同 article で既に走っているタスクがあれば、その結果を待つだけ (重複抑止)
        if let existing = activeTasks[articleID] {
            await existing.value
            return
        }

        // 既に終了状態なら no-op
        if let existing = article.body,
           existing.status == .succeeded || existing.status == .permanentlyFailed {
            return
        }
        // rawHTML 不在なら no-op (ArticleBody を作らない)
        guard let rawHTML = article.enrichment?.rawHTML, !rawHTML.isEmpty else {
            return
        }

        let task = Task { [weak self] in
            await self?.performExtraction(article: article, html: rawHTML)
            await self?.removeTask(id: articleID)
        }
        activeTasks[articleID] = task
        await task.value
    }

    private func removeTask(id: UUID) {
        activeTasks.removeValue(forKey: id)
    }

    private func performExtraction(article: Article, html: String) async {
        let articleID = article.id
        let articleTitle = article.title
        processingMonitor?.start(.body, articleID: articleID, title: articleTitle)
        defer { processingMonitor?.finish(articleID: articleID) }

        try? store.upsert(
            article: article,
            status: .extracting,
            extractedText: nil,
            extractionVersion: extractionVersion,
            lastExtractedAt: Date()
        )

        // HTML パースは detached Task で main thread をブロックしない
        let parsed = await Task.detached(priority: .utility) {
            BodyExtractor.extract(html: html)
        }.value

        if Task.isCancelled { return }

        let resultText = parsed.extractedText
        let succeeded = (resultText?.count ?? 0) >= minimumBodyLength

        try? store.upsert(
            article: article,
            status: succeeded ? .succeeded : .failed,
            extractedText: succeeded ? resultText : nil,
            extractionVersion: extractionVersion,
            lastExtractedAt: Date()
        )

        // spec 004 トリガ: 成功時に知識抽出を fire-and-forget でキック
        if succeeded, let knowledgeExtractionService {
            Task {
                await knowledgeExtractionService.extract(article: article)
            }
        }
    }

    func backfillAll() async {
        do {
            let pending = try store.fetchPendingArticles()
            for article in pending {
                if Task.isCancelled { return }
                await extract(article: article)
            }
        } catch {
            // log only
        }
    }

    func cancelAll() {
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }
}

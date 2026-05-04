//
//  KnowledgeExtractionService.swift
//  KnowledgeTree
//
//  spec 004 — contracts/knowledge-extraction-service.md
//
//  availability チェック → KnowledgeExtractor 呼び出し → ArticleKnowledgeStore 保存 の orchestration。
//  ArticleBody .succeeded を起点にトリガ (BodyExtractionService から fire-and-forget)。
//  起動時 backfill で既存 Article の catch-up。
//

import Foundation
import os

protocol KnowledgeExtractionServiceProtocol: Sendable {
    func extract(article: Article) async
    func backfillAll() async
    func cancelAll()
}

@MainActor
final class DefaultKnowledgeExtractionService: KnowledgeExtractionServiceProtocol {
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "knowledge")
    private let extractor: KnowledgeExtractor
    private let store: ArticleKnowledgeStoreProtocol
    private let availabilityChecker: AvailabilityChecker
    private let processingMonitor: ProcessingMonitor?
    private let minimumTextLength: Int
    private let extractionVersion: Int

    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    init(
        extractor: KnowledgeExtractor,
        store: ArticleKnowledgeStoreProtocol,
        availabilityChecker: AvailabilityChecker = SystemLanguageModelAvailabilityChecker(),
        processingMonitor: ProcessingMonitor? = nil,
        minimumTextLength: Int = 200,
        extractionVersion: Int = 1
    ) {
        self.extractor = extractor
        self.store = store
        self.availabilityChecker = availabilityChecker
        self.processingMonitor = processingMonitor
        self.minimumTextLength = minimumTextLength
        self.extractionVersion = extractionVersion
    }

    func extract(article: Article) async {
        let articleID = article.id

        // 同 article で既に走っているタスクがあれば、その結果を待つだけにする (重複防止)
        if let existing = activeTasks[articleID] {
            await existing.value
            return
        }

        // 冪等性チェック (succeeded / partiallySucceeded / extracting は早期 return)
        if let existing = article.extractedKnowledge {
            switch existing.status {
            case .succeeded, .partiallySucceeded, .extracting:
                return
            case .pending, .failed, .skipped:
                break  // 続行
            }
        }

        // 入力チェック
        guard let text = article.body?.extractedText, text.count >= minimumTextLength else {
            logger.notice("knowledge skipped: body text too short for \(article.url, privacy: .public)")
            return
        }

        // Apple Intelligence availability チェック (FR-003 / Principle IV)
        guard availabilityChecker.isAvailable else {
            logger.notice("knowledge skipped: Apple Intelligence unavailable")
            try? store.upsertStatus(article: article, status: .skipped)
            return
        }

        let task = Task { [weak self] in
            await self?.performExtraction(article: article, text: text)
            await self?.removeTask(id: articleID)
        }
        activeTasks[articleID] = task
        await task.value
    }

    private func removeTask(id: UUID) {
        activeTasks.removeValue(forKey: id)
    }

    private func performExtraction(article: Article, text: String) async {
        let articleID = article.id
        let articleTitle = article.title
        processingMonitor?.start(.knowledge, articleID: articleID, title: articleTitle)
        defer { processingMonitor?.finish(articleID: articleID) }

        try? store.upsertStatus(article: article, status: .extracting)

        if text.count > KnowledgeExtractor.defaultMaxBodyChars {
            logger.notice("knowledge truncating body for \(article.url, privacy: .public): \(text.count) chars → \(KnowledgeExtractor.defaultMaxBodyChars) chars")
        }

        let startTime = Date()
        let result: Result<ExtractedKnowledgeOutput, Error>
        do {
            let output = try await extractor.extract(extractedText: text)
            result = .success(output)
        } catch {
            result = .failure(error)
        }
        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)

        if Task.isCancelled { return }

        switch result {
        case .success(let output):
            let status = Self.determineStatus(output: output)
            logger.notice("knowledge result for \(article.url, privacy: .public): status=\(String(describing: status), privacy: .public) durationMs=\(durationMs) facts=\(output.keyFacts.count) entities=\(output.entities.count)")
            if status == .failed {
                try? store.upsertFailure(article: article, reason: "AI が記事から知識を抽出できませんでした")
            } else {
                try? store.upsertSucceeded(
                    article: article,
                    status: status,
                    output: output,
                    modelVersion: nil,
                    durationMs: durationMs
                )
            }
        case .failure(let error):
            let reason = String(describing: error)
            logger.error("knowledge generation failed for \(article.url, privacy: .public): \(reason, privacy: .public)")
            try? store.upsertFailure(article: article, reason: reason)
        }
    }

    /// 4 出力のうちいくつ取れたかで .succeeded / .partiallySucceeded / .failed を判定。
    static func determineStatus(output: ExtractedKnowledgeOutput) -> ExtractionStatus {
        let hasEssence = !output.essence.isEmpty
        let hasSummary = !output.summary.isEmpty
        let hasKeyFacts = !output.keyFacts.isEmpty
        let hasEntities = !output.entities.isEmpty
        let count = [hasEssence, hasSummary, hasKeyFacts, hasEntities].filter { $0 }.count

        switch count {
        case 4: return .succeeded
        case 1, 2, 3: return .partiallySucceeded
        default: return .failed
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
            // log only — UI には何も出さない (Principle V)
        }
    }

    func cancelAll() {
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }
}

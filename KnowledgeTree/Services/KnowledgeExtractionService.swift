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
    /// spec 006: chunked パスに切り替える本文長の閾値。これ以下は単発パス。
    private let chunkSizeChars: Int
    /// spec 006: 1 記事あたりの最大 chunk 数。10000 文字超は冒頭 10 chunk のみ要約。
    private let maxChunks: Int

    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    init(
        extractor: KnowledgeExtractor,
        store: ArticleKnowledgeStoreProtocol,
        availabilityChecker: AvailabilityChecker = SystemLanguageModelAvailabilityChecker(),
        processingMonitor: ProcessingMonitor? = nil,
        minimumTextLength: Int = 200,
        extractionVersion: Int = 1,
        chunkSizeChars: Int = 1_000,
        maxChunks: Int = 10
    ) {
        self.extractor = extractor
        self.store = store
        self.availabilityChecker = availabilityChecker
        self.processingMonitor = processingMonitor
        self.minimumTextLength = minimumTextLength
        self.extractionVersion = extractionVersion
        self.chunkSizeChars = chunkSizeChars
        self.maxChunks = maxChunks
    }

    func extract(article: Article) async {
        let articleID = article.id

        // 同 article で既に走っているタスクがあれば、その結果を待つだけにする (重複防止)
        if let existing = activeTasks[articleID] {
            await existing.value
            return
        }

        // 冪等性チェック: 完了済 (succeeded/partiallySucceeded) のみ早期 return。
        // .extracting は app crash / lock 等で stale 状態になっている可能性があるため
        // 続行 (本当に in-flight ならば冒頭の activeTasks dedup で待機される)。
        if let existing = article.extractedKnowledge {
            switch existing.status {
            case .succeeded, .partiallySucceeded:
                return
            case .pending, .failed, .skipped, .extracting:
                break  // 続行 (extracting は stale state として再開可能)
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

        try? store.upsertStatus(article: article, status: .extracting)

        // spec 006: 本文長で chunked / 単発を切り替え
        if text.count <= chunkSizeChars {
            // === 単発パス (spec 004 既存挙動) ===
            processingMonitor?.start(.knowledge, articleID: articleID, title: articleTitle)
            defer { processingMonitor?.finish(articleID: articleID) }

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
        } else {
            // === Chunked パス (spec 006) ===
            await performChunkedExtraction(
                article: article,
                articleID: articleID,
                articleTitle: articleTitle,
                text: text
            )
        }
    }

    /// spec 006: chunked summarization の orchestration。
    /// chunk 分割 → 各 chunk 逐次生成 → meta-summary → aggregator merge → upsert。
    private func performChunkedExtraction(
        article: Article,
        articleID: UUID,
        articleTitle: String,
        text: String
    ) async {
        let split = ChunkSplitter.split(
            text: text,
            maxChars: chunkSizeChars,
            maxChunks: maxChunks
        )
        let chunks = split.chunks
        let skippedTail = split.skippedTailChars
        // 総ステップ数 = chunk 数 + meta-summary 1 (meta が出ない場合でも progressTotal は固定)
        let totalSteps = chunks.count + 1

        processingMonitor?.start(
            .knowledge,
            articleID: articleID,
            title: articleTitle,
            progressIndex: 0,
            progressTotal: totalSteps
        )
        defer { processingMonitor?.finish(articleID: articleID) }

        logger.notice("knowledge chunked start for \(article.url, privacy: .public): \(text.count) chars → \(chunks.count) chunks (skippedTail: \(skippedTail))")

        let startTime = Date()
        var results: [ChunkResult] = []
        for (i, chunk) in chunks.enumerated() {
            if Task.isCancelled { return }
            let result = await extractor.extractFromChunk(chunk)
            results.append(result)
            processingMonitor?.updateProgress(articleID: articleID, index: i + 1)
            if let error = result.error {
                logger.error("knowledge chunk \(i + 1)/\(chunks.count) failed for \(article.url, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }

        if Task.isCancelled { return }

        // meta-summary 生成
        let chunkEssences = results.compactMap { $0.output?.essence }
        let metaSummary = await extractor.extractMetaSummary(chunkEssences: chunkEssences)
        processingMonitor?.updateProgress(articleID: articleID, index: totalSteps)

        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
        let aggregated = ChunkedKnowledgeAggregator.merge(results: results, metaSummary: metaSummary)
        let status = aggregated.determineStatus()

        logger.notice("knowledge chunked result for \(article.url, privacy: .public): status=\(String(describing: status), privacy: .public) durationMs=\(durationMs) processed=\(aggregated.successfulChunkCount)/\(chunks.count) facts=\(aggregated.keyFacts.count) entities=\(aggregated.entities.count) metaOK=\(aggregated.metaSummarySucceeded) skippedTail=\(skippedTail)")

        switch status {
        case .failed:
            try? store.upsertFailure(
                article: article,
                reason: "全 \(chunks.count) chunk 失敗"
            )
        case .succeeded, .partiallySucceeded:
            // chunk 数 + (meta 成功なら 1)
            let processedCount = aggregated.successfulChunkCount + (aggregated.metaSummarySucceeded ? 1 : 0)
            try? store.upsertSucceeded(
                article: article,
                status: status,
                output: aggregated.toOutput(),
                modelVersion: nil,
                durationMs: durationMs,
                chunkProcessedCount: processedCount,
                chunkTotalCount: totalSteps,
                skippedTailChars: skippedTail
            )
        case .pending, .extracting, .skipped:
            // determineStatus は上記 3 値しか返さないが、enum 網羅で no-op
            break
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

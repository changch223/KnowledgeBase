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
    /// spec 010 で default を 30 に拡張 (階層化対応で 30000 文字までフルカバー)。
    private let maxChunks: Int
    /// spec 009: chunked summarization の incremental 永続化先 (default は no-op で後方互換)
    private let chunkProgressStore: ChunkProgressStoreProtocol
    /// spec 012: knowledge 抽出 succeeded 後の auto-tag 用 (default nil で後方互換)
    private let tagStore: TagStore?
    /// spec 018: knowledge 抽出 succeeded 後の Category Digest 再集約用 (default nil で後方互換)
    private let digestService: KnowledgeDigestService?
    /// spec 021: knowledge 抽出 succeeded 後の essence embedding 生成用 (default nil で後方互換)
    private let embeddingService: EmbeddingService?
    /// spec 037: knowledge 抽出 succeeded 後の conflict 検出用 (default nil で後方互換)
    private let conflictDetectionService: ConflictDetectionServiceProtocol?
    /// spec 040: knowledge 抽出 succeeded 後の graph 抽出用 (default nil で後方互換)
    private let graphExtractionService: GraphExtractionServiceProtocol?
    /// spec 042: knowledge 抽出 succeeded 後の ConceptPage 自動生成 / 更新用 (default nil で後方互換)
    private let conceptSynthesisService: ConceptSynthesisServiceProtocol?

    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    init(
        extractor: KnowledgeExtractor,
        store: ArticleKnowledgeStoreProtocol,
        availabilityChecker: AvailabilityChecker = SystemLanguageModelAvailabilityChecker(),
        processingMonitor: ProcessingMonitor? = nil,
        minimumTextLength: Int = 200,
        extractionVersion: Int = 1,
        chunkSizeChars: Int = 1_000,
        maxChunks: Int = 30,
        chunkProgressStore: ChunkProgressStoreProtocol? = nil,
        tagStore: TagStore? = nil,
        digestService: KnowledgeDigestService? = nil,
        embeddingService: EmbeddingService? = nil,
        conflictDetectionService: ConflictDetectionServiceProtocol? = nil,
        graphExtractionService: GraphExtractionServiceProtocol? = nil,
        conceptSynthesisService: ConceptSynthesisServiceProtocol? = nil
    ) {
        self.extractor = extractor
        self.store = store
        self.availabilityChecker = availabilityChecker
        self.processingMonitor = processingMonitor
        self.minimumTextLength = minimumTextLength
        self.extractionVersion = extractionVersion
        self.chunkSizeChars = chunkSizeChars
        self.maxChunks = maxChunks
        // @MainActor isolated init は default 引数で書けないため nil 受け → fallback で NoopChunkProgressStore
        self.chunkProgressStore = chunkProgressStore ?? NoopChunkProgressStore()
        self.tagStore = tagStore
        self.digestService = digestService
        self.embeddingService = embeddingService
        self.conflictDetectionService = conflictDetectionService
        self.graphExtractionService = graphExtractionService
        self.conceptSynthesisService = conceptSynthesisService
    }

    /// spec 042: knowledge 抽出 succeeded/partiallySucceeded 直後に呼ばれる ConceptPage 自動生成 hook。
    /// fire-and-forget で非同期実行 (失敗しても本フローに影響しない)。
    /// conceptSynthesisService が nil なら no-op (後方互換)。
    private func synthesizeConceptIfPossible(article: Article) {
        guard let conceptSynthesisService else { return }
        Task { [weak self] in
            _ = self
            await conceptSynthesisService.processNewArticle(article: article)
        }
    }

    /// spec 040: knowledge 抽出 succeeded/partiallySucceeded 直後に呼ばれる graph 抽出 hook。
    /// fire-and-forget で非同期実行 (失敗しても本フローに影響しない)。
    private func extractGraphIfPossible(article: Article) {
        guard let graphExtractionService else { return }
        Task { [weak self] in
            _ = self
            await graphExtractionService.extract(article: article)
        }
    }

    /// spec 037: knowledge 抽出 succeeded/partiallySucceeded 直後に呼ばれる conflict 検出 hook。
    /// fire-and-forget で非同期実行 (失敗しても本フローに影響しない)。
    private func detectConflictsIfPossible(article: Article) {
        guard let conflictDetectionService else { return }
        Task { [weak self] in
            _ = self
            await conflictDetectionService.detect(article: article)
        }
    }

    /// spec 021: knowledge 抽出 succeeded/partiallySucceeded 直後に呼ばれる embedding 生成 hook。
    /// embeddingService が nil または不可端末の場合は no-op (後方互換)。essence が空でも title で fallback。
    private func generateEmbeddingIfPossible(article: Article) {
        guard let embeddingService, embeddingService.isAvailable else { return }
        let text: String
        if let essence = article.extractedKnowledge?.essence, !essence.isEmpty {
            text = essence
        } else {
            let title = article.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return }
            text = title
        }
        guard let vector = embeddingService.embed(text) else { return }
        article.essenceEmbedding = vector.asEmbeddingData
    }

    /// spec 012: knowledge 抽出 succeeded/partiallySucceeded 直後に呼ばれる auto-tag hook。
    /// tagStore が nil なら no-op (後方互換)。
    private func applyAutoTagsIfPossible(article: Article) {
        guard let tagStore else { return }
        AutoTagApplier.apply(to: article, using: tagStore)
    }

    /// spec 018: knowledge 抽出 succeeded/partiallySucceeded 直後に呼ばれる Digest stale 化 hook。
    /// digestService が nil なら no-op (後方互換)。
    /// 該当記事の Tag.categoryRaw から Category を引いて該当 Category の Digest を stale 化。
    private func markDigestStaleIfPossible(article: Article) {
        guard let digestService else { return }
        // article.tags はこの時点で applyAutoTagsIfPossible により設定済み
        let categoryNames = Set(article.tags.compactMap(\.categoryRaw))
        for name in categoryNames {
            guard let category = CategorySeed.allSeeds.first(where: { $0.name == name }) else {
                continue
            }
            digestService.markStale(for: category)
        }
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
                    // spec 012: 単一パス auto-tag hook
                    applyAutoTagsIfPossible(article: article)
                    // spec 018: Category Digest stale 化 hook
                    markDigestStaleIfPossible(article: article)
                    // spec 021: essence embedding 生成 hook
                    generateEmbeddingIfPossible(article: article)
                    // spec 037: 時系列事実上書き検出 hook (fire-and-forget)
                    detectConflictsIfPossible(article: article)
                    // spec 040: Knowledge Graph 抽出 hook (fire-and-forget)
                    extractGraphIfPossible(article: article)
                    // spec 042: ConceptPage 自動生成 / 更新 hook (fire-and-forget)
                    synthesizeConceptIfPossible(article: article)
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

    /// spec 006 + 009 + 010: chunked summarization orchestration。
    /// - chunks <= 10: spec 006 既存パス (単一 meta-summary)
    /// - chunks > 10: spec 010 階層パス (lvl1 → lvl2 中間 meta → lvl3 最終 meta)
    /// - 各 chunk 完了で chunkProgressStore.add で incremental 永続化 (spec 009)
    /// - リジューム時は既完了 chunkIndex を skip
    /// - 完了で chunkProgressStore.cleanup
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

        // spec 010: chunks > 10 で階層化
        let useHierarchical = chunks.count > 10
        let lvl2GroupCount = useHierarchical
            ? Int((Double(chunks.count) / 10.0).rounded(.up))
            : 0
        let totalSteps = chunks.count + lvl2GroupCount + 1

        processingMonitor?.start(
            .knowledge,
            articleID: articleID,
            title: articleTitle,
            progressIndex: 0,
            progressTotal: totalSteps
        )
        defer { processingMonitor?.finish(articleID: articleID) }

        // === lvl1 chunks の incremental resume (spec 009) ===
        try? store.upsertStatus(article: article, status: .extracting)
        guard let knowledge = article.extractedKnowledge else { return }

        let completed: [LoadedChunkProgress] = (try? chunkProgressStore.fetchAll(knowledge: knowledge)) ?? []
        let completedIndices = Set(completed.map(\.chunkIndex))

        logger.notice("knowledge chunked start for \(article.url, privacy: .public): \(text.count) chars → \(chunks.count) chunks (alreadyCompleted: \(completedIndices.count), hierarchical: \(useHierarchical), skippedTail: \(skippedTail))")

        processingMonitor?.updateProgress(articleID: articleID, index: completedIndices.count)

        let startTime = Date()
        // 既完了の output を ChunkResult として復元
        var results: [ChunkResult] = completed.map {
            ChunkResult(chunkIndex: $0.chunkIndex, output: $0.output, error: nil)
        }

        // 残り chunks のみ処理
        for chunk in chunks where !completedIndices.contains(chunk.index) {
            if Task.isCancelled { return }
            let result = await extractor.extractFromChunk(chunk)
            results.append(result)
            // incremental save
            if let output = result.output {
                try? chunkProgressStore.add(
                    knowledge: knowledge,
                    chunkIndex: chunk.index,
                    output: output
                )
            }
            processingMonitor?.updateProgress(articleID: articleID, index: results.count)
            if let error = result.error {
                logger.error("knowledge chunk \(chunk.index + 1)/\(chunks.count) failed for \(article.url, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }

        if Task.isCancelled { return }

        // === lvl2 / lvl3 (spec 010 階層化) ===
        let aggregated: AggregatedKnowledge
        let metaCallCount: Int

        if useHierarchical {
            // chunkIndex 昇順に sort
            let sortedResults = results.sorted { $0.chunkIndex < $1.chunkIndex }
            let groups = HierarchicalChunkedSummarizer.makeGroups(sortedResults, groupSize: 10)

            let intermediates = await HierarchicalChunkedSummarizer.runIntermediateMetaSummaries(
                groups: groups,
                extractor: extractor
            ) { [weak self] groupIndex in
                await MainActor.run {
                    self?.processingMonitor?.updateProgress(
                        articleID: articleID,
                        index: results.count + groupIndex
                    )
                }
            }

            if Task.isCancelled { return }

            let lvl3 = await HierarchicalChunkedSummarizer.runFinalMetaSummary(
                intermediateResults: intermediates,
                extractor: extractor
            )
            processingMonitor?.updateProgress(articleID: articleID, index: totalSteps)

            aggregated = ChunkedKnowledgeAggregator.mergeHierarchical(
                lvl1Results: sortedResults,
                lvl2Results: intermediates,
                lvl3Result: lvl3
            )
            metaCallCount = intermediates.compactMap { $0.output }.count + (lvl3 != nil ? 1 : 0)
        } else {
            // spec 006 既存パス (単一 meta-summary)
            let chunkEssences = results.compactMap { $0.output?.essence }
            let metaSummary = await extractor.extractMetaSummary(chunkEssences: chunkEssences)
            processingMonitor?.updateProgress(articleID: articleID, index: totalSteps)
            aggregated = ChunkedKnowledgeAggregator.merge(results: results, metaSummary: metaSummary)
            metaCallCount = aggregated.metaSummarySucceeded ? 1 : 0
        }

        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
        let status = aggregated.determineStatus()

        logger.notice("knowledge chunked result for \(article.url, privacy: .public): status=\(String(describing: status), privacy: .public) durationMs=\(durationMs) processed=\(aggregated.successfulChunkCount)/\(chunks.count) hierarchical=\(useHierarchical) facts=\(aggregated.keyFacts.count) entities=\(aggregated.entities.count) metaCalls=\(metaCallCount) skippedTail=\(skippedTail)")

        switch status {
        case .failed:
            try? store.upsertFailure(
                article: article,
                reason: "全 \(chunks.count) chunk 失敗"
            )
            try? chunkProgressStore.cleanup(knowledge: knowledge)
        case .succeeded, .partiallySucceeded:
            let processedCount = aggregated.successfulChunkCount + metaCallCount
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
            try? chunkProgressStore.cleanup(knowledge: knowledge)
            // spec 012: chunked パス auto-tag hook
            applyAutoTagsIfPossible(article: article)
            // spec 018: Category Digest stale 化 hook (chunked パス)
            markDigestStaleIfPossible(article: article)
            // spec 021: essence embedding 生成 hook (chunked パス)
            generateEmbeddingIfPossible(article: article)
            // spec 037: 時系列事実上書き検出 hook (chunked パス、fire-and-forget)
            detectConflictsIfPossible(article: article)
            // spec 040: Knowledge Graph 抽出 hook (chunked パス、fire-and-forget)
            extractGraphIfPossible(article: article)
            // spec 042: ConceptPage 自動生成 / 更新 hook (chunked パス、fire-and-forget)
            synthesizeConceptIfPossible(article: article)
        case .pending, .extracting, .skipped:
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

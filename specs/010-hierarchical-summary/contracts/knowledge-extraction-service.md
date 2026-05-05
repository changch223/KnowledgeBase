# Contract: KnowledgeExtractionService (階層化分岐への修正)

**File**: `KnowledgeTree/Services/KnowledgeExtractionService.swift` (既存に修正)

## 責務

`performChunkedExtraction` 内で `chunks.count > 10` の場合は階層パスへ振り分け、それ以外は spec 006 既存パスを使う。

## API (変更なし、内部実装のみ修正)

```swift
init(
    extractor: KnowledgeExtractor,
    store: ArticleKnowledgeStoreProtocol,
    availabilityChecker: AvailabilityChecker = SystemLanguageModelAvailabilityChecker(),
    processingMonitor: ProcessingMonitor? = nil,
    minimumTextLength: Int = 200,
    extractionVersion: Int = 1,
    chunkSizeChars: Int = 1_000,
    maxChunks: Int = 30,                               // spec 010: 10 → 30
    chunkProgressStore: ChunkProgressStoreProtocol = NoopChunkProgressStore()  // spec 009 既存
)
```

## 内部実装変更

### performChunkedExtraction

```swift
private func performChunkedExtraction(article, articleID, articleTitle, text) async {
    let split = ChunkSplitter.split(text: text, maxChars: chunkSizeChars, maxChunks: maxChunks)
    let chunks = split.chunks
    let skippedTail = split.skippedTailChars

    // === 階層判定 (spec 010) ===
    let useHierarchical = chunks.count > 10
    let lvl2GroupCount = useHierarchical
        ? Int(ceil(Double(chunks.count) / 10.0))
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

    try? store.upsertStatus(article: article, status: .extracting)
    guard let knowledge = article.extractedKnowledge else { return }

    // === lvl1 chunks 処理 (incremental save、spec 009 既存) ===
    let completed: [LoadedChunkProgress] = (try? chunkProgressStore.fetchAll(knowledge: knowledge)) ?? []
    let completedIndices = Set(completed.map(\.chunkIndex))
    var results: [ChunkResult] = completed.map { ChunkResult(chunkIndex: $0.chunkIndex, output: $0.output, error: nil) }
    processingMonitor?.updateProgress(articleID, index: completedIndices.count)

    let startTime = Date()
    for chunk in chunks where !completedIndices.contains(chunk.index) {
        if Task.isCancelled { return }
        let result = await extractor.extractFromChunk(chunk)
        results.append(result)
        if let output = result.output {
            try? chunkProgressStore.add(knowledge: knowledge, chunkIndex: chunk.index, output: output)
        }
        processingMonitor?.updateProgress(articleID, index: results.count)
    }

    if Task.isCancelled { return }

    // === lvl2 / lvl3 (chunks > 10 のみ) ===
    let aggregated: AggregatedKnowledge

    if useHierarchical {
        // lvl2 中間 meta-summary
        let groups = HierarchicalChunkedSummarizer.makeGroups(results.sorted { $0.chunkIndex < $1.chunkIndex }, groupSize: 10)
        let intermediates = await HierarchicalChunkedSummarizer.runIntermediateMetaSummaries(
            groups: groups,
            extractor: extractor
        ) { [weak self] groupIndex in
            await MainActor.run {
                self?.processingMonitor?.updateProgress(articleID: articleID, index: results.count + groupIndex)
            }
        }

        if Task.isCancelled { return }

        // lvl3 最終 meta-summary
        let lvl3 = await HierarchicalChunkedSummarizer.runFinalMetaSummary(
            intermediateResults: intermediates,
            extractor: extractor
        )
        processingMonitor?.updateProgress(articleID, index: totalSteps)

        // 集約
        aggregated = ChunkedKnowledgeAggregator.mergeHierarchical(
            lvl1Results: results,
            lvl2Results: intermediates,
            lvl3Result: lvl3
        )
    } else {
        // spec 006 既存パス
        let chunkEssences = results.compactMap { $0.output?.essence }
        let metaSummary = await extractor.extractMetaSummary(chunkEssences: chunkEssences)
        processingMonitor?.updateProgress(articleID, index: totalSteps)
        aggregated = ChunkedKnowledgeAggregator.merge(results: results, metaSummary: metaSummary)
    }

    let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
    let status = aggregated.determineStatus()

    switch status {
    case .failed:
        try? store.upsertFailure(article: article, reason: "全 \(chunks.count) chunk 失敗")
        try? chunkProgressStore.cleanup(knowledge: knowledge)
    case .succeeded, .partiallySucceeded:
        let processedCount = aggregated.successfulChunkCount + (useHierarchical
            ? (intermediates.compactMap { $0.output }.count + (lvl3 != nil ? 1 : 0))
            : (aggregated.metaSummarySucceeded ? 1 : 0))
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
    case .pending, .extracting, .skipped:
        break
    }
}
```

## ChunkedKnowledgeAggregator.mergeHierarchical (新規 method)

```swift
extension ChunkedKnowledgeAggregator {
    static func mergeHierarchical(
        lvl1Results: [ChunkResult],
        lvl2Results: [IntermediateMetaResult],
        lvl3Result: ExtractedKnowledgeOutput?
    ) -> AggregatedKnowledge {
        // keyFacts / entities は lvl1 から重複排除統合 (spec 006 既存ロジック流用)
        let keyFacts = mergeKeyFacts(from: lvl1Results.compactMap { $0.output })
        let entities = mergeEntities(from: lvl1Results.compactMap { $0.output })

        // essence / summary 決定
        let essence: String
        let summary: String
        if let lvl3 = lvl3Result {
            essence = lvl3.essence
            summary = lvl3.summary
        } else if !lvl2Results.compactMap({ $0.output }).isEmpty {
            // lvl2 連結 fallback
            let lvl2Essences = lvl2Results.compactMap { $0.output?.essence }.filter { !$0.isEmpty }
            essence = lvl2Essences.first ?? ""
            summary = String(lvl2Essences.joined(separator: "\n").prefix(300))
        } else if let firstSuccess = lvl1Results.compactMap({ $0.output }).first {
            // lvl1 連結 fallback
            essence = firstSuccess.essence
            let allEssences = lvl1Results.compactMap { $0.output?.essence }.filter { !$0.isEmpty }
            summary = String(allEssences.joined(separator: "\n").prefix(300))
        } else {
            essence = ""
            summary = ""
        }

        let successfulCount = lvl1Results.filter { $0.output != nil }.count
        let totalCount = lvl1Results.count
        let metaOK = lvl3Result != nil

        return AggregatedKnowledge(
            essence: essence,
            summary: summary,
            keyFacts: keyFacts,
            entities: entities,
            successfulChunkCount: successfulCount,
            totalChunkCount: totalCount,
            metaSummarySucceeded: metaOK
        )
    }
}
```

## 後方互換

- spec 006 chunked tests (chunks ≤ 10) は無修正で pass: `useHierarchical == false` 分岐で既存コード通る
- 既存 `merge(results:metaSummary:)` は無変更、`mergeHierarchical` は新規追加メソッド
- spec 009 incremental save との統合は変更なし (chunkProgressStore は lvl1 のみ)

## 新規テストケース

```swift
@Test("chunks 5 個は spec 006 単一 meta パス (lvl2 抜き)")
func nonHierarchicalForSmall()

@Test("chunks 18 個は階層パス、lvl2 = 2 groups, lvl3 = 1")
func hierarchicalForEighteen()

@Test("chunks 30 個は lvl2 = 3 groups")
func hierarchicalForThirty()

@Test("lvl2 1 つ失敗 + lvl3 成功 → .succeeded")
func partialLvl2WithLvl3Success()

@Test("lvl2 全失敗 → .partiallySucceeded (lvl1 fallback)")
func allLvl2FailedPartial()

@Test("lvl3 失敗 + lvl2 1+ 成功 → .partiallySucceeded (lvl2 fallback)")
func lvl3FailedWithLvl2Partial()

@Test("incremental save: 12 chunks 完了済 → 残り 6 chunks + lvl2 + lvl3 のみ")
func resumesPartialLvl1()
```

# Contract: KnowledgeExtractionService (incremental パスへの修正)

**File**: `KnowledgeTree/Services/KnowledgeExtractionService.swift` (既存に大幅修正)

## 責務

spec 006 で実装済の chunked パス (`performChunkedExtraction`) を **incremental save / resume** 方式に書き換える。
- 各 chunk 完了直後に `chunkProgressStore.add` で永続化
- 開始時に `chunkProgressStore.fetchAll` で既完了 chunk を取得 → skip
- 全完了後に `chunkProgressStore.cleanup`

外部 API は変更なし (spec 006 の `extract(article:)` の挙動は同じ)。

## API (init 引数追加 + 内部実装変更)

```swift
@MainActor
final class DefaultKnowledgeExtractionService: KnowledgeExtractionServiceProtocol {
    init(
        extractor: KnowledgeExtractor,
        store: ArticleKnowledgeStoreProtocol,
        availabilityChecker: AvailabilityChecker = SystemLanguageModelAvailabilityChecker(),
        processingMonitor: ProcessingMonitor? = nil,
        minimumTextLength: Int = 200,
        extractionVersion: Int = 1,
        chunkSizeChars: Int = 1_000,
        maxChunks: Int = 10,
        chunkProgressStore: ChunkProgressStoreProtocol = NoopChunkProgressStore()  // 新規 default
    )

    // 既存 API
    func extract(article: Article) async
    func backfillAll() async
    func cancelAll()
}
```

`chunkProgressStore` の default 値が `NoopChunkProgressStore` (何もしない実装) なので、spec 006 の既存テストは無修正で pass する (後方互換)。本番では `KnowledgeTreeApp.bootstrap` で `SwiftDataChunkProgressStore` を inject。

## 内部実装の変更点

### performChunkedExtraction の incremental 化

```swift
private func performChunkedExtraction(
    article: Article,
    articleID: UUID,
    articleTitle: String,
    text: String
) async {
    let split = ChunkSplitter.split(text: text, maxChars: chunkSizeChars, maxChunks: maxChunks)
    let chunks = split.chunks
    let skippedTail = split.skippedTailChars
    let totalSteps = chunks.count + 1

    processingMonitor?.start(
        .knowledge,
        articleID: articleID,
        title: articleTitle,
        progressIndex: 0,
        progressTotal: totalSteps
    )
    defer { processingMonitor?.finish(articleID: articleID) }

    // article.extractedKnowledge を確保 (.extracting で upsert)
    try? store.upsertStatus(article: article, status: .extracting)
    guard let knowledge = article.extractedKnowledge else { return }

    // === incremental resume ===
    // 既完了 chunks を progress store から取得
    let completed: [LoadedChunkProgress] = (try? chunkProgressStore.fetchAll(knowledge: knowledge)) ?? []
    let completedIndices = Set(completed.map(\.chunkIndex))

    logger.notice("knowledge chunked start (or resume) for \(article.url, privacy: .public): chunks=\(chunks.count) alreadyCompleted=\(completedIndices.count)")

    // 完了済の進捗を monitor に反映
    processingMonitor?.updateProgress(articleID: articleID, index: completedIndices.count)

    let startTime = Date()
    var results: [ChunkResult] = completed.map { progress in
        ChunkResult(chunkIndex: progress.chunkIndex, output: progress.output, error: nil)
    }

    // 残り chunks のみ処理
    for chunk in chunks where !completedIndices.contains(chunk.index) {
        if Task.isCancelled { return }
        let result = await extractor.extractFromChunk(chunk)
        results.append(result)

        // 各 chunk 完了直後に incremental save
        if let output = result.output {
            try? chunkProgressStore.add(knowledge: knowledge, chunkIndex: chunk.index, output: output)
        }
        processingMonitor?.updateProgress(articleID: articleID, index: results.count)
    }

    if Task.isCancelled { return }

    // === meta-summary ===
    let chunkEssences = results.compactMap { $0.output?.essence }
    let metaSummary = await extractor.extractMetaSummary(chunkEssences: chunkEssences)
    processingMonitor?.updateProgress(articleID: articleID, index: totalSteps)

    let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
    let aggregated = ChunkedKnowledgeAggregator.merge(results: results, metaSummary: metaSummary)
    let status = aggregated.determineStatus()

    switch status {
    case .failed:
        try? store.upsertFailure(article: article, reason: "全 \(chunks.count) chunk 失敗")
        try? chunkProgressStore.cleanup(knowledge: knowledge)  // cleanup
    case .succeeded, .partiallySucceeded:
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
        try? chunkProgressStore.cleanup(knowledge: knowledge)  // cleanup
    case .pending, .extracting, .skipped:
        break
    }
}
```

### 既存 spec 006 テスト互換

- Mock テストでは `chunkProgressStore` が default `NoopChunkProgressStore` のため、`fetchAll` は常に空 → 全 chunks を最初から処理 → spec 006 の既存挙動と同じ
- `add` / `cleanup` も noop なので、Mock store の検証ロジックには影響しない

### 新規テストケース (spec 009)

```swift
@Test("3 chunks 完了済の状態から extract → chunks 4-N + meta のみ呼ばれる")
func resumesFromIncrementalProgress()

@Test("各 chunk 完了で chunkProgressStore.add が呼ばれる")
func savesProgressIncrementally()

@Test("完了時に chunkProgressStore.cleanup が呼ばれる")
func cleansUpAfterCompletion()

@Test(".failed 完了時も chunkProgressStore.cleanup が呼ばれる")
func cleansUpOnFailure()

@Test("中断 (Task.isCancelled) で中間 progress は永続化済 (cleanup されない)")
func incrementalProgressSurvivesCancel()
```

## bootstrap 時の inject 変更

`KnowledgeTreeApp.swift`:

```swift
let chunkProgressStore = SwiftDataChunkProgressStore(
    context: context,
    refreshTrigger: refreshTrigger
)
let knowledgeService = DefaultKnowledgeExtractionService(
    extractor: knowledgeExtractor,
    store: knowledgeStore,
    processingMonitor: processingMonitor,
    chunkProgressStore: chunkProgressStore  // 新規
)
```

## 不変条件

1. extract(article:) の外部 API / 状態遷移は spec 006 と同一
2. chunkProgressStore.add は順番に呼ばれる (chunkIndex 0, 1, 2, ...)、reverse / random order 不可
3. 完了時 (succeeded / partial / failed) で chunkProgressStore.cleanup が必ず呼ばれる
4. 中断時 (Task.isCancelled) は cleanup されず、中間 progress が次回 resume で利用される

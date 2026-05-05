# Contract: KnowledgeExtractor (chunked extension)

**File**: `KnowledgeTree/Services/KnowledgeExtractor.swift` (既存に拡張)

## 責務

Foundation Models (`LanguageModelSession`) を直接呼び出す唯一の境界。spec 004 で `extract(extractedText:)` を、spec 005 で `defaultMaxBodyChars` 切り詰めを実装済。spec 006 では:

1. `extractFromChunk(_:)` 新設 — 1 chunk を処理する per-chunk 生成
2. `extractMetaSummary(chunkEssences:)` 新設 — 全 chunk の essence を統合する meta-summary 生成
3. `extract(extractedText:)` の挙動は **変更なし** (spec 004 既存、後方互換)
4. `buildPrompt(text:)` は per-chunk 用にそのまま流用、`buildMetaSummaryPrompt(chunkEssences:)` を別関数で新設

## API

```swift
@MainActor
struct KnowledgeExtractor {
    let session: LanguageModelSessionProtocol

    // 既存 (spec 004) — 1000 文字以下の単発パスで使用
    static let defaultMaxBodyChars = 1_000  // spec 005 の 1200 → 1000 に変更
    func extract(
        extractedText: String,
        maxBodyChars: Int = KnowledgeExtractor.defaultMaxBodyChars
    ) async throws -> ExtractedKnowledgeOutput

    // 新規 (spec 006) — chunked パス各 chunk
    func extractFromChunk(_ chunk: Chunk) async -> ChunkResult

    // 新規 (spec 006) — meta-summary
    func extractMetaSummary(chunkEssences: [String]) async -> ExtractedKnowledgeOutput?

    // 既存 + 新規 (内部)
    static func buildPrompt(text: String) -> String                       // 既存 (per-chunk と単発で共通)
    static func buildMetaSummaryPrompt(chunkEssences: [String]) -> String // 新規
    static func truncate(text: String, maxChars: Int) -> String           // 既存 (単発パス用)
}
```

## extractFromChunk の挙動

```swift
func extractFromChunk(_ chunk: Chunk) async -> ChunkResult {
    let prompt = Self.buildPrompt(text: chunk.text)
    do {
        let output = try await session.generateKnowledge(prompt: prompt)
        return ChunkResult(chunkIndex: chunk.index, output: output, error: nil)
    } catch {
        return ChunkResult(chunkIndex: chunk.index, output: nil, error: error)
    }
}
```

- chunk 失敗時は `ChunkResult(output: nil, error: error)` を返す (throw しない)
- 上位の Service 側で全失敗判定するため、各 chunk の失敗は集約で吸収

## extractMetaSummary の挙動

```swift
func extractMetaSummary(chunkEssences: [String]) async -> ExtractedKnowledgeOutput? {
    guard !chunkEssences.isEmpty else { return nil }
    let prompt = Self.buildMetaSummaryPrompt(chunkEssences: chunkEssences)
    do {
        return try await session.generateKnowledge(prompt: prompt)
    } catch {
        return nil
    }
}
```

- 入力空 → nil 返却 (Aggregator で fallback 処理)
- 失敗時 nil 返却 (上位で `.partiallySucceeded` 判定)

## buildMetaSummaryPrompt の出力例

```text
以下は記事の各部分から抽出した要点です。これらを統合して 1 つの記事全体の要約を作ってください。

# 統合ルール (厳守)
- 各部分の要点に明示されている内容のみを使ってください
- 推測・補完による情報の追加は行わないでください
- essence と summary は互いに矛盾しないでください
- すべて日本語で出力してください

# 各部分の要点
1. <chunk 1 essence>
2. <chunk 2 essence>
...
N. <chunk N essence>
```

prompt 文字数:
- instruction: ~150 文字
- 各 essence: 最大 150 文字 × 10 = 1500 文字
- 合計: ~1650 文字 ≒ 2800 token

context window 4096 token に対して 1300 token のマージン。

## 不変条件

1. `extractFromChunk` は throw しない (常に ChunkResult を返す)
2. `extractMetaSummary` は throw しない (常に Optional を返す)
3. 既存 `extract(extractedText:)` の API / 挙動は変更なし
4. session の呼び出しは 1 chunk あたり 1 回 + meta-summary 1 回 (chunked 1 記事で最大 11 回)

## テストケース

`KnowledgeExtractorTests.swift` (既存) に追加:

```swift
@Test("extractFromChunk 正常系: ChunkResult.output が non-nil")
func extractFromChunkSuccess()

@Test("extractFromChunk 異常系: session が throw → ChunkResult.error 設定")
func extractFromChunkFailure()

@Test("extractMetaSummary 正常系: ExtractedKnowledgeOutput を返す")
func extractMetaSummarySuccess()

@Test("extractMetaSummary 異常系: session が throw → nil")
func extractMetaSummaryFailure()

@Test("extractMetaSummary 入力空 → nil")
func extractMetaSummaryEmpty()

@Test("buildMetaSummaryPrompt 各 chunk essence が含まれる")
func buildMetaSummaryPromptContent()

@Test("buildMetaSummaryPrompt は元記事本文を含まない (per-chunk と区別)")
func metaSummaryPromptDoesNotContainBody()
```

## Service 側 (`DefaultKnowledgeExtractionService`) の影響

`extract(article:)` 内に分岐追加 (data-model.md セクション 5 参照):

```swift
if text.count <= 1000 {
    // 単発パス (spec 004 既存) — 変更なし
} else {
    // chunked パス (新規)
    let split = ChunkSplitter.split(text: text, maxChars: 1000, maxChunks: 10)
    monitor.start(.knowledge, articleID, title, progressIndex: 0, progressTotal: split.chunks.count + 1)
    var results: [ChunkResult] = []
    for (i, chunk) in split.chunks.enumerated() {
        if Task.isCancelled { break }
        let r = await extractor.extractFromChunk(chunk)
        results.append(r)
        monitor.updateProgress(articleID, index: i + 1)
    }
    let metaInput = results.compactMap { $0.output?.essence }.filter { !$0.isEmpty }
    let metaSummary = await extractor.extractMetaSummary(chunkEssences: metaInput)
    monitor.updateProgress(articleID, index: split.chunks.count + 1)
    let aggregated = ChunkedKnowledgeAggregator.merge(results: results, metaSummary: metaSummary)
    let status = aggregated.determineStatus()
    if status == .failed {
        try? store.upsertFailure(article, reason: "全 \(split.chunks.count) chunk 失敗")
    } else {
        try? store.upsertSucceeded(
            article: article,
            status: status,
            output: aggregated.toOutput(),
            modelVersion: nil,
            durationMs: durationMs,
            chunkProcessedCount: aggregated.successfulChunkCount + (metaSummary != nil ? 1 : 0),
            chunkTotalCount: split.chunks.count + 1,
            skippedTailChars: split.skippedTailChars
        )
    }
}
```

`upsertSucceeded` のシグネチャは新列 3 つを引数に追加 (default 値で既存呼び出しは無修正可能)。

## ProcessingMonitor の API 拡張

```swift
@MainActor
@Observable
final class ProcessingMonitor {
    // 既存
    func start(_ phase: Phase, articleID: UUID, title: String)
    func finish(articleID: UUID)

    // 新規 (spec 006)
    func start(
        _ phase: Phase,
        articleID: UUID,
        title: String,
        progressIndex: Int,    // 0 (まだ何も完了してない)
        progressTotal: Int     // 期待される完了数 (chunks + meta)
    )
    func updateProgress(articleID: UUID, index: Int)

    // ActiveTask 構造体に optional 2 fields 追加
    struct ActiveTask: Identifiable, Sendable {
        let id: UUID
        let articleTitle: String
        let phase: Phase
        let startedAt: Date
        var progressIndex: Int? = nil
        var progressTotal: Int? = nil
    }
}
```

`BottomStatusBar` の表示分岐:
- `progressIndex != nil && progressTotal != nil` → "知識抽出中 N/M" (例: "知識抽出中 3/6")
- それ以外 → "知識抽出中" (従来)

## 後方互換テスト

`KnowledgeExtractionServiceTests` の以下は **無修正で pass する**こと:
- `extractAlreadySucceededIsNoOp`
- `extractWhenAppleIntelligenceUnavailableMarksSkipped`
- `extractWithShortTextIsNoOp`
- `extractWithFullOutputMarksSucceeded` (本文 < 1000 文字テストケース)
- `extractWithEmptyOutputMarksFailed`
- `extractWithPartialOutputMarksPartiallySucceeded`
- `extractWhenModelThrowsMarksFailed`
- `backfillProcessesMultipleArticles`
- `determineStatusReturnsCorrectValue`

新規ケース追加:
- `extractWithLongTextSplitsIntoChunks`
- `extractWithLongTextAllChunksSucceedSavesMergedKnowledge`
- `extractWithLongTextOneChunkFailsMarksPartiallySucceeded`
- `extractWithLongTextAllChunksFailMarksFailed`
- `extractWithLongTextMetaSummaryFailsMarksPartiallySucceeded`
- `extractUpdatesMonitorProgressOnEachChunk`
- `extractWith15000CharsTruncatesTailAndRecordsSkipped`

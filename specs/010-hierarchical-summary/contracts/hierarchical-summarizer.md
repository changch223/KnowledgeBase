# Contract: HierarchicalChunkedSummarizer

**File**: `KnowledgeTree/Services/HierarchicalChunkedSummarizer.swift` (新規)

## 責務

階層化のグループ分割と lvl2/lvl3 の orchestration を担う純粋関数群。LM 呼び出し自体は `KnowledgeExtractor` に委譲。Service 層から呼び出される。

## API

```swift
enum HierarchicalChunkedSummarizer {
    /// chunks を groupSize ごとのバケットに分割。
    /// chunks=18, groupSize=10 → [[c0..c9], [c10..c17]]
    static func makeGroups<T>(_ items: [T], groupSize: Int = 10) -> [[T]]

    /// lvl2 中間 meta を逐次生成。
    /// 各グループの essences (lvl1 chunks の essence) を入力に extractMetaSummary を呼ぶ。
    /// progressCallback は lvl2 1 つ完了ごとに呼ばれる。
    static func runIntermediateMetaSummaries(
        groups: [[ChunkResult]],
        extractor: KnowledgeExtractor,
        progressCallback: ((Int) async -> Void)? = nil
    ) async -> [IntermediateMetaResult]

    /// lvl3 最終 meta を生成。
    /// lvl2 中間 meta の essences (失敗 nil は除外) を入力。
    /// 入力空 / 全失敗時は nil 返却。
    static func runFinalMetaSummary(
        intermediateResults: [IntermediateMetaResult],
        extractor: KnowledgeExtractor
    ) async -> ExtractedKnowledgeOutput?
}

struct IntermediateMetaResult: Sendable {
    let groupIndex: Int
    let chunkIndices: ClosedRange<Int>
    let output: ExtractedKnowledgeOutput?
    let error: Error?
}
```

## 動作詳細

### makeGroups

```swift
static func makeGroups<T>(_ items: [T], groupSize: Int = 10) -> [[T]] {
    precondition(groupSize >= 1)
    var result: [[T]] = []
    var index = 0
    while index < items.count {
        let end = min(index + groupSize, items.count)
        result.append(Array(items[index..<end]))
        index = end
    }
    return result
}
```

### runIntermediateMetaSummaries

```swift
static func runIntermediateMetaSummaries(
    groups: [[ChunkResult]],
    extractor: KnowledgeExtractor,
    progressCallback: ((Int) async -> Void)? = nil
) async -> [IntermediateMetaResult] {
    var results: [IntermediateMetaResult] = []
    for (i, group) in groups.enumerated() {
        if Task.isCancelled { break }
        let firstIndex = group.first?.chunkIndex ?? 0
        let lastIndex = group.last?.chunkIndex ?? firstIndex
        let essences = group.compactMap { $0.output?.essence }.filter { !$0.isEmpty }
        let output = await extractor.extractMetaSummary(chunkEssences: essences)
        results.append(IntermediateMetaResult(
            groupIndex: i,
            chunkIndices: firstIndex...lastIndex,
            output: output,
            error: output == nil ? NSError(domain: "intermediateMetaFailed", code: i) : nil
        ))
        await progressCallback?(i + 1)
    }
    return results
}
```

### runFinalMetaSummary

```swift
static func runFinalMetaSummary(
    intermediateResults: [IntermediateMetaResult],
    extractor: KnowledgeExtractor
) async -> ExtractedKnowledgeOutput? {
    let essences = intermediateResults.compactMap { $0.output?.essence }.filter { !$0.isEmpty }
    guard !essences.isEmpty else { return nil }
    return await extractor.extractMetaSummary(chunkEssences: essences)
}
```

## 不変条件

1. `makeGroups([], 10) == []`
2. `makeGroups(items, 1)` は items.count 個の単要素グループ
3. `makeGroups(items, n).flatMap { $0 } == items` (順序保持で全要素含む)
4. `runIntermediateMetaSummaries` は throw しない、失敗は IntermediateMetaResult.output == nil で表現
5. `runFinalMetaSummary` は入力空 / 全失敗時 nil

## テストケース

```swift
@Test("空配列は空配列")
func emptyArrayMakesEmpty()

@Test("18 items を 10 ずつ分割 → [10, 8]")
func eighteenSplits()

@Test("30 items を 10 ずつ → [10, 10, 10]")
func thirtySplits()

@Test("groupSize=1 で 5 items → 5 単要素グループ")
func sizeOneAllSingletons()

@Test("Mock extractor で 2 groups を順次処理")
func intermediateRuns()

@Test("Mock extractor が group 1 で throw → result.output == nil")
func intermediateHandlesFailure()

@Test("全 intermediate 失敗 → finalMetaSummary nil")
func finalNilWhenAllIntermediateFailed()

@Test("Task.isCancelled で intermediateMeta が中断")
func intermediateRespectsCancellation()
```

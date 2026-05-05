# Data Model: 階層的 chunked summarization (Phase 1)

**Feature**: spec 010
**Date**: 2026-05-05

## 1. 永続化エンティティ

新規追加なし。spec 009 の `KnowledgeChunkProgress` を lvl1 chunks 用にそのまま流用。

`ExtractedKnowledge` の既存列の扱い:

| 列 | spec 010 での意味 |
|---|---|
| `chunkProcessedCount` | 成功した LM 呼び出し数 (lvl1 + lvl2 + lvl3) |
| `chunkTotalCount` | 計画上の総 LM 呼び出し数 = lvl1 chunks + lvl2 グループ数 + 1 (lvl3) |
| `skippedTailChars` | 30,000 文字超過分の文字数 |

例 (chunks=18 文字数=18000):
- chunkTotalCount = 18 + 2 + 1 = 21
- chunkProcessedCount = 21 (全成功)
- skippedTailChars = 0

例 (chunks=5 文字数=5000):
- chunkTotalCount = 5 + 0 + 1 = 6 (lvl2 スキップ)
- chunkProcessedCount = 6 (全成功)

## 2. Transient エンティティ (in-memory only)

### IntermediateMetaResult

```swift
struct IntermediateMetaResult: Sendable {
    let groupIndex: Int                       // 0..<groupCount
    let chunkIndices: ClosedRange<Int>        // 該当する lvl1 chunkIndex 範囲
    let output: ExtractedKnowledgeOutput?     // 失敗時 nil
    let error: Error?
}
```

lvl2 中間 meta-summary 1 つの結果。in-memory only。

### HierarchicalAggregationInput

```swift
struct HierarchicalAggregationInput: Sendable {
    let lvl1Results: [ChunkResult]
    let lvl2Results: [IntermediateMetaResult]
    let lvl3Result: ExtractedKnowledgeOutput?  // lvl3 最終 meta、失敗時 nil
}
```

`ChunkedKnowledgeAggregator.mergeHierarchical(input:)` の入力。

## 3. 状態遷移 (ExtractionStatus)

spec 006 / 008 / 009 の遷移を維持 + 階層化判定の分岐追加:

```text
.pending
   │
   ▼ extract(article:)
.extracting
   │
   ├──── chunks <= 10 ──▶ spec 006 既存単一 meta パス
   │                       └─ 完了 → .succeeded / .partiallySucceeded / .failed
   │
   └──── chunks > 10 ──▶ spec 010 階層パス (lvl1 → lvl2 → lvl3)
                           ├─ lvl1 全成功 + lvl2 全成功 + lvl3 成功 → .succeeded
                           ├─ lvl1 1+ + lvl2 1+ + lvl3 失敗 → .partiallySucceeded (lvl2 連結 fallback)
                           ├─ lvl1 1+ + lvl2 全失敗 → .partiallySucceeded (lvl1 連結 fallback)
                           ├─ lvl2 1 つ失敗 + lvl3 成功 → .succeeded (lvl3 が他 lvl2 で補完)
                           └─ lvl1 全失敗 → .failed
```

## 4. データフロー

### 階層パス (chunks > 10)

```text
1. ChunkSplitter.split(text, maxChars=1000, maxChunks=30) → chunks
2. spec 009 incremental: 既完了 lvl1 chunks を chunkProgressStore.fetchAll で取得
3. 残り lvl1 chunks を逐次処理 + chunkProgressStore.add
4. 全 lvl1 chunks 完了 → results: [ChunkResult]
5. HierarchicalChunkedSummarizer.makeGroups(results, groupSize=10) → groups: [[ChunkResult]]
6. for each group:
       essences = group.compactMap { $0.output?.essence }
       intermediate = await extractor.extractMetaSummary(chunkEssences: essences)
       lvl2Results.append(IntermediateMetaResult(groupIndex, range, intermediate))
       monitor.updateProgress(articleID, index: ...)
7. lvl2Essences = lvl2Results.compactMap { $0.output?.essence }
8. lvl3Result = await extractor.extractMetaSummary(chunkEssences: lvl2Essences)
9. ChunkedKnowledgeAggregator.mergeHierarchical(input: ...) → AggregatedKnowledge
10. status = aggregated.determineStatus()
11. store.upsertSucceeded / upsertFailure
12. chunkProgressStore.cleanup
```

### 後方互換パス (chunks <= 10)

spec 006 そのまま。spec 010 では分岐の片側として保持。

## 5. 不変条件

| ID | 条件 |
|---|---|
| INV-1 | chunks <= 10 のとき lvl2/lvl3 は実行されない (spec 006 互換) |
| INV-2 | chunks > 10 のとき lvl2 グループ数 = `ceil(chunks/10)` |
| INV-3 | chunks > 10 のとき lvl3 は最大 1 回実行される (lvl2 全失敗の場合除く) |
| INV-4 | keyFacts / entities は lvl1 chunks の output からのみ集約される (lvl2/lvl3 は essence/summary のみ) |
| INV-5 | chunkTotalCount = chunks + (chunks > 10 ? ceil(chunks/10) : 0) + 1 |
| INV-6 | skippedTailChars = max(0, text.count - chunks.count * 1000) |

## 6. fixture

```swift
// Mock LM が各階層で異なる挙動をするテスト用
let chunks18Article = ...   // 18,000 chars 本文
// lvl1: 18 chunks → 18 LM 呼び出し
// lvl2: 2 groups (10 + 8 chunks) → 2 LM 呼び出し
// lvl3: 1 LM 呼び出し
// 合計 21 LM 呼び出し
// chunkProcessedCount = 21, chunkTotalCount = 21, skippedTailChars = 0
```

## 7. パフォーマンス

| chunks | lvl1 | lvl2 | lvl3 | 合計 LM | 推定時間 (各 25s) |
|---|---|---|---|---|---|
| 5 | 5 | 0 | 1 | 6 | 2.5 分 |
| 10 | 10 | 0 | 1 | 11 | 4.6 分 |
| 11 | 11 | 2 | 1 | 14 | 5.8 分 |
| 18 | 18 | 2 | 1 | 21 | 8.7 分 |
| 30 | 30 | 3 | 1 | 34 | 14.2 分 |

実行時間が 5 分超になるケースは spec 009 BGTask 経路を活用。

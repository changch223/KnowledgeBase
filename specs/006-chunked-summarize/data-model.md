# Data Model: 長文記事の Chunked Summarization (Phase 1)

**Feature**: spec 006
**Date**: 2026-05-05

spec 006 は spec 004 / 005 の `ExtractedKnowledge` を拡張する。新規エンティティの追加は無し (chunked 処理は transient データのみで完結)。

---

## 1. 永続化エンティティ (@Model)

### 1.1 ExtractedKnowledge (既存 + 列追加)

spec 004 で導入済の @Model を拡張する。**新規 3 列を追加**:

| 既存列 | 型 | 概要 |
|---|---|---|
| `id` | `UUID` | 主キー |
| `article` | `Article` | 元記事への非 optional 参照 (Constitution Principle III) |
| `statusRaw` | `String` | `ExtractionStatus` raw value |
| `essence` | `String?` | 1 文要約 (≤150 文字) |
| `summary` | `String?` | 数文要約 (≤300 文字) |
| `generatedAt` | `Date?` | 生成完了日時 |
| `modelVersion` | `String?` | 使用モデルバージョン |
| `extractionVersion` | `Int` | 抽出ロジックバージョン (chunked 導入後は 2 にバンプ) |
| `generationDurationMs` | `Int?` | 総生成時間 |
| `failureReason` | `String?` | spec 005 で追加。全失敗時の理由 |

| 新規列 | 型 | 概要 |
|---|---|---|
| `chunkProcessedCount` | `Int` | 成功した chunk 数 (含 meta-summary。未chunked 時は 1) |
| `chunkTotalCount` | `Int` | 総 chunk 数 (chunk 数 + meta-summary 1)。未chunked 時は 1 |
| `skippedTailChars` | `Int` | 10 chunk 上限超過で要約対象外となった末尾文字数 (未chunked 時は 0、10000 文字以下なら 0) |

**バリデーション**:
- `chunkProcessedCount >= 0`
- `chunkProcessedCount <= chunkTotalCount`
- `chunkTotalCount >= 1` (少なくとも 1 回の生成)
- `skippedTailChars >= 0`

**migration**: 既存 schema は migration 必要。SwiftData は同 schema version のままだと既存 DB の永続データに新列を追加 (lightweight migration)。新列の default 値:
- 既存レコード: `chunkProcessedCount = 1, chunkTotalCount = 1, skippedTailChars = 0` (単発生成済とみなす)

**migration 戦略**: `extractionVersion` を `1 → 2` にバンプし、新規生成時のみ chunked 列を意味ある値に。既存レコードは migration で default 0/0/0 が入る (extractionVersion 1 のまま)、ユーザーが Detail で再抽出ボタンを押せば最新ロジックで再生成。

### 1.2 KeyFact / KnowledgeEntity (既存、変更なし)

spec 004 既存の @Model。chunked 処理では複数 chunk から重複排除して統合した結果を保存する。

---

## 2. Transient エンティティ (永続化しない、処理中のみ)

### 2.1 Chunk

```swift
struct Chunk: Equatable, Sendable {
    let index: Int          // 0..<total
    let total: Int          // 総 chunk 数 (1..10)
    let text: String        // chunk の本文 (≤1000 chars)
}
```

**生成元**: `ChunkSplitter.split(text:maxChars:maxChunks:) -> [Chunk]`
**用途**: 各 chunk を 1 回ずつ Foundation Models に渡す
**永続化**: 無し (Service 内で配列保持、処理完了後は破棄)

### 2.2 ChunkResult

```swift
struct ChunkResult: Sendable {
    let chunkIndex: Int
    let output: ExtractedKnowledgeOutput?  // 失敗時 nil
    let error: Error?                      // 成功時 nil
}
```

**生成元**: `KnowledgeExtractor.extractFromChunk(_ chunk: Chunk) async -> ChunkResult`
**用途**: per-chunk の生成結果を保持。partial success の判定に使用
**永続化**: 無し

### 2.3 AggregatedKnowledge

```swift
struct AggregatedKnowledge: Sendable {
    let essence: String         // meta-summary の essence (or first chunk fallback)
    let summary: String         // meta-summary の summary (or chunks の連結 fallback)
    let keyFacts: [KeyFactOutput]    // 重複排除後の統合
    let entities: [KnowledgeEntityOutput]  // 重複排除後の統合
    let successfulChunkCount: Int
    let totalChunkCount: Int
    let metaSummarySucceeded: Bool
}
```

**生成元**: `ChunkedKnowledgeAggregator.merge(results: [ChunkResult], metaSummary: ExtractedKnowledgeOutput?) -> AggregatedKnowledge`
**用途**: Service 層が SwiftData に永続化する直前の中間表現
**永続化**: 無し

---

## 3. State Transition (ExtractionStatus)

spec 004 の `ExtractionStatus` enum はそのまま流用。chunked パスでも同じ状態遷移:

```text
.pending
   │
   ▼ extract(article:) 呼び出し
.extracting
   │
   ├──── 全 chunk 失敗 ──────▶ .failed (failureReason 設定)
   ├──── 1+ chunk 成功 + meta 成功 ──▶ .succeeded
   ├──── 1+ chunk 成功 + meta 失敗 ──▶ .partiallySucceeded
   ├──── 4 出力うち 1-3 のみ取得 (単発パス時のみ) ──▶ .partiallySucceeded
   ├──── Apple Intelligence 利用不可 ──▶ .skipped
   └──── 本文未取得 (text < 200 chars) ──▶ 状態変更なし (early return)
```

**重要**: chunked パス処理中の中間状態 (chunk 3/5 完了時点等) は **`.extracting` のまま保持**。ユーザーから見れば「処理中」、最後の meta-summary 完了 (or 失敗確定) で状態を遷移させる。途中状態を Detail 画面に出さないことで spec 005 の Detail UI 仕様 (extracting / pending → ProgressView 表示) と整合。

---

## 4. 既存型との互換性

| 型 | 変更 | 理由 |
|---|---|---|
| `ExtractedKnowledge` (@Model) | 列追加 (3 列) | chunk 数 / skip char の永続化 |
| `KeyFact` (@Model) | 変更なし | 既存スキーマで OK |
| `KnowledgeEntity` (@Model) | 変更なし | 既存スキーマで OK |
| `ExtractedKnowledgeOutput` (Generable) | 変更なし | per-chunk + meta-summary 共通で再利用 |
| `KeyFactOutput` (Generable) | 変更なし | per-chunk から得て aggregator が dedupe |
| `KnowledgeEntityOutput` (Generable) | 変更なし | 同上 |
| `ExtractionStatus` (enum) | 変更なし | partial success / failed / skipped は既存 case |
| `ProcessingMonitor.ActiveTask` (struct) | optional 2 fields 追加 | progress N/M 表示のため |

---

## 5. 生成 → 永続化のフロー

```text
1. Service.extract(article:) 呼び出し
2. body 未取得 → return
3. availability 不可 → upsertStatus(.skipped) → return
4. activeTasks に既存 → 待機 → return (重複抑止 spec 005)
5. text.count <= 1000 → 単発パス (spec 004 既存)
       upsertStatus(.extracting)
       extractor.extract(text:) → ExtractedKnowledgeOutput
       upsertSucceeded(article, status, output, ...,
                       chunkProcessedCount: 1,
                       chunkTotalCount: 1,
                       skippedTailChars: 0)
6. text.count > 1000 → chunked パス (新規)
       upsertStatus(.extracting)
       monitor.start(.knowledge, articleID, title, progressIndex: 0, progressTotal: chunks.count + 1)
       chunks = ChunkSplitter.split(text, maxChars: 1000, maxChunks: 10)
       skippedTailChars = max(0, text.count - chunks.totalChars)
       results = []
       for (i, chunk) in chunks.enumerated() {
           result = await extractor.extractFromChunk(chunk)
           results.append(result)
           monitor.updateProgress(articleID, index: i + 1)
       }
       metaInput = results.compactMap { $0.output?.essence }
       metaResult = await extractor.extractMetaSummary(chunkEssences: metaInput)
       monitor.updateProgress(articleID, index: chunks.count + 1)
       aggregated = ChunkedKnowledgeAggregator.merge(results: results, metaSummary: metaResult)
       status = aggregated.determineStatus()
       upsertSucceeded(article, status, aggregated.toOutput(),
                       chunkProcessedCount: aggregated.successfulChunkCount + (metaResult != nil ? 1 : 0),
                       chunkTotalCount: chunks.count + 1,
                       skippedTailChars: skippedTailChars)
       monitor.finish(articleID)
```

`ChunkedKnowledgeAggregator.determineStatus()` ロジック:
- `successfulChunkCount == 0` → `.failed`
- `successfulChunkCount > 0 && metaSummarySucceeded` → `.succeeded`
- `successfulChunkCount > 0 && !metaSummarySucceeded` → `.partiallySucceeded`

---

## 6. 永続化 schema migration

SwiftData lightweight migration:
1. `ExtractedKnowledge` に 3 列追加 (default 値あり)
2. SwiftData が自動マイグレーション (新列に default 値挿入)
3. アプリ起動時に migration が走る (透過的)
4. 既存データは `chunkProcessedCount = 1, chunkTotalCount = 1, skippedTailChars = 0` で扱われる
5. ユーザーが Detail 画面の再抽出ボタンを押した場合のみ最新ロジックで上書き

**spec 005 の `failureReason` 列追加と同じパターン** で SwiftData が安全に処理する。手動 migration コード不要。

---

## 7. テスト用 fixture

`KnowledgeTreeTests/` で以下の sample text を fixture とする:

| Fixture | 文字数 | 期待 chunk 数 | 用途 |
|---|---|---|---|
| `shortBody` | 800 | 0 (単発パス) | 単発パス互換性 |
| `mediumBody` | 2500 | 3 | 一般的な chunked |
| `longBody` | 9500 | 10 | 上限ぎりぎり |
| `oversizeBody` | 15000 | 10 + skipped 5000 | tail truncation |
| `noFullStopBody` | 1500 | 2 (hard cut) | 句点無し境界 |

各 fixture は `BodyFixtures.swift` (新規) または既存テスト helper に追加。

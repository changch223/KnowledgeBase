# Data Model: バックグラウンド AI 抽出継続 (Phase 1)

**Feature**: spec 009
**Date**: 2026-05-05

## 1. 永続化エンティティ (@Model)

### 1.1 KnowledgeChunkProgress (新規 @Model)

各 chunk の生成結果を JSON 文字列で保持し、リジューム時に LM 再呼び出しを省略する。

```swift
@Model
final class KnowledgeChunkProgress {
    @Attribute(.unique) var id: UUID
    var knowledge: ExtractedKnowledge   // cascade inverse
    var chunkIndex: Int                  // 0..<chunkTotalCount-1 (meta は除く)
    var chunkOutputJSON: String          // ExtractedKnowledgeOutput を Codable で encode
    var savedAt: Date

    init(
        id: UUID = UUID(),
        knowledge: ExtractedKnowledge,
        chunkIndex: Int,
        chunkOutputJSON: String,
        savedAt: Date = Date()
    ) { ... }
}
```

**バリデーション**:
- `chunkIndex >= 0 && chunkIndex < 10` (spec 006 の最大 chunk 数)
- `chunkOutputJSON` は valid JSON で `ExtractedKnowledgeOutput` decode 可能
- 同 `knowledge` 内で `chunkIndex` は unique (DB 制約は無いがアプリ層で重複防止)

**Lifecycle**:
- chunked extraction で 1 chunk 完了 → insert
- 全 chunks + meta-summary 完了 → ExtractedKnowledge.upsertSucceeded で全件 cascade delete
- ExtractedKnowledge.status が `.failed` (全 chunk 失敗) → cleanup されるが essence/summary は空のまま

### 1.2 BackgroundExtractionQueueEntry (新規 @Model)

BGTask が起動した時に処理する article の queue。

```swift
@Model
final class BackgroundExtractionQueueEntry {
    @Attribute(.unique) var id: UUID
    var articleID: UUID                  // Article.id への soft reference
    var queuedAt: Date

    init(id: UUID = UUID(), articleID: UUID, queuedAt: Date = Date()) { ... }
}
```

**バリデーション**:
- `articleID` は Article.id を参照 (但し relationship ではなく単純 UUID)
- 同 articleID で複数 entry が存在しないこと (アプリ層で重複防止)

**Lifecycle**:
- chunked extraction が始まった article ID を enqueue
- BGTask 起動時に最古 (queuedAt 昇順) を dequeue
- 該当 Article が削除されていれば skip + entry 削除
- chunked 処理完了 (`.succeeded` / `.partiallySucceeded` / `.failed`) で entry 削除

### 1.3 ExtractedKnowledge (既存 + 1 relationship 追加)

| 既存フィールド | 型 | 概要 |
|---|---|---|
| (spec 004-008 で定義済) | ... | ... |
| `chunkProcessedCount` | `Int` | 既存 (spec 006) |
| `chunkTotalCount` | `Int` | 既存 (spec 006) |
| `skippedTailChars` | `Int` | 既存 (spec 006) |

| 新規 relationship | 型 | 概要 |
|---|---|---|
| `chunkProgress` | `[KnowledgeChunkProgress]` | cascade delete inverse |

```swift
@Relationship(deleteRule: .cascade, inverse: \KnowledgeChunkProgress.knowledge)
var chunkProgress: [KnowledgeChunkProgress] = []
```

**Migration**: SwiftData lightweight migration で relationship 追加 (default `[]` で既存レコード自動)。spec 005-008 の column 追加と同じパターン。

### 1.4 SharedSchema (既存 + 2 新規 entity 追加)

```swift
static var all: Schema {
    Schema([
        Article.self,
        ArticleEnrichment.self,
        ArticleBody.self,
        ExtractedKnowledge.self,
        KeyFact.self,
        KnowledgeEntity.self,
        Tag.self,
        KnowledgeChunkProgress.self,            // spec 009 新規
        BackgroundExtractionQueueEntry.self,    // spec 009 新規
    ])
}
```

Share Extension target にも `KnowledgeChunkProgress.swift` と `BackgroundExtractionQueueEntry.swift` の membership 追加が必要 (spec 005 / 008 で確立した pattern)。

## 2. Generable types に Codable を追加

spec 004 で定義済の Generable types を Codable 準拠化:

```swift
@Generable
struct ExtractedKnowledgeOutput: Codable {  // Codable 追加
    let essence: String
    let summary: String
    let keyFacts: [KeyFactOutput]
    let entities: [KnowledgeEntityOutput]
}

@Generable
struct KeyFactOutput: Codable {
    let statement: String
    let type: FactType
}

@Generable
enum FactType: String, Codable {  // raw value で Codable
    case event, claim, statistic, definition, quote
}

@Generable
struct KnowledgeEntityOutput: Codable {
    let name: String
    let type: EntityType
    let salience: Int
}

@Generable
enum EntityType: String, Codable {
    case person, organization, location, concept, product, work
}
```

**Encoder / Decoder**: `JSONEncoder` / `JSONDecoder` 標準。`KnowledgeChunkProgress.chunkOutputJSON` の encode/decode は `ChunkProgressStore` 内のヘルパで集約。

## 3. State Transition (ExtractionStatus)

spec 006 の状態遷移を継承 + BGTask 経路の追加:

```text
.pending
   │
   ▼ extract(article:) 呼び出し (前景 or BGTask)
.extracting
   │
   ├──── 全 chunks 完了 + meta-summary 成功 ──▶ .succeeded
   │      (KnowledgeChunkProgress を cleanup)
   ├──── 1+ chunk 成功 + meta 失敗 ────────▶ .partiallySucceeded
   │      (KnowledgeChunkProgress を cleanup、最初の chunk を fallback)
   ├──── 全 chunks 失敗 ─────────────────▶ .failed
   │      (KnowledgeChunkProgress を cleanup)
   ├──── BGTask 時間切れ (中断) ──────────▶ .extracting のまま (中間 KnowledgeChunkProgress 保持)
   │      (queue entry を保持、次回 BGTask で再開)
   ├──── Apple Intelligence 不可 ──────────▶ .skipped
   ├──── 本文未取得 ─────────────────────▶ 状態変更なし (early return)
   └──── アプリ完全終了 → 再起動 ──────────▶ spec 008 backfill が pickup → 再開
```

**incremental resume の挙動**:
1. extract(article:) 呼び出し
2. status が `.extracting` でも続行 (spec 008 fix で実装済)
3. ChunkSplitter.split で同じ chunks を再生成
4. `chunkProgress` から既完了 chunkIndex を取得
5. 残り chunkIndex のみ LM に渡す
6. 全 chunks + meta 完了 → 既存 ChunkedKnowledgeAggregator.merge → upsertSucceeded

## 4. データフロー

### 4.1 chunked extraction 開始時 (前景)

```text
1. Service.extract(article:) 呼び出し
2. (spec 005-008 ガード省略)
3. 本文 > 1000 chars → chunked パス分岐
4. monitor.start(.knowledge, ..., progressIndex: 0, progressTotal: chunks+1)
5. 各 chunk:
     - extractor.extractFromChunk(chunk) → output
     - chunkProgressStore.add(knowledge, chunkIndex, JSON.encode(output))   // NEW: incremental save
     - monitor.updateProgress(articleID, index: i+1)
6. meta-summary:
     - extractor.extractMetaSummary(chunkEssences)
     - aggregator.merge(results, metaSummary)
     - store.upsertSucceeded(article, status, output, ...)
7. chunkProgressStore.cleanup(knowledge)   // 全 progress を削除
8. monitor.finish(articleID)
```

### 4.2 chunked extraction の中断 → BGTask 再開

```text
[前景処理中の任意のタイミング]
  ・ ユーザーがデバイスをロック
  ・ アプリが background 移行 (scenePhase == .background)
  ↓
1. KnowledgeExtractionService が「処理中の article がある」と判断
   → queue.enqueue(articleID)
   → scheduler.scheduleBGTaskIfNeeded()
2. iOS が最適タイミングで BGTask を dispatch
   ↓
3. BackgroundExtractionScheduler.handler(task:) 起動
   ↓
4. queue.dequeue() で article 取り出し
5. BackgroundExtractionRunner.run(article: article, task: backgroundTask)
   ↓
6. knowledgeService.extract(article:) 呼び出し
   ↓
7. spec 008 ガード: status .extracting でも続行 (stale state recovery)
8. ChunkSplitter で chunks 再生成
9. chunkProgressStore.fetchAll(knowledge) で完了 chunkIndex 取得
10. 残り chunks のみ LM 呼び出し → 各完了で incremental save
11. expirationHandler 発動 → currentTask.cancel() → setTaskCompleted(success: false)
    → queue.enqueue(articleID) で再 enqueue → scheduleNext で次回予約
12. 全 chunks + meta 完了 → upsertSucceeded → cleanup → queue.remove(articleID)
```

### 4.3 アプリ完全終了 → 再起動 (spec 008 フォールバック)

```text
[アプリ完全終了中]
  ・ BGTask が走らなかった (system 判断による未 dispatch)
  ↓
[ユーザーがアプリを再起動]
1. App.init() で BackgroundExtractionScheduler.registerHandler() を呼ぶ
2. bootstrap で knowledgeService.backfillAll() を呼ぶ
3. fetchPendingArticles が `.extracting` 残骸を pickup (spec 008 既存)
4. extract(article:) 呼び出し
5. chunkProgressStore.fetchAll(knowledge) で既完了 chunkIndex 取得
6. 残り chunks のみ LM 呼び出し → ... (4.2 と同じ流れ)
```

## 5. 不変条件

| ID | 不変条件 |
|---|---|
| INV-1 | KnowledgeChunkProgress.chunkIndex は同 knowledge 内で重複しない |
| INV-2 | ExtractedKnowledge.status == `.succeeded` のとき chunkProgress は空 (cleanup 済) |
| INV-3 | ExtractedKnowledge.status == `.extracting` のとき chunkProgress 0+ 件 |
| INV-4 | BackgroundExtractionQueueEntry.articleID で参照される Article が削除されたら、entry も削除される (BGTask 起動時に検出) |
| INV-5 | extract(article:) 完了時 (succeeded/partial/failed) は queue から該当 entry を必ず削除 |

## 6. テスト用 fixture

```swift
// 5 chunks 必要な記事の incremental progress
let knowledge = ExtractedKnowledge(article: article, status: .extracting)
let progress0 = KnowledgeChunkProgress(
    knowledge: knowledge,
    chunkIndex: 0,
    chunkOutputJSON: """
        {"essence":"chunk0 essence","summary":"chunk0 summary","keyFacts":[],"entities":[]}
    """
)
// progress1, progress2 同様 (chunks 0-2 完了済)
// chunks 3-4 は未処理
// resume 時に extract(article:) 呼ぶと chunks 3-4 + meta-summary のみ実行される
```

## 7. パフォーマンス特性

| 操作 | 計算量 | 期待時間 |
|---|---|---|
| chunkProgress.add (1 chunk) | O(1) insert + save | < 50 ms |
| chunkProgress.fetchAll(knowledge) | O(N) where N = 完了 chunks | < 10 ms (10 件以下) |
| chunkProgress.cleanup(knowledge) | O(N) cascade delete | < 50 ms |
| queue.enqueue / dequeue | O(1) | < 10 ms |
| queue.fetchOldest | O(N) sort + fetchLimit 1 | < 50 ms |
| BGTask register (App.init) | O(1) | < 1 ms |

すべて Constitution パフォーマンスゲート (100 ms 入力フィードバック) 内。

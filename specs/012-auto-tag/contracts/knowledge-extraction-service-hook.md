# Contract: KnowledgeExtractionService Hook

**Created**: 2026-05-05
**File**: `KnowledgeTree/Services/KnowledgeExtractionService.swift` (改修)

## 責務

`DefaultKnowledgeExtractionService` に **AutoTagApplier 呼び出し hook** を組み込む。単一パス + chunked パスの両方で `upsertSucceeded` 直後に発火。

## 改修内容

### 1. プロパティ追加

```swift
final class DefaultKnowledgeExtractionService: KnowledgeExtractionServiceProtocol {
    private let extractor: KnowledgeExtractor
    private let store: ArticleKnowledgeStoreProtocol
    private let processingMonitor: ProcessingMonitor?
    private let chunkProgressStore: ChunkProgressStoreProtocol?
    private let tagStore: TagStore?    // ← 新規
    
    // ...
}
```

### 2. イニシャライザ拡張

```swift
init(
    extractor: KnowledgeExtractor,
    store: ArticleKnowledgeStoreProtocol,
    processingMonitor: ProcessingMonitor? = nil,
    chunkProgressStore: ChunkProgressStoreProtocol? = nil,
    tagStore: TagStore? = nil    // ← 新規 default nil
) {
    self.extractor = extractor
    self.store = store
    self.processingMonitor = processingMonitor
    self.chunkProgressStore = chunkProgressStore
    self.tagStore = tagStore    // ← 新規
}
```

### 3. プライベート helper 追加

```swift
private func applyAutoTagsIfPossible(article: Article) {
    guard let tagStore else { return }
    AutoTagApplier.apply(to: article, using: tagStore)
}
```

### 4. 単一パス hook (line 140-146 直後)

**Before** (現状):
```swift
case .success(let output):
    let status = Self.determineStatus(output: output)
    logger.notice(...)
    if status == .failed {
        try? store.upsertFailure(article: article, reason: "...")
    } else {
        try? store.upsertSucceeded(
            article: article,
            status: status,
            output: output,
            modelVersion: nil,
            durationMs: durationMs
        )
    }
```

**After** (改修後):
```swift
case .success(let output):
    let status = Self.determineStatus(output: output)
    logger.notice(...)
    if status == .failed {
        try? store.upsertFailure(article: article, reason: "...")
    } else {
        try? store.upsertSucceeded(
            article: article,
            status: status,
            output: output,
            modelVersion: nil,
            durationMs: durationMs
        )
        applyAutoTagsIfPossible(article: article)    // ← 1 行追加
    }
```

### 5. Chunked パス hook (line 294-306 直後)

**Before** (現状):
```swift
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
```

**After** (改修後):
```swift
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
    applyAutoTagsIfPossible(article: article)    // ← 1 行追加
```

## 改修の network 効果

| 経路 | 自動波及 |
|---|---|
| Detail「再抽出」ボタン → `knowledgeService.extract(article:)` | ✅ (hook 経由) |
| spec 002 enrichment chain → bodyService.extract → knowledgeService.extract | ✅ (hook 経由) |
| spec 009 BG task → `BackgroundExtractionRunner.runOne()` → `knowledgeService.extract()` | ✅ (hook 経由) |
| spec 010 階層的 chunk summarization → 同 service 内 `performChunkedExtraction` → 同 `upsertSucceeded` | ✅ (hook 経由) |
| bootstrap backfill → `knowledgeService.backfillAll()` → 順次 `extract()` | ✅ (hook 経由、ただし既存タグありの記事は早期 skip) |

## bootstrap での DI

```swift
// KnowledgeTreeApp.swift bootstrap()
let tagStore = TagStore(context: context, refreshTrigger: refreshTrigger)

let knowledgeService = DefaultKnowledgeExtractionService(
    extractor: knowledgeExtractor,
    store: knowledgeStore,
    processingMonitor: processingMonitor,
    chunkProgressStore: chunkProgressStore,
    tagStore: tagStore    // ← spec 012 で追加
)
```

bootstrap 内で TagStore 構築 → knowledgeService に inject。1 行のみ追加。

## 後方互換性

- `tagStore: nil` (default) なら apply は no-op → 既存テスト全 pass
- 既存テスト (`KnowledgeExtractionServiceTests`) は `tagStore` を渡していないので動作変更ゼロ
- 新規テスト (`AutoTagApplierTests`) のみ TagStore 込みで検証

## 副作用順序

1. `try? store.upsertSucceeded(...)` で `ExtractedKnowledge.statusRaw = .succeeded` (or .partiallySucceeded) を確定
2. `try? chunkProgressStore.cleanup(...)` で chunked 中間データ削除 (chunked パスのみ)
3. `applyAutoTagsIfPossible(article:)` で auto-apply 実行
4. `TagStore.addTag` 内で `RefreshTrigger.bump()` 発火 → UI 即時更新
5. KnowledgeExtractionService.run の SwiftUI body 復帰 (BG task の場合は task expire まで)

## エラーハンドリング

- `applyAutoTagsIfPossible` は内部で `try?` (AutoTagApplier 経由) なので throw しない
- もし AutoTagApplier 内で uncaught panic があれば、knowledge 抽出全体は既に完了しているため (upsertSucceeded 完了後) 影響軽微
- Constitution Principle II の「graceful failure」を満たす

## テスト追加

新規 hook の integration test は本 spec ではスコープ外 (Constitution テストゲート的に AutoTagApplierTests で十分)。`KnowledgeExtractionServiceTests` は既存通り (tagStore: nil で動作確認継続)。

将来 spec で integration test を追加する場合のシナリオ:
- 短文記事 → run() → tags 5 件
- 長文記事 → performChunkedExtraction() → tags 5 件
- 失敗記事 → run() → tags 0 件
- 既存タグあり記事 → run() → tags 不変

これらは MVP では実機 quickstart 検証で代用 (quickstart.md 参照)。

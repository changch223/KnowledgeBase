# Contract: BackgroundExtractionRunner

**File**: `KnowledgeTree/Services/BackgroundExtractionRunner.swift` (新規)

## 責務

BGTask 実行コンテキスト内で、1 article の chunked knowledge extraction を進める。前景の `KnowledgeExtractionService.extract(article:)` を経由することで、incremental save / 重複抑止 / availability チェックを継承する。

## API

```swift
@MainActor
final class BackgroundExtractionRunner {
    private let knowledgeService: KnowledgeExtractionServiceProtocol
    private let articleStore: ArticleStoreProtocol
    private var currentTask: Task<Void, Never>?

    init(
        knowledgeService: KnowledgeExtractionServiceProtocol,
        articleStore: ArticleStoreProtocol
    )

    /// queue から取り出した article ID で chunked extraction を実行する。
    /// - Returns: success (全 chunks + meta 完了) なら true、時間切れ / 中断なら false
    @discardableResult
    func run(articleID: UUID) async -> Bool

    /// 進行中の処理を即停止 (expirationHandler から呼ばれる)。
    func cancelCurrent()
}
```

## 動作詳細

### run(articleID:)

```swift
@discardableResult
func run(articleID: UUID) async -> Bool {
    // 1. Article を SwiftData から fetch
    guard let article = try? articleStore.fetchByID(articleID) else {
        return true  // 削除済 (skip 扱い、success)
    }

    // 2. knowledgeService.extract を呼び出し
    //    - spec 008 fbcde69 ガード: status .extracting でも続行
    //    - spec 005 重複抑止ガード: activeTasks に既存 task があれば待機
    //    - chunked パスは内部で resume 判定 (ChunkProgressStore 経由)
    let task = Task { [weak self] in
        await self?.knowledgeService.extract(article: article)
    }
    currentTask = task
    defer { currentTask = nil }

    await task.value

    // 3. 完了状態を確認
    let finalStatus = article.extractedKnowledge?.status
    return finalStatus == .succeeded || finalStatus == .partiallySucceeded || finalStatus == .skipped
}
```

### cancelCurrent

```swift
func cancelCurrent() {
    currentTask?.cancel()
    // KnowledgeExtractionService.activeTasks 内の Task も Task.isCancelled で停止する
}
```

## 既存サービスとの統合

`BackgroundExtractionRunner.run` は **薄い wrapper** であり、実処理は `KnowledgeExtractionService.extract` 経由。

これにより:
- spec 005 の重複抑止が BGTask 内でも機能 (前景処理と衝突しない)
- spec 006 の chunked パスがそのまま動作 (incremental save も継承)
- spec 008 の stale state 自動回復ロジックが BGTask 内でも有効
- KnowledgeExtractor の availability チェックが BGTask 内でも動く (`SystemLanguageModel.availability`)

## 不変条件

1. `run(articleID:)` は throw しない (Bool を返す、内部エラーはログのみ)
2. articleID で参照される Article が削除されていれば success: true で return
3. `cancelCurrent` は idempotent (複数回呼んでもクラッシュしない)
4. cancellation 後の SwiftData 状態は spec 006 の incremental save により最終 chunk の進捗まで保持

## テストケース

```swift
@Test("削除済み articleID で run → true (success)")
func deletedArticleReturnsTrue()

@Test("有効な article で run → knowledgeService.extract が呼ばれる")
func validArticleDispatches()

@Test("status .succeeded で完了 → run は true を返す")
func succeededReturnsTrue()

@Test("status .extracting (中断) で完了 → run は false を返す")
func extractingReturnsFalse()

@Test("cancelCurrent で進行中 task が cancel される")
func cancelStopsTask()

@Test("incremental progress (3 chunks 完了済) を持つ article で run → chunks 4-N + meta のみ実行")
func resumeFromIncrementalProgress()  // Mock LM で chunkIndex 0-2 は呼ばれない確認
```

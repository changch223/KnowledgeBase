# Contract: AutoTagBackfillRunner

**Created**: 2026-05-05
**File**: `KnowledgeTree/Services/AutoTagBackfillRunner.swift`

## 責務

bootstrap で 1 回呼ばれ、UserDefaults フラグが false なら既存全 article を走査して tags 0 件 + knowledge succeeded のものに `AutoTagApplier.apply()` を適用、完了でフラグ true セット。再実行防止 + UI 進捗表示 + ロギング。

## API

```swift
@MainActor
final class AutoTagBackfillRunner {
    private let context: ModelContext
    private let tagStore: TagStore
    private let processingMonitor: ProcessingMonitor?
    private let flagStore: BackfillFlagStore
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "auto-tag-backfill")

    init(
        context: ModelContext,
        tagStore: TagStore,
        processingMonitor: ProcessingMonitor? = nil,
        flagStore: BackfillFlagStore = UserDefaultsBackfillFlagStore()
    )

    /// bootstrap で 1 回呼ばれる。フラグが既に true なら early return。
    /// 全候補 article を AutoTagApplier.apply で処理 → 完了でフラグ true。
    func run() async
}
```

## 入力契約

| パラメータ | 型 | 制約 |
|---|---|---|
| `context` | `ModelContext` | bootstrap の sharedModelContainer.mainContext を渡す |
| `tagStore` | `TagStore` | bootstrap で構築済の TagStore (spec 008) |
| `processingMonitor` | `ProcessingMonitor?` | UI 進捗表示用 (nil でも動作、テスト時 nil 可) |
| `flagStore` | `BackfillFlagStore` | default `UserDefaultsBackfillFlagStore()`、test で InMemory 注入可 |

## 出力契約

戻り値なし (副作用のみ):

- 各候補 article の `tags` に 0〜5 件の Tag 追加 (TagStore 経由)
- `flagStore.markCompleted()` で次回起動時の重複実行防止
- `processingMonitor.start(.tagBackfilling, ...)` / `finish` の呼び出しで BottomStatusBar 表示
- Logger に進捗ログ (info / debug / error)

## アルゴリズム

```
func run() async {
    // 1. フラグチェック (FR-002)
    guard !flagStore.isCompleted() else {
        logger.debug("auto-tag backfill skipped: already completed")
        return
    }
    
    // 2. 候補取得 (FR-006 / FR-007)
    let descriptor = FetchDescriptor<Article>(
        sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
    )
    let allArticles = (try? context.fetch(descriptor)) ?? []
    let candidates = allArticles.filter { article in
        guard article.tags.isEmpty else { return false }
        guard let knowledge = article.extractedKnowledge else { return false }
        return knowledge.status == .succeeded || knowledge.status == .partiallySucceeded
    }
    
    logger.notice("auto-tag backfill starting: \(candidates.count)/\(allArticles.count) candidates")
    
    // 3. UI 進捗開始 (FR-014 / FR-015)
    let backfillID = Self.backfillProcessingID
    processingMonitor?.start(
        .tagBackfilling,
        articleID: backfillID,
        title: "全タグ整理中",
        progressIndex: 0,
        progressTotal: candidates.count
    )
    
    // 4. 各候補処理 (FR-010 / FR-013)
    var processedIndex = 0
    for article in candidates {
        AutoTagApplier.apply(to: article, using: tagStore)
        processedIndex += 1
        processingMonitor?.updateProgress(articleID: backfillID, index: processedIndex)
    }
    
    // 5. UI 進捗終了 (FR-017)
    processingMonitor?.finish(articleID: backfillID)
    
    // 6. フラグセット (FR-003)
    flagStore.markCompleted()
    
    logger.notice("auto-tag backfill completed: processed \(processedIndex) articles")
}

// 固定 UUID for backfill 用の ProcessingMonitor key
static let backfillProcessingID = UUID(uuidString: "00000000-0000-0000-0000-AB13BACFB13F")!
```

## エラーハンドリング

- `context.fetch` 失敗 → empty array で続行 (`(try? context.fetch(descriptor)) ?? []`)
- AutoTagApplier.apply 内の例外は AutoTagApplier 内で `try?` 吸収 (spec 012 既存)
- ループ全体に try/catch は不要 (内部例外なし)
- flagStore.markCompleted の失敗は実質起こらないが、起こっても次回起動で再実行される (副作用は冪等)

## ロギング

- `Logger(subsystem: "app.KnowledgeTree", category: "auto-tag-backfill")`
- skip case → `.debug`: "skipped: already completed"
- 開始 → `.notice`: "starting: N/M candidates"
- 完了 → `.notice`: "completed: processed N articles"

## ProcessingMonitor 連携

- `processingMonitor.start(.tagBackfilling, articleID: backfillProcessingID, title: "全タグ整理中", progressIndex: 0, progressTotal: candidates.count)` で BottomStatusBar に「タグ整理中 0/100」表示
- 各 article 処理ごとに `updateProgress(articleID:, index: processedIndex)` で「タグ整理中 N/100」へ
- 全完了で `finish(articleID:)` で BottomStatusBar 非表示
- backfillProcessingID は backfill 専用の固定 UUID で、通常の Article.id と衝突しない (00000000 prefix で明示)

## パフォーマンス

| 件数 | 期待実行時間 | メモリ |
|---|---|---|
| 0 件 | 即時 (~10ms) | < 1KB |
| 100 件 | ~30 秒 (各 article 50ms × 5 タグ + bookkeeping) | ~100KB |
| 1000 件 | ~5 分 (50ms × 1000 = 50 秒、+ TagStore 書き込みのバッチ) | ~1MB |
| 10000 件 | ~50 分 (許容、SC 設定なし) | ~10MB |

10000 件は practically 起動が長すぎるが、極端ケースで crash しないことのみ保証 (Constitution パフォーマンスゲート 100ms 以内ではないが、起動時 1 回限定 + BottomStatusBar 表示で UX 整合)。

## 副作用境界

- `tagStore.addTag` 内で `RefreshTrigger.bump` 発火 → spec 011 KnowledgeMap で新ノード fade-in
- ProcessingMonitor の状態変化 → `BottomStatusBar` の表示更新
- UserDefaults への 1 回だけ書き込み

## テスト

`KnowledgeTreeTests/AutoTagBackfillRunnerTests.swift`:

| Test | 検証 |
|---|---|
| `testFlagFalseRunsBackfill` | InMemoryBackfillFlagStore (false) → run → 候補に tag 付与 + flag = true |
| `testFlagTrueSkipsBackfill` | InMemoryBackfillFlagStore (true) → run → 候補不変、flag = true 維持 |
| `testOnlyTargetsArticlesWithEmptyTagsAndSucceededKnowledge` | 4 種類混在 (target / tag 既存 / failed / pending) → target のみ tag 付与 |
| `testSkipsArticlesWithExistingTags` | tags 1 件付き → 触られず |
| `testSkipsArticlesWithFailedKnowledge` | status = .failed → 触られず |
| `testProcessesNewestFirst` | savedAt 異なる 3 article → 処理順序が savedAt desc |
| `testHandlesEmptyDatabase` | article 0 件 → crash せず flag = true |

各テストで:
- `private typealias Tag = KnowledgeTree.Tag`
- in-memory ModelContainer
- `InMemoryBackfillFlagStore()` を inject
- `TagStore(context:, refreshTrigger: nil)` を構築
- `AutoTagBackfillRunner(context:, tagStore:, processingMonitor: nil, flagStore:).run()` を await

## 依存

- `Article`, `Tag`, `KnowledgeEntity`, `ExtractedKnowledge` (既存 @Model)
- `AutoTagApplier.apply()` (spec 012 既存)
- `TagStore.addTag()` (spec 008 既存)
- `SuggestedTagFinder.find()` (spec 008 既存、AutoTagApplier 経由で間接利用)
- `ProcessingMonitor` (spec 005 既存、`.tagBackfilling` Phase 拡張)
- `BackfillFlagStore` (本 spec で新規 protocol、UserDefaultsBackfillFlagStore + InMemoryBackfillFlagStore 実装)

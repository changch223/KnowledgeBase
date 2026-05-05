# Contract: AutoCategoryBackfillRunner

**File**: `KnowledgeTree/Services/AutoCategoryBackfillRunner.swift`

## 責務

bootstrap で 1 度限り、既存全 Tag (`categoryRaw == nil`) を AutoCategoryClassifier で classify、`categoryRaw` を更新。spec 013 AutoTagBackfillRunner と完全同パターン。

## API

```swift
@MainActor
final class AutoCategoryBackfillRunner {
    static let backfillProcessingID = UUID(uuidString: "00000000-0000-0000-0000-CA7E0CEAA70F")!

    init(
        context: ModelContext,
        classifier: AutoCategoryClassifier,
        processingMonitor: ProcessingMonitor? = nil,
        flagStore: BackfillFlagStore = UserDefaultsBackfillFlagStore(key: "auto_category_backfill_v1_done")
    )

    func run() async
}
```

## 入力契約

| パラメータ | 型 | 制約 |
|---|---|---|
| `context` | `ModelContext` | bootstrap の `sharedModelContainer.mainContext` を渡す |
| `classifier` | `AutoCategoryClassifier` | spec 015 の AutoCategoryClassifier |
| `processingMonitor` | `ProcessingMonitor?` | UI 進捗表示用 (nil でも動作) |
| `flagStore` | `BackfillFlagStore` | default `UserDefaultsBackfillFlagStore(key: "auto_category_backfill_v1_done")`、test で InMemory 注入可 |

## 出力契約

戻り値なし (副作用のみ):

- 各候補 Tag (categoryRaw == nil) の `categoryRaw` を classifier 結果で更新
- `flagStore.markCompleted()` で次回起動時 skip
- `processingMonitor.start(.categoryClassifying, ...)` / `updateProgress` / `finish` で BottomStatusBar 表示
- Logger に進捗ログ (notice / debug / error)

## アルゴリズム

```
func run() async {
    // 1. フラグチェック
    guard !flagStore.isCompleted() else {
        logger.debug("auto-category backfill skipped: already completed")
        return
    }

    // 2. categoryRaw == nil の Tag を fetch
    let descriptor = FetchDescriptor<Tag>(
        predicate: #Predicate { $0.categoryRaw == nil },
        sortBy: [SortDescriptor(\.name)]
    )
    let candidates = (try? context.fetch(descriptor)) ?? []

    logger.notice("auto-category backfill starting: \(candidates.count) candidates")

    // 候補 0 件 → flag だけ true、return
    guard !candidates.isEmpty else {
        flagStore.markCompleted()
        logger.notice("auto-category backfill completed: 0 candidates")
        return
    }

    // 3. ProcessingMonitor 開始
    let backfillID = Self.backfillProcessingID
    processingMonitor?.start(
        .categoryClassifying,
        articleID: backfillID,
        title: "全タグのカテゴリー分類中",
        progressIndex: 0,
        progressTotal: candidates.count
    )

    // 4. 1 件ずつ classify + save
    for (index, tag) in candidates.enumerated() {
        let categoryName = await classifier.classify(tagName: tag.name)
        tag.categoryRaw = categoryName
        try? context.save()
        processingMonitor?.updateProgress(
            articleID: backfillID,
            index: index + 1
        )
    }

    // 5. ProcessingMonitor 終了
    processingMonitor?.finish(articleID: backfillID)

    // 6. フラグ true セット
    flagStore.markCompleted()

    logger.notice("auto-category backfill completed: classified \(candidates.count) tags")
}
```

## エラーハンドリング

- `context.fetch` 失敗 → empty array で続行
- `classifier.classify` 内例外 → 既に "その他" を返す設計、ループ継続
- `context.save()` 失敗 → log + 次の Tag へ進む (個別失敗で全体停止しない)
- ループ全体に try/catch 不要 (内部で吸収)

## 副作用

- `Tag.categoryRaw` 更新 (per Tag, immediate save で部分結果保存)
- `flagStore.markCompleted()` で 1 度限り
- ProcessingMonitor の状態変化 → BottomStatusBar 表示
- (将来) RefreshTrigger.bump で UI 即時更新可能だが、本 spec では bump せず (BottomStatusBar progress で十分)

## パフォーマンス

| Tag 数 | 想定実行時間 (Foundation Models on-device) | メモリ |
|---|---|---|
| 0 件 | 即時 (~10ms) | < 1KB |
| 100 件 | 5-10 分 (1 件あたり 3-5 秒) | ~100KB |
| 500 件 | 25-40 分 | ~500KB |
| 1000 件 | 50 分以上 | ~1MB |

500+ 件は実用的には起動時間が長すぎる。MVP では 1000 件まで動作することを保証 (起動時間問題は将来 spec で段階分割)。

## テスト (`AutoCategoryBackfillRunnerTests.swift`)

| Test | 検証 |
|---|---|
| `testFlagFalseRunsBackfill` | flagStore false + Tag 2 件 (categoryRaw nil) → 全 Tag classify、flag = true |
| `testFlagTrueSkipsBackfill` | flagStore true → 候補に変化なし、flag 維持 |
| `testOnlyTargetsTagsWithNilCategoryRaw` | 4 種類混在 (categoryRaw nil + "テクノロジー" + "学術" + "その他") → nil の Tag のみ classify |
| `testHandlesEmptyDatabase` | Tag 0 件 → flag = true、crash なし |
| `testFallbackToOtherWhenClassifierReturnsOther` | InMemoryClassifier で全部 "その他" 返却 → 全 Tag が "その他" になる |
| `testProcessesAllCandidatesEvenOnPartialFailure` | classifier mock で 1 件目だけ "その他"、2 件目は "テクノロジー" → 両方更新確認 |
| `testRunSetsFlagEvenWhenAllFail` | classifier 全 "その他" → flag = true セット (= 完了扱い) |

各テストで `private typealias Tag = KnowledgeTree.Tag` + in-memory ModelContainer + InMemoryBackfillFlagStore (UserDefaults 汚染なし)。

## 依存

- `Tag` (spec 008 + 015 改修)
- `AutoCategoryClassifier` (spec 015 新規)
- `ProcessingMonitor` (spec 005 + 015 拡張)
- `BackfillFlagStore` (spec 013 既存)
- `os.Logger`

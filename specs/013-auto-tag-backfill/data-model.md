# Phase 1 Data Model: spec 013 (既存記事への auto-tag backfill)

**Created**: 2026-05-05

## 概要

本 spec は **新 @Model / 新 schema migration / 新 transient struct すらゼロ**。`UserDefaults` の Bool フラグ 1 つを追加するのみ。

---

## Section A: 既存 @Model 利用 (改修なし)

| @Model | 利用方法 |
|---|---|
| `Article` | 読: 全件取得 (`FetchDescriptor<Article>`)、`tags` / `extractedKnowledge` を確認 <br> 書: `tags` への Tag 追加 (TagStore 経由、spec 008 既存) |
| `Tag` | spec 008 既存 / 新規 Tag を `TagStore.addTag` 経由で追加 |
| `ExtractedKnowledge` | 読: `statusRaw` / `status` (computed) / `entities` |
| `KnowledgeEntity` | 読: SuggestedTagFinder 経由 (spec 008/012 既存) |

---

## Section B: 新規 Persistent State (UserDefaults キー)

### B-1. `auto_tag_backfill_v1_done`

backfill が完了したかどうかの 1 度限り永続フラグ。

| 項目 | 値 |
|---|---|
| Storage | `UserDefaults.standard` (App Group ではない、main app プロセス専用) |
| Key | `"auto_tag_backfill_v1_done"` |
| Type | `Bool` |
| Default | `false` (UserDefaults.bool(forKey:) のデフォルト) |
| 設定タイミング | backfill ループ完了後 (個別 article 失敗があっても完了扱い、FR-030) |
| リセット | アプリ再インストール / 設定アプリでの「データ削除」/ 開発時の手動削除 |

### B-2. `BackfillFlagStore` protocol (Service 層)

```swift
protocol BackfillFlagStore {
    func isCompleted() -> Bool
    func markCompleted()
}

final class UserDefaultsBackfillFlagStore: BackfillFlagStore {
    private let key: String
    private let defaults: UserDefaults

    init(
        key: String = "auto_tag_backfill_v1_done",
        defaults: UserDefaults = .standard
    ) {
        self.key = key
        self.defaults = defaults
    }

    func isCompleted() -> Bool { defaults.bool(forKey: key) }
    func markCompleted() { defaults.set(true, forKey: key) }
}

final class InMemoryBackfillFlagStore: BackfillFlagStore {
    private var done = false
    func isCompleted() -> Bool { done }
    func markCompleted() { done = true }
}
```

production では `UserDefaultsBackfillFlagStore` (default key)、test では `InMemoryBackfillFlagStore` を inject。

---

## Section C: ProcessingMonitor.Phase 拡張

### C-1. Phase enum 拡張

spec 005 既存:

```swift
enum Phase: Int, Comparable, Sendable {
    case enrichment = 0
    case body = 1
    case knowledge = 2
    // spec 013: 追加
    case tagBackfilling = 3
}
```

priority order (low → high): enrichment < body < knowledge < tagBackfilling
priority order (UI 表示優先度): knowledge > body > enrichment > tagBackfilling

**注意**: `current` の選択ロジック (`tasksByArticle.values.max`) は `phase < rhs.phase` で max を取るため、`.tagBackfilling = 3` は **数値最大** = 最後に表示優先度 (= 最も front に出る)。これは backfill が他の処理と同時に走っているケースで意図しない結果を招く可能性。

**修正方針**: `current` の優先度ロジックを変更せず (spec 005 既存挙動維持)、代わりに backfill のみ単独で走るシナリオを想定。spec 002/003/004 の通常 chain は backfill 中も走る可能性があるが、以下の理由で衝突は実質的に発生しない:

- bootstrap の `enrichmentService.backfillAll() → bodyService.backfillAll() → knowledgeService.backfillAll() → tagStore.cleanupOrphans() → backfillRunner.run()` は **順次実行** (上 4 つは spec 002/003/004 既存、本 spec は最後に追加)
- 4 つの backfillAll が完了するまで `processingMonitor.tasksByArticle` は順次空になる
- backfill 開始時点では他の処理はほぼ完了 (新規 share 経由は除く、稀)

詳細は contracts/auto-tag-backfill-runner.md で詰める。

### C-2. BottomStatusBar の phase label 追加

`KnowledgeTree/Views/BottomStatusBar.swift` の `phaseLabel(_ phase: Phase) -> LocalizedStringKey` (or 同等関数) に case 追加:

```swift
case .tagBackfilling: "タグ整理中"
```

`Localizable.xcstrings` に「タグ整理中」キー追加。

---

## State Transitions

### backfill 全体の状態遷移

| From | Event | To |
|---|---|---|
| アプリ起動 | bootstrap の前段 (spec 004 backfillAll 完了) | backfillRunner.run() 呼び出し |
| `flagStore.isCompleted() == true` | run() 内 1st guard | early return (no-op) |
| `flagStore.isCompleted() == false` | candidates 取得 | ProcessingMonitor.start(.tagBackfilling, ...) → 各 article 処理 → finish |
| 各 article 処理 | AutoTagApplier.apply() | tags 0〜5 件追加 + RefreshTrigger.bump |
| 全候補処理完了 | flagStore.markCompleted() | flag = true、ProcessingMonitor.finish |

### ProcessingMonitor の状態 (backfill 中)

| Phase | tasksByArticle | BottomStatusBar 表示 |
|---|---|---|
| backfill 開始時 | `[backfillID: ActiveTask(phase: .tagBackfilling, articleTitle: "全タグ整理中")]` | 「タグ整理中」+ ProgressView |
| 完了 | `[:]` | 非表示 |

`backfillID` は backfill 用の固定 UUID (例: `UUID(uuidString: "00000000-0000-0000-0000-AUTOTAGBACKFL")!` など、衝突しないダミー)。

---

## Validation Rules

| Rule | 適用先 | 違反時の挙動 |
|---|---|---|
| `flagStore.isCompleted()` 早期 return | run() 1st guard | 全 backfill ロジックを skip |
| `article.tags.isEmpty == true` | candidate filter | スキップ (FR-007) |
| `article.extractedKnowledge != nil` | candidate filter | スキップ (FR-007) |
| `extractedKnowledge.status in [.succeeded, .partiallySucceeded]` | candidate filter | スキップ (FR-007) |
| 個別 article の例外 | run() ループ内 | log + 次 article へ進む (FR-029) |
| flagStore.markCompleted() | run() 末尾 | 個別失敗があっても完了扱いで実行 (FR-030) |

---

## 永続化なし宣言 (SwiftData)

本 spec で **新規 SwiftData @Model は追加しない**。`SharedSchema.all` の改修は不要。schema migration は **走らない**。既存 ModelContainer は spec 012 までと同じ構成で起動する。

UserDefaults キーが 1 つ追加されるが、これは SwiftData ではなく `UserDefaults.standard` プロセス specific の永続化。

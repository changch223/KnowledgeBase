# Phase 0 Research: spec 013 (既存記事への auto-tag backfill)

**Created**: 2026-05-05
**Branch**: `013-auto-tag-backfill`

技術不確実性を 5 つの研究項目 (R1〜R5) に分割し、各項目で **Decision / Rationale / Alternatives considered** を記録する。

---

## R1: ProcessingMonitor 拡張方針 (新フェーズ追加 vs 既存メカニズム代用)

### Decision

`ProcessingMonitor.Phase` enum に **`.tagBackfilling = 3`** を追加する (案 A)。`BottomStatusBar` の phase label にも対応文字列「タグ整理中」を追加。

### Rationale

- 専用フェーズで意図が明確 (「タグ整理中」と表示できる、誤解の余地なし)
- 既存 `enrichment` / `body` / `knowledge` 3 フェーズの並列拡張で、enum.rawValue ordering も問題なし (`.tagBackfilling = 3` が最後で priority 最低、knowledge より前面に出ない)
- BottomStatusBar の `current` 計算 (priority desc) で:
  - knowledge / body / enrichment が走っている記事と同時に backfill が起きると knowledge / body / enrichment が優先表示される (= 新規記事処理を妨げない)
  - 単独の backfill 時のみ「タグ整理中…」表示 (clean UX)
- ProcessingMonitor を仮想 article で偽装 (案 B) すると `articleTitle: "全タグ整理中"` が UX 文言として誤解を招く (個別 article 名が表示される位置に「全タグ整理中」が出るため違和感あり)

### Alternatives considered

- **案 B**: 既存 ProcessingItem を仮想 article として inject → `articleTitle` フィールドの semantic confusion、却下
- **案 C**: BottomStatusBar とは独立の専用 BackfillProgressBar を新設 → UI コンポーネント増加で複雑性 up、却下
- **案 D**: 進捗を表示しない (calm UX 至上主義) → 1 分間の起動遅延を無音で待たせるのは不安喚起、却下

---

## R2: UserDefaults キー命名と隔離 (テスト容易化)

### Decision

production 用は `UserDefaults.standard` を使い、キー名は `auto_tag_backfill_v1_done` (Bool, default false)。

テスト用に `BackfillFlagStore` protocol を導入し、production は `UserDefaultsBackfillFlagStore` (UserDefaults.standard ラップ)、test は `InMemoryBackfillFlagStore` (Dictionary-based) を使う。

```swift
protocol BackfillFlagStore {
    func isCompleted() -> Bool
    func markCompleted()
}

final class UserDefaultsBackfillFlagStore: BackfillFlagStore {
    private let key: String
    init(key: String = "auto_tag_backfill_v1_done") { self.key = key }
    func isCompleted() -> Bool { UserDefaults.standard.bool(forKey: key) }
    func markCompleted() { UserDefaults.standard.set(true, forKey: key) }
}

final class InMemoryBackfillFlagStore: BackfillFlagStore {
    private var done = false
    func isCompleted() -> Bool { done }
    func markCompleted() { done = true }
}
```

### Rationale

- protocol 経由でテスト時に UserDefaults.standard を汚染しない (CI 環境 + 連続テスト実行で副作用残存しない)
- production の動作は spec.md の FR-002 / FR-003 を直接実装
- キー名に `_v1` 接尾辞を含めて、将来 spec で v2 backfill が必要になった時に新キー (例: `auto_tag_backfill_v2_done`) で再実行できる設計
- Constitution Additional Constraints の「UserDefaults の非自明な用途禁止」例外: 「1 度だけ実行する migration / backfill フラグ」は典型的な使い方として許容

### Alternatives considered

- **A**: SwiftData @Model `BackfillState` を作る → 新 schema migration 必要 → MVP スコープ違反、却下
- **B**: AppStorage を使う (UserDefaults wrapper) → SwiftUI View 内でしか宣言できない、Service 層では使えない、却下
- **C**: UserDefaults.standard を直接 Runner 内で叩く → テスト隔離不可、却下

---

## R3: 並行性とアクター (MainActor 順次実行 vs Task.detached)

### Decision

`AutoTagBackfillRunner.run()` を `@MainActor async` として定義し、内部で **MainActor 上で順次同期実行**。`Task.detached` / `Task.yield` / `Task.sleep` は使わない。

```swift
@MainActor
final class AutoTagBackfillRunner {
    func run() async {
        guard !flagStore.isCompleted() else { return }
        // ... 全件処理 ...
        flagStore.markCompleted()
    }
}
```

### Rationale

- AutoTagApplier / TagStore は MainActor 注釈、SwiftData ModelContext も MainActor 制約 → 結局 MainActor 上に bounce する
- `Task.detached` で main thread を解放しても、各 article 処理時に MainActor へ jump back → オーバーヘッドが増えるだけ
- 起動時 1 回のみ、BottomStatusBar 「タグ整理中…」表示で UX 整合
- ユーザーが「タグ整理中」中に AI ブレインタブを開いても、新タグが付与されるたびに RefreshTrigger.bump で UI が更新される (KnowledgeMap でノード fade-in)

### Alternatives considered

- **A**: `Task.detached(priority: .background)` で background queue に逃がす → MainActor 制約で意味なし、却下
- **B**: 各 article 間で `await Task.yield()` を入れて他のイベントに譲る → 起動時 1 回のみ実行で他にイベントが少ない、過剰最適化、却下
- **C**: Combine / async stream でストリーム処理 → 既存パターン (ChunkedKnowledgeAggregator 等) と整合しない、却下

---

## R4: SwiftData fetch とメモリ使用量

### Decision

`FetchDescriptor<Article>(sortBy: [SortDescriptor(\.savedAt, order: .reverse)])` で **全件 1 ショット fetch**、メモリ上で filter:

```swift
let descriptor = FetchDescriptor<Article>(
    sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
)
let allArticles = (try? context.fetch(descriptor)) ?? []
let candidates = allArticles.filter { article in
    article.tags.isEmpty
        && article.extractedKnowledge != nil
        && (article.extractedKnowledge?.status == .succeeded
            || article.extractedKnowledge?.status == .partiallySucceeded)
}
```

### Rationale

- 1000 件 × Article ~1KB = 1MB 程度 (Constitution パフォーマンスゲート 100MB 以内 ✅)
- 10000 件 × 1KB = 10MB でも許容範囲
- savedAt desc で **最新の article 優先** (FR-018) → ユーザーは新しい記事に最も興味を持つ、UI に早く反映される
- SwiftData predicate で `article.tags.isEmpty` を表現するのは relationship traversal 不安定 (spec 008 の経験) のため、メモリ filter で安全

### Alternatives considered

- **A**: `FetchDescriptor` の predicate で `tags.@count == 0 && extractedKnowledge.statusRaw == "succeeded"` → SwiftData の relationship aggregation predicate は安定しない、却下
- **B**: 100 件ずつ batch fetch (page-by-page) → 1000 件規模では 1 ショットで OK、却下
- **C**: 古い article から処理 (savedAt asc) → 古い記事は優先度が低い、UX 的に新しい記事を先に整理すべき、却下

---

## R5: テスト戦略 (フラグ + 順次処理 + 候補 filter)

### Decision

`AutoTagBackfillRunnerTests.swift` で 7 ケース:

| Test | 検証 |
|---|---|
| `testFlagFalseRunsBackfill` | flagStore.isCompleted = false → run → 候補 article に tag 付与 + flag = true |
| `testFlagTrueSkipsBackfill` | flagStore.isCompleted = true → run → 候補 article に変化なし、再実行されない |
| `testOnlyTargetsArticlesWithEmptyTagsAndSucceededKnowledge` | 4 種類 article 混在 (target / 既存タグあり / failed / pending) → target のみ tag 付与 |
| `testSkipsArticlesWithExistingTags` | tags ≥ 1 件 article → 触られず skip |
| `testSkipsArticlesWithFailedKnowledge` | knowledge.status = .failed → skip |
| `testProcessesNewestFirst` | savedAt 異なる 3 article → 処理順序が savedAt desc |
| `testHandlesEmptyDatabase` | article 0 件 → crash せず flag = true |

各テストで:
- `private typealias Tag = KnowledgeTree.Tag` (SwiftUI Tag 衝突解消)
- `ModelConfiguration(isStoredInMemoryOnly: true)` で全 entity 込み container 構築
- `InMemoryBackfillFlagStore()` を inject (UserDefaults 汚染なし)
- `TagStore(context:, refreshTrigger: nil)` で TagStore 構築
- `ProcessingMonitor()` を構築 (副作用なし、test 内ではメソッド呼び出しが logger に流れる程度)
- `AutoTagBackfillRunner(context:, tagStore:, processingMonitor:, flagStore:).run()` を await
- 結果検証: 各 article の `tags.count` / `tags.map(\.name)` / flagStore.isCompleted()

### Rationale

- 純粋関数ではないが、副作用 (TagStore.addTag / flagStore.markCompleted / ProcessingMonitor の状態変化) はすべてテスト可能な形で隔離可能
- 状態を持つ class なので、毎テスト新インスタンスで初期化
- spec 012 AutoTagApplierTests のパターンを踏襲 (一貫性)

### Alternatives considered

- **A**: bootstrap 経由の integration test → bootstrap 構築コスト高、AutoTagBackfillRunner 単体の logic は unit test で十分、却下
- **B**: ProcessingMonitor の状態変化を spy / mock で検証 → MVP では `start` / `finish` が呼ばれることを期待値で検証する程度で十分、却下
- **C**: UI test で BottomStatusBar 「タグ整理中…」表示確認 → spec 011 の UI test 既存パターン、本 spec では unit test で代替、quickstart 実機検証で UI 確認

---

## まとめ

すべての R1〜R5 で技術判断を確定。NEEDS CLARIFICATION 残存ゼロ。Phase 1 (data-model / contracts / quickstart) に進める。

**コア発見**:
- ProcessingMonitor.Phase enum 拡張で UI 統合シンプル
- BackfillFlagStore protocol でテスト隔離
- MainActor 順次実行で並行性問題なし
- 全件 1 ショット fetch + メモリ filter で予測可能なパフォーマンス

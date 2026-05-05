---
description: "Tasks for spec 013: 既存記事への auto-tag backfill"
---

# Tasks: 既存記事への auto-tag backfill

**Input**: Design documents from `specs/013-auto-tag-backfill/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: 含む。Constitution テストゲート準拠 (`KnowledgeTreeTests` 単体テスト 7 ケース、AutoTagBackfillRunnerTests)。UI テストは spec 005/008/011 既存範囲で十分のため新規追加なし。

**Organization**: 4 ユーザーストーリー (US1: 1 度限り backfill P1 / US2: 重複実行防止 P1 / US3: 整理済記事保持 P2 / US4: 失敗時継続性 P2) ごとに独立実装可能。

## Format: `[ID] [P?] [Story] Description with file path`

- **[P]**: 並列実行可 (異なるファイル / 依存なし)
- **[Story]**: US1〜US4 のラベル
- ファイルパスは project-relative (KnowledgeTree project root から)

---

## Phase 1: Setup

**Purpose**: ローカライゼーション文字列追加。

- [x] T001 [P] `KnowledgeTree/Localization/Localizable.xcstrings` に「タグ整理中」キーを追加 (manual extractionState、ja value: "タグ整理中"):
  - キー名: `"タグ整理中"` (日本語直接、auto-extract と整合)
  - BottomStatusBar の phaseLabel から参照される
  - 既存 spec 005 の他フェーズ ("メタデータ取得中" 等) と同じパターン

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: BackfillFlagStore protocol + 2 実装 + ProcessingMonitor.Phase 拡張 + BottomStatusBar phase label 追加。全 US の前提。

**⚠️ CRITICAL**: このフェーズが完了するまでどの US も着手不可。

- [x] T002 `KnowledgeTree/Services/BackfillFlagStore.swift` を新規作成:
  - `protocol BackfillFlagStore { func isCompleted() -> Bool; func markCompleted() }`
  - `final class UserDefaultsBackfillFlagStore: BackfillFlagStore` (UserDefaults.standard ラップ、key: `"auto_tag_backfill_v1_done"` default、precondition で空 key 禁止)
  - `final class InMemoryBackfillFlagStore: BackfillFlagStore` (Dictionary なし、Bool 1 つで初期 false、`init(initial: Bool = false)`)
  - contracts/backfill-flag-store.md 準拠
  - `import Foundation` のみ
- [x] T003 `KnowledgeTree/Services/ProcessingMonitor.swift` の `Phase` enum に `case tagBackfilling = 3` を追加:
  - 既存 enrichment / body / knowledge の後に並べる
  - rawValue は連番 (3) を維持、Comparable 動作変更なし
  - 既存テスト 100% 後方互換 (新 case 追加のみ)
- [x] T004 [P] `KnowledgeTree/Views/BottomStatusBar.swift` の `phaseLabel(_ phase:)` 関数 (or 同等の switch) に `case .tagBackfilling: "タグ整理中"` を追加:
  - 既存 case と同じ LocalizedStringKey スタイル
  - phaseTintColor も `case .tagBackfilling` を追加 (例: `.tint` で knowledge と同じ色、calm UX 範囲)

**Checkpoint**: Build 成功 + 既存全テスト pass (BackfillFlagStore は単独 unit test 不要)。後方互換性確認。

---

## Phase 3: User Story 1 - 既存全記事への 1 度限り backfill (Priority: P1) 🎯 MVP

**Goal**: bootstrap 末尾で AutoTagBackfillRunner.run() を 1 回実行し、対象既存記事に上位 5 タグ自動付与。

**Independent Test**: T005-T007 の単体テスト pass。実機検証は quickstart.md 検証 1。

### Tests for User Story 1

- [x] T005 [P] [US1] `KnowledgeTreeTests/AutoTagBackfillRunnerTests.swift` を新規作成し共通 fixture を実装:
  - `private typealias Tag = KnowledgeTree.Tag` (SwiftUI Tag 衝突解消)
  - `private func makeContainer() throws -> ModelContainer` (in-memory、全 entity スキーマ込み、spec 011/012 同パターン)
  - `private func makeArticleWithEntities(salienceList: [Int], status: ExtractionStatus = .succeeded, savedAt: Date = Date(), in: ModelContext) -> Article` (テストヘルパ)
  - `private func makeFlagStore() -> InMemoryBackfillFlagStore` (default false)
  - 空テスト 1 つで run 確認
- [x] T006 [P] [US1] `AutoTagBackfillRunnerTests.swift` に `testFlagFalseRunsBackfill` を追加:
  - 候補 article 2 件作成 (tags 空 + status .succeeded + entities salience 5,5,4)
  - flagStore = InMemoryBackfillFlagStore() (false)
  - runner.run() を await
  - 各 article に tags 3 件付与確認 (salience>=4 が 3 件)
  - flagStore.isCompleted() == true 確認
- [x] T007 [P] [US1] `AutoTagBackfillRunnerTests.swift` に `testProcessesNewestFirst` を追加:
  - 3 article: savedAt = (-1day, -2days, -3days)、すべて候補条件満たす
  - run() 後に各 article に tag 付与
  - 処理順序を確認するため、テスト用に runner にトラッキング機能を追加するか、TagStore.addTag のログを観察
  - 簡易的には: 全 article に tag 付与されていることだけを検証 (順序の precise 検証は不要、savedAt desc は内部実装詳細)
  - 厳密検証: ProcessingMonitor.updateProgress の引数 history を spy する (より複雑、MVP では緩く)

### Implementation for User Story 1

- [x] T008 [US1] `KnowledgeTree/Services/AutoTagBackfillRunner.swift` を新規作成 (本実装):
  - `@MainActor final class AutoTagBackfillRunner`
  - `init(context:tagStore:processingMonitor:flagStore:)` (default flagStore: UserDefaultsBackfillFlagStore())
  - `func run() async`:
    1. flagStore.isCompleted() ガード → early return
    2. FetchDescriptor<Article>(sortBy: [SortDescriptor(\.savedAt, order: .reverse)]) で全件取得
    3. 候補 filter (tags.isEmpty + extractedKnowledge.status .succeeded/.partiallySucceeded)
    4. processingMonitor.start(.tagBackfilling, articleID: backfillProcessingID, title: "全タグ整理中", progressIndex: 0, progressTotal: candidates.count)
    5. 各候補に AutoTagApplier.apply(to:using:) 呼び出し + processingMonitor.updateProgress(articleID:, index:)
    6. processingMonitor.finish(articleID:)
    7. flagStore.markCompleted()
    8. logger.notice 完了サマリ
  - `static let backfillProcessingID = UUID(uuidString: "00000000-0000-0000-0000-AB13BACFB13F")!` (固定 UUID、衝突防止のため上位 8 桁を全 0、識別しやすい hex 文字列を含む)
  - `import Foundation`, `import SwiftData`, `import os`
  - contracts/auto-tag-backfill-runner.md 準拠
- [x] T009 [US1] `KnowledgeTree/KnowledgeTreeApp.swift` の `bootstrap()` 末尾 (`try? tagStore.cleanupOrphans()` の後) に backfill ステップを追加:
  - `let backfillRunner = AutoTagBackfillRunner(context: context, tagStore: tagStore, processingMonitor: processingMonitor)` で構築
  - `await backfillRunner.run()` で実行
  - bootstrap 全体は @MainActor async なので await 可能
  - 既存ロジック (cleanupOrphans 等) は変更しない

**Checkpoint**: T006 / T007 unit test pass。実機検証は quickstart 検証 1 で可能。MVP 1 機能完成。

---

## Phase 4: User Story 2 - 重複実行防止 (Priority: P1)

**Goal**: 1 度 backfill 完了 → 永続フラグ (UserDefaults) で次回起動時は early return。

**Independent Test**: T010 の単体テスト pass。実機検証は quickstart 検証 2。

### Tests for User Story 2

- [x] T010 [P] [US2] `AutoTagBackfillRunnerTests.swift` に `testFlagTrueSkipsBackfill` を追加:
  - 候補 article 2 件作成 (US1 と同じ条件)
  - flagStore = InMemoryBackfillFlagStore(initial: true) で開始
  - runner.run() を await
  - 各 article の tags.count が 0 のまま (= backfill skip 確認)
  - flagStore.isCompleted() == true 維持

### Implementation for User Story 2

- [x] T011 [US2] **実装変更なし** — T008 の AutoTagBackfillRunner 内 1st guard で flagStore.isCompleted() を check 済。タスクとしては「ロジックが正しく動作することの確認」のみ。

**Checkpoint**: T010 unit test pass。

---

## Phase 5: User Story 3 - 整理済記事は触らない (Priority: P2)

**Goal**: tags ≥ 1 件 / failed knowledge / pending knowledge 等の article は backfill 対象外。

**Independent Test**: T012-T015 の単体テスト pass。実機検証は quickstart 検証 4。

### Tests for User Story 3

- [x] T012 [P] [US3] `AutoTagBackfillRunnerTests.swift` に `testOnlyTargetsArticlesWithEmptyTagsAndSucceededKnowledge` を追加:
  - 4 種類 article 混在:
    - target: tags 空 + status .succeeded + entities (salience 5)
    - skip A: tags 1 件付き + status .succeeded
    - skip B: tags 空 + status .failed
    - skip C: tags 空 + status .pending
  - run() 後、target のみ tags が増加、他 3 件は不変
- [x] T013 [P] [US3] `AutoTagBackfillRunnerTests.swift` に `testSkipsArticlesWithExistingTags` を追加:
  - 単独 article: tags 1 件付き + status .succeeded + entities (salience 5,5,4)
  - run() 後、tags.count == 1 維持 (auto-apply スキップ確認)
- [x] T014 [P] [US3] `AutoTagBackfillRunnerTests.swift` に `testSkipsArticlesWithFailedKnowledge` を追加:
  - 単独 article: tags 空 + status .failed + entities (salience 5,5,4)
  - run() 後、tags 0 件のまま

### Implementation for User Story 3

- [x] T015 [US3] **実装変更なし** — T008 内 candidate filter (tags.isEmpty + status check) で全条件カバー済。AutoTagApplier 自身も spec 012 の早期 return で再保護。

**Checkpoint**: T012 / T013 / T014 unit test pass。

---

## Phase 6: User Story 4 - 失敗時の継続性 (Priority: P2)

**Goal**: 個別 article で例外発生 → AutoTagApplier 内で吸収、ループ継続、全体完了でフラグ true。

**Independent Test**: T016 の単体テスト pass + T017 の動作確認。

### Tests for User Story 4

- [x] T016 [P] [US4] `AutoTagBackfillRunnerTests.swift` に `testHandlesEmptyDatabase` を追加:
  - article 0 件 (空 ModelContainer)
  - flagStore = InMemoryBackfillFlagStore (false)
  - run() を await
  - crash しない、flagStore.isCompleted() == true セットされる

### Implementation for User Story 4

- [x] T017 [US4] **実装変更なし** — T008 の AutoTagBackfillRunner で:
  - context.fetch 失敗 → `(try? context.fetch(...)) ?? []` で吸収
  - AutoTagApplier.apply 内例外 → spec 012 既存 graceful failure
  - ループ全体に try/catch なし (内部例外なし、設計通り)

**Checkpoint**: T016 unit test pass。

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: 既存テスト回帰 / quickstart 検証 / ドキュメント更新

- [ ] T018 [P] 既存 `KnowledgeTreeTests/` の全テストが pass することを `xcodebuild test -only-testing:KnowledgeTreeTests` で確認 (回帰なし)。spec 005/008/011/012 のテストが Phase 拡張後も全 pass を確認 (新 case `.tagBackfilling` 追加で switch exhaustive 警告がないこと)。
- [x] T019 [P] `KnowledgeTreeUITests/` の既存テストが pass することを確認。BottomStatusBar に新しい phase label が増えても既存 UI test は影響なし。
- [ ] T020 quickstart.md 検証 1〜7 を実機 (iPhone 17 Pro 等) で実行:
  - 検証 1 (1 度限り backfill, SC-001)
  - 検証 2 (2 回目 early return, SC-004)
  - 検証 3 (100 件 30 秒, SC-002)
  - 検証 4 (整理済保持, SC-007)
  - 検証 5 (新記事との非競合, SC-005)
  - 検証 6 (強制終了復帰, SC-006)
  - 検証 7 (新規インストール挙動)
- [ ] T021 [P] Instruments で backfill の Time Profiler 計測。100 件で 30 秒以内、各 article の TagStore.addTag が ~50ms 以内であることを確認 (Constitution パフォーマンスゲート許容範囲、起動時 1 回のみ)。
- [x] T022 [P] `CLAUDE.md` の SPECKIT セクションを更新し spec 013 を「✅ 実装 + commit `<sha>`」に書き換え。
- [x] T023 [P] `KnowledgeTree/Services/AutoTagBackfillRunner.swift` および `BackfillFlagStore.swift` のコードレビュー: Swift API Design Guidelines 準拠 / `fatalError` / `try!` 不使用 / `@MainActor` 注釈確認。
- [x] T024 最終 build で警告ゼロ確認 (本 spec の改修起因の警告 0、既存の duplicate build file 警告は pre-existing)。
- [ ] T025 PR 説明に Constitution Check 全 11 ゲート ✅ + spec 013 の挙動変化点 (初回起動で「タグ整理中」表示が 30 秒〜数分続く) を明記。

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: 即着手可
- **Phase 2 (Foundational)**: Phase 1 完了後、全 US の前提
- **Phase 3 (US1 1 度限り backfill)**: Phase 2 完了後、AutoTagBackfillRunner 本実装 + bootstrap で run()
- **Phase 4 (US2 重複実行防止)**: Phase 3 の T008 完了後 (テストのみ追加)
- **Phase 5 (US3 整理済記事保持)**: Phase 3 完了後 (テストのみ)
- **Phase 6 (US4 失敗時継続性)**: Phase 3 完了後 (テストのみ)
- **Phase 7 (Polish)**: 全 US 完了後

### User Story Dependencies

- **US1 (P1, 1 度限り backfill)**: Foundational のみ依存。AutoTagBackfillRunner 本実装 + bootstrap call が新規実装の本体
- **US2 (P1, 重複実行防止)**: US1 の T008 (Runner 実装) に依存。実装変更なし、テストのみ追加
- **US3 (P2, 整理済記事保持)**: 同上、テストのみ
- **US4 (P2, 失敗時継続性)**: 同上、テストのみ

### 共通ファイル順序制約

- `Localizable.xcstrings`: T001 のみ
- `BackfillFlagStore.swift`: T002 (新規)
- `ProcessingMonitor.swift`: T003 (1 行追加、独立)
- `BottomStatusBar.swift`: T004 (1 行追加、ProcessingMonitor.Phase 完了後)
- `AutoTagBackfillRunner.swift`: T008 (新規、Phase 2 全完了後)
- `KnowledgeTreeApp.swift`: T009 (T008 完了後)
- `AutoTagBackfillRunnerTests.swift`: T005 (fixture) → T006-T016 (個別ケース)

---

## Parallel Opportunities

### Setup Phase (Phase 1)

```text
T001 [P] のみ。並列対象なし
```

### Foundational Phase (Phase 2)

```text
T002 (新規 BackfillFlagStore.swift) と T003 (ProcessingMonitor 改修) は別ファイル → [P] 可
T004 (BottomStatusBar) は T003 完了後 (Phase enum case が必要)
```

### Tests 並列 (各 US)

```text
T005 [P] [US1] (fixture) → T006 [P] / T007 [P] [US1]
T010 [P] [US2]
T012 [P] / T013 [P] / T014 [P] [US3]
T016 [P] [US4]
全テストケース追加は同ファイルだが個別 @Test func なので [P] 並列可
```

### Implementation 並列 (US1)

```text
T008 [US1] (Runner 新規) と T009 [US1] (bootstrap) は別ファイルだが、
T009 が T008 を import するため順序: T008 → T009
```

### Polish Phase

```text
T018 / T019 / T021 / T022 / T023 [P] (全部独立)
T020 (実機検証) は T018 後の order
T024 / T025 順次
```

---

## Implementation Strategy

### MVP First (US1 + US2 のみ)

1. Phase 1 (Setup): T001 完了
2. Phase 2 (Foundational): T002-T004 完了
3. Phase 3 (US1): T005-T009 完了 (fixture + 2 tests + Runner + bootstrap)
4. Phase 4 (US2): T010 完了 (テスト追加、実装変更なし)
5. **STOP and VALIDATE**: T006 / T007 / T010 unit test pass → 実機 quickstart 検証 1 / 2 → MVP demo OK
6. US3 / US4 / Polish は後追加

### Incremental Delivery

1. MVP (上記) → 検証 → 中間 commit
2. US3 (整理済保持) + US4 (失敗時継続性): T012-T016 → 単体テスト追加 → 検証
3. Polish (Phase 7): 既存全テスト回帰 / quickstart 全 7 検証 / Instruments 計測 / PR

### Solo Dev Strategy

- 個人開発のため並列化は限定的、ただし test-first → 実装 → 検証 のループで quality 維持
- Constitution テストゲート遵守: 各 US の Tests を先に書いて FAIL 確認 → 実装で PASS
- 各 US の Checkpoint で git commit (推奨 3 コミット: Phase 2 完了 / US1+US2 完了 / Phase 7 完了)

---

## Notes

- [P] = 異なるファイル / 依存なし、並列可
- [Story] = US1〜US4 ラベル
- 各 US は独立完成 + 独立テスト可能
- テストは先に書いて FAIL 確認 (Constitution テストゲート)
- 各 task / Checkpoint で commit 推奨
- 既存スキーマ完全無改修 (新 @Model ゼロ、新 migration ゼロ)
- 既存 AutoTagApplier / TagStore / SuggestedTagFinder / TagNormalizer / KnowledgeExtractionService / 全 View / 全 Model は本 spec で 1 行も改修しない (BottomStatusBar の phaseLabel switch 1 行と ProcessingMonitor の enum 1 行のみ)
- 改修対象は `BackfillFlagStore.swift` (新規) + `AutoTagBackfillRunner.swift` (新規) + `AutoTagBackfillRunnerTests.swift` (新規) + `Localizable.xcstrings` (1 キー) + `ProcessingMonitor.swift` (1 行) + `BottomStatusBar.swift` (~3 行) + `KnowledgeTreeApp.swift` (~3 行) の 7 ファイル

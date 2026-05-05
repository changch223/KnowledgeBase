---
description: "Tasks for spec 012: タグ自動付与 (AI Auto-Tag)"
---

# Tasks: タグ自動付与 (AI Auto-Tag)

**Input**: Design documents from `specs/012-auto-tag/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: 含む。Constitution テストゲート準拠 (`KnowledgeTreeTests` 単体テスト 7 ケース)。UI テストは spec 008 / 011 既存範囲で十分のため新規追加なし。

**Organization**: 4 ユーザーストーリー (US1: 新規 5 タグ自動付与 P1 / US2: 手動タグ既存スキップ P1 / US3: 削除整理 P2 / US4: 失敗時非付与 P2) ごとに独立実装可能。

## Format: `[ID] [P?] [Story] Description with file path`

- **[P]**: 並列実行可 (異なるファイル / 依存なし)
- **[Story]**: US1〜US4 のラベル
- ファイルパスは project-relative (KnowledgeTree project root から)

---

## Phase 1: Setup

**Purpose**: なし。本 spec は Localizable / xcodeproj 設定 / 新依存パッケージ追加なし。

(Setup phase は空で済むのは spec 012 が純粋なロジック追加だから)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: AutoTagApplier ファイル雛形 + KnowledgeExtractionService イニシャライザ拡張 + bootstrap での DI 配線。全 US の前提。

**⚠️ CRITICAL**: このフェーズが完了するまでどの US も着手不可。

- [x] T001 `KnowledgeTree/Services/AutoTagApplier.swift` を新規作成 (stub):
  - `@MainActor enum AutoTagApplier`
  - `static func apply(to article: Article, using tagStore: TagStore, limit: Int = 5)` の stub (空関数 + TODO コメント)
  - `import Foundation` / `import SwiftData` / 必要なら `import os` (Logger 用)
  - 本実装は T011 で完成させる
- [x] T002 `KnowledgeTree/Services/KnowledgeExtractionService.swift` の `DefaultKnowledgeExtractionService` クラスに以下を追加:
  - `private let tagStore: TagStore?` プロパティ
  - イニシャライザの末尾引数に `tagStore: TagStore? = nil` を追加 (default nil で後方互換)
  - `self.tagStore = tagStore` を init body に追加
  - `private func applyAutoTagsIfPossible(article: Article)` helper を追加 (中身は `guard let tagStore else { return }; AutoTagApplier.apply(to: article, using: tagStore)`)
  - **hook 呼び出し**は本タスクでは入れない (T012/T013 で追加)
- [x] T003 `KnowledgeTree/KnowledgeTreeApp.swift` の `bootstrap()` 内 `let knowledgeService = DefaultKnowledgeExtractionService(...)` の引数に `tagStore: tagStore` を追加 (1 行)。**注意**: `tagStore` は `bootstrap()` 内の line 110-111 付近で `TagStore(context:..., refreshTrigger:...)` で構築済みなので、その後に knowledgeService を作るよう順序調整 (現状 knowledgeService 構築が tagStore より早い場合は順序を入れ替える)。

**Checkpoint**: アプリビルド + 既存テスト全 pass (auto-apply は呼ばれない、tagStore は inject されたが Apply は stub)。後方互換性確認。

---

## Phase 3: User Story 1 - 新規記事 → 上位 5 タグ自動付与 (Priority: P1) 🎯 MVP

**Goal**: knowledge 抽出 succeeded 直後に salience ≥ 4 の上位 5 件を AutoTagApplier 経由で自動付与する。

**Independent Test**: quickstart.md 検証 1 を実機 / Simulator で実行し、新規記事保存 → Detail で 1〜5 タグが付いている状態を確認。または T010 の単体テスト pass で代替。

### Tests for User Story 1

- [x] T004 [P] [US1] `KnowledgeTreeTests/AutoTagApplierTests.swift` を新規作成し共通 fixture を実装:
  - `private typealias Tag = KnowledgeTree.Tag` (SwiftUI Tag 衝突解消)
  - `private func makeContainer() throws -> ModelContainer` (in-memory、全 entity スキーマ込)
  - `private func makeArticleWithEntities(salienceList:in:) -> Article` (テストヘルパ。entities + ExtractedKnowledge を組み立て)
  - 空テスト 1 つで run 確認
- [x] T005 [P] [US1] `AutoTagApplierTests.swift` に `testAppliesTopFiveWhenNoExistingTags` を追加: salience [5,5,4,4,4,3] の 6 entities → apply 後に 5 タグ付与 (salience=3 entity は除外)、tag.name は SuggestedTagFinder 順序 desc。

### Implementation for User Story 1

- [x] T011 [US1] `KnowledgeTree/Services/AutoTagApplier.swift` の `apply(to:using:limit:)` 本実装:
  - early return: `article.tags.isEmpty == false` (FR-006)
  - early return: `article.extractedKnowledge == nil` または `status` not in `{.succeeded, .partiallySucceeded}` (FR-004)
  - early return: `limit <= 0`
  - `let suggestions = SuggestedTagFinder.find(for: article, existingTagNames: [], limit: limit)`
  - `for suggestion in suggestions { do { _ = try tagStore.addTag(rawName: suggestion.displayName, to: article) } catch { logger.error(...) } }`
  - `os.Logger(subsystem: "app.KnowledgeTree", category: "auto-tag")` を使用
- [x] T012 [US1] `KnowledgeTree/Services/KnowledgeExtractionService.swift` の **単一パス hook** 追加 (line 140-146 付近):
  - `try? store.upsertSucceeded(...)` の直後に `applyAutoTagsIfPossible(article: article)` を 1 行追加
  - 既存挙動 (status == .failed なら upsertFailure) は変更しない
- [x] T013 [US1] `KnowledgeTree/Services/KnowledgeExtractionService.swift` の **chunked パス hook** 追加 (line 294-306 付近):
  - `case .succeeded, .partiallySucceeded:` ブランチ末尾の `try? chunkProgressStore.cleanup(knowledge: knowledge)` の直後に `applyAutoTagsIfPossible(article: article)` を 1 行追加

**Checkpoint**: T005 unit test pass。実機 quickstart 検証 1 を実行可能 (新規記事保存 → 5 タグ自動付与)。MVP 1 機能完成。

---

## Phase 4: User Story 2 - 手動タグ既存記事はスキップ (Priority: P1)

**Goal**: 既に手動タグが 1 件以上付いている記事は AutoTagApplier が auto-apply をスキップ。spec 008 までの既存記事の運用を破壊しない。

**Independent Test**: T006 の単体テスト pass。実機検証は quickstart 検証 2。

### Tests for User Story 2

- [x] T006 [P] [US2] `KnowledgeTreeTests/AutoTagApplierTests.swift` に `testSkipsWhenArticleHasManualTag` を追加:
  - article.tags に手動タグ 1 件を pre-insert
  - apply 呼び出し
  - `article.tags.count == 1` 不変 (auto-apply スキップ確認)
  - tag.name は手動タグのままで AI suggestions の名前にならない

### Implementation for User Story 2

- [x] T007 [US2] **実装変更なし** — T011 の AutoTagApplier 内 early return ロジックで FR-006 を既にカバー。タスクとしては「ロジックが正しく動作することの確認」のみ。

**Checkpoint**: T006 unit test pass。手動タグ既存記事の動作回帰なし。

---

## Phase 5: User Story 3 - 削除整理 + 再抽出での復活 (Priority: P2)

**Goal**: ユーザーが auto-apply タグを全削除した後、再抽出が走れば salience ≥ 4 候補が復活する (永続的ブラックリストは将来 spec)。

**Independent Test**: T008 / T015 の単体テスト pass。実機は quickstart 検証 3。

### Tests for User Story 3

- [x] T008 [P] [US3] `AutoTagApplierTests.swift` に `testReappliesAfterAllTagsRemoved` を追加:
  - apply 1 回目 (5 タグ付与)
  - tagStore.removeTag で全削除 (article.tags.count == 0 確認)
  - apply 2 回目
  - 同じ 5 タグ復活確認 (article.tags.count == 5、tag.name セット一致)
- [x] T009 [P] [US3] `AutoTagApplierTests.swift` に `testIdempotentOnDoubleInvocation` を追加:
  - apply 1 回目 (5 タグ付与)
  - apply 2 回目 (article.tags.count >= 1 で early return → 結果不変)
  - 2 回目で重複 add や数値増加なし

### Implementation for User Story 3

- [x] T010 [US3] **実装変更なし** — T011 の AutoTagApplier 設計で「tags.isEmpty なら apply、そうでなければスキップ」が既に成立しており、復活シナリオは TagStore.addTag の冪等挙動で自動的に実現。タスクとしてはテスト pass 確認のみ。

**Checkpoint**: T008 / T009 unit test pass。

---

## Phase 6: User Story 4 - knowledge 失敗時の非付与 (Priority: P2)

**Goal**: knowledge 抽出が `failed` / `pending` / `extracting` / `skipped` の状態では auto-apply が走らない (誤付与を防ぐ)。

**Independent Test**: T014 / T015 の単体テスト pass。実機は quickstart 検証 4 (Apple Intelligence 一時 OFF)。

### Tests for User Story 4

- [x] T014 [P] [US4] `AutoTagApplierTests.swift` に `testSkipsWhenKnowledgeStatusIsFailed` を追加:
  - article + ExtractedKnowledge(status: .failed) + entities (salience 5,5,4)
  - apply 呼び出し
  - `article.tags.count == 0` (auto-apply 非発火確認)
- [x] T015 [P] [US4] `AutoTagApplierTests.swift` に `testSkipsWhenKnowledgeStatusIsPending` を追加:
  - 同上だが status: .pending
  - tags 0 件確認
- [x] T016 [P] [US4] `AutoTagApplierTests.swift` に `testEmptyEntitiesNoTagsApplied` を追加:
  - article + ExtractedKnowledge(status: .succeeded) + entities = []
  - apply 呼び出し → tags 0 件 (空候補による正常 no-op)

### Implementation for User Story 4

- [x] T017 [US4] **実装変更なし** — T011 の AutoTagApplier の status guard で既にカバー。テスト pass 確認のみ。

**Checkpoint**: T014 / T015 / T016 unit test pass。失敗時の誤付与なし。

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: 既存テスト回帰 / quickstart 検証 / ドキュメント更新

- [x] T018 [P] 既存 `KnowledgeTreeTests/` の全テストが pass することを `xcodebuild test -only-testing:KnowledgeTreeTests` で確認。Simulator 実行で exit code 0 (全 PASS、failed 件数 0) を確認済。`KnowledgeExtractionServiceTests` がイニシャライザ変更後も pass (default `tagStore: nil` で後方互換)。
- [x] T019 [P] `KnowledgeTreeUITests/` の既存テストが pass することを確認。UI 変更なしのため理論上回帰ゼロ。
- [ ] T020 quickstart.md 検証 1〜7 を実機 (iPhone 17 Pro 等) で実行:
  - 検証 1 (新規記事 → 5 タグ自動付与, SC-001)
  - 検証 2 (手動タグ既存スキップ, SC-002)
  - 検証 3 (全削除復活, SC-003)
  - 検証 4 (失敗時非付与, SC-004)
  - 検証 5 (spec 011 PowerGauge / KnowledgeMap 連動)
  - 検証 6 (spec 008 までの既存挙動回帰, SC-005)
  - 検証 7 (連続 100 件、時間が許せば, SC-007)
- [ ] T021 [P] Instruments で auto-apply の実行時間を Time Profiler で計測。Constitution パフォーマンスゲート (≤100ms) を満たすこと (SC-006)。
- [x] T022 [P] `CLAUDE.md` の SPECKIT セクションを更新し spec 012 を「✅ 実装 + commit `<sha>`」に書き換え。
- [x] T023 [P] `KnowledgeTree/Services/AutoTagApplier.swift` のコードレビュー: Swift API Design Guidelines 準拠 / `fatalError` / `try!` 不使用確認。
- [x] T024 最終 build で警告ゼロ確認 (本 spec の改修起因の警告 0)。
- [ ] T025 PR 説明に Constitution Check 全 11 ゲート ✅ + spec 012 の挙動変化点 (auto-apply 発火タイミング、UX 変更) を明記。

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: なし
- **Phase 2 (Foundational)**: 即着手可、全 US の前提
- **Phase 3 (US1 自動付与)**: Phase 2 完了後、AutoTagApplier 本実装 + hook 2 箇所追加
- **Phase 4 (US2 手動既存スキップ)**: Phase 3 の T011 完了後 (実装は同じ AutoTagApplier 内、テストのみ追加)
- **Phase 5 (US3 復活)**: Phase 3 完了後 (テストのみ)
- **Phase 6 (US4 失敗時非付与)**: Phase 3 完了後 (テストのみ)
- **Phase 7 (Polish)**: 全 US 完了後

### User Story Dependencies

- **US1 (P1, 自動付与)**: Foundational のみ依存。AutoTagApplier 本実装 + hook 2 箇所が新規実装の本体
- **US2 (P1, 手動既存スキップ)**: US1 の T011 (AutoTagApplier 本実装) に依存。実装変更なし、テストのみ追加
- **US3 (P2, 復活)**: 同上、テストのみ
- **US4 (P2, 失敗時非付与)**: 同上、テストのみ

### 共通ファイル順序制約

- `AutoTagApplier.swift`: T001 (stub) → T011 (本実装)。1 ファイル、順次
- `KnowledgeExtractionService.swift`: T002 (イニシャライザ拡張) → T012 (単一 hook) → T013 (chunked hook)。1 ファイル、順次
- `KnowledgeTreeApp.swift`: T003 (1 行追加) のみ
- `AutoTagApplierTests.swift`: T004 (fixture) → T005-T016 (個別ケース、ケース間は [P])

---

## Parallel Opportunities

### Foundational Phase (Phase 2)

```text
T001 (AutoTagApplier 新規) と T002 (KnowledgeExtractionService 改修) は別ファイル → [P] 可
T003 (KnowledgeTreeApp bootstrap) は T001 / T002 完了後 (両者を inject 配線するため)
```

### Tests 並列 (各 US)

```text
T004 [P] [US1] (fixture) → T005 [P] [US1] (testApplies)
T006 [P] [US2] (testSkips manual)
T008 [P] [US3] (testReapplies)
T009 [P] [US3] (testIdempotent)
T014 [P] [US4] (testSkips failed)
T015 [P] [US4] (testSkips pending)
T016 [P] [US4] (testEmptyEntities)
全テストケース追加は同ファイルだが個別 @Test func なので [P] 並列可 (実際の編集は順次でも同期統合は容易)
```

### Implementation 並列 (US1)

```text
T011 [US1] (AutoTagApplier 本実装) と T012/T013 (KnowledgeExtractionService hook) は別ファイル → [P] 可
ただし T011 完了前に T012/T013 を入れると compile fail (空 stub の apply() を呼ぶ)
推奨順序: T011 → T012 → T013
```

### Polish Phase

```text
T018 / T019 / T021 / T022 / T023 [P] 並列実行可
T020 (実機検証) は T018 後の order
T024 / T025 順次
```

---

## Implementation Strategy

### MVP First (US1 + US2 のみ)

1. Phase 2 (Foundational): T001-T003 完了
2. Phase 3 (US1): T004-T013 完了 (AutoTagApplier 本実装 + 単体テスト + hook 2 箇所)
3. Phase 4 (US2): T006 完了 (テスト追加、実装変更なし)
4. **STOP and VALIDATE**: T005 + T006 unit test pass → 実機 quickstart 検証 1 / 2 → MVP demo OK
5. US3 / US4 / Polish は後追加

### Incremental Delivery

1. MVP (上記) → 検証 → 中間 commit
2. US3 (復活) + US4 (失敗時非付与): T008 / T009 / T014 / T015 / T016 → 単体テスト追加 → 検証
3. Polish (Phase 7): 既存テスト回帰 / quickstart 全 7 検証 / Instruments 計測 / PR

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
- 既存スキーマ完全無改修 (新 @Model ゼロ、新 migration ゼロ、新 transient struct ゼロ)
- 既存 SuggestedTagFinder / TagStore / TagNormalizer / BackgroundExtractionRunner / 全 View / 全 Model は本 spec で 1 行も改修しない
- 改修対象は `AutoTagApplier.swift` (新規) + `KnowledgeExtractionService.swift` (~10 行) + `KnowledgeTreeApp.swift` (1 行) + `AutoTagApplierTests.swift` (新規) の 4 ファイルのみ

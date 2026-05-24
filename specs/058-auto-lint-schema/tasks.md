# Tasks: Auto-Lint + Schema 外出し + Confirm UX 廃止

**Input**: spec.md / plan.md
**Branch**: `056-uiux-redesign-v3` (V3.0 統合)
**Total**: 38 tasks across 6 phases

## Phase A — Confirm UX 廃止 + UI 削除 (P1、~600 行、3 日)

- [ ] T001 ConflictProposal.status に `autoResolved` case 追加 + SwiftData lightweight migration (`KnowledgeTree/Models/ConflictProposal.swift`)
- [ ] T002 ConflictDetectionService に auto-resolve API (`KnowledgeTree/Services/ConflictDetectionService.swift`)
- [ ] T003 GraphProposalReviewService に auto-resolve (高信頼度 採用 / 低信頼度 skip) (`KnowledgeTree/Services/GraphProposalReviewService.swift`)
- [ ] T004 ActionItemsReviewView ファイル削除 + KnowledgeClipView から navigationDestination + import 削除 (`KnowledgeTree/Views/ActionItemsReviewView.swift` + `KnowledgeClipView.swift`)
- [ ] T005 FollowingPeopleSection から `⚠️ 更新が必要 (N)` badge 削除 (`KnowledgeTree/Views/FollowingPeopleSection.swift`)
- [ ] T006 GraphProposalsSection 削除 (CategoryDetailView から、ファイル存在すれば削除)
- [ ] T007 ConflictHistoryDisclosure 新規 (ArticleDetailView 末尾「過去の見解 (N) ▼」、`KnowledgeTree/Views/ConflictHistoryDisclosure.swift`、~80 行)
- [ ] T008 ArticleDetailView に ConflictHistoryDisclosure 配線 (`KnowledgeTree/Views/ArticleDetailView.swift`)

## Phase B — LintEngine core (P1、~1000 行、5-7 日)

- [ ] T009 LintEngine Protocol + Default 新規 (`KnowledgeTree/Services/LintEngine.swift`、~300 行、6 step state machine)
- [ ] T010 Step 1 ConceptPage merge logic (編集距離 ≤ 2 OR embedding sim ≥ 0.85)
- [ ] T011 Step 2 ConceptPage delete logic (60 日 + ≤ 1 件 + 非 follow)
- [ ] T012 Step 3 Tag delete (orphan, articles=空)
- [ ] T013 Step 4 ConceptPage link 強化 (categoryRaw + embedding 類似)
- [ ] T014 Step 5 Tag/Category 再分類 (AutoCategoryClassifier 経由)
- [ ] T015 LintLog @Model 新規 (`KnowledgeTree/Models/LintLog.swift`) + SharedSchema 統合
- [ ] T016 LintEngineTests 新規 (`KnowledgeTreeTests/LintEngineTests.swift`、~250 行、各 step + idempotent)

## Phase C — SavedAnswer auto-refresh + 週 1 BGTask (P1、~500 行、3 日)

- [ ] T017 SavedAnswerService.autoRefreshStale API (`KnowledgeTree/Services/SavedAnswerService.swift`)
- [ ] T018 LintEngine Step 6 = auto-refresh + ConflictProposal auto-resolve cleanup
- [ ] T019 BackgroundExtractionScheduler に `app.KnowledgeTree.weeklyLint` 追加 (`KnowledgeTree/Services/BackgroundExtractionScheduler.swift`)
- [ ] T020 Info.plist BGTaskSchedulerPermittedIdentifiers 拡張
- [ ] T021 KnowledgeTreeApp で BGTask handler register + LintEngine 注入 (`KnowledgeTree/KnowledgeTreeApp.swift`)

## Phase D — Settings UI (P2、~500 行、3 日)

- [ ] T022 HealthScoreService Protocol + Default (`KnowledgeTree/Services/HealthScoreService.swift`)
- [ ] T023 HealthScoreCard view (`KnowledgeTree/Views/HealthScoreCard.swift`、Settings 内上部)
- [ ] T024 LintLogSection view (`KnowledgeTree/Views/LintLogSection.swift`、直近 30 件表示)
- [ ] T025 LintNowButton view (`KnowledgeTree/Views/LintNowButton.swift`、60 秒 debounce)
- [ ] T026 SettingsView に 3 component 追加 (`KnowledgeTree/Views/SettingsView.swift`)
- [ ] T027 HealthScoreServiceTests (`KnowledgeTreeTests/HealthScoreServiceTests.swift`、~150 行)

## Phase E — Schema 外出し (P3、~400 行、2 日)

- [ ] T028 docs/iknow-schema.md 新規 (LLM 指示書テンプレ、AB test base)
- [ ] T029 SchemaLoader 新規 (`KnowledgeTree/Services/SchemaLoader.swift`、Foundation file API + cache + fallback)
- [ ] T030 KnowledgeTreeApp 起動時 SchemaLoader.shared.load
- [ ] T031 ChatService / LintEngine で SchemaLoader 経由参照 (production fallback)
- [ ] T032 pbxproj or Build Phases で docs/iknow-schema.md を App Bundle に追加
- [ ] T033 SchemaLoaderTests (`KnowledgeTreeTests/SchemaLoaderTests.swift`、~100 行)
- [ ] T034 SchemaLoader.reloadIfChanged (debug build only)

## Phase F — Polish + Final (Polish、~300 行、2 日)

- [ ] T035 Build 警告ゼロ + 全 regression test PASS
- [ ] T036 CLAUDE.md 更新 (spec 058 → 🔧 実装中)
- [ ] T037 PR #17 update + commit + push
- [ ] T038 実機検証 (ユーザー、quickstart.md SC-001〜SC-018)

## Dependencies

- T001 (ConflictProposal schema) → T002 (ConflictDetectionService refactor)
- T002 → T004 (ActionItemsReviewView 削除は ConflictProposal 自動採用後)
- T009 (LintEngine) → T010-T014 (各 step)
- T015 (LintLog) → T010-T014 (永続化呼出)
- T021 (BGTask register) → T019 (BGTask schedule)
- T026 (Settings UI 統合) → T023-T025 (component 完成後)
- 全 Phase → T035-T038 (Polish)

## Parallel Opportunities [P]

- T010, T011, T012, T013, T014 (LintEngine 各 step) は別 logic、並列可
- T023, T024, T025 (Settings UI 3 component) は別 view、並列可
- T016, T027, T033 (3 test suite) は別 file、並列可
- T028 (schema.md) は単独可、いつでも

## MVP 範囲

Phase A + Phase B (T001-T016) = 17 tasks = MVP の core。
Phase C は週 1 BGTask、Phase D-F は polish。

## 実装規模

- 新規 12 ファイル + 改修 12 ファイル + 削除 1 ファイル = ~4500-5500 行
- 期間: 4-6 週間
- 38 tasks

# Implementation Plan: Auto-Lint + Schema 外出し + Confirm UX 廃止

**Branch**: `056-uiux-redesign-v3` (V3.0 = spec 056 + 057 + 058 統合)
**Date**: 2026-05-24
**Spec**: [spec.md](./spec.md)

## Summary

「ユーザーに聞かず、AI が裏で勝手に整理する」を実体化。Autoresearch + LLM Wiki のチューニング思想 (program.md / val_bpb / NEVER STOP loop) を iKnow に完全移植。

技術的アプローチ:
- **Confirm UX 廃止**: ConflictProposal / StaleSavedAnswer / Graph proposals を AI 自動採用、対応 UI 全削除
- **Lint loop (6 step)**: 統合 → 削除 → リンク → 再分類 → refresh を週 1 BGTask + 手動 trigger で実行
- **健全性スコア**: 単一指標 (孤立 + 矛盾) で deterministic 評価、Settings に静かに表示
- **Schema 外出し**: docs/iknow-schema.md に LLM 指示書、code fallback で production 安全保証
- **「過去の見解」DisclosureGroup**: 矛盾検出時にデータロスゼロで旧情報も保持

## Technical Context

**Language/Version**: Swift 6 / SwiftUI / SwiftData (iOS 26+)
**Primary Dependencies**: Foundation, SwiftUI, SwiftData, Foundation Models, BackgroundTasks
**Storage**: SwiftData (新 @Model 1 つ = LintLog)、UserDefaults (BGTask schedule flag)、Foundation file API (schema.md)
**Testing**: XCTest / Swift Testing macro、in-memory ModelContainer、Mock LM、Date 注入
**Target Platform**: iOS 26+ / iPadOS 26+
**Project Type**: mobile-app
**Performance Goals**: Lint loop 1000 article 規模で 30 秒以内 / 個別 step idempotent / BGTask 30s expirationHandler 対応
**Constraints**: 既存 confirm UI 削除での regression 防止 / CloudKit lightweight migration (LintLog 新 @Model + ConflictProposal.status enum 拡張)
**Scale/Scope**: 新規 10-12 + 改修 10-12 + 削除 1 = ~4500-5500 行、4-6 週間、30-40 タスク

## Constitution Check

- [X] **I. Privacy-first**: Lint loop 完全 on-device、Schema は local docs/ のみ、外部 API 呼び出しゼロ
- [X] **II. MVP / 引き算**: 「ユーザーに聞かない」哲学徹底、機能追加ではなく Confirm UX 廃止 + 自動化
- [X] **III. ソース追跡**: 矛盾は「両方残す」default、Article は不変 (Raw sources)、データロスゼロ
- [X] **IV. iOS 実現可能性**: BGTaskScheduler 既存パターン (spec 009/042 同) + Foundation file API + 既存 service reuse
- [X] **V. Calm UX**: 本 spec の core — Apple Photos Memories 風、確認 UI 全廃、log は控えめ
- [X] **VI. Architecture**: Protocol + DI + 既存 hook 拡張、Lint loop は 6 step state machine
- [X] **VII. 日本語ファースト**: 全 UI 文言日本語 (「整理しました」「健全性スコア」「過去の見解」)

### Quality Gates

- [X] **コード品質**: Swift API Guidelines、protocol 抽象化 (LintEngine / HealthScoreService / SchemaLoader)
- [X] **テスト**: 新 service 3 つに unit test (LintEngineTests / HealthScoreServiceTests / SchemaLoaderTests)、既存 regression PASS
- [X] **アクセシビリティ**: 新 view (HealthScoreCard / LintLogSection / 過去の見解 DisclosureGroup) に accessibilityIdentifier
- [X] **パフォーマンス**: Lint loop 30 秒以内 + BGTask expirationHandler graceful stop

## Project Structure

```text
KnowledgeTree/
├── Models/
│   ├── LintLog.swift                              # 新規 (@Model)
│   └── ConflictProposal.swift                     # 改修 (autoResolved status case)
├── Services/
│   ├── LintEngine.swift                           # 新規 (Protocol + Default)
│   ├── HealthScoreService.swift                   # 新規 (Protocol + Default)
│   ├── SchemaLoader.swift                         # 新規 (Foundation file API)
│   ├── ConflictDetectionService.swift             # 改修 (auto-resolve)
│   ├── SavedAnswerService.swift                   # 改修 (auto-refresh hook)
│   ├── GraphProposalReviewService.swift           # 改修 (auto-resolve)
│   ├── ConceptPageStore.swift                     # 改修 (auto-merge logic)
│   ├── TagStore.swift                             # 改修 (orphan auto-cleanup)
│   ├── BackgroundExtractionScheduler.swift        # 改修 (週 1 BGTask)
│   └── ServiceContainer.swift                     # 改修 (新 3 service inject)
├── Views/
│   ├── HealthScoreCard.swift                      # 新規 (Settings 内)
│   ├── LintLogSection.swift                       # 新規 (Settings 内)
│   ├── LintNowButton.swift                        # 新規 (Settings 内)
│   ├── ConflictHistoryDisclosure.swift            # 新規 (ArticleDetailView 末尾)
│   ├── ActionItemsReviewView.swift                # 削除
│   ├── FollowingPeopleSection.swift               # 改修 (⚠️ badge 削除)
│   ├── KnowledgeClipView.swift                    # 改修 (navigationDestination 削除)
│   ├── SettingsView.swift                         # 改修 (HealthScoreCard / LintNowButton / LintLogSection 追加)
│   └── ArticleDetailView.swift                    # 改修 (ConflictHistoryDisclosure 追加)
├── KnowledgeTreeApp.swift                         # 改修 (BGTask handler register + Lint service DI)
└── Localization/Localizable.xcstrings              # ~30 文言追加

docs/
└── iknow-schema.md                                # 新規 (LLM 指示書 AB test ベース)

KnowledgeTreeTests/
├── LintEngineTests.swift                          # 新規 (~250 行)
├── HealthScoreServiceTests.swift                  # 新規 (~150 行)
└── SchemaLoaderTests.swift                        # 新規 (~100 行)

Info.plist                                          # BGTaskSchedulerPermittedIdentifiers 拡張
```

## Implementation Phases

### Phase A (P1、~600 行、3 日) — Confirm UX 廃止 + UI 削除

- T001: ConflictProposal.status に `autoResolved` case 追加 + SwiftData lightweight migration
- T002: ConflictDetectionService に auto-resolve API、検出時に即 autoResolved 化
- T003: GraphProposalReviewService に auto-resolve (高信頼度 採用 / 低信頼度 skip)
- T004: ActionItemsReviewView ファイル削除 + KnowledgeClipView navigationDestination 削除
- T005: FollowingPeopleSection から `⚠️ 更新が必要 (N)` badge 削除
- T006: GraphProposalsSection 削除 (CategoryDetailView から)
- T007: ConflictHistoryDisclosure 新規 (ArticleDetailView 末尾「過去の見解 (N) ▼」)
- T008: ArticleDetailView に ConflictHistoryDisclosure 配線

### Phase B (P1、~1000 行、5-7 日) — LintEngine core

- T009: LintEngine Protocol + Default 新規 (6 step state machine)
- T010: Step 1 ConceptPage merge (編集距離 ≤ 2 OR embedding sim ≥ 0.85)
- T011: Step 2 ConceptPage delete (60 日 + ≤ 1 件 + 非 follow)
- T012: Step 3 Tag delete (orphan)
- T013: Step 4 ConceptPage link 強化 (categoryRaw + embedding 類似)
- T014: Step 5 Tag/Category 再分類 (AutoCategoryClassifier 経由)
- T015: LintLog @Model 新規 + 各 step で永続化
- T016: LintEngineTests 新規 (~250 行、各 step 個別 + idempotent)

### Phase C (P1、~500 行、3 日) — SavedAnswer auto-refresh + 週 1 BGTask

- T017: SavedAnswerService.autoRefreshStale API 新規 (isStale → agent loop 経由)
- T018: LintEngine Step 6 = SavedAnswer auto-refresh + ConflictProposal auto-resolve cleanup
- T019: BackgroundExtractionScheduler に `app.KnowledgeTree.weeklyLint` 追加
- T020: Info.plist BGTaskSchedulerPermittedIdentifiers 拡張
- T021: KnowledgeTreeApp で BGTask handler register + LintEngine 注入

### Phase D (P2、~500 行、3 日) — Settings UI

- T022: HealthScoreService Protocol + Default 新規
- T023: HealthScoreCard view 新規 (Settings 内、上部表示)
- T024: LintLogSection view 新規 (直近 30 件表示)
- T025: LintNowButton view 新規 (60 秒 debounce)
- T026: SettingsView に 3 component 追加
- T027: HealthScoreServiceTests 新規 (~150 行)

### Phase E (P3、~400 行、2 日) — Schema 外出し

- T028: docs/iknow-schema.md 新規 (LLM 指示書テンプレ)
- T029: SchemaLoader 新規 (Foundation file API + cache + fallback)
- T030: KnowledgeTreeApp 起動時 SchemaLoader.shared.load
- T031: ChatService / LintEngine で SchemaLoader 経由参照 (production fallback)
- T032: Info.plist or pbxproj で docs/ を App Bundle に含める
- T033: SchemaLoaderTests 新規 (~100 行)
- T034: SchemaLoader.reloadIfChanged (debug build only)

### Phase F (Polish、~300 行、2 日) — Tests + Final

- T035: Build 警告ゼロ + 全 regression test PASS
- T036: CLAUDE.md 更新 (spec 058 → 🔧 実装中)
- T037: PR #17 update + ロックダウン commit
- T038: 実機検証 (ユーザー、quickstart.md SC-001〜SC-018)

## Status

- [X] Phase 0: research (本 plan.md 内に統合)
- [X] Phase 1: data-model (本 plan.md Project Structure 参照)
- [X] Constitution Check 全 PASS
- [ ] Phase 2: tasks.md 生成
- [ ] Implementation

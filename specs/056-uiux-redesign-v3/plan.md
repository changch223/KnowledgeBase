# Implementation Plan: UIUX Redesign V3.0 — 3-Tab Simplification

**Branch**: `056-uiux-redesign-v3` | **Date**: 2026-05-24 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/056-uiux-redesign-v3/spec.md`

## Summary

V2.5 まで機能を足し算で増やしてきた結果、4 タブ + 各タブ内 8 セクション超で「ごちゃごちゃ」状態になった iKnow を、Apple HIG (Clarity / Deference / Depth) と Apple News/Photos の Today パターンに沿って **引き算で再設計** する。

中核体験: **「気になったものが、勝手に整理される」** (週 1-2 回ライトユース前提)

技術的アプローチ:
- 5 root tab (学習 / AI チャット / 知識 Clip / ライブラリ / Settings) → **3 root tab** (知識 Clip / ライブラリ / AI チャット)
- 知識 Clip タブを 8 セクション → **3 セクション** (最近の記事 / 続きが気になるもの / 追っている人物・モノ) に削減
- 削除した root view (UnderstandingTabView / AIBrainView / SettingsView) の機能は新動線で完全保持
- 新規 3 service + 12 view、改修 8 ファイル、削除 3 ファイル
- 全 SwiftData @Model 変更ゼロ (UI 専用 spec)
- V2.5 (CloudKit) と一括で V3.0 release

## Technical Context

**Language/Version**: Swift 6 / SwiftUI / SwiftData (iOS 26+)
**Primary Dependencies**: Foundation, SwiftUI, SwiftData, Foundation Models (既存)
**Storage**: SwiftData (既存)、UserDefaults (差分 cache + V3 migration flag + suggested prompts cache)
**Testing**: XCTest / Swift Testing macro、in-memory ModelContainer、Mock + 純粋関数 unit test、XCUIApplication + accessibilityIdentifier UI test
**Target Platform**: iOS 26+ / iPadOS 26+ (macOS 対象外)
**Project Type**: mobile-app (iOS native, SwiftUI)
**Performance Goals**: 知識 Clip タブ 1 秒以内表示 / 60 fps scroll (Article 1000 件 + ConceptPage 100 件 + GraphNode 200 件) / FAB → URL → 保存 30 秒以内 / 📊 → Knowledge Graph 2 秒以内
**Constraints**: 既存 spec 044/042/043/040/018/035/036/037/046/051 の動作完全保持、SwiftData @Model 変更ゼロ
**Scale/Scope**: 新規 12-15 ファイル + 改修 8 + 削除 3 = ~2000-2300 行、2-3 週間、~25-30 タスク

## Constitution Check

Reference: `.specify/memory/constitution.md` (v1.0.0)

### 主要原則 (Core Principles)

- [X] **I. プライバシーファースト・ローカルファースト** — UI redesign のみ、新規データ収集ゼロ。全データは既存 SwiftData (+CloudKit private DB、spec 051) 内に保持。外部送信なし。
- [X] **II. MVP ファースト開発** — **本 spec の core 原則** — 引き算で必要なものだけを表に出す。Memories / Apple Sign In / 多言語対応 等は明示的に範囲外。
- [X] **III. ソースに基づいた知識生成** — 引用記事 chip (spec 047) / KnowledgeGraph (spec 040/041) / ConceptPage 詳細 (spec 042) 等の source 追跡 UI は全継承。新 UI も既存 @Model 経由なので追跡可能性維持。
- [X] **IV. iOS の実現可能性を重視する** — SwiftUI 標準 (NavigationStack / TabView / List / LazyVStack / Sheet) + 既存 service 流用。iOS 26+ 前提、Apple Intelligence 既存対応 (spec 048) 継承。
- [X] **V. シンプルで落ち着いた UX** — **本 spec の core 原則** — Apple HIG Clarity / Deference / Depth 準拠。streak / バッジ / 通知 / 強い色 一切なし。tab 数削減 + section 数削減で認知負荷削減。
- [X] **VI. 保守しやすい SwiftUI アーキテクチャ** — 新規 3 service は Protocol + Default DI、ServiceContainer 経由 inject。各 view 200 行以下を目標、巨大 view 回避。
- [X] **VII. 日本語ファースト** — 全 UI 文言日本語 (「最近の記事」「続きが気になるもの」「追っている人物・モノ」「+ 追加」「家庭教師が考えています…」等)。Localizable.xcstrings 経由で生文字列なし。

### Quality Gates (二次ゲート)

- [X] **コード品質** — Swift API Design Guidelines 準拠。`fatalError` / `try!` 等は新規コードに導入しない。新規抽象化 (RecentArticlesService / SuggestedPromptGenerator / LibraryDateGrouper) は Protocol + Default DI で再利用可能、各 view との結合度を最小化。
- [X] **テスト** — 新規 service 3 つ全て Mock + 純粋関数 unit test (8+6+5=19 ケース)。既存 unit test 全 regression PASS 必須。in-memory ModelContainer + SharedSchema.all 利用。UI test は accessibilityIdentifier 経由で 3 ケース新規 (タブ削減 / FAB / Suggested prompt tap)。
- [X] **アクセシビリティ・UX 一貫性** — 新規 view 全 interactive 要素に accessibilityIdentifier (例: `tab.knowledgeClip`, `section.recentArticles`, `card.understanding.{id}`, `fab.addArticle`, `prompt.suggested.{index}`)。Dynamic Type / Dark Mode / VoiceOver 対応 (DesignSystem token 経由)。SF Symbols ("person.crop.circle" 等) 利用。生文字列禁止。
- [X] **パフォーマンス** — 知識 Clip 1 秒以内 (SC-003)、60fps 維持 (SC-008)、@Query は predicate or fetchLimit 指定、LazyVStack で大量データ対応、escaping closure に [weak self]。Knowledge Graph 全体画面は Category 単位 subgraph 分割で重さ対処 (R7)。

## Project Structure

### Documentation (this feature)

```text
specs/056-uiux-redesign-v3/
├── plan.md              # This file
├── research.md          # Phase 0 output (12 research questions R1-R12)
├── data-model.md        # Phase 1 output (transient struct 4 + UserDefaults key 2)
├── quickstart.md        # Phase 1 output (15 検証シナリオ)
├── contracts/           # Phase 1 output
│   ├── recent-articles-service.md
│   ├── suggested-prompt-generator.md
│   ├── library-date-grouper.md
│   ├── knowledge-clip-view.md
│   ├── library-grouped-view.md
│   ├── chat-tab-view-toolbar.md
│   ├── knowledge-graph-full-screen-view.md
│   ├── action-items-review-view.md
│   ├── avatar-menu.md
│   ├── fab-button.md
│   └── add-article-sheet.md
├── checklists/
│   └── requirements.md  # Quality checklist (spec)
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
KnowledgeTree/
├── Views/                                # 改修 + 新規
│   ├── KnowledgeClipView.swift           # 全面再構成 (8 → 3 sections)
│   ├── ChatTabView.swift                 # toolbar 📊 + Suggested prompts
│   ├── ArticleListView.swift             # LibraryGroupedView と統合 or 置換
│   ├── SettingsView.swift                # UnderstandingStatsSection 統合
│   ├── UnderstandingTabView.swift        # 削除
│   ├── AIBrainView.swift                 # 削除
│   ├── RecentArticlesSection.swift       # 新規
│   ├── InterestingNextSection.swift      # 新規
│   ├── FollowingPeopleSection.swift      # 新規
│   ├── ActionItemsReviewView.swift       # 新規 (旧 FactConflicts + Stale 統合)
│   ├── SuggestedPromptsSection.swift     # 新規
│   ├── KnowledgeGraphFullScreenView.swift  # 新規 (📊 アイコン遷移先)
│   ├── LibraryGroupedView.swift          # 新規 (日付別 grouping)
│   ├── LibraryFilterPills.swift          # 新規
│   ├── AddArticleSheet.swift             # 新規
│   ├── FABButton.swift                   # 新規 (再利用 component)
│   └── AvatarMenu.swift                  # 新規
├── Services/                             # 新規 3
│   ├── RecentArticlesService.swift       # Protocol + Default
│   ├── SuggestedPromptGenerator.swift    # Protocol + Default
│   └── LibraryDateGrouper.swift          # 純粋関数 + transient struct
├── KnowledgeTreeApp.swift                # AppTab 5 → 3, default migration
├── LastOpenedStore.swift                 # 差分判定 helper 追加
├── ServiceContainer.swift                # 新 3 service inject
└── Localization/Localizable.xcstrings    # ~40 文言追加

KnowledgeTreeTests/
├── RecentArticlesServiceTests.swift      # 新規 8 ケース
├── SuggestedPromptGeneratorTests.swift   # 新規 6 ケース
└── LibraryDateGrouperTests.swift         # 新規 5 ケース

KnowledgeTreeUITests/
└── V3RedesignUITests.swift               # 新規 3 ケース (タブ削減 / FAB / Suggested prompt)
```

**Structure Decision**: 既存の `KnowledgeTree/Views/` + `KnowledgeTree/Services/` 構造を踏襲。新規ファイルは同ディレクトリに配置 (spec 044/042/043 同パターン)。SharedSchema / pbxproj 変更不要 (SwiftData @Model 無変更のため Share/Safari Extension target にも新ファイル追加不要)。

## Complexity Tracking

(Constitution Check 全 PASS、Complexity 違反なし — 表記不要)

---

## Phase 0: Research

12 個の研究質問 (R1-R12) を `research.md` に展開。要点:

- R1: 3 タブ TabView 構造 + tab default migration 方式
- R2: KnowledgeClipView 8 → 3 セクション再構成戦略
- R3: RecentArticlesService 差分判定 + cache 永続化方式
- R4: InterestingNextSection 混在表示 (UnderstandingCard + KnowledgeDigest 統一)
- R5: FollowingPeopleSection + ⚠️ Action Items badge 統合
- R6: SuggestedPromptGenerator 動的生成 + fallback + cache
- R7: KnowledgeGraphFullScreenView 全 Category subgraph 表示
- R8: LibraryGroupedView 日付別 grouping アルゴリズム
- R9: AddArticleSheet URL validation + 重複検知
- R10: AvatarMenu iPhone push vs iPad sheet 分岐
- R11: FABButton scroll 同期 + 共通 component 化
- R12: テスト戦略 (新規 19 + UI 3 + 既存全 regression)

詳細: [research.md](./research.md)

## Phase 1: Design Artifacts

### Data Model

新規 SwiftData @Model: **なし** (UI 専用 spec)

新規 transient struct (4 つ):
- `MixedSurfaceCard` (enum case understanding(UnderstandingCard) / digest(KnowledgeDigest) — InterestingNextSection 表示単位)
- `LibraryDateGroup` (enum case today / yesterday / thisWeek / thisMonth / earlier — LibraryGroupedView)
- `SuggestedPrompt` (struct text: String, sourceType: enum — AI チャット空状態)
- `ActionItemBadgeData` (struct conflictCount: Int, staleSavedAnswerCount: Int, total: Int — ⚠️ badge)

UserDefaults キー (2 つ):
- `spec056_recent_articles_cache` (JSON Array<UUID>、max 3 件 — 差分ゼロ時の維持)
- `spec056_suggested_prompts_cache` (JSON SuggestedPrompt + date — 1 日 1 回更新)
- `spec056_v3_migrated` (Bool — V2.5 → V3.0 初回起動 tooltip 表示判定)

詳細: [data-model.md](./data-model.md)

### Contracts (11)

各 component の interface 契約を `contracts/` 配下に記述:

| ファイル | 対象 |
|---|---|
| recent-articles-service.md | RecentArticlesServiceProtocol + Default |
| suggested-prompt-generator.md | SuggestedPromptGeneratorProtocol + Default |
| library-date-grouper.md | LibraryDateGrouper 純粋関数 + LibraryDateGroup enum |
| knowledge-clip-view.md | 新 KnowledgeClipView 構造 + 3 sections |
| library-grouped-view.md | LibraryGroupedView + LibraryFilterPills |
| chat-tab-view-toolbar.md | ChatTabView の 📊 + Suggested prompts 追加 |
| knowledge-graph-full-screen-view.md | KnowledgeGraphFullScreenView (📊 遷移先) |
| action-items-review-view.md | ActionItemsReviewView (⚠️ badge 遷移先) |
| avatar-menu.md | AvatarMenu component |
| fab-button.md | FABButton 共通 component |
| add-article-sheet.md | AddArticleSheet modal |

### Quickstart

`quickstart.md` に 15 シナリオ (spec.md SC-001〜SC-018 を実機検証手順化)。

## Implementation Phases

Phase 分割で段階 commit:

### Phase A (P1 必須、~1500 行、1 週間)

3 タブ構成 + KnowledgeClipView 全面再構成 + 削除 root view の動線維持。

- T001: AppTab 5 → 3 case 削減 (KnowledgeTreeApp.swift)
- T002: V3 migration flag + 起動 default 知識 Clip 強制
- T003: AvatarMenu component 新規
- T004: KnowledgeClipView 全面再構成 (8 → 3 sections + toolbar avatar)
- T005: RecentArticlesService 新規 (Protocol + Default + UserDefaults cache)
- T006: RecentArticlesSection 新規
- T007: InterestingNextSection 新規 (MixedSurfaceCard 統合)
- T008: FollowingPeopleSection 新規 (⚠️ badge 統合)
- T009: ActionItemsReviewView 新規 (旧 FactConflicts + Stale 統合)
- T010: 削除 root view (UnderstandingTabView / AIBrainView) 物理削除
- T011: Empty States 統合 (3 セクション + AI チャット)
- T012: RecentArticlesServiceTests 新規 (8 ケース)

### Phase B (P2 推奨、~400 行、3 日)

ライブラリ 日付 grouping + 検索/フィルター + FAB。

- T013: LibraryDateGrouper 新規 (純粋関数)
- T014: LibraryGroupedView 新規 (or ArticleListView 統合)
- T015: LibraryFilterPills 新規
- T016: FABButton 新規 (共通 component)
- T017: AddArticleSheet 新規
- T018: LibraryDateGrouperTests 新規 (5 ケース)

### Phase C (P2 推奨、~250 行、2 日)

AI チャット suggested prompts + 📊 Knowledge Graph 全体画面。

- T019: SuggestedPromptGenerator 新規 (Protocol + Default + cache)
- T020: SuggestedPromptsSection 新規
- T021: ChatTabView toolbar 📊 + suggested prompts integration
- T022: KnowledgeGraphFullScreenView 新規
- T023: SuggestedPromptGeneratorTests 新規 (6 ケース)

### Phase D (Polish, 2 日)

- T024: SettingsView に UnderstandingStatsSection 統合 (旧 AI ブレイン統計の格下げ)
- T025: V3 migration onboarding tooltip 表示
- T026: V3RedesignUITests 新規 (3 ケース)
- T027: Build 警告ゼロ確認 (xcodebuild clean build iPhone 17 Simulator)
- T028: 全テスト regression PASS 確認
- T029: CLAUDE.md 更新 (spec 056 を 📝 → 🔧 実装中、後に ✅ 完成)
- T030: 実機検証 (ユーザー実施、quickstart.md SC-001〜SC-018)

詳細 task 分解は `/speckit-tasks` で生成。

## Constitution Re-Check (Post-Design)

Phase 1 完了後の Constitution 再確認:

- I (privacy): ✅ 維持
- II (MVP / 引き算): ✅ Phase A/B/C/D に分け、各 phase が独立 release 可能な MVP slice
- III (source 追跡): ✅ 全継承
- IV (iOS 実現可能性): ✅ SwiftUI 標準 + 既存 service 流用
- V (calm UX): ✅ 維持、Empty States で「親切な空白」追加
- VI (architecture): ✅ Protocol + DI + 各 view 200 行以下目標
- VII (日本語ファースト): ✅ 全 UI 日本語、xcstrings 経由

全 PASS、追加 Complexity 違反なし。

---

## Status

- [X] Phase 0: research.md 生成
- [X] Phase 1: data-model.md + contracts/ + quickstart.md 生成
- [X] Constitution Check 全 PASS
- [ ] Phase 2: tasks.md 生成 (`/speckit-tasks` で実施)
- [ ] Implementation (`/speckit-implement` で実施)

# Implementation Plan: SavedAnswer (AI Chat 答えの永続化と概念ページへの紐付け)

**Branch**: `043-saved-answer` | **Date**: 2026-05-23 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/043-saved-answer/spec.md`

## Summary

`SavedAnswer` は iKnow V1 Phase A 第 2 弾、Karpathy LLM Wiki 思想の **Compound Moment 条件 1** を実体化する。AI Chat (spec 021) の答えに引用が 2 件以上 + 答え本文 50 字以上あれば、その質問と答えを永続化し、引用記事から関連 ConceptPage (spec 042) を解決して紐付ける。これにより、一過性だった chat 答えが「ConceptPage に蓄積される第二の知識層」として compound する。

Foundation Models / AI 合成は使わない純粋ロジック層。spec 037 ConflictDetection / spec 042 ConceptPage と同 fire-and-forget hook パターンで ChatService.ask() 末尾と KnowledgeExtractionService.extract() 末尾に hook を 2 箇所追加。spec 042 ConceptPageDetailView / DetailLoader と同 `@Query live check` パターンで SavedAnswer 詳細画面の crash 回避。

UI は ConceptPage 詳細画面に 5 番目セクション「この概念についての質問と答え (N)」追加 + SavedAnswer 詳細画面新規 + SavedAnswer 全履歴画面 (P2) + SettingsView エントリ + 検索 (P3)。

新規 7 ファイル (実装 6 + テスト 1) + 改修 8 ファイル = ~1300 行。Mock 不要 (純粋ロジック)、in-memory ModelContainer + 既存 MockChatAnswerOutput パターンで 8-10 ケース。期間 2 週間。

## Technical Context

**Language/Version**: Swift 6 (Swift 5.9+ 既存基盤に準拠)
**Primary Dependencies**: SwiftUI / SwiftData (`@Model SavedAnswer` を SharedSchema に追加、lightweight migration)
**Storage**: SwiftData (App Group container 共有、ChatSession / ChatMessage / Article / ConceptPage と同 store)
**Testing**: XCTest (`KnowledgeTreeTests` — in-memory `ModelContainer(SharedSchema.all)` + Mock 不要 (純粋 CRUD ロジック)、ChatServiceTests に MockSavedAnswerService 追加で hook 検証)
**Target Platform**: iOS 26+ / iPadOS 26+
**Project Type**: iOS mobile app (Xcode project 既存、main target + Share/Safari extension)
**Performance Goals**:
- AI Chat 答え表示から SavedAnswer 永続化まで 5 秒以内 (SC-001)
- 同 question 重複防止 100% (SC-002)
- ConceptPage 詳細画面の「質問と答え」セクション表示 1 秒以内 (SC-003)
- SavedAnswer 詳細から Article jump 1 秒以内 (SC-004)
- 100+ 件 SavedAnswer 履歴画面で scroll 60fps (SC-005)
- ピン / 削除 操作 1 秒以内 (SC-006)
- 新記事 ingest → 関連 SavedAnswer isStale 化 5 分以内 (SC-007)
- 検索 (P3) で 100+ 件中の query 一致 1 秒以内 (SC-008)

**Constraints**:
- 完全 on-device (Constitution I)、Foundation Models 不使用 (spec 021 ChatService が AI 担当)
- auto-save は silent fire-and-forget、UI 通知ゼロ (Constitution V calm UX、SC-001)
- @Relationship.nullify で Article 側影響ゼロ (片方向、spec 042 ConceptPage と同パターン)
- ChatSession 削除でも SavedAnswer は残す (履歴保護、chatSessionID は nullable)
- 重複防止: question (空白 trim 後完全一致、case sensitive) で既存 SavedAnswer fetch → skip

**Scale/Scope**:
- 初期想定 SavedAnswer 数: 30-100 件 (1 ユーザー、6 ヶ月)
- 引用記事数: SavedAnswer あたり 2-10 件想定
- relatedConceptIDs: 最大 5 件 (mentionCount/関連記事数 desc)
- 新規ファイル 7 / 改修ファイル 8 = ~1300 行
- Mock テストケース 8-10 + hook 検証 2-3 = ~10-13 ケース
- 期間 2 週間 (Phase A、spec 042 より小規模)
- タスク数見込み: 14-18

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Reference: `.specify/memory/constitution.md` (v1.0.0). 全 7 原則 + 4 quality gate.

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — SavedAnswer / question / answer は SwiftData (ローカル) に永続化。Foundation Models 不使用、外部送信ゼロ。chatSessionID も local UUID。
- [x] **II. MVP ファースト開発** — spec 043 は V1 Phase A 第 2 弾、Compound Moment 条件 1 実体化に focus。P1 (auto-save + ConceptPage surface + 詳細閲覧) + P2 (履歴 + pin/delete + isStale 連動) + P3 (検索) を 1 spec で完成。Out of Scope (WikiLint / Community / Understanding Chat / Widget / 手動保存 / AI 結合) を明示分離。
- [x] **III. ソースに基づいた知識生成** — `citedArticles` は @Relationship.nullify で Article への参照を保持 (FR-003)。SavedAnswer 詳細画面で引用記事タップ → Article Detail jump 可能 (FR-016, SC-004)。AI 答えはユーザーが目視で根拠を辿れる構造。
- [x] **IV. iOS 実現可能性を重視する** — 既存 spec 021 ChatService の `ask()` 末尾、spec 042 KnowledgeExtractionService の extract 末尾、両 hook で完結。新 framework / API 追加ゼロ。
- [x] **V. シンプルで落ち着いた UX** — auto-save silent (FR-005、進捗バー / 通知 / バッジゼロ)。ConceptPage 詳細画面のセクションは関連 SavedAnswer 0 件なら非表示 (US2 シナリオ 1)。calm UX 完全遵守。
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — 層分離: Model (SavedAnswer) / Service (SavedAnswerServiceProtocol + DefaultSavedAnswerService) / View (Row / Section / DetailView / HistoryView)。既存 hook pattern (spec 037 / 040 / 042) と完全同型。
- [x] **VII. 日本語ファースト** — UI 全文言日本語、Localizable.xcstrings に ~12 文言追加 (View body 内 literal 禁止)。question / answer は user 入力言語維持 (英語質問もそのまま保存)。

### Quality Gates (二次ゲート)

- [x] **コード品質** — `fatalError` / `try!` / `!` 使用ゼロ (既存 service 同パターン)。新規 protocol (`SavedAnswerServiceProtocol`) は実装 1 + Mock テスト 1 = 2 箇所利用 (新規抽象化 2 箇所以上ルール充足)。
- [x] **テスト** — `SavedAnswerServiceTests` 8-10 ケース (in-memory ModelContainer + SharedSchema.all)、`ChatServiceTests` 拡張 1-2 ケース (`MockSavedAnswerService` で hook 検証)、`ConceptPageStoreTests` 拡張 1 ケース (merge 連動)。実ネットワーク使用ゼロ。
- [x] **アクセシビリティ・UX 一貫性** — 全 interactive 要素に `accessibilityIdentifier`。Dynamic Type / Dark Mode (spec 017 `Color.adaptive` 流用) / VoiceOver 対応。SF Symbols (`pin.fill`, `trash`, `quote.bubble.fill`, `magnifyingglass`)。
- [x] **パフォーマンス** — @Query は `#Predicate` + 必要に応じ `fetchLimit` 境界付け。100+ 件履歴は LazyVStack で 60fps (SC-005)。escaping closure `[weak self]`。

## Project Structure

### Documentation (this feature)

```text
specs/043-saved-answer/
├── plan.md                                   # This file (/speckit-plan output)
├── research.md                               # Phase 0 (R1-R10)
├── data-model.md                             # Phase 1 (SavedAnswer @Model + transient)
├── quickstart.md                             # Phase 1 (SC-001〜SC-008 検証手順)
├── contracts/
│   ├── saved-answer-model.md
│   ├── saved-answer-service.md
│   ├── chat-service-hook.md
│   ├── knowledge-extraction-stale-hook.md
│   ├── saved-answer-detail-view.md
│   ├── saved-answer-section.md
│   └── saved-answer-history-view.md
├── checklists/
│   └── requirements.md                       # 既作成、全 PASS
└── tasks.md                                  # Phase 2 (/speckit-tasks 出力、本 plan では未生成)
```

### Source Code (repository root)

```text
KnowledgeTree/
├── Models/
│   └── SavedAnswer.swift                     # ★ 新規 (~80 行) — @Model 12 フィールド + computed property
├── Services/
│   ├── ChatService.swift                     # ★ 改修 (~15 行) — ask 末尾 fire-and-forget hook + SavedAnswerService DI
│   ├── KnowledgeExtractionService.swift      # ★ 改修 (~10 行) — extract 末尾 markStaleForArticle hook (single + chunked 両経路)
│   ├── ConceptPageStore.swift                # ★ 改修 (~10 行) — merge で SavedAnswer.relatedConceptIDs の source→target 置換
│   ├── SavedAnswerService.swift              # ★ 新規 (~250 行) — Protocol + DefaultSavedAnswerService
│   ├── ServiceContainer.swift                # ★ 改修 (~3 行) — savedAnswerService 追加
│   ├── SearchService.swift                   # ★ 改修 P3 (~30 行) — searchSavedAnswers 純関数追加
│   └── (既存 service 群)
├── Views/
│   ├── SavedAnswerRow.swift                  # ★ 新規 (~80 行) — 履歴 / セクション内 row
│   ├── SavedAnswerSection.swift              # ★ 新規 (~80 行) — ConceptPage 詳細 内セクション (NavigationLink + 「+N」)
│   ├── SavedAnswerDetailView.swift           # ★ 新規 (~200 行) — 質問 / 答え / 引用記事 / 関連概念ページ + toolbar pin/delete
│   ├── SavedAnswerHistoryView.swift          # ★ 新規 (~150 行) — 全 list + 検索 P3
│   ├── ConceptPageDetailView.swift           # ★ 改修 (~10 行) — SavedAnswerSection を 5 番目セクションに配置
│   ├── SettingsView.swift                    # ★ 改修 (~5 行) — SavedAnswerHistoryView への NavigationLink
│   └── (既存 view 群)
├── SharedSchema.swift                        # ★ 改修 (1 行) — `SavedAnswer.self` 追加
├── KnowledgeTreeApp.swift                    # ★ 改修 (~5 行) — bootstrap で savedAnswerService 構築 + inject
└── Localization/Localizable.xcstrings        # ★ 改修 — 新規 ~12 文言

KnowledgeTreeTests/
├── SavedAnswerServiceTests.swift             # ★ 新規 (~280 行、8-10 ケース)
├── ChatServiceTests.swift                    # ★ 改修 (~30 行) — MockSavedAnswerService + hook 検証 1-2 ケース
└── ConceptPageStoreTests.swift               # ★ 改修 (~25 行) — merge 連動検証 1 ケース
```

**Structure Decision**: 既存 Xcode project + multi-target 構成維持。SavedAnswer.swift は ShareExtension + SafariExtension 両 target にも追加 (spec 042 ConceptPage と同 pbxproj 編集: PBXBuildFile + PBXFileReference + Sources entries)。Main target は auto-sync (PBXFileSystemSynchronizedRootGroup) で自動取り込み (spec 042 の Info.plist exception set はそのまま使用、新規 .swift は除外対象に該当しない)。Info.plist 編集なし (BGTask 追加なし、純粋ロジック層)。

## Complexity Tracking

> **Constitution Check 全 PASS。Complexity Tracking 記載不要。**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (該当なし) | — | — |

# Implementation Plan: Understanding Chat (家庭教師ループ + 学習タブ)

**Branch**: `044-understanding-chat` | **Date**: 2026-05-23 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/044-understanding-chat/spec.md`

## Summary

spec 044 は **iKnow V1 Phase A の核心ロジック完成 spec** で、Karpathy「You can outsource your thinking, but you cannot outsource your understanding」の **家庭教師ループ** を実体化する。spec 021 (秘書ループ = ChatService) + spec 042 (ConceptPage) + spec 043 (SavedAnswer) で完成した「秘書」と並ぶ「家庭教師」の片輪を作り、V1 出荷可能にする。

**中核メカニズム**: 4 タブ目に新規「学習タブ」を追加 (起動 default) → ConceptPage / SavedAnswer を「学習カード」として 5-tier 優先度で surface → 1 タップで Deep Dive Chat 起動 (既存 ChatService 流用、prompt context に家庭教師調注入) → 下部 sticky 「✓ わかった / 🤔 もっと / ✗ 違う」3 ボタンで `ConceptPage.userUnderstanding` (spec 042 既存 0-5 フィールド、本 spec で初活用) を更新 + 1-hop graph 波及 + 行動履歴 (`UnderstandingInteraction` 新 @Model) 永続化。

**技術的アプローチ**: 純粋ロジック層 (新 @Model 1 つ + 3 新 service Protocol+Default)、Foundation Models 直接呼び出しゼロ (deep dive chat は ChatService 経由)、SwiftData 標準のみ、新 framework / API 追加ゼロ。spec 037 / 042 / 043 と同 fire-and-forget hook + `@Query live check` パターン踏襲。

**Out of Scope**: streak / バッジ / 通知 / 効果音 (永久 non-goal、Constitution V) / 「正解 / 不正解」テスト UI (VISION 明示 non-goal) / Widget (spec 048) / iKnow リブランディング (spec 050)。

新規 11 ファイル (実装 8 + テスト 3) + 改修 7 ファイル = ~1750 行。Mock 不要 (純粋ロジック)、in-memory ModelContainer + 既存 MockLanguageModelSession 流用 + MockUnderstandingTrackerService 1 つ追加で 23-25 ケース。期間 3-4 週間。

## Technical Context

**Language/Version**: Swift 6 (Swift 5.9+ 既存基盤に準拠)
**Primary Dependencies**: SwiftUI / SwiftData (`@Model UnderstandingInteraction` を SharedSchema に追加、lightweight migration) / FoundationModels (spec 021 ChatService 経由、直接 import なし)
**Storage**: SwiftData (App Group container 共有、ConceptPage / SavedAnswer / ChatSession / Article と同 store)
**Testing**: XCTest (`KnowledgeTreeTests` — in-memory `ModelContainer(SharedSchema.all)` + Mock 不要 (純粋ロジック層) + 既存 MockLanguageModelSession 流用 + 新 MockUnderstandingTrackerService 1 つ)
**Target Platform**: iOS 26+ / iPadOS 26+
**Project Type**: iOS mobile app (Xcode project 既存、main target + Share/Safari extension)
**Performance Goals**:
- 学習タブ open → 上位 5 カード表示 1 秒以内 (SC-001)
- カードタップ → deep dive chat 画面 + AI 初期発話 3 秒以内 (SC-002、Apple Intelligence 利用可時)
- 「✓ わかった」タップ → DB 反映 + UI 更新 1 秒以内 (SC-003)
- 1-hop graph 波及 (5-10 node) → DB 反映 2 秒以内 (SC-004)
- 100+ 件 UnderstandingCard リストで scroll 60fps (SC-006)
- 空状態 placeholder 表示 1 秒以内 (SC-007)
- 起動 default タブ = 学習タブ 100% (SC-005)
- streak / バッジ / 通知 / 効果音 一切発生ゼロ (SC-009)

**Constraints**:
- 完全 on-device (Constitution I)、Foundation Models は spec 021 ChatService 経由のみ
- streak / バッジ / 通知 / 効果音 永久禁止 (Constitution V、FR-022〜024 で binary check)
- ChatSession 削除でも UnderstandingInteraction は残す (履歴保護、Relationship なし孤立 OK)
- ConceptPage / SavedAnswer 削除済の UnderstandingInteraction は targetID 孤立残存 (UI には現れない、行動履歴の集計のみで利用、削除は migration ジョブ不要)
- 起動 default タブ変更 (spec 035 `.knowledgeClip` → `.learning`) は user setting で override 不可、ただし session 内では選択タブ自由
- 1-hop graph 波及は spec 040 GraphNode/GraphEdge を流用、graph 不存在時は silent degrade (波及スキップ、ConceptPage 本体の +1 は実行)
- userUnderstanding +0.5 累積は Int round-half-up で +1 化 (内部 Float キャッシュなし、UnderstandingInteraction 履歴から都度算出)

**Scale/Scope**:
- 初期想定 ConceptPage 数: 50-200 件 / SavedAnswer 数: 30-100 件 (1 ユーザー、6 ヶ月)
- UnderstandingInteraction 件数: 1 ユーザー / 月あたり 50-200 件想定、年間 1000-2400 件
- surface 上限: 5 件 (1 画面)、全件画面で 100-500 件想定 (LazyVStack)
- 1-hop neighbor: graph 1 node あたり最大 10-20 件
- 新規ファイル 11 (実装 8 + テスト 3) / 改修ファイル 7 = ~1750 行
- Mock テストケース 23-25 (10 surface + 8 tracker + 5 starter + 2 hook 検証)
- 期間 3-4 週間 (Phase A、最大規模)
- タスク数見込み: 22-28

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Reference: `.specify/memory/constitution.md` (v1.0.0). 全 7 原則 + 4 quality gate.

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — `UnderstandingInteraction` 全件 SwiftData (ローカル) に永続化。Foundation Models は spec 021 ChatService 経由 (on-device)、外部送信ゼロ。targetID も local UUID。
- [x] **II. MVP ファースト開発** — spec 044 は V1 Phase A 最大、家庭教師ループ完成に focus。P1 (surface + 起動 default + chat + ✓ + 🤔) + P2 (+N / ✗ / SavedAnswer surface / 学習する Button) + P3 (軽量統計) を 1 spec で完成。Out of Scope (Widget / リブランディング / dashboard / streak / 正解 UI) を明示分離。
- [x] **III. ソースに基づいた知識生成** — Deep dive chat は ChatService (spec 021) 経由で **既存 RAG** を利用 → 引用記事はそのまま AI 答えに付随 (spec 021 既存仕様)。SavedAnswer 経由カード起動時は spec 043 既存 citedArticles 経由で原典追跡可能。本 spec は新規 AI 生成物を作らないので Constitution III 該当箇所は既存仕様継承のみ。
- [x] **IV. iOS 実現可能性を重視する** — 既存 SwiftData + 既存 ChatService 流用、新 framework / API 追加ゼロ。Apple Intelligence 不可時は ChatService 既存 fallback (essence 並べ) に乗る (spec 021 既存仕様)。
- [x] **V. シンプルで落ち着いた UX** — FR-022/023/024 で streak / バッジ / 通知 / 効果音 完全禁止、SC-009 で binary 検証可能。空状態 placeholder + 全 max userUnderstanding 時の「次の学びを待っています」UI で迷路化回避 (Edge Case)。AI ブレイン統計 (P3) は 0 件で非表示 (SC-010、calm UX 完全遵守)。
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — 層分離: Model (UnderstandingInteraction + UnderstandingCard transient) / Service 3 つ (Surface / Tracker / DeepDiveChatStarter、各 Protocol + Default) / View 4 つ (TabView / CardRow / ListView / DeepDiveChatView)。既存 ServiceContainer + DI + RefreshTrigger パターン踏襲。ChatService に依存するが ChatService 自体は無改修。
- [x] **VII. 日本語ファースト** — UI 全文言日本語、Localizable.xcstrings に ~20 文言追加 (「✓ わかった」「🤔 もっと」「✗ 違う」「新しい知識」「更新が必要」「理解が浅い」「深掘り余地あり」「復習」「学習する」等)。家庭教師 prompt も日本語、ChatService が日本語 LM 経由で生成。

### Quality Gates (二次ゲート)

- [x] **コード品質** — `fatalError` / `try!` / `!` 使用ゼロ (既存 service 同パターン)。新規 protocol 3 つ (`UnderstandingCardSurfaceServiceProtocol` / `UnderstandingTrackerServiceProtocol` / `DeepDiveChatStarterProtocol`) は各実装 1 + Mock テスト 1 = 各 2 箇所利用 (新規抽象化 2 箇所以上ルール充足)。
- [x] **テスト** — `UnderstandingCardSurfaceServiceTests` 10 ケース (in-memory ModelContainer + SharedSchema.all)、`UnderstandingTrackerServiceTests` 8 ケース (graph 波及含む)、`DeepDiveChatStarterTests` 5 ケース (MockChatService + MockLanguageModelSession)、`ChatServiceTests` 既存に hook 検証ゼロ追加 (本 spec は ChatService 無改修)。実ネットワーク使用ゼロ、`Date` 注入 (spec 037/042/043 同パターン)。UI テストは pre-existing flaky 8 件以外の主要シナリオを `KnowledgeTreeUITests` に 2-3 件追加 (学習タブ起動 + カードタップ + 「✓ わかった」)。
- [x] **アクセシビリティ・UX 一貫性** — 全 interactive 要素に `accessibilityIdentifier` (`tab.learning` / `card.understanding.{kind}.{id}` / `button.understood` / `button.needMore` / `button.dismissed` / `link.allCards`)。Dynamic Type / Dark Mode (spec 017 `Color.adaptive` 流用) / VoiceOver 対応 (3 ボタンに `accessibilityLabel` 日本語明示)。SF Symbols (`book.fill`, `lightbulb.fill`, `checkmark.circle.fill`, `questionmark.bubble.fill`, `xmark.circle.fill`)。
- [x] **パフォーマンス** — `@Query` は `#Predicate` + `fetchLimit` 境界付け (ConceptPage は 50-200 件想定、SavedAnswer 30-100 件想定、UnderstandingInteraction は最近 30 日分 fetch)。100+ 件 UnderstandingCardListView は LazyVStack で 60fps (SC-006)。escaping closure `[weak self]`。1-hop 波及は graph node 5-10 個想定、2 秒以内完了 (SC-004)。

## Project Structure

### Documentation (this feature)

```text
specs/044-understanding-chat/
├── plan.md                                   # This file (/speckit-plan output)
├── research.md                               # Phase 0 (R1-R12)
├── data-model.md                             # Phase 1 (UnderstandingInteraction @Model + transient)
├── quickstart.md                             # Phase 1 (SC-001〜SC-010 検証手順)
├── contracts/
│   ├── understanding-interaction-model.md
│   ├── understanding-card-transient.md
│   ├── understanding-card-surface-service.md
│   ├── understanding-tracker-service.md
│   ├── deep-dive-chat-starter.md
│   ├── understanding-tab-view.md
│   ├── deep-dive-chat-view.md
│   ├── understanding-card-row.md
│   └── concept-page-detail-learn-button.md
├── checklists/
│   └── requirements.md                       # 既作成、全 PASS
└── tasks.md                                  # Phase 2 (/speckit-tasks 出力、本 plan では未生成)
```

### Source Code (repository root)

```text
KnowledgeTree/
├── Models/
│   └── UnderstandingInteraction.swift        # ★ 新規 (~90 行) — @Model + UnderstandingCard transient + UnderstandingCardKind enum + UnderstandingCardLabel enum
├── Services/
│   ├── UnderstandingCardSurfaceService.swift # ★ 新規 (~200 行) — Protocol + DefaultUnderstandingCardSurfaceService (5-tier scoring)
│   ├── UnderstandingTrackerService.swift     # ★ 新規 (~180 行) — Protocol + Default (recordUnderstood/NeedMore/Dismissed/OpenedChat + 1-hop 波及)
│   ├── DeepDiveChatStarter.swift             # ★ 新規 (~100 行) — Protocol + Default (ChatService wrapper + tutor prompt context 注入)
│   ├── ServiceContainer.swift                # ★ 改修 (~5 行) — 3 新 service 追加
│   └── (既存 service 群)
├── Views/
│   ├── UnderstandingTabView.swift            # ★ 新規 (~120 行) — 新タブ root + 上位 5 + +N + empty state
│   ├── UnderstandingCardRow.swift            # ★ 新規 (~100 行) — 統一カード UI (ConceptPage + SavedAnswer 両対応)
│   ├── UnderstandingCardListView.swift       # ★ 新規 (~80 行) — P2 全件 list (LazyVStack)
│   ├── DeepDiveChatView.swift                # ★ 新規 (~200 行) — chat UI + sticky 3 button bar
│   ├── ConceptPageDetailView.swift           # ★ 改修 (~10 行) — toolbar に「学習する」Button + push DeepDiveChatView
│   ├── AIBrainTabView.swift                  # ★ 改修 (~30 行) — P3 US10 統計セクション (0 件で非表示)
│   ├── ChatTabView.swift                     # 無改修 (既存仕様)
│   └── (既存 view 群)
├── SharedSchema.swift                        # ★ 改修 (1 行) — `UnderstandingInteraction.self` 追加
├── KnowledgeTreeApp.swift                    # ★ 改修 (~20 行) — .learning 新 case + tab default 切替 + 3 新 service 構築 + inject
└── Localization/Localizable.xcstrings        # ★ 改修 — 新規 ~20 文言

KnowledgeTreeTests/
├── UnderstandingCardSurfaceServiceTests.swift # ★ 新規 (~250 行、10 ケース)
├── UnderstandingTrackerServiceTests.swift     # ★ 新規 (~200 行、8 ケース)
└── DeepDiveChatStarterTests.swift             # ★ 新規 (~150 行、5 ケース)

KnowledgeTreeUITests/
└── UnderstandingTabUITests.swift              # ★ 新規 (~80 行、3 ケース: 学習タブ起動 + カードタップ + 「✓ わかった」)
```

**Structure Decision**: 既存 Xcode project + multi-target 構成維持。`UnderstandingInteraction.swift` は ShareExtension + SafariExtension 両 target にも追加 (spec 042 / 043 同 pbxproj 編集: PBXBuildFile + PBXFileReference + Sources entries)。Main target は auto-sync (PBXFileSystemSynchronizedRootGroup) で自動取り込み (spec 042 の Info.plist exception set はそのまま、新規 .swift は除外対象に該当しない)。Info.plist 編集なし (BGTask 追加なし、純粋ロジック層)。`KnowledgeTreeApp.swift` の TabSection enum と LastOpenedStore の default を変更 (spec 035 の `.knowledgeClip` → `.learning`、migration ロジック ~5 行)。

## Complexity Tracking

> **Constitution Check 全 PASS。Complexity Tracking 記載不要。**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (該当なし) | — | — |

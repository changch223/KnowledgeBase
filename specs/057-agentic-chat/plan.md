# Implementation Plan: Agentic Chat

**Branch**: `056-uiux-redesign-v3` (spec 056 と一括 V3.0 release)
**Date**: 2026-05-24
**Spec**: [spec.md](./spec.md)

## Summary

ChatGPT/Gemini 風の agentic chat を Apple Foundation Models のみで実現。LLM が `@Generable enum AgentAction` を毎 turn 返し、Swift 側で switch 分岐して状態遷移する agent loop を実装。

中核:
- 既存 `ChatService.send / ask` の public API を維持、内部実装を全面 refactor
- 「分かりません」廃止 (post-process filter + prompt 制約)
- max 3 round clarification → 必ず最終答え
- 引用 chip は記事関連時のみ (透過的 mode 表示)
- SavedAnswer auto-save 廃止 (将来分)、long press menu で 明示保存

## Technical Context

**Language/Version**: Swift 6 / SwiftUI / SwiftData (iOS 26+)
**Primary Dependencies**: Foundation, SwiftUI, SwiftData, Foundation Models (Apple Intelligence), Accelerate (既存 embedding)
**Storage**: SwiftData (既存)、UserDefaults (long press hint flag)
**Testing**: XCTest / Swift Testing macro、in-memory ModelContainer、Mock LanguageModelSession (既存)、deterministic Date 注入
**Target Platform**: iOS 26+ / iPadOS 26+ (macOS 対象外)
**Project Type**: mobile-app (iOS native, SwiftUI)
**Performance Goals**: agent loop 即答 <= 2.5 sec / clarification 含む <= 5 sec / RAG 含む <= 8 sec
**Constraints**: Apple Foundation Models のみ (external API 不使用)、token 4096 上限、tool calling 不在の代替を Generable enum で
**Scale/Scope**: 新規 6-8 ファイル + 改修 5-6 ファイル + テスト 2 ファイル = ~1500-2000 行、1-2 週間、~22 タスク

## Constitution Check

Reference: `.specify/memory/constitution.md` (v1.0.0)

### 主要原則 (Core Principles)

- [X] **I. プライバシーファースト・ローカルファースト** — Apple Foundation Models 完全 on-device、external LLM API 不使用 (FR-040/041)、新規データ収集ゼロ
- [X] **II. MVP ファースト開発** — RAG「分かりません」問題を agentic で解決、機能追加ではなく置換。multimodal / Web 検索 / API 統合は明示的に範囲外
- [X] **III. ソースに基づいた知識生成** — 引用 chip + ConceptPage chip は agent flow 内で維持 (FR-016/017)、source 追跡可能性は AgentAction.finalAnswer.citedArticleIDs で保証
- [X] **IV. iOS の実現可能性を重視する** — Apple Foundation Models @Generable enum で agent state 構造化 (Tool Use 不在の代替)、既存 spec 044 DeepDiveChatService 実装パターン踏襲、iOS 26+ 標準
- [X] **V. シンプルで落ち着いた UX** — 透過的 mode (引用 chip の有無で自然に分かる)、streak/バッジ/通知ゼロ、clarification は自然な会話で過剰ではない (max 3 round)
- [X] **VI. 保守しやすい SwiftUI アーキテクチャ** — Protocol + DI 維持、ChatService public API 不変で UI 改修ゼロ、AgentAction enum で intent 明示
- [X] **VII. 日本語ファースト** — clarification 質問 / hedge phrase / action menu / hint tooltip 全日本語、Localizable.xcstrings 経由

### Quality Gates (二次ゲート)

- [X] **コード品質** — Swift API Design Guidelines 準拠、`fatalError` 不使用、新規抽象化 (AgentAction enum / AgenticChatService protocol) は protocol + DI で再利用可能
- [X] **テスト** — AgenticChatServiceTests (10+ ケース) + AgentActionTests (Generable round-trip + enum 分岐) 新規、既存全 regression PASS 必須
- [X] **アクセシビリティ・UX 一貫性** — 新規 view (ClarificationChipsView / AnswerActionsMenu) に accessibilityIdentifier、Dynamic Type / Dark Mode / VoiceOver 対応、生文字列禁止 (xcstrings 経由)
- [X] **パフォーマンス** — 即答 <= 2.5 sec (SC-010)、agent loop max 3 round で <= 8 sec、token efficiency (Generable enum schema を小さく保つ)

## Project Structure

### Documentation (this feature)

```text
specs/057-agentic-chat/
├── plan.md              # This file
├── research.md          # Phase 0 output (R1-R10)
├── data-model.md        # Phase 1 output (新 AgentAction enum + 関連 transient struct)
├── quickstart.md        # Phase 1 output (12 検証シナリオ = SC-001〜SC-012)
├── contracts/           # Phase 1 output (5 files)
│   ├── agent-action.md
│   ├── agentic-chat-service.md
│   ├── language-model-session-protocol.md
│   ├── clarification-chips-view.md
│   └── answer-actions-menu.md
├── checklists/
│   └── requirements.md  # ✅ all pass
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
KnowledgeTree/
├── Models/
│   └── AgentAction.swift                    # 新規 @Generable enum + 関連型 (~120 行)
├── Services/
│   ├── ChatService.swift                    # 改修: 内部 agentic refactor (~300 行 → ~400 行)
│   ├── AgenticChatService.swift             # 新規 (or ChatService 内部に統合、判断は後述)
│   ├── LanguageModelSessionProtocol.swift   # 改修: generateAgentAction 追加 (~30 行)
│   ├── SavedAnswerService.swift             # 改修: captureIfWorthy = no-op + saveExplicit 新規 (~30 行)
│   └── HedgePhraseFilter.swift              # 新規 純粋関数 (post-process filter、~50 行)
├── Views/
│   ├── ChatTabView.swift                    # 改修: clarification chips 統合 + long press menu 配線 (~50 行追加)
│   ├── ChatMessageRow.swift                 # 改修: long press menu 追加 + 引用 chip 条件表示 (~40 行追加)
│   ├── ClarificationChipsView.swift         # 新規 (~80 行)
│   └── AnswerActionsMenu.swift              # 新規 (~60 行)
└── Localization/Localizable.xcstrings       # ~20 文言追加

KnowledgeTreeTests/
├── AgentActionTests.swift                   # 新規 (~150 行、Generable round-trip + 分岐)
└── AgenticChatServiceTests.swift            # 新規 (~250 行、10+ ケース)
```

**Structure Decision**: 既存ディレクトリ構造踏襲。ChatService は内部実装を全面 refactor、新 `AgenticChatService` protocol を導入するか、ChatService 内部に統合するかは R3 で判断。

## Implementation Phases

### Phase A (P1 必須、~1200 行、5-7 日)

Agent loop core + 「分かりません」廃止 + UI 透過化。

- T001: AgentAction `@Generable` enum 新規 (Models/AgentAction.swift)
- T002: LanguageModelSessionProtocol に `generateAgentAction` 追加
- T003: HedgePhraseFilter 純粋関数 新規 (Services/HedgePhraseFilter.swift)
- T004: ChatService 内部 refactor (agentic loop 実装、max 3 round)
- T005: 既存 ChatService.send / ask public API 互換性維持確認
- T006: AgentActionTests 新規 (Generable round-trip 6 ケース + 分岐 4 ケース)
- T007: AgenticChatServiceTests 新規 (10 ケース、agent loop 各 path)

### Phase B (P2 推奨、~500 行、3 日)

Clarification chips + long press menu + SavedAnswer 移行。

- T008: ClarificationChipsView 新規
- T009: ChatTabView に chips 統合 (clarification 表示時)
- T010: AnswerActionsMenu 新規 (保存/コピー/共有)
- T011: ChatMessageRow に long press menu 配線
- T012: SavedAnswerService.captureIfWorthy → no-op 化 + saveExplicit API 新規
- T013: 既存 auto-save SavedAnswer の data 維持確認 (regression test)

### Phase C (P3 polish + final、~300 行、2 日)

Error handling + UI feedback + xcstrings + 全 test 回帰。

- T014: agent loop UI feedback (考えています / 検索中 / まとめ中 spinner + hint)
- T015: Error UI + retry button
- T016: Localizable.xcstrings に ~20 文言追加
- T017: long press hint tooltip 初回表示 (UserDefaults flag)
- T018: Build 警告ゼロ確認
- T019: 全 unit test regression PASS 確認
- T020: CLAUDE.md 更新 (spec 057 → 🔧 実装中)
- T021: 実機検証 (ユーザー、quickstart.md SC-001〜SC-012)

## Phase 0 Research (research.md)

R1-R10 で技術判断 + Apple Foundation Models の制約調査:

- R1: AgentAction @Generable enum design (case enumeration / payload size)
- R2: ChatService 内部 refactor vs 新 AgenticChatService protocol
- R3: max 3 round clarification の terminate 条件 + state machine
- R4: HedgePhraseFilter のキーワード set + 置換ロジック
- R5: ClarificationChipsView の UI レイアウト + auto-fill 連動
- R6: AnswerActionsMenu の long press 実装 (.contextMenu vs .swipeActions vs custom)
- R7: SavedAnswer auto-save 廃止の hook 削除戦略 + regression risk
- R8: token efficiency for Generable enum (4096 上限対策)
- R9: agent loop debug logging (Console.app visibility)
- R10: テスト戦略 (Mock LanguageModelSession の AgentAction 返却 sequence 制御)

## Phase 1 Design (data-model.md / contracts/)

### Data Model

新規 SwiftData @Model: **なし** (UI / Service layer のみ)

新規 transient enum / struct:
- `AgentAction` (@Generable enum、4 case + payload)
- `AgentState` (transient struct、loop iteration counter + accumulated context)
- `SuggestedChip` (transient struct、text + auto-fill target)
- `HedgePhrase` (constants、置換用文言集)
- `AgentLoopResult` (transient struct、final ChatMessage + cited article IDs + debug info)

UserDefaults キー (1 つ):
- `spec057_longPressHintShown` (Bool、初回 long press hint 表示済 flag)

### Contracts (5)

- agent-action.md: `@Generable enum AgentAction` + payload struct
- agentic-chat-service.md: ChatService 内部 agent loop interface (内部統合 or 新 protocol、R2 で判断)
- language-model-session-protocol.md: `generateAgentAction(prompt:context:)` 追加
- clarification-chips-view.md: chips UI + auto-fill 連動
- answer-actions-menu.md: long press menu + 3 アクション

### Quickstart

`quickstart.md` に 12 シナリオ (spec.md SC-001〜SC-012 を実機検証手順化)。

## Constitution Re-Check (Post-Design)

Phase 1 完了後の Constitution 再確認:

- I (privacy): ✅ Apple Foundation Models 完全 on-device 維持、external API ゼロ
- II (MVP): ✅ RAG「分かりません」問題の根本解決、機能置換、Phase A/B/C 段階 release 可能
- III (source 追跡): ✅ AgentAction.finalAnswer.citedArticleIDs で source 追跡保証、引用 chip 維持
- IV (iOS 実現可能性): ✅ @Generable enum で agent state、tool calling 不在の代替パターン確立 (spec 044 同様)
- V (calm UX): ✅ 透過的 mode、clarification は max 3 round に限定、過剰干渉なし
- VI (architecture): ✅ public API 維持で UI 改修ゼロ、内部 refactor のみ
- VII (日本語ファースト): ✅ 全 UI 文言日本語、xcstrings 経由

全 PASS、Complexity 違反なし。

---

## Status

- [X] Phase 0: research.md 生成
- [X] Phase 1: data-model.md + contracts/ + quickstart.md 生成
- [X] Constitution Check 全 PASS
- [ ] Phase 2: tasks.md 生成 (`/speckit-tasks` で実施)
- [ ] Implementation (auto mode で実施)

# Tasks: Agentic Chat

**Input**: Design documents from `/specs/057-agentic-chat/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ (5 files), quickstart.md
**Tests**: AgentActionTests + AgenticChatServiceTests 新規必須、既存 regression 全 PASS 必須
**Organization**: 3 Phase (A=必須/B=推奨/C=polish)、21 タスク

## Format

`- [ ] [TaskID] [P?] [Story?] Description with file path`

---

## Phase 1: Setup

- [ ] T001 Localizable.xcstrings に ~20 文言追加 (`KnowledgeTree/Localization/Localizable.xcstrings`) — answer.actions.* / agent loop hint / hedge phrase 関連

---

## Phase 2: Foundational

- [ ] T002 [P] AgentAction `@Generable` enum 新規 (`KnowledgeTree/Models/AgentAction.swift`、~120 行) — 4 case (immediate / askClarification / searchArticles / finalAnswer) + Guide / Sendable / Codable / Equatable
- [ ] T003 [P] HedgePhraseFilter 純粋関数 新規 (`KnowledgeTree/Services/HedgePhraseFilter.swift`、~50 行) — bannedPhrases + hedgeReplacements + replace(_:)
- [ ] T004 LanguageModelSessionProtocol に `generateAgentAction(prompt:context:)` 追加 (`KnowledgeTree/Services/LanguageModelSessionProtocol.swift`、~30 行) — Foundation 実装 + Mock 実装

---

## Phase 3: User Story 1+2+3+4+5 — Agent loop core (Priority: P1) 🎯 MVP

- [ ] T005 [US1-5] ChatService 内部 refactor (`KnowledgeTree/Services/ChatService.swift`、~150 行追加 / 100 行修正) — agentLoop private func + buildAgentPrompt + formatClarification + AgentState + max 3 iteration、public API 無変更
- [ ] T006 [US5] ChatMessage に `clarificationSuggestions: [String]?` 追加 (`KnowledgeTree/Models/ChatMessage.swift`、~5 行) — schema 無変更、optional field 追加
- [ ] T007 [US1-5] AgentActionTests 新規 (`KnowledgeTreeTests/AgentActionTests.swift`、~150 行、10 ケース) — Codable round-trip 各 case + enum 分岐 + edge cases
- [ ] T008 [US1-5] AgenticChatServiceTests 新規 (`KnowledgeTreeTests/AgenticChatServiceTests.swift`、~250 行、10+ ケース) — Mock LM の AgentAction sequence 制御で各 path 検証
- [ ] T009 [US1-5] Build 警告ゼロ確認 (`xcodebuild build -scheme KnowledgeTree`) + 既存 ChatServiceTests regression PASS

---

## Phase 4: User Story 2+3 — Clarification chips (Priority: P1)

- [ ] T010 [P] [US2] ClarificationChipsView 新規 (`KnowledgeTree/Views/ClarificationChipsView.swift`、~80 行) — 3 chip 縦並び、Capsule outline、tap callback
- [ ] T011 [US2-3] ChatMessageRow / ChatTabView に chips 統合 (`KnowledgeTree/Views/ChatMessageRow.swift` + `KnowledgeTree/Views/ChatTabView.swift`、~30 行追加) — assistant message に `clarificationSuggestions` あれば chips 表示、tap で auto-fill + 自動送信

---

## Phase 5: User Story 6 — Long press menu (Priority: P2)

- [ ] T012 [P] [US6] AnswerActionsMenu 新規 (`KnowledgeTree/Views/AnswerActionsMenu.swift`、~80 行) — .contextMenu の 3 button (保存/コピー/共有) + ShareLink
- [ ] T013 [US6] ChatMessageRow に .contextMenu 配線 (`KnowledgeTree/Views/ChatMessageRow.swift`、~15 行追加) — assistant message のみ menu 表示
- [ ] T014 [US6] SavedAnswerService 改修 (`KnowledgeTree/Services/SavedAnswerService.swift`、~40 行) — captureIfWorthy / captureIfWorthyOrReplaceStale を no-op 化 + saveExplicit 新規追加 (関連 ConceptPage 解決ロジックは spec 043 流用)
- [ ] T015 [US6] SavedAnswerServiceTests 拡張 (`KnowledgeTreeTests/SavedAnswerServiceTests.swift`、~80 行追加) — auto-save 廃止検証 + saveExplicit 動作 3 ケース

---

## Phase 6: User Story 7 — Agent loop UI feedback (Priority: P2)

- [ ] T016 [US7] ChatTabView に agent loop hint 追加 (`KnowledgeTree/Views/ChatTabView.swift`、~25 行追加) — 「考えています…」spinner + 「(記事を検索中…)」「(まとめ中…)」hint、agent state 連動

---

## Phase 7: User Story 8 — Error retry (Priority: P3)

- [ ] T017 [US8] Error UI + retry button (`KnowledgeTree/Views/ChatTabView.swift`、~20 行追加) — Foundation Models error 時に error bubble + retry button、tap で同 question 再送信

---

## Phase 8: Polish

- [ ] T018 long press hint tooltip 初回表示 (`KnowledgeTree/Views/ChatTabView.swift`、~15 行追加) — UserDefaults `spec057_longPressHintShown` flag で 1 回限り表示
- [ ] T019 Build 警告ゼロ確認 + 全 test regression PASS — `xcodebuild test -only-testing:KnowledgeTreeTests -parallel-testing-enabled NO` で BUILD SUCCEEDED + TEST SUCCEEDED + spec 057 由来 warning ゼロ
- [ ] T020 CLAUDE.md 更新 (`CLAUDE.md`) — spec 057 を 📝 → 🔧 実装中 (本 branch `056-uiux-redesign-v3`、未 commit) に更新
- [ ] T021 PR #17 update + 実機検証 (quickstart.md SC-001〜SC-012、ユーザー実施) — `gh pr edit 17` で description 更新 (spec 056 + spec 057 統合 V3.0 release)

---

## Dependencies

- T001 (xcstrings) — 独立、最初に
- T002, T003 — 独立、並列可
- T004 → T005 (agentic refactor は protocol 拡張後)
- T005 → T007 + T008 + T009 (テストは ChatService refactor 後)
- T005 → T011 (UI 統合は ChatService から ChatMessage 経由)
- T006 → T011 (clarificationSuggestions field 追加後)
- T010 → T011 (chips view を ChatMessageRow に統合)
- T012 → T013 (AnswerActionsMenu を ChatMessageRow に配線)
- T014 → T015 (SavedAnswerService 改修後にテスト)
- T012-T015 → T013 (menu + service の両方完了で配線)
- 全完了 → T019 → T020 → T021

## Parallel Execution

- T002, T003 並列可 (異なるファイル)
- T010, T012 並列可 (異なる view ファイル)
- T007, T008 並列可 (異なる test ファイル)
- T015 並列可 (異なる test ファイル)

## MVP 範囲

T001-T009 (Phase 1-3) = P1 only、agent loop core + 「分かりません」廃止 + 既存 UI で動作。
Phase 4-7 が P2/P3、polish。

## 実装規模

- 新規 6 ファイル (AgentAction / HedgePhraseFilter / ClarificationChipsView / AnswerActionsMenu / 2 test) + 改修 6 ファイル (ChatService / ChatMessage / LangProtocol / ChatMessageRow / ChatTabView / SavedAnswerService) + xcstrings
- ~1500-2000 行 (実装 + テスト)
- 期間: 1-2 週間

## 検証

実機検証 (T021) はユーザー。Simulator build + Simulator unit test PASS まで Claude が実装。

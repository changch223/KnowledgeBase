# Tasks: SavedAnswer.isStale 表示 + 「再生成」アクション

**Feature**: spec 045
**Branch**: 044-understanding-chat 内に内包
**Tests**: Unit tests YES (Service の 2 new method)

---

## Phase 1: Setup + Foundational

- [X] T001 Add ~6 Japanese strings to `KnowledgeTree/Localization/Localizable.xcstrings`: 「更新が必要」/「再生成」/「更新済としてマーク」/「この答えは保存後に関連記事が追加されています。再生成で最新の AI 答えを得られます。」/「⚠️ 更新が必要 (%lld)」/「絞り込み解除」
- [X] T002 Add `markFresh(_:) throws` and `captureIfWorthyOrReplaceStale(question:answer:citedArticleIDs:sessionID:) async` methods to `KnowledgeTree/Services/SavedAnswerService.swift` (Protocol + Default 実装、~40 行)
- [X] T003 Add `pendingRegenerateRequest: PendingRegenerateRequest?` property + `PendingRegenerateRequest` struct to `KnowledgeTree/Services/ServiceContainer.swift` (~10 行)

---

## Phase 2: UI 表示 (P1)

- [X] T004 [US1] Add isStale chip + `clock.badge.exclamationmark` icon to `KnowledgeTree/Views/SavedAnswerRow.swift` (~15 行、orange、pin chip と並列)
- [X] T005 [US1+US2] Add `staleNoticeBanner` + `regenerateButton` (toolbar) + `markFreshMenuItem` (toolbar ellipsis menu) to `KnowledgeTree/Views/SavedAnswerDetailView.swift` (~50 行)

---

## Phase 3: 再生成フロー (P1)

- [X] T006 [US2] Modify `KnowledgeTree/KnowledgeTreeApp.swift` to observe `serviceContainer.pendingRegenerateRequest` and switch `selectedTab = .chat` when set (~10 行)
- [X] T007 [US2] Modify `KnowledgeTree/Views/ChatTabView.swift` `.task` to consume `pendingRegenerateRequest`: create new ChatSession + auto-send question, then clear request (~15 行)

---

## Phase 4: フィルター chip (P2)

- [X] T008 [US3] Add isStale filter chip (件数 0 で非表示) + `@State showStaleOnly` filter logic to `KnowledgeTree/Views/SavedAnswerHistoryView.swift` (~30 行)

---

## Phase 5: Tests + Polish

- [X] T009 Add 3-4 test cases to `KnowledgeTreeTests/SavedAnswerServiceTests.swift`: markFresh の動作 / captureIfWorthyOrReplaceStale が既存 stale を保持しつつ新規 SavedAnswer を追加 / 既存 isStale=false なら通常 captureIfWorthy 動作 / question 完全一致 + isStale=false (古い fresh あり) なら新規 skip
- [X] T010 `xcodebuild clean build` SUCCEEDED + `SavedAnswerServiceTests` 全 PASS + 既存 ChatServiceTests / ConceptPageStoreTests / DeepDiveChatServiceTests regression なし
- [X] T011 CLAUDE.md に spec 045 を「🔧 実装完了」追記
- [ ] T012 実機検証 (ユーザー、SC-001〜SC-010、spec 044 + spec 030 と一緒に)

---

## Dependencies

- T001 / T002 / T003 並列可
- T004 (Row) → T005 (Detail に依存しない、別 view) → T008 並列可
- T005 完了で再生成 Button が押せるが、T006+T007 がないと AI チャットタブ起動しても何も起きない
- T007 は T003 (PendingRegenerateRequest 型) 必要
- T009 → T002 後、T010 → 全実装後

## Summary

12 tasks、~350 行、~2-3 時間。新規ファイル ゼロ、新規 @Model / Schema / Protocol ゼロ。

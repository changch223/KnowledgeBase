# Tasks: LazyVStack 系 view の削除手段 (contextMenu 採用)

**Feature Branch**: `030-category-row-deletion` (本作業は `044-understanding-chat` ブランチ内に内包実装)
**Input**: Design documents from `/specs/030-category-row-deletion/`
**Prerequisites**: spec.md, plan.md

**Tests requested**: NO (純 UI 拡張、既存 SwiftDataArticleStoreTests でカバー済の `modelContext.delete` を inline 利用するだけ)

**Organization**: Phase 1 (P1 LazyVStack 系、必須) → Phase 2 (P2 List 系 UX 統合、optional) → Phase 3 (Polish)

---

## Phase 1: LazyVStack 系 (P1) — 必須

- [X] T001 [US1] Add `.contextMenu` (削除 destructive Button) + `delete(_ article:)` helper to `KnowledgeTree/Views/CategoryFilteredListView.swift` ArticleRow Button (line 130 周辺)
- [X] T002 [US2] Add `.contextMenu` + `delete` helper to `KnowledgeTree/Views/CategoryKnowledgeDetailView.swift` ArticleRow Button (line 178 周辺)

(両 task は spec 044 実装以前に既に完了済。本 spec 030 作成時に確認した時点で実装済 verified)

---

## Phase 2: List 系 UX 統合 (P2、optional) — 本セッションで実施

**Goal**: 既存 `.swipeActions` の上に `.contextMenu` を併記、全 5 view で「swipe + 長押し」の 2 経路で削除可能にする。

- [X] T003 [US3] Add `.contextMenu` (after `.swipeActions`) to `KnowledgeTree/Views/ArticleListView.swift` ArticleRow Button (line 162 周辺、`.swipeActions` 直後に併記)
- [X] T004 [US3] Add `.contextMenu` to `KnowledgeTree/Views/TagFilteredListView.swift` ArticleRow Button (line 54 周辺)
- [X] T005 [US3] Add `.contextMenu` to `KnowledgeTree/Views/EntityFilteredListView.swift` ArticleRow Button (line 63 周辺)

---

## Phase 3: Polish

- [X] T006 `xcodebuild build -scheme KnowledgeTree` SUCCEEDED, 既存 SwiftDataArticleStoreTests 全 PASS
- [X] T007 CLAUDE.md に spec 030 を「✅ 実装完了」追記 (commit hash + PR は user merge 後に追記)
- [ ] T008 実機検証 (ユーザー、SC-001〜SC-007、quickstart.md なし、spec.md 成功基準で直接判定)

---

## Dependencies

- Phase 1: 既完了
- Phase 2: 各 view 独立、3 task 並列可
- Phase 3: Phase 2 完了後

## Summary

総タスク数: 8 (T001-T008)、Phase 1 = 2 件既完了、Phase 2 = 3 件 (~15 行)、Phase 3 = 3 件 (verification + docs)。新規ファイル ゼロ、新規 schema ゼロ、新規 service ゼロ。

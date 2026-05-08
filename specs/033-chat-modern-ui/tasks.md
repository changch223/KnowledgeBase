# Tasks — spec 033 AI Chat モダン UI 刷新

**Spec**: [spec.md](./spec.md) / **Plan**: [plan.md](./plan.md)

## Phase 1: 研究 — 結論

- [x] R1 Foundation Models streaming API → **案 B (擬似 streaming) を MVP で採用**。真 streaming は将来 spec
- [x] R2 NavigationSplitView の iPhone 挙動 → SwiftUI 標準動作 (`.balanced`) で OK
- [x] R3 SwiftUI Text + AttributedString tap handler → `environment(\.openURL)` + `onOpenURL` 経路
- [x] R4 prompt での inline link → `[タイトル](article-id://UUID)` 形式 + post-process regex
- [x] R5 token 数管理 → 簡易文字数換算 (3000 字上限、超過は古い順 truncate)

## Phase 2: Foundation

- [ ] T001 [P] xcstrings に chat.* 新文言追加 (~10 文言) — `Localizable.xcstrings`
- [ ] T002 [P] ChatService.send に contextMessages 引数追加 (default 直前 4 message) — `Services/ChatService.swift`
- [ ] T003 [P] ChatService.deleteSession(_:) 追加 — `Services/ChatService.swift`
- [ ] T004 multi-turn 対応 prompt 改修 (`buildPromptWithContext`)
- [ ] T005 inline link 形式の prompt 指示追加
- [ ] T006 ChatService 既存 ChatServiceTests 11/11 PASS 維持

## Phase 3: Sidebar UI

- [ ] T007 [US1] ChatSessionRow 新規 — `Views/ChatSessionRow.swift`
- [ ] T008 [US1] ChatHistorySidebar 新規 — `Views/ChatHistorySidebar.swift`
- [ ] T009 [US4] session row 左 swipe 削除
- [ ] T010 [US5] 「+ 新しいチャット」button

## Phase 4: NavigationSplitView 統合

- [ ] T011 [US1] ChatTabView を NavigationSplitView 構造に改修
- [ ] T012 [US1] toolbar ハンバーガーアイコン
- [ ] T013 [US1] pinnedSessionID と sidebar 連動

## Phase 5: 擬似 streaming + Inline link

- [ ] T014 [US3] ChatMessageRow に streaming 表示 state (`isStreaming` + `displayedText`)
- [ ] T015 [US3] sendQuestion に「擬似 streaming」を追加 — assistant 回答を 1 文字ずつ追加表示
- [ ] T016 [US6] ChatMessageRow で本文を AttributedString に変換、`article-id://` link を埋め込み
- [ ] T017 [US6] `.environment(\.openURL)` で article-id URL を捕捉、Article fetch + NavigationLink

## Phase 6: テスト + Polish

- [ ] T018 ChatServiceTests に追加 (multi-turn context / deleteSession / inline link prompt → 3 ケース追加)
- [ ] T019 build 警告ゼロ + 既存テスト全回帰 PASS
- [ ] T020 CLAUDE.md / ROADMAP 更新
- [ ] T021 実機検証 (ユーザー、SC-001〜SC-012)

## 状態
🔧 Phase 2 から implement 中。

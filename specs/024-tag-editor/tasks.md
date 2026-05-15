# Tasks — spec 024 Tag 編集 / 統合 / 削除 UI

**Spec**: [spec.md](./spec.md) / **Plan**: [plan.md](./plan.md)

## Phase 1: TagStore 拡張
- [x] T001 TagStore に rename / merge / delete 拡張 + TagStoreError enum
- [x] T002 TagStoreEditTests 8 ケース PASS

## Phase 2: UI
- [x] T003 TagEditSheet 新規 (rename / merge / delete + 確認 alert)
- [x] T004 TagManagementView 新規 (List + sort + 検索 + sheet)

## Phase 3: 統合
- [x] T005 SettingsView に「タグ管理」row 追加 + TagManagementDestination
- [x] T006 xcstrings 文言 19 種追加

## Phase 4: Polish
- [x] T007 build 警告ゼロ + 全関連 58 テスト PASS
- [ ] T008 CLAUDE.md / ROADMAP 更新 (commit 内に含める)
- [ ] T009 実機検証 (ユーザー)

## 状態
✅ implement 完了、実機検証待ち。

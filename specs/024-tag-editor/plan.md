# Plan: Tag 編集 / 統合 / 削除 UI

**Spec**: [spec.md](./spec.md)

## Architecture

```
[SettingsView]
  └── 新「タグ管理」row → NavigationLink

[TagManagementView] (新)
  └── List(allTags, sort: article count desc)
       └── row tap → sheet(TagEditSheet)

[TagEditSheet] (新)
  ├── Section "タグ名": TextField + 保存 button
  ├── Section "統合": Picker (除外 self) + 統合 button
  └── Section "削除": destructive button + 確認 alert

[TagStore] (拡張)
  ├── rename(_ tag: Tag, to: String) throws -> Tag
  │   └── 同名既存あれば merge 経路
  ├── merge(source: Tag, into target: Tag) throws
  │   └── source.articles を target に移動 + source delete
  └── delete(_ tag: Tag) throws
       └── articles relationship 解除 + Tag delete
```

## Implementation Outline

### Phase 1: TagStore 拡張
- T001 [P] TagStore.rename / merge / delete 実装
- T002 [P] TagStoreEditTests 7 ケース
- T003 RefreshTrigger 通知

### Phase 2: UI
- T004 TagEditSheet 新規 — Form ベース
- T005 TagManagementView 新規 — List + sort

### Phase 3: 統合
- T006 SettingsView に「タグ管理」row 追加
- T007 xcstrings 文言追加

### Phase 4: Polish
- T008 build 警告ゼロ + 既存テスト全回帰
- T009 CLAUDE.md / ROADMAP 更新
- T010 実機検証 (ユーザー)

## 主要研究項目

1. **rename と merge の境界** — rename で同名既存があれば自動 merge 提案 / 自動 merge 実行
2. **循環 merge 防止** — Picker で source 自身 + 同じ Category 強制? — UX 検討、MVP は自身のみ除外
3. **article count 0 cleanup** — 既存 cleanupOrphans() を merge/delete 後に呼ぶ
4. **RefreshTrigger** — 操作後の UI 更新タイミング、SwiftData @Query reactive で十分か

## MVP 範囲外

- 一括 multi-select 編集
- Tag 色設定
- Tag 並び順カスタム
- Tag メモ / 説明文
- AI 自動命名修正
- Category 編集 (10 ジャンル固定の改編)

## 依存

- spec 008 TagStore + TagNormalizer
- spec 005 RefreshTrigger
- spec 015 Tag.categoryRaw

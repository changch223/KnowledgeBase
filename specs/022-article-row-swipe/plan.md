# Implementation Plan: ArticleRow 左 swipe アクション (削除)

**Branch**: `022-article-row-swipe` (実装時に作成)
**Date**: 2026-05-06
**Spec**: [spec.md](./spec.md)

## Summary

ArticleRow を使う全 view で iOS 標準 `swipeActions(edge: .leading)` を追加、左 swipe → 「削除」ボタン (destructive) → ArticleStore.delete 呼び出し。SwiftData の cascade / nullify 設定で関連データ自動 cleanup、TagStore.cleanupOrphans で孤児タグ削除。新 @Model なし、新 service なし。

技術アプローチ:
- **改修 5 view**: ArticleListView / TagFilteredListView / EntityFilteredListView / CategoryFilteredListView / CategoryKnowledgeDetailView (各 ForEach 内に `.swipeActions` 追加)
- **改修 1 store**: ArticleStore (delete メソッド確認 / 追加)
- **新規 0 ファイル** (View modifier として inline で十分)
- **新規テスト 1 ファイル**: ArticleStoreDeleteTests (3 ケース)

## Technical Context

**Language/Version**: Swift 6
**Primary Dependencies**: SwiftUI 6, SwiftData
**Storage**: 既存 SwiftData (Article cascade / nullify 設定済)
**Testing**: Swift Testing + in-memory ModelContainer
**Target Platform**: iOS 26+ / iPadOS 26+
**Performance Goals**: swipe 動作 ≤100ms、削除 ≤300ms
**Constraints**:
- 既存 view ロジック保持
- 既存 SwiftData schema 無改変
- ArticleRow struct 自体は改修なし (親 view で `.swipeActions`)
**Scale/Scope**: ~6 ファイル改修、~80 行、~5 タスク (小スコープ)

## Constitution Check

- [x] **I. プライバシーファースト**: ローカル削除のみ、外部送信ゼロ
- [x] **II. MVP**: 削除のみ、お気に入り / アーカイブ / undo / 一括削除 / ゴミ箱 は将来 spec
- [x] **III. ソース追跡**: 削除は意図的、KnowledgeDigest.sourceArticles から `.nullify` で残骸保持 (Constitution III 整合)
- [x] **IV. iOS 実現可能性**: SwiftUI `swipeActions` 標準 API
- [x] **V. calm UX**: 削除確認 alert なし、削除後 toast なし、iOS 標準 swipe で完了
- [x] **VI. アーキテクチャ**: ArticleStore.delete 経由で Service 層分離、UI は薄い
- [x] **VII. 日本語ファースト**: 「削除」ボタン文言日本語

**Quality Gates**: 全 PASS

## Project Structure

```text
KnowledgeTree/
├── Services/
│   └── ArticleStore.swift              # 【改修?】delete メソッド確認 / 必要なら追加
└── Views/
    ├── ArticleListView.swift           # 【改修】.swipeActions
    ├── TagFilteredListView.swift       # 【改修】.swipeActions
    ├── EntityFilteredListView.swift    # 【改修】.swipeActions
    ├── CategoryFilteredListView.swift  # 【改修】.swipeActions
    └── CategoryKnowledgeDetailView.swift  # 【改修】.swipeActions

KnowledgeTreeTests/
└── ArticleStoreDeleteTests.swift       # 【新規】3 ケース
```

## 主要研究項目 (実装時に詳細化)

1. ArticleStore.delete メソッドの存在確認 (なければ追加)
2. TagStore.cleanupOrphans が削除後に走る hook 位置 (既存 KnowledgeTreeApp bootstrap or ArticleStore.delete 内)
3. KnowledgeDigest.sourceArticles の `.nullify` 動作確認 (spec 018 でテスト済)
4. SwiftUI `swipeActions` の Reduce Motion 自動対応
5. ForEach 内各行に modifier 適用するか、ArticleRow に View modifier extension 追加するか

## Implementation Outline

### Phase 1: Setup (該当なし)

### Phase 2: Foundational
- T001: ArticleStore.delete メソッド確認 (なければ追加)、TagStore.cleanupOrphans 呼び出し追加
- T002: ArticleStoreDeleteTests 新規 (3 ケース): 単体削除 / Tag 孤児化 / KnowledgeDigest sourceArticles から null 化

### Phase 3: US1 — ArticleListView swipe
- T003: ArticleListView の ForEach 内に `.swipeActions(edge: .leading)` 追加 + 削除 Button (destructive、trash icon)

### Phase 4: 全 view 適用
- T004: TagFilteredListView / EntityFilteredListView / CategoryFilteredListView / CategoryKnowledgeDetailView に同 modifier を追加

### Phase 5: Polish
- T005: build 警告ゼロ + 既存テスト回帰 + 実機検証

## MVP 範囲外 (将来 spec)

- 「お気に入り」action
- 「アーカイブ」action
- 削除 undo (iOS Mail 風)
- 一括削除 (multi-select)
- ゴミ箱 (30 日保持)
- 削除確認 alert (要望あれば追加可、現在は constitution V で却下)
- 右 swipe アクション (将来)

## 規模

小 (~80 行、~5 タスク)、改修 5 view + 1 service + 新規テスト 1。実装容易。

## 状態

📝 specify+plan 完了。`/speckit-tasks` + `/speckit-implement` は spec 019/020/021 完了後 or 別タイミング (運用で削除欲しくなった時) に実施予定。

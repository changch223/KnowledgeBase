# Implementation Plan: LazyVStack 系 view の削除手段 (contextMenu 採用)

**Branch**: `030-category-row-deletion` (実装時に作成)
**Date**: 2026-05-06
**Spec**: [spec.md](./spec.md)

## Summary

ArticleRow の上位 Button に `.contextMenu { Button(role: .destructive) { delete } }` を追加。LazyVStack 構造の 2 view (CategoryFilteredListView / CategoryKnowledgeDetailView) で動作、optional で List 系 3 view にも同 menu 追加で UX 統一。

## Technical Context

**Language/Version**: Swift 6
**Primary Dependencies**: SwiftUI (contextMenu)、SwiftData (`ModelContext.delete`)
**Storage**: 既存 cascade / nullify、改修なし
**Testing**: 既存 SwiftDataArticleStoreTests でカバー済 (delete メソッド)
**Target Platform**: iOS 26+ / iPadOS 26+
**Performance Goals**: 削除アクション → リスト更新 < 100ms (RefreshTrigger 経由 @Query auto invalidate)
**Constraints**:
- 既存 .swipeActions (List 系) を変更しない
- spec 016 / 018 の LazyVStack design を保持
- delete 確認 alert 禁止 (constitution V)
**Scale/Scope**: 極小 (~30 行、~5 タスク)

## Constitution Check

- [x] I (privacy): SwiftData ローカル削除のみ、外部送信ゼロ
- [x] II (MVP): 削除のみ、お気に入り/アーカイブ/undo は将来 spec
- [x] III (source 追跡): cascade で関連 (Enrichment / Body / Knowledge / chunkProgress) も削除、Tag は relationship 解除のみ (cleanupOrphans が孤児 Tag 処理)
- [x] IV (実現可能性): SwiftUI .contextMenu は iOS 13+ 確立 API
- [x] V (calm UX): 長押し → menu → 削除、確認 alert なし、toast なし
- [x] VI (architecture): 純 UI 拡張、新 service ゼロ、既存 inline delete pattern 踏襲
- [x] VII (日本語): xcstrings の `list.deleteAction` 既存キー再利用

**Quality Gates**: 全 PASS

## Project Structure

```text
KnowledgeTree/Views/
├── CategoryFilteredListView.swift           # 【改修】ArticleRow Button に .contextMenu 追加
├── CategoryKnowledgeDetailView.swift        # 【改修】ArticleRow Button に .contextMenu 追加
├── ArticleListView.swift                    # 【optional 改修】List swipe + contextMenu 併用
├── TagFilteredListView.swift                # 【optional 改修】同上
└── EntityFilteredListView.swift             # 【optional 改修】同上
```

新規ファイル: ゼロ。

## 実装の核

### LazyVStack 系 view (CategoryFilteredListView line 120-128)

```swift
ForEach(filteredArticles, id: \.id) { article in
    Button {
        presentedArticle = article
    } label: {
        ArticleRow(article: article, refreshTick: refreshTick)
    }
    .buttonStyle(.plain)
    .contextMenu {
        Button(role: .destructive) {
            delete(article)
        } label: {
            Label("list.deleteAction", systemImage: "trash")
        }
    }
    Divider().padding(.leading, DS.Spacing.xxl)
}
```

`delete` helper を view 末尾に追加 (既存 List 系と同パターン):

```swift
@Environment(\.modelContext) private var modelContext

private func delete(_ article: Article) {
    modelContext.delete(article)
    try? modelContext.save()
}
```

### CategoryKnowledgeDetailView (line 167-172) も同様

### List 系 view (optional FR-008)

`.swipeActions` の上に `.contextMenu` を併記:

```swift
.swipeActions(edge: .trailing, allowsFullSwipe: true) { ... }
.contextMenu {
    Button(role: .destructive) {
        delete(article)
    } label: {
        Label("list.deleteAction", systemImage: "trash")
    }
}
```

## Implementation Outline

### Phase 1: LazyVStack 系 (P1、必須)
- T001 [US1] CategoryFilteredListView に .contextMenu + delete helper 追加
- T002 [US2] CategoryKnowledgeDetailView に .contextMenu + delete helper 追加

### Phase 2: List 系 UX 統合 (P2、optional)
- T003 [US3] ArticleListView に .contextMenu 追加 (swipe と併用)
- T004 [US3] TagFilteredListView に .contextMenu 追加
- T005 [US3] EntityFilteredListView に .contextMenu 追加

### Phase 3: Polish + 検証
- T006 build SUCCEEDED + 既存 unit test 全回帰 PASS
- T007 CLAUDE.md / ROADMAP.md 更新
- T008 実機検証 (ユーザー、SC-001〜SC-007)

## MVP 範囲

最小は **Phase 1 のみ** (T001-T002、~10 行)。Phase 2 (List 系 UX 統合) はユーザー判断で。

## 検証

1. xcodebuild build SUCCEEDED
2. 既存 unit test 全回帰 PASS (削除関連: SwiftDataArticleStoreTests / 関連 store tests)
3. 実機検証:
   - SC-001: Category 詳細で長押し → contextMenu 表示
   - SC-002: 「削除」タップ → 即削除
   - SC-003: 知識 Clip 詳細で同様
   - SC-006: alert 出ない
   - SC-007: 既存 swipe 動作維持

## MVP 範囲外 (将来 spec)

- 削除 undo (iOS Mail 風 5 秒キャンセル) → spec 023+ 候補
- お気に入り / アーカイブ → spec 023+ 候補
- 一括削除 (multi-select) → 別 spec
- ゴミ箱 (30 日保持) → 別 spec、データ即時削除運用
- 削除確認 alert → constitution V 違反、却下

## 規模

極小 (~30 行 + optional ~15 行、~3-8 タスク)。spec 022 の延長、新 schema / new service ゼロ。

## 状態

📝 specify+plan 完了。/speckit-tasks + /speckit-implement は spec 021 実機検証完了後 or ユーザー判断後に実施予定。

# Feature Specification: LazyVStack 系 view の削除手段 (Category 詳細 / 知識 Clip 詳細)

**Feature Branch**: `030-category-row-deletion` (実装時に作成)
**Created**: 2026-05-06
**Status**: Draft (specify+plan only)

## なぜ (Why)

spec 022 で List 系 3 view (ArticleListView / TagFilteredListView / EntityFilteredListView) には `.swipeActions` で削除を追加済。しかし **CategoryFilteredListView / CategoryKnowledgeDetailView は ScrollView + LazyVStack 構造** で、SwiftUI の `.swipeActions` は **List/Form の row 内でのみ動作** するため使えなかった。

その結果:
- ユーザーが「Category 詳細」または「知識 Clip 詳細」から記事を削除したい時、ライブラリタブに戻る必要がある
- 運用が長くなるほど、Category ごとの整理がストレス

spec 022 の「運用上必要な削除手段」を **全 5 view で統一** する。

## ゴール

- LazyVStack 構造を保ったまま削除手段を追加 (spec 016 / 018 design 判断を覆さない)
- 既存の `.swipeActions` (List 系 3 view) と UX が大きく乖離しない
- Constitution V「ストレスゼロ」: 不安喚起 UI 禁止、削除確認 alert なし
- 既存削除フロー (`ArticleStore.delete` / TagStore.cleanupOrphans / @Relationship cascade) を再利用

## 非ゴール

- List 化リファクタ (spec 016 で意図的に LazyVStack 採用、design 影響大)
- DragGesture カスタム実装 (実装複雑、メンテコスト高、accessibility 配慮も必要)
- お気に入り / アーカイブ追加 (将来 spec)
- 削除 undo (将来 spec)
- 一括削除 (将来 spec)

## 採用案: contextMenu (長押し → メニュー)

iOS 標準パターン、`.swipeActions` のような direct manipulation よりは 1 アクション増えるが:
- 全 5 view で **同じ実装パターン** が使える (List / LazyVStack 区別なし)
- iOS 標準 long-press で発見性も悪くない (ユーザーは Photos / Mail で慣れている)
- accessibility (VoiceOver) と互換性高
- 実装コスト極小 (各 view ~5 行)

選択肢比較:

| 案 | 実装コスト | UX 一貫性 | accessibility | リスク |
|---|---|---|---|---|
| (a) List 化リファクタ | 大 (~100 行 / view) | List swipe だけに統一 | List 標準 | spec 016 design 影響 |
| **(b) contextMenu** | 小 (~5 行 / view) | List swipe + LazyVStack 長押し混在 | 標準パターン | UX が分断する懸念 |
| (c) DragGesture カスタム | 大 (~150 行 / view) | List swipe と完全一致 | 自前で a11y 対応 | メンテコスト高 |

**(b) を採用**: 全 5 view 統一は両立しないが、List 系の swipe を残しつつ LazyVStack 系に長押しを追加する **混在運用** が現実解。ユーザーは「ライブラリタブ → swipe」「Category 詳細 → 長押し」で使い分けることになる。

## ユーザストーリー

### US1 (P1) — Category 詳細から記事削除

1. AI ブレインタブ → Category 行タップ → CategoryFilteredListView 表示
2. ArticleRow を**長押し** (約 0.5 秒)
3. contextMenu 表示: 「削除」(赤、destructive、`trash` icon)
4. タップで即削除、リストから消える

### US2 (P1) — 知識 Clip 詳細から記事削除

1. 知識 Clip タブ → カードタップ → CategoryKnowledgeDetailView 表示
2. 元記事一覧の ArticleRow を長押し
3. contextMenu「削除」
4. タップで即削除

### US3 (P2) — List 系 view との UX 整合

長押しメニューを **List 系 3 view にも追加** することで、全 5 view で統一動作:
- swipe → 削除 (既存)
- 長押し → 削除メニュー (本 spec で追加)

ユーザーは好きな方法で削除できる。

## 機能要件

- **FR-001**: ArticleRow を **NavigationLink + contextMenu** でラップ可能にする (既存ボタン構造を保ったまま)
- **FR-002**: contextMenu アクション: 「削除」(`trash` icon、`role: .destructive`)
- **FR-003**: タップで `modelContext.delete(article) + try? modelContext.save()` を実行 (既存 List 系 view と同じ inline 実装)
- **FR-004**: 削除確認 alert なし (constitution V、List 系と整合)
- **FR-005**: 削除後の確認 toast なし
- **FR-006**: spec 022 の `.swipeActions` (List 系 3 view) は変更しない (補完的に契約 menu 追加可能)
- **FR-007**: 改修対象: `CategoryFilteredListView.swift:120` / `CategoryKnowledgeDetailView.swift:167` の各 ArticleRow ラッパー
- **FR-008**: optional: 既存 List 系 view (ArticleListView / TagFilteredListView / EntityFilteredListView) にも同 contextMenu を追加 (UX 整合、~3 行 / view)
- **FR-009**: 削除後、spec 005 RefreshTrigger 経由で全 view auto reload (LazyVStack も @Query 駆動なので動作)

## 成功基準

- SC-001: CategoryFilteredListView で ArticleRow 長押し → contextMenu「削除」表示
- SC-002: 「削除」タップ → 即削除、リストから消える
- SC-003: CategoryKnowledgeDetailView でも同様動作
- SC-004: 削除後、ライブラリタブに戻ると該当記事が消えている
- SC-005: List 系 3 view も swipe + 長押しメニュー 両方で削除可能 (FR-008 採用時)
- SC-006: 削除確認 alert / toast 出ない
- SC-007: 既存 swipe (List 系) は引き続き動作

## アサンプション

- iOS 標準 contextMenu はアプリ内全体で動作 (確立 API)
- 長押し時間は iOS 標準 (約 0.5 秒)、変更不要
- VoiceOver では「カスタムアクション: 削除」として読み上げ (iOS 標準動作)

## 依存・前提

- spec 022 (List 系 swipe 削除実装済)
- spec 016 (CategoryFilteredListView 新設)
- spec 018 (CategoryKnowledgeDetailView 新設)
- 既存 SwiftData cascade / nullify 削除動作

## 想定実装規模

- 改修 2 view (LazyVStack 系) + optional 3 view (List 系で UX 整合) = 最大 5 view
- ~30 行 (修正のみ、新規ファイルゼロ)
- ~3-5 タスク (Phase 1-3、極小スコープ)
- 新規テストはなし or 統合テスト 1-2 件 (削除動作検証)

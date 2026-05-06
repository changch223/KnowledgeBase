# Feature Specification: ArticleRow 左 swipe アクション (削除)

**Feature Branch**: `022-article-row-swipe`
**Created**: 2026-05-06
**Status**: ✅ 部分実装完了 (List 系 3 view、2026-05-06)。LazyVStack 系 2 view は SwiftUI 制約により別 spec 候補 (spec 030+)。

**実装範囲 (本 commit)**:
- `ArticleListView.swift:162` (spec 001 から既実装、確認のみ)
- `TagFilteredListView.swift:46-65` ✅ swipeActions + delete helper 追加
- `EntityFilteredListView.swift:54-72` ✅ swipeActions + delete helper 追加
- swipe 方向: **`.trailing`** (iOS 標準パターンに合わせて、spec.md 当初の `.leading` から修正)

**範囲外 (spec 030+ 候補)**:
- `CategoryFilteredListView` (LazyVStack)
- `CategoryKnowledgeDetailView` (LazyVStack)
- 理由: SwiftUI `.swipeActions` は List/Form row 専用、ScrollView + LazyVStack では動作しない

## なぜ (Why)

ROADMAP「A 優先度高 (運用上必要)」項目: 削除手段がないと運用上限界が来る。記事数が増えると整理が必要。現在 (spec 019 まで) は記事削除の UI が存在しない。

ユーザー要望は明示されていないが、運用していく上で必須機能。Constitution V「シンプルで落ち着いた UX」を守りつつ、最小限の整理機能を提供。

## ゴール

- ArticleRow を使う全 view (ライブラリ / Tag / Entity / Category 詳細 / 知識 Clip 詳細) で左 swipe → 削除
- iOS 標準 `swipeActions(edge: .leading)` を使用
- 削除確認 alert なし (iOS 標準 destructive swipe で十分)
- 削除後の確認 toast / バナー表示なし (constitution V)
- 関連 SwiftData (Article + Tag relationship + KnowledgeDigest sourceArticles) の cleanup

## 非ゴール

- 「お気に入り」アクション → 将来 spec
- 「アーカイブ」アクション → 将来 spec
- 削除 undo (iOS Mail 風) → 将来 spec、本 spec MVP 最小
- 一括削除 → 将来 spec
- ゴミ箱 (30 日保持) → 将来 spec、データ即時削除
- 削除確認 alert → constitution V「ストレス UI 禁止」、iOS 標準 swipe で十分

## ユーザストーリー (P1: US1 / P2: US2)

### US1 (P1) — ArticleRow 左 swipe で削除

ライブラリタブ等で ArticleRow を左 swipe → 「削除」ボタン (赤、destructive) 表示 → タップで即削除。アプリ起動中の他 view にも反映 (RefreshTrigger)。

### US2 (P2) — 関連データのクリーンアップ

Article 削除時:
- Tag relationship 解除 (既存 spec 008 cascade なし、自動 detach)
- 孤児 Tag は TagStore.cleanupOrphans が拾う
- KnowledgeDigest.sourceArticles から null 化 (spec 018 で `.nullify` 設定済)
- ExtractedKnowledge / KeyFact / Entity / ArticleEnrichment / ArticleBody は cascade 削除 (既存)

## 機能要件 (抜粋)

- **FR-001**: ArticleRow を `.swipeActions(edge: .leading)` でラップ可能にする helper modifier、または親 view 側で適用 (View Modifier extension)
- **FR-002**: swipe アクション: 「削除」(赤、destructive、`trash` icon)
- **FR-003**: タップで `ArticleStore.delete(article:)` 呼び出し
- **FR-004**: ArticleStore.delete は `context.delete(article) + try context.save()`
- **FR-005**: SwiftData の `.cascade` (Enrichment / Body / Knowledge) と `.nullify` (Digest sourceArticles) と `tags` (relationship 解除のみ) で自動 handling
- **FR-006**: 削除後、TagStore.cleanupOrphans で孤児タグ削除 (既存)
- **FR-007**: spec 005 RefreshTrigger 経由で全 view auto reload
- **FR-008**: 削除確認 alert なし (iOS 標準 swipe で完了)
- **FR-009**: 削除後の確認 toast なし (constitution V)
- **FR-010**: ArticleRow を使う全 view (ArticleListView / TagFilteredListView / EntityFilteredListView / CategoryFilteredListView / CategoryKnowledgeDetailView) で同 modifier 適用

## 成功基準

- SC-001: ArticleListView で記事を左 swipe → 「削除」ボタン表示
- SC-002: 「削除」タップ → 即削除、行が animated で消える
- SC-003: 削除後、Tag が孤児になれば TagStore で削除される
- SC-004: 削除後、KnowledgeDigest.sourceArticles から記事が外れる (Digest 自体は残る)
- SC-005: TagFilteredListView / Category 詳細画面 / 知識 Clip 詳細画面 等でも同様に動作
- SC-006: アプリ再起動後も削除が反映 (永続化済み)
- SC-007: 既存テスト全回帰 PASS

## 依存・前提

- 既存 SwiftData schema (spec 018 まで) 完全保持
- 既存 ArticleStore.delete() メソッド (確認、なければ追加)
- 既存 TagStore.cleanupOrphans() (spec 008、再利用)

## アサンプション

- iOS 標準 `swipeActions` で十分、カスタム gesture 不要
- 削除即時、undo 不要 (将来 spec)
- 削除確認 alert 不要 (swipe + ボタンタップの 2 ステップで暗黙的確認)
- ArticleRow 自体には modifier を直接付けず、親 view 側で `.swipeActions` を ForEach 内の各行に適用 (SwiftUI 慣習)

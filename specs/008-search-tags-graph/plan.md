# Implementation Plan: 保存記事の振り返り支援 (検索 + タグ + エンティティ横断)

**Branch**: `008-search-tags-graph` | **Date**: 2026-05-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/008-search-tags-graph/spec.md`

## Summary

3 つの振り返り機能を 1 spec で実装:
1. **全文検索**: 一覧画面に `.searchable` を配置し、Article + ArticleEnrichment + ExtractedKnowledge + KeyFact + KnowledgeEntity を横断する SwiftData Predicate ベースの検索
2. **タグ付け**: 新規 `Tag` (@Model) + `Article.tags` 多対多 relationship、Detail 画面でのタグ追加 UI、タグ一覧画面 + タグ絞り込み画面
3. **エンティティ横断**: Detail 画面下部に共通 entity を持つ関連記事 5 件、entity チップタップ → entity 絞り込み画面
4. **タグ自動提案**: salience 4 以上の entity を 1 タップでタグに採用

技術アプローチ: 検索は `@Query(filter: ...)` の動的 predicate 構築 (SwiftUI 5+ で `Binding<String>` 検索クエリと連動)、関連記事計算は純粋関数 `RelatedArticleFinder`、タグ正規化は `Tag.normalize(_:)` static method。新規 view 3 つ (TagListView / TagFilteredListView / EntityFilteredListView) を NavigationStack 内に配置。

## Technical Context

**Language/Version**: Swift 6.x (Xcode 16+, iOS 26+)
**Primary Dependencies**: SwiftUI (`.searchable`), SwiftData, Foundation
**Storage**: SwiftData + 新規 `Tag` @Model + `Article.tags` 多対多 relationship
**Testing**: Swift Testing + XCTest UI testing
**Target Platform**: iOS 26+ / iPadOS 26+
**Project Type**: mobile-app
**Performance Goals**:
- 1000 記事の状態で検索クエリ入力 → 結果表示 ≤ 200 ms (SC-001)
- タグ追加 → タグ一覧反映 ≤ 0.5 秒 (SC-002)
- 関連記事計算 ≤ 1 秒 (SC-004)
- 自動タグ提案表示 ≤ 0.5 秒 (SC-005)
**Constraints**:
- 検索は SwiftData Predicate で linear scan (1000 記事規模を想定)
- タグ正規化: lowercase + trim、絵文字 / 全角 OK
- Tag 削除で参照記事 0 件なら自動削除
- 関連記事は entity name の case-insensitive 共通数で sort、上位 5 件
- 自動提案は salience 4 以上 + 上位 5 件 + 既存タグ重複除外
**Scale/Scope**: 1 ユーザーあたり数百〜1000 記事 / 数十〜数百タグ / Article × Tag 多対多なので join 行は数千レベル

## Constitution Check

Reference: `.specify/memory/constitution.md` (v1.0.0)

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — 検索 / タグ / 関連記事すべて SwiftData ローカル。外部送信無し
- [x] **II. MVP ファースト開発** — relevance score / 検索インデックス / タグ色アイコン / グラフ可視化 / 複合フィルタ / 検索ページネーション すべて MVP 範囲外と spec.md Assumptions で明示。AI 自動タグ (完全自動付与) は採用せず、ユーザー承認 1 タップ (US4) のみ
- [x] **III. ソースに基づいた知識生成** — 検索結果のハイライトは元記事フィールドの実値を表示、推測無し。関連記事は AI 抽出 entity を元に計算 (元記事に明示されていた entity のみ使用)
- [x] **IV. iOS の実現可能性を重視する** — `.searchable` / `@Query(filter:)` / SwiftUI NavigationStack 標準 API のみ。サードパーティ無し
- [x] **V. シンプルで落ち着いた UX** — タグチップ / 検索バー / 関連記事リスト すべてミニマル。色やバッジ不安喚起無し。空状態メッセージは丁寧に
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — `RelatedArticleFinder` (純粋関数) / `TagNormalizer` (純粋関数) / `SearchPredicate` (predicate 構築) を Service 層から分離。新規 view 3 つは独立ファイル化
- [x] **VII. 日本語ファースト** — UI 文言 / 空状態メッセージ / Localizable.xcstrings すべて日本語。検索は case-insensitive substring なので日本語/英語混在も自然に動作

### Quality Gates (二次ゲート)

- [x] **コード品質** — `Tag` @Model の正規化は init 時に強制 (`@Attribute(.unique)` で name 一意制約)。`fatalError` 不使用。新規抽象化 (RelatedArticleFinder, SearchPredicate, TagNormalizer) は 2 箇所以上の利用 + テストで担保
- [x] **テスト** — `RelatedArticleFinder` の sort / 上限 / 自身除外テスト、`TagNormalizer` の正規化 10 ケース、`SearchPredicate` の動的構築テスト (SwiftData in-memory ModelContainer)、UI テストで `.searchable` の入力 → 結果表示動作確認
- [x] **アクセシビリティ・UX 一貫性** — 検索バーは標準 `.searchable` で VoiceOver 対応自動。タグチップは `accessibilityIdentifier` を `tagChip-<name>`、削除ボタンは `tagChipDeleteButton-<name>`。関連記事行は既存 `articleListRow` を流用
- [x] **パフォーマンス** — `@Query(filter:)` の Predicate は SwiftData 最適化 (column index 利用)。1000 記事程度なら 200 ms 達成可能。Predicate 内では `relationships` traversal を最小化 (Article 自体の title + url を主、relationship は 1 段のみ traverse)。LazyVStack で virtual scroll

**結論**: Constitution Check 全項目 ✓ パス

## Project Structure

### Documentation (this feature)

```text
specs/008-search-tags-graph/
├── plan.md
├── research.md
├── data-model.md
├── contracts/
│   ├── tag-store.md
│   ├── search-predicate.md
│   ├── related-article-finder.md
│   └── views.md
├── quickstart.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
KnowledgeTree/
├── Models/
│   ├── Article.swift                          # 既存 + tags relationship
│   └── Tag.swift                              # 新規 @Model
├── Services/
│   ├── TagStore.swift                         # 新規 (タグ CRUD + 正規化 + 孤児削除)
│   ├── TagNormalizer.swift                    # 新規 (純粋関数)
│   ├── SearchPredicate.swift                  # 新規 (動的 Predicate 構築)
│   └── RelatedArticleFinder.swift             # 新規 (純粋関数 [Article] → [RelatedArticle])
├── Views/
│   ├── ArticleListView.swift                  # 既存 + .searchable + ナビゲーションボタン
│   ├── ArticleDetailView.swift                # 既存 + タグセクション + 関連記事セクション + 自動提案
│   ├── ArticleRow.swift                       # 既存 + 検索ハイライト対応
│   ├── TagChip.swift                          # 新規
│   ├── TagInputField.swift                    # 新規 (Detail 画面のタグ追加 UI)
│   ├── TagListView.swift                      # 新規 (タグ一覧)
│   ├── TagFilteredListView.swift              # 新規 (タグ絞り込み記事一覧)
│   ├── EntityFilteredListView.swift           # 新規 (entity 絞り込み記事一覧)
│   └── RelatedArticlesSection.swift           # 新規 (Detail 画面の関連記事セクション)
└── Localization/
    └── Localizable.xcstrings                  # 新規キー (search.placeholder / search.empty / tag.* / detail.related.* / detail.suggestedTags.*)

KnowledgeTreeTests/
├── TagNormalizerTests.swift                   # 新規
├── TagStoreTests.swift                        # 新規
├── SearchPredicateTests.swift                 # 新規
└── RelatedArticleFinderTests.swift            # 新規
```

**Structure Decision**: 既存 Models/Services/Views 配置を踏襲。新規 view 5 つは独立ファイル化 (Constitution Principle VI)。検索 / タグ / 関連記事は別の純粋関数モジュールに分離して責務明確化。

## 設計判断 (Phase 0 → Phase 1 への橋渡し)

### #1 動的 Predicate vs Manual filtering

SwiftUI 5+ で `@Query(filter: ...)` は computed predicate を受けられる。検索クエリの変化に応じて Predicate を再構築 → SwiftData が自動で再 fetch。

代替: View 側で `articles.filter { ... }` する manual filtering → SwiftData の最適化 (column index 等) を活かせない、1000 記事で 200 ms 達成困難。

採用: **動的 Predicate**。`@Query` の filter は struct として独立構築 (SearchPredicate.swift)。

### #2 検索フィールドの Predicate 表現

SwiftData `Predicate<Article>` は relationship traversal 可能だが、`Article.body.extractedText` のような string contains は SwiftData 最新版 (iOS 26 SDK) で動作することを前提。`localizedStandardContains` を使う:

```swift
#Predicate<Article> { article in
    article.title.localizedStandardContains(query) ||
    (article.enrichment?.canonicalTitle?.localizedStandardContains(query) ?? false) ||
    (article.enrichment?.summary?.localizedStandardContains(query) ?? false) ||
    (article.extractedKnowledge?.essence?.localizedStandardContains(query) ?? false) ||
    (article.extractedKnowledge?.summary?.localizedStandardContains(query) ?? false) ||
    article.extractedKnowledge?.keyFacts.contains { $0.statement.localizedStandardContains(query) } ?? false ||
    article.extractedKnowledge?.entities.contains { $0.name.localizedStandardContains(query) } ?? false
}
```

注意: SwiftData Predicate は `optional?.method()` を直接書けない場合がある。実装時に動作確認、ダメなら View 側で post-filter する fallback 用意。

### #3 タグ正規化の徹底

`TagNormalizer.normalize(_ raw: String) -> String?`:
- trim whitespaces
- lowercase
- 絵文字 / CJK は touch しない
- 50 文字超は prefix 50 で truncate
- 空文字列なら nil

`Tag.init(name:)` は `TagNormalizer.normalize` 必須経由。`Tag` の `name` は `@Attribute(.unique)` で重複防止 (DB レベルで強制)。

### #4 タグ追加 UX

Detail 画面で「+ 追加」ボタンタップ → TextField + 確定ボタン inline で出現。確定で:
1. raw input を `TagNormalizer.normalize` で正規化 → nil なら no-op
2. `TagStore.addTag(name: normalized, to: article)` 呼ぶ
3. TagStore 内: 既存 Tag があれば再利用 (relationship 追加のみ)、無ければ新規 insert
4. `RefreshTrigger.bump()` で UI 更新 (spec 005 メカニズム)

### #5 タグ削除 + 孤児削除

Detail 画面のタグチップ × ボタン → `TagStore.removeTag(name: normalized, from: article)`:
1. relationship から外す
2. tag.articles.isEmpty なら `context.delete(tag)`
3. save → bump

`TagStore.cleanupOrphans()` を bootstrap か backfill で定期実行する案もあるが、削除時に同期で処理する方がシンプル。

### #6 関連記事計算

`RelatedArticleFinder.find(for article: Article, in allArticles: [Article], limit: Int = 5) -> [RelatedArticle]`:
1. `currentEntities = Set(article.extractedKnowledge?.entities.map { $0.name.lowercased().trimmingCharacters... } ?? [])`
2. `currentEntities.isEmpty` なら return []
3. for other in allArticles where other.id != article.id:
4. `otherEntities = Set(other.extractedKnowledge?.entities.map { ... } ?? [])`
5. `commonCount = currentEntities.intersection(otherEntities).count`
6. `commonCount > 0` なら candidate に追加
7. sort by commonCount desc, then by other.savedAt desc
8. take limit (5)
9. return [RelatedArticle(article: other, commonEntityCount: commonCount, commonEntities: ...)]

### #7 自動タグ提案

Detail 画面のタグセクション内、既存タグ chips の下に「自動提案」row:
- `article.extractedKnowledge?.entities` を salience 降順 sort
- salience >= 4 のもののみ
- 上位 5 件
- 既に手動タグ登録済 (正規化後 name 一致) を除外
- 各候補は「+ <name>」ボタン chip
- タップで `TagStore.addTag(name: normalized, to: article)`、即時消失

### #8 検索結果のハイライト

検索結果の各 ArticleRow で:
- マッチしたフィールドを 1 つ選んで (優先順位: title > canonicalTitle > essence > summary > keyFact > entity) excerpt 表示
- excerpt はマッチ周辺 ±30 文字
- マッチ箇所を `AttributedString` で bold
- マッチが title の場合は既存 displayTitle に bold だけ適用、excerpt 重複しない
- マッチが他フィールドの場合は ArticleRow 下部に excerpt 行を追加

`SearchHighlighter.highlight(article:query:) -> SearchHighlight?` を新規導入。

### #9 タグ絞り込み画面

`TagFilteredListView(tagName: String)`:
- 内部で `@Query(filter: #Predicate<Article> { $0.tags.contains { $0.name == tagName } })`
- 既存 ArticleRow を流用 (検索ハイライト無効、saved 日時降順)
- navigation title: 「tag: \(tagName)」
- タップで Detail sheet (既存)

### #10 entity 絞り込み画面

`EntityFilteredListView(entityName: String)`:
- 内部で `@Query(filter: #Predicate<Article> { $0.extractedKnowledge?.entities.contains { $0.name.localizedLowercase == entityName.lowercased() } ?? false })`
- 既存 ArticleRow 流用
- navigation title: 「entity: \(entityName)」

## Complexity Tracking

> Constitution Check 全項目 ✓ のため記載不要

## 次フェーズ

1. **Phase 0** (research.md): SwiftData Predicate の `optional?.method()` 動作 / 動的 Predicate のパフォーマンス特性 / `.searchable` の placement / 関連記事計算の早期最適化要否
2. **Phase 1** (data-model + contracts + quickstart): Tag @Model + Article.tags 多対多、TagStore / SearchPredicate / RelatedArticleFinder / TagNormalizer の interface contract、各新規 view の役割と navigation flow、検証手順
3. **Phase 2** (`/speckit-tasks`): 実装タスク分解

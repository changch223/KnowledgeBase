---

description: "Task list for spec 008 - 振り返り支援 (検索 + タグ + エンティティ横断)"
---

# Tasks: 振り返り支援 (検索 + タグ + エンティティ横断 + 自動提案)

**Input**: Design documents from `/specs/008-search-tags-graph/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: 含む。SwiftData in-memory ModelContainer + Mock RefreshTrigger を使用。

## Path Conventions

- iOS app: `KnowledgeTree/{Models,Services,Views,Localization}/` + `KnowledgeTreeTests/`

---

## Phase 1: Setup

- [ ] T001 git ブランチ確認 (`008-search-tags-graph`)、spec 006 / 007 の Foundational 列追加 (ExtractedKnowledge / ArticleEnrichment) と独立であることを確認
- [ ] T002 [P] 既存テスト pass を確認

---

## Phase 2: Foundational (Blocking Prerequisites)

**目的**: Tag @Model + Article.tags 多対多 + TagNormalizer 純粋関数

**⚠️ CRITICAL**: 全 US がここに依存

- [ ] T003 `KnowledgeTree/Models/Tag.swift` を新規作成。`@Model final class Tag` with `@Attribute(.unique) var name: String` + `@Relationship(inverse: \Article.tags) var articles: [Article] = []`
- [ ] T004 `KnowledgeTree/Models/Article.swift` に `@Relationship var tags: [Tag] = []` を追加 (T003 の inverse として)
- [ ] T005 `KnowledgeTree/SharedSchema.swift` の Schema.all に `Tag.self` を追加 (main app + Share Extension の両方で見える、spec 005 既存パターン)
- [ ] T006 [P] `KnowledgeTree/Services/TagNormalizer.swift` を新規作成。contracts/tag-store.md の `normalize(_:)` API 実装 (trim + lowercased + 50 char prefix + 空文字 nil)
- [ ] T007 [P] `KnowledgeTreeTests/TagNormalizerTests.swift` を新規作成。8 ケース (空 / 空白 / trim+lowercase / 50 文字超 / 絵文字 / CJK / 全角空白 / case 違い同一)
- [ ] T008 schema migration テスト: 既存 Article レコードが migration 後に tags=[] となることを `SwiftDataArticleStoreTests.swift` の新ケースで確認

**Checkpoint**: Foundation ready - US1 / US2 / US3 / US4 着手可能

---

## Phase 3: User Story 1 - 過去に保存した記事を検索で見つける (P1) 🎯 MVP

**Goal**: ArticleListView の検索バー、SwiftData Predicate ベースの検索、結果ハイライト。

**Independent Test**: 10 件の記事を fixture で作成、各フィールドにユニークな文字列を仕込み、検索クエリで該当記事のみが返ることを `SearchPredicateTests` で確認。

### Tests for User Story 1 ⚠️

- [ ] T009 [P] [US1] `KnowledgeTreeTests/SearchPredicateTests.swift` を新規作成。10 ケース (空 / 空白 / title マッチ / canonicalTitle / essence / keyFact / entity / tag / case-insensitive / 該当無し) を SwiftData in-memory ModelContainer で検証
- [ ] T010 [P] [US1] `KnowledgeTreeTests/SearchHighlighterTests.swift` を新規作成。8 ケース (title 優先 / fallthrough / nil / radius / 複数マッチ全 bold / case-insensitive / 空クエリ / fieldName 別)
- [ ] T011 [P] [US1] `KnowledgeTreeTests/Fixtures/SearchFixtures.swift` を新規作成。data-model.md セクション 7 の fixture (10 articles with varied fields, articleWithFiveEntities, articleWithSharedEntities)

### Implementation for User Story 1

- [ ] T012 [P] [US1] `KnowledgeTree/Services/SearchPredicate.swift` を新規作成。contracts/search-predicate.md の `make(query:) -> Predicate<Article>?` 実装。8 フィールド OR の動的 Predicate
- [ ] T013 [P] [US1] `KnowledgeTree/Services/SearchHighlighter.swift` を新規作成。`highlight(article:query:)` + `highlightText(_:query:radius:)` 実装。AttributedString + bold 適用
- [ ] T014 [US1] `KnowledgeTree/Views/ArticleListView.swift` を refactor: `@State searchQuery` 追加、root NavigationStack に `.searchable` 配置、inner `ArticleListContent` を切り出して `@Query(filter: SearchPredicate.make(query:))` で動的 fetch (research.md R4 の inner View pattern)
- [ ] T015 [US1] `KnowledgeTree/Views/ArticleRow.swift` に `searchQuery: String = ""` 引数追加。non-empty なら `SearchHighlighter.highlight(article:query:)` で excerpt 表示行を追加 (T013 完了後)
- [ ] T016 [P] [US1] `KnowledgeTree/Localization/Localizable.xcstrings` に `search.placeholder` (例: "記事を検索"), `search.empty.title` (例: "該当する記事がありません"), `search.field.title` / `search.field.canonicalTitle` / `search.field.essence` / `search.field.summary` / `search.field.keyFact` / `search.field.entity` / `search.field.tag` を追加
- [ ] T017 [US1] SwiftData Predicate の relationship traversal が動作するか実機で確認。動かない場合は SearchPredicate.make を Article 直接フィールドのみに limit して View 側で post-filter する fallback 実装に切替 (research.md R1)

**Checkpoint**: US1 単独動作。1000 件以下の記事で検索 200 ms 以内。

---

## Phase 4: User Story 2 - 記事に手動でタグを付ける (P2)

**Goal**: Tag CRUD + Detail 画面のタグセクション + タグ一覧画面 + タグ絞り込み画面

**Independent Test**: TagStore.addTag → fetchAllTags → removeTag → cleanupOrphans のサイクルを `TagStoreTests` で確認、UI フローを実機で動作確認。

### Tests for User Story 2 ⚠️

- [ ] T018 [P] [US2] `KnowledgeTreeTests/TagStoreTests.swift` を新規作成。10 ケース (新規追加 / 既存再利用 / 重複 no-op / 空 nil / 正規化 / 削除 + cleanup / 他 article で残る / 存在しない nil / fetchAll sort / cleanupOrphans)

### Implementation for User Story 2

- [ ] T019 [P] [US2] `KnowledgeTree/Services/TagStore.swift` を新規作成。contracts/tag-store.md の API 実装 (addTag / removeTag / fetchAllTags / cleanupOrphans)。RefreshTrigger インジェクション
- [ ] T020 [US2] `KnowledgeTree/Services/ServiceContainer.swift` (spec 005 既存) に `var tagStore: TagStore?` を追加し、`KnowledgeTreeApp.bootstrap()` で初期化 (TagStore に refreshTrigger を inject)
- [ ] T021 [P] [US2] `KnowledgeTree/Views/TagChip.swift` を新規作成。contracts/views.md の API
- [ ] T022 [P] [US2] `KnowledgeTree/Views/TagInputField.swift` を新規作成。contracts/views.md の API (TextField + 確定ボタン + onSubmit)
- [ ] T023 [US2] `KnowledgeTree/Views/ArticleDetailView.swift` に `tagsSection` を追加 (knowledge セクションの前)。既存 article.tags チップ + 「+ 追加」TagInputField (T021, T022 完了後)
- [ ] T024 [P] [US2] `KnowledgeTree/Views/TagListView.swift` を新規作成。`@Query(sort: \Tag.name)` + ContentUnavailableView (空時) + NavigationLink で TagFilteredListView へ
- [ ] T025 [P] [US2] `KnowledgeTree/Views/TagFilteredListView.swift` を新規作成。`@Query(filter:)` で tag 絞り込み + 既存 ArticleRow 流用 (検索ハイライト無効) + sheet で Detail
- [ ] T026 [US2] `KnowledgeTree/Views/ArticleListView.swift` の toolbar に「タグ一覧」ナビゲーションボタンを追加 + `navigationDestination(for: TagListDestination.self)`
- [ ] T027 [P] [US2] `Localizable.xcstrings` に `tag.list.title`, `tag.list.empty.title`, `tag.filtered.title`, `tag.filtered.empty.title`, `tag.input.placeholder`, `tag.input.add`, `detail.tags.heading` を追加

**Checkpoint**: US1 + US2 動作。タグ追加・削除・一覧・絞り込みが UI で動く。

---

## Phase 5: User Story 3 - 関連記事をエンティティ経由で発見する (P2)

**Goal**: Detail 画面下部の関連記事セクション + entity 絞り込み画面。

**Independent Test**: `RelatedArticleFinder.find` 単体テスト + Detail 画面で関連記事 5 件表示の実機確認。

### Tests for User Story 3 ⚠️

- [ ] T028 [P] [US3] `KnowledgeTreeTests/RelatedArticleFinderTests.swift` を新規作成。9 ケース (共通 0 / base entity 無し / 自記事除外 / commonCount sort / savedAt tiebreak / 上限 5 / commonEntities 上位 3 salience / case-insensitive / trim)

### Implementation for User Story 3

- [ ] T029 [P] [US3] `KnowledgeTree/Services/RelatedArticleFinder.swift` を新規作成。contracts/related-article-finder.md の API 実装 (純粋関数 find + RelatedArticle struct)
- [ ] T030 [P] [US3] `KnowledgeTree/Views/RelatedArticlesSection.swift` を新規作成。contracts/views.md の構成。`@Query var allArticles` で全記事取得 → `RelatedArticleFinder.find()` 呼び出し → 各 row 表示 + NavigationLink
- [ ] T031 [US3] `KnowledgeTree/Views/ArticleDetailView.swift` の LazyVStack に `RelatedArticlesSection(article: article)` を追加 (knowledge と body の間) (T030 完了後)
- [ ] T032 [P] [US3] `KnowledgeTree/Views/EntityFilteredListView.swift` を新規作成。entity name で絞り込み + 既存 ArticleRow 流用
- [ ] T033 [US3] `KnowledgeTree/Views/KnowledgeSummaryView.swift` 既存の entity チップに NavigationLink を追加 (T032 完了後): タップで `EntityFilteredListView(entityName: chip.name)` へ遷移
- [ ] T034 [US3] `ArticleListView` の `navigationDestination(for: EntityFilteredDestination.self) { ... }` を追加 (`for: String.self` と衝突しないよう、専用 type を導入)
- [ ] T035 [P] [US3] `Localizable.xcstrings` に `detail.related.heading` (例: "関連記事"), `entity.filtered.title` を追加

**Checkpoint**: US1 + US2 + US3 動作。関連記事と entity 絞り込みが UI で動く。

---

## Phase 6: User Story 4 - エンティティから自動タグ提案 (P3)

**Goal**: salience 4 以上の entity を 1 タップでタグ採用。

**Independent Test**: `SuggestedTagFinder.find` 単体テスト + Detail 画面で提案チップ動作の実機確認。

### Tests for User Story 4 ⚠️

- [ ] T036 [P] [US4] `KnowledgeTreeTests/SuggestedTagFinderTests.swift` を新規作成。8 ケース (salience >=4 / <4 除外 / 既存タグ除外 / salience desc sort / dedupe / 空 / 上限 5 / displayName preserve)

### Implementation for User Story 4

- [ ] T037 [P] [US4] `KnowledgeTree/Services/SuggestedTagFinder.swift` を新規作成。contracts/related-article-finder.md の SuggestedTagFinder API + SuggestedTag struct
- [ ] T038 [US4] `KnowledgeTree/Views/ArticleDetailView.swift` の `tagsSection` に「自動提案」サブセクション追加: `SuggestedTagFinder.find()` 呼び出し → 提案チップ表示 → タップで `tagStore.addTag(rawName:to:)` (T023 を拡張、T037 完了後)
- [ ] T039 [P] [US4] `Localizable.xcstrings` に `detail.suggestedTags.heading` (例: "AI 提案") を追加

**Checkpoint**: 全 US 動作。

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T040 [P] 全 spec 001-008 テスト pass 確認 (`xcodebuild test`)
- [ ] T041 [P] specs/008-search-tags-graph/quickstart.md の S1〜S8 を実機で実行 (記事 30+ 件保存済の状態)
- [ ] T042 [P] パフォーマンス計測: 1000 記事の状態で検索クエリ入力 → 結果表示までの時間を Xcode Instruments で計測。200 ms 以内を確認 (SC-001)
- [ ] T043 [P] アクセシビリティ確認: `.searchable` の VoiceOver 対応、各 TagChip / RelatedArticleRow の accessibilityIdentifier 設定済を確認
- [ ] T044 spec 005 の live update が新規 view (TagListView / TagFilteredListView / EntityFilteredListView) でも機能することを実機で確認 (RefreshTrigger.bump → @Query 再 fetch)
- [ ] T045 git commit + push + PR description 更新

---

## Dependencies & Execution Order

### Phase 依存

- **Phase 1 (Setup)**: 即着手
- **Phase 2 (Foundational)**: T003 → T004 → T005、T006 + T007 並列、T008 は T003 後
- **Phase 3 (US1)**: Phase 2 完了後。テスト (T009-T011 並列) → 実装 (T012, T013, T016 並列) → T014 → T015 → T017 (動作確認)
- **Phase 4 (US2)**: Phase 2 完了後 (US1 と並列可能)。T018 → T019 → T020 → T021, T022 並列 → T023 → T024, T025 並列 → T026 → T027
- **Phase 5 (US3)**: Phase 2 完了後 (US1 / US2 と並列可能)。T028 → T029, T030 並列 → T031 → T032 → T033 → T034 → T035
- **Phase 6 (US4)**: Phase 4 完了後 (TagStore に依存)。T036 → T037, T039 並列 → T038
- **Phase 7 (Polish)**: 全完了後

### User Story 並列性

- US1 (検索) / US2 (タグ) / US3 (関連記事) は実装ファイルが分離されているため並列可
- US4 (自動提案) は US2 (TagStore) に依存
- 推奨: 開発者 1 名なら US1 → US2 → US3 → US4 の順、複数なら US1 / US2 / US3 並列着手 → US2 完了後に US4

### Within Each User Story

- テスト先 (T009-T011, T018, T028, T036) → 実装
- Models (T003-T005) → Services (T006, T012, T013, T019, T029, T037) → Views (T014, T015, T021-T027, T030-T035, T038)
- Localization (T016, T027, T035, T039) は独立、いつでも並列可

---

## Implementation Strategy

### MVP 路線 (US1 Only)

1. Phase 1 → Phase 2
2. Phase 3 (US1 検索) — テスト → 実装
3. **STOP & VALIDATE**: 検索バーで複数フィールド横断検索が動くこと確認
4. Demo 可能 (検索のみ MVP リリース)

### Incremental Delivery

1. MVP (US1) merge → ユーザーリリース
2. US2 (タグ) merge → タグ管理機能リリース
3. US3 (関連記事) merge → エンティティ横断リリース
4. US4 (自動提案) merge → 完成形

### Parallel Team Strategy

- Developer A: Phase 1 + 2 → Phase 3 (US1)
- Developer B: Phase 4 (US2)、Phase 2 完了後着手
- Developer C: Phase 5 (US3)、Phase 2 完了後着手
- US2 完了後 Developer A が US4 着手
- 全員 Phase 7 で polish

---

## Parallel Example: Phase 3 テスト群

```bash
Task: "SearchPredicateTests.swift 新規"      # T009
Task: "SearchHighlighterTests.swift 新規"    # T010
Task: "SearchFixtures.swift 新規"            # T011
```

```bash
# Phase 3 実装並列:
Task: "SearchPredicate.swift 新規"            # T012
Task: "SearchHighlighter.swift 新規"          # T013
Task: "Localizable.xcstrings 検索キー追加"    # T016
```

---

## Notes

- spec 005 の RefreshTrigger / NotificationCenter / Timer fallback / @Bindable パターンを継承
- spec 006 / 007 の追加で生成された essence / keyFacts / entities / 連結 HTML 由来の本文も検索対象になる (新規対応不要、SearchPredicate がフィールドを横断するため)
- `Tag.name` の `@Attribute(.unique)` で DB レベル重複防止
- `@Query(filter:)` の動的 Predicate 構築は inner View pattern (research.md R4) で SwiftUI が再 fetch を保証
- 関連記事計算は同期純粋関数 (1000 記事規模で OK、メインスレッド問題なし、research.md R5)
- SwiftData Predicate の relationship traversal が iOS 26 SDK で部分的に動かない場合の fallback (T017) を必ず確認すること
- 既存テスト (spec 001-007) は **無修正で pass** することが merge 条件

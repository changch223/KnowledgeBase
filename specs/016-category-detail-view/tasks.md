# Tasks: Category 詳細画面 + ArticleRow 時間軸 + ArticleDetailView 本文折りたたみ (spec 016)

**Input**: Design documents from `/specs/016-category-detail-view/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: 純関数 / computed property に対する unit test を含める (DisclosureGroup / NavigationStack 標準挙動は除外、quickstart 実機検証で代替)。

**Organization**: 4 user stories (US1〜US4) ごとに Phase を分けて独立 deliver 可能。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 並列可能 (異なるファイル、依存なし)
- **[Story]**: US1〜US4 のいずれか
- 全タスクに project-relative path を記載

---

## Phase 1: Setup

**Purpose**: 文言追加と新規 destination 配置

- [x] T001 `KnowledgeTree/Localization/Localizable.xcstrings` に新規 5 文言追加 (`category.detail.tagFilter.expand` / `category.detail.tagFilter.collapse` / `category.detail.empty.title` / `category.detail.empty.description` / `reader.bodyDisclosureLabel`)。日本語 only。
- [x] T002 `KnowledgeTree/Views/ArticleListView.swift` 末尾に `struct CategoryFilteredDestination: Hashable { let category: Category }` を追加 (既存 `TagFilteredDestination` の隣)

---

## Phase 2: Foundational

**Purpose**: 全 User Story 共通の helper を先に整備

- [x] T003 `KnowledgeTree/Views/ArticleRow.swift` に `private enum SavedAtFormatter` を追加 (`format(_:now:)` 純関数 + static let formatters。R3 / contracts/article-row-saved-at.md 仕様)

**Checkpoint**: T001-T003 完了で全 US が並列着手可能

---

## Phase 3: User Story 3 (P1) — ArticleRow 時間軸表示 🎯 MVP

**Goal**: 全 ArticleRow に savedAt 時間軸 (今日/昨日/N 日前/絶対) を表示

**Independent Test**:
- ライブラリタブの ArticleRow に savedAt 表示が出る
- `ArticleRowSavedAtTests` が PASS

(US3 を最初に持ってくる理由: US1 / US2 の CategoryFilteredListView も ArticleRow を使うため、先に savedAt 表示を完成させる)

- [x] T004 [US3] `KnowledgeTreeTests/ArticleRowSavedAtTests.swift` を新規作成。`SavedAtFormatter.format(_:now:)` の 5 ケース (今日 / 昨日 / 3 日前 / >7 日前 / 未来) を検証。fixture 不要、`Date(timeIntervalSince1970:)` で時刻注入
- [x] T005 [US3] `KnowledgeTree/Views/ArticleRow.swift` の URL Text 行を HStack 化し savedAt Text を右に追加 (font: caption2 / foregroundStyle: secondary)
- [x] T006 [US3] `KnowledgeTree/Views/ArticleRow.swift` の `combinedAccessibilityLabel` に savedAt の絶対値 ("YYYY 年 M 月 D 日 HH:mm 保存") を追加

**Checkpoint**: T004-T006 完了で US3 完成。`xcodebuild test` で `ArticleRowSavedAtTests` 5/5 PASS、ライブラリタブで savedAt 表示確認可能

---

## Phase 4: User Story 1 (P1) — Category タップで全記事 + タグフィルター 🎯 MVP

**Goal**: AI ブレインタブの Category 行タップ → CategoryFilteredListView 遷移、全 Tag union 記事 + タグフィルターチップ表示

**Independent Test**:
- AI ブレインタブで Category タップ → 数字 = 表示記事数 (B1 修正確認)
- タグフィルターチップ「+N ▼」展開
- `CategoryFilteredListViewTests` が PASS

- [x] T007 [P] [US1] `KnowledgeTreeTests/CategoryFilteredListViewTests.swift` を新規作成。in-memory `ModelContainer` + Tag/Article fixture で `categoryTags` / `displayedTags` / `hiddenTagCount` / `filteredArticles` の 8 ケースを検証 (contracts/category-filtered-list-view.md)
- [x] T008 [US1] `KnowledgeTree/Views/CategoryFilteredListView.swift` を新規作成。@Query<Tag> + @State (selectedTagNames / showsAllTags) + computed property 4 つ + body (NavigationTitle large + LazyHStack タグフィルター + LazyVStack 記事リスト + ContentUnavailableView)。private inline `TagFilterChip` も同ファイルに配置
- [x] T009 [US1] `KnowledgeTree/Views/AIBrainView.swift` の `KnowledgeCategoryRow` を wrap する `NavigationLink(value:)` を `TagFilteredDestination` から `CategoryFilteredDestination(category: entry.category)` に変更
- [x] T010 [US1] `KnowledgeTree/Views/AIBrainView.swift` の NavigationStack に `.navigationDestination(for: CategoryFilteredDestination.self) { dest in CategoryFilteredListView(category: dest.category) }` を追加
- [x] T011 [US1] `KnowledgeTree/Views/KnowledgeCategoryRow.swift` から `let topTagName: String` プロパティを削除 + accessibilityLabel から topTagName 参照を削除
- [x] T012 [US1] `KnowledgeTree/Views/AIBrainView.swift` の `CategoryListEntry` struct から `topTagName: String` フィールドを削除 + `categoryEntries` computed property の `topTag` 計算を削除

**Checkpoint**: T007-T012 完了で US1 完成。`xcodebuild test` で `CategoryFilteredListViewTests` 8/8 PASS、AI ブレインタブで Category タップ → CategoryFilteredListView 遷移確認可能

---

## Phase 5: User Story 2 (P1) — タグフィルター OR 条件

**Goal**: CategoryFilteredListView でタグチップ選択 / 解除で OR 条件記事フィルター

**Independent Test**:
- タグチップタップで選択 toggle、Action Blue 強調
- 複数選択で OR 条件
- 選択中チップ再タップで解除

(T008 で実装済の `selectedTagNames` 操作 + `filteredArticles` computed が US2 を満たす。確認のみで追加コード不要だが、選択 toggle UI ロジックを念のため明示)

- [x] T013 [US2] `KnowledgeTree/Views/CategoryFilteredListView.swift` の TagFilterChip タップ action を確認: `selectedTagNames.contains(tag.name) ? selectedTagNames.remove(tag.name) : selectedTagNames.insert(tag.name)`
- [x] T014 [US2] `KnowledgeTree/Views/CategoryFilteredListView.swift` の TagFilterChip の `isSelected` 視覚効果を確認 (Action Blue 背景 + white text vs tagFill 背景 + ink text)
- [x] T015 [US2] `CategoryFilteredListViewTests` で OR 条件ケース 2 つ (1 タグ選択 / 2 タグ選択) が含まれることを T007 と合算で確認

**Checkpoint**: T013-T015 完了で US2 完成。実機 quickstart SC-002 検証可能

---

## Phase 6: User Story 4 (P2) — ArticleDetailView 本文折りたたみ

**Goal**: ArticleDetailView 本文セクションを DisclosureGroup でラップ、初期 collapsed

**Independent Test**:
- ArticleDetailView 開くと本文 collapsed
- 「本文を読む」タップで展開
- 再度開くと collapsed (毎回リセット)

- [x] T016 [US4] `KnowledgeTree/Views/ArticleDetailView.swift` の struct スコープに `@State private var isBodyExpanded: Bool = false` を追加
- [x] T017 [US4] `KnowledgeTree/Views/ArticleDetailView.swift` の `bodySection` 計算プロパティを書き換え: `paragraphs.isEmpty` 時は `EmptyView`、それ以外は `DisclosureGroup(isExpanded: $isBodyExpanded, content: { ... }, label: { Text("reader.bodyDisclosureLabel").font(DS.Typography.sectionTitle) })` でラップ。accessibilityHint「タップして本文を展開」+ accessibilityIdentifier "reader.bodyDisclosure"
- [x] T018 [US4] `KnowledgeTree/Views/ArticleDetailView.swift` の旧 `Text("reader.bodySectionTitle")` 参照を削除 (DisclosureGroup label に置換済)

**Checkpoint**: T016-T018 完了で US4 完成。実機で記事タップ → 本文 collapsed → 「本文を読む」タップで展開確認

---

## Phase 7: Polish & Cross-Cutting

**Purpose**: 既存テスト回帰確認 + ビルド警告ゼロ + CLAUDE.md 更新

- [x] T019 [P] `xcodebuild -scheme KnowledgeTree -destination "platform=iOS Simulator,name=iPhone 16" test` で全テスト実行、spec 015 まで 66+ ケース + 新規 13 ケース (5 + 8) 全 PASS 確認
- [x] T020 [P] `xcodebuild -scheme KnowledgeTree -destination "platform=iOS Simulator,name=iPhone 16" build` でビルド警告ゼロ確認
- [x] T021 [P] `CLAUDE.md` の spec 016 行を「📝 計画完了」→「✅ 実装」に更新 (本ブランチ + commit hash 追記)
- [ ] T022 quickstart 9 シナリオ (SC-001〜SC-009) を実機検証 (ユーザー実施)

---

## Dependencies

```
T001, T002 (Setup)
   ↓
T003 (Foundational helper)
   ↓
   ├─→ T004-T006 (US3, MVP) ─┐
   ├─→ T007-T012 (US1, MVP) ─┤
   ├─→ T013-T015 (US2)        ┤
   └─→ T016-T018 (US4)        ┤
                               ↓
                         T019-T022 (Polish)
```

US1 / US2 は同じファイル `CategoryFilteredListView.swift` を触るため、US2 は US1 完了後 (T013-T015 は T008 上に確認・微調整タスク)。
US3 / US4 は独立ファイル、US1 と並列可能 (T004-T006 と T007-T012 と T016-T018 は P 並列)。

## Parallel Opportunities

- T004-T006 (US3 ArticleRow 改修) ‖ T007-T012 (US1 CategoryFilteredListView 新規) ‖ T016-T018 (US4 ArticleDetailView 改修): 全部別ファイル、並列実装可
- T019, T020, T021: Polish フェーズで並列

## Implementation Strategy

### MVP (US1 + US3 のみで価値提供可)

T001-T003 → T004-T012 で:
- B1 バグ修正 (US1)
- ArticleRow に savedAt 表示 (US3)

US2 は US1 の延長 (T013-T015 は確認タスク主体)、US4 は P2 で後回し可。

### 段階リリース提案

1. **Sprint 1 (MVP)**: Phase 1 + 2 + 3 + 4 = T001-T012 (US1 + US3 完成、B1 修正 deliver)
2. **Sprint 2**: Phase 5 + 6 = T013-T018 (US2 + US4 完成、UX 完成)
3. **Sprint 3 (Polish)**: Phase 7 = T019-T022 (テスト回帰 + 実機検証)

実装規模目安: 22 タスク、~150 行 net change + ~250 行新規。

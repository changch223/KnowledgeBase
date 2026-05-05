---
description: "Tasks for spec 015: AI ブレインタブ v2 + DesignSystem migration + Category 階層"
---

# Tasks: AI ブレインタブ v2 + DesignSystem migration + Category 階層

**Input**: Design documents from `specs/015-ai-brain-v2-categories/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ 5 個 ✅, quickstart.md ✅

**Tests**: 含む。Constitution テストゲート準拠 (`KnowledgeTreeTests` 単体テスト 12 ケース、UI test 改修)。

**Organization**: 4 ユーザーストーリー (US1: 知識分野俯瞰 P1 / US2: Category タップ遷移 P1 / US3: Apple-quiet 視覚 P1 / US4: 自動 Category 分類 P2) ごとに独立実装可能。

## Format: `[ID] [P?] [Story] Description with file path`

- **[P]**: 並列実行可
- **[Story]**: US1〜US4
- ファイルパスは project-relative

---

## Phase 1: Setup

- [x] T001 [P] `KnowledgeTree/Localization/Localizable.xcstrings` に v2 + Category 関連の文字列を追加:
  - `aibrain.stats.articles` ("記事") / `aibrain.stats.entities` ("知識") / `aibrain.stats.facts` ("ファクト")
  - `aibrain.categories.heading` ("カテゴリ別知識")
  - `aibrain.categories.empty.title` ("カテゴリーがありません") / `aibrain.categories.empty.body` ("記事を保存するとカテゴリーが表示されます")
  - `aibrain.insight.empty.headline` ("Safari から記事を保存しましょう") / `aibrain.insight.empty.subtext` ("Share Sheet で「知積」を選択")
  - `aibrain.insight.top.headline %@` ("最も読んでいる分野: %@") / `aibrain.insight.top.subtext %lld` ("%lld 記事")
  - `aibrain.category.row.count %lld` ("%lld 記事") / `aibrain.category.row.voiceover %@ %lld` ("%@、%lld 記事") / `aibrain.category.row.hint` ("タップで該当記事一覧へ遷移")
  - `status.phase.categoryClassifying` ("カテゴリー分類中")
  - "全タグのカテゴリー分類中" (BottomStatusBar title)

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: 全 US の前提。

- [x] T002 `KnowledgeTree/Models/Tag.swift` に `var categoryRaw: String?` attribute 追加 (default nil)。SwiftData lightweight migration 自動対応。`init(name:)` を `init(name: String, categoryRaw: String? = nil)` に拡張。既存呼び出し側 (TagStore.addTag) は default nil で後方互換。
- [x] T003 [P] `KnowledgeTree/Services/CategorySeed.swift` を新規作成: `struct Category { name, englishName, order, symbolName }` + `enum CategorySeed { static let allSeeds: [Category] (10 個) + static func category(for name: String?) -> Category + static var otherCategory }`。data-model.md Section B-2 に従い 10 個ハードコード (テクノロジー / 経済 / 健康 / デザイン / 学術 / アート / ニュース / スポーツ / エンタメ / その他)。
- [x] T004 [P] `KnowledgeTree/Services/AutoCategoryClassifier.swift` を新規作成: `protocol AutoCategoryClassifier` + `final class FoundationModelsAutoCategoryClassifier` + `final class InMemoryAutoCategoryClassifier` + `@Generable struct CategoryClassificationOutput`。contracts/auto-category-classifier.md 準拠。LanguageModelSessionProtocol を使用、SystemLanguageModel.availability チェック、不正値 / 失敗 → "その他" fallback。
- [x] T005 `KnowledgeTree/Services/ProcessingMonitor.swift` の `Phase` enum に `case categoryClassifying = 4` を追加。Comparable / Sendable は既存通り。
- [x] T006 `KnowledgeTree/DesignSystem.swift` を refactor: 5 新 token (actionBlue #0a4d8c / actionBlueFocus #1565b8 / parchment #faf8f3 / knowledgeTile #f5f5f7 / tagFill #eaeaef) を `enum Color` に追加。**廃止予定 9 token は alias として残す** (aiBrandStart = actionBlue.opacity(0.10) / aiBrandEnd = actionBlue.opacity(0.20) / aiBrandEdge / aiBrandNodeFill / aiBrandNodeStroke / phaseEnrichment = actionBlue / phaseBody / phaseKnowledge / phaseTagging)。コメントで「将来 spec で廃止」記載。`dsAIGradientBackground` ViewModifier は削除しない (廃止 view が使用)。
- [x] T007 `KnowledgeTree/Views/BottomStatusBar.swift` の `phaseTintColor(_)` 関数を全 case で `DS.Color.actionBlue` を返すように簡略化 (`return DS.Color.actionBlue` のみの 1 行関数化)。`phaseLabel(_)` の switch に `case .categoryClassifying: return "status.phase.categoryClassifying"` を追加。

**Checkpoint**: ビルド成功 + 既存全テスト pass (alias 残しで廃止 view も compile 維持)。

---

## Phase 3: User Story 1 - 知識分野俯瞰 (Priority: P1) 🎯 MVP

**Goal**: AI ブレインタブが Stats Row + AI Insight Card + Category List で表示される。

**Independent Test**: T015-T017 単体テスト pass + 実機 quickstart 検証 1-2。

### Tests for User Story 1

- [x] T008 [P] [US1] `KnowledgeTreeTests/AutoCategoryClassifierTests.swift` を新規作成: contracts/auto-category-classifier.md の 5 ケース全実装 (testInMemoryReturnsMappedCategory / testInMemoryReturnsDefaultForUnknown / testInMemoryReturnsDefaultForEmpty / testInMemoryRespectsCustomDefault / testFallbackContainsAllSeedNames)。InMemory mock 中心。
- [x] T009 [P] [US1] `KnowledgeTreeUITests/AIBrainTabUITests.swift` を改修: 旧 6 ケースのうち PowerGauge / KnowledgeMap / RecentActivity 系 4 ケースを削除、新 4 ケース (`testAIBrainTabShowsStatsRow` / `testInsightCardPresent` / `testCategoryListPresent` / `testCategoryListEmptyStateOnFreshInstall`) を追加。`testLibraryTabRetainsExistingBehavior` と `testAIBrainRootAccessibilityIdentifier` は保持。新 identifier (`aibrain.stats_row` / `aibrain.insight_card` / `aibrain.category_list` / `aibrain.category_list.empty`) を使用。

### Implementation for User Story 1

- [x] T010 [P] [US1] `KnowledgeTree/Views/AIBrainStatsRow.swift` を新規作成。contracts/ai-brain-stats-row.md 準拠。`@Query<Article>/<KnowledgeEntity>/<KeyFact>` で集計、`@State animatedArticleCount/EntityCount/FactCount` で 3 数字を `withAnimation(DS.Animation.ifMotionAllowed(.counterAppear))` で 0.5 秒カウントアップ。`HStack` で 3 列 + Divider、`dsCardBackground()` 背景。`accessibilityIdentifier("aibrain.stats_row")` + `accessibilityElement(.combine)` + accessibilityLabel 集約。
- [x] T011 [P] [US1] `KnowledgeTree/Views/AIInsightCard.swift` を新規作成。contracts/ai-insight-card.md 準拠。`tags: [Tag]` を引数で受け、`topCategoryEntry: (Category, Int)?` computed property で Tag グループ化 + 最大集計。タグ 0 件: 「Safari から記事を保存しましょう」+ tray アイコン。タグ 1 件以上: 「最も読んでいる分野: {Category 名}」+ sparkles + N 記事 subtext。背景 `actionBlue.opacity(0.06)` + 0.5px hairline border。`accessibilityIdentifier("aibrain.insight_card")`。
- [x] T012 [P] [US1] `KnowledgeTree/Views/KnowledgeCategoryRow.swift` を新規作成。contracts/knowledge-category-row.md 準拠。`category: Category, articleCount: Int, maxCount: Int, topTagName: String` を受け、`HStack` で Category 名 (80pt left aligned) + プログレスバー (GeometryReader で ratio = articleCount / maxCount、`actionBlue` fill on `tagFill` background) + 「N 記事」(60pt right aligned, monospacedDigit)。`NavigationLink(value: TagFilteredDestination(tagName: topTagName))` でタップ遷移。`accessibilityIdentifier("aibrain.category_row.\(category.englishName.lowercased())")`。
- [x] T013 [US1] `KnowledgeTree/Views/AIBrainView.swift` を完全書き換え。research.md R8 構造に従い、`NavigationStack { ZStack { ScrollView { VStack(spacing: DS.Spacing.section) { AIBrainStatsRow + AIInsightCard(tags: allTags) + CategoryListSection(tags: allTags) } } + BottomStatusBar } }`。`@Query<Tag>` で allTags 取得。`CategoryListSection` は private struct として同ファイル内 or 別ファイルで定義、Category 別グループ化 + 集計 + 降順 sort + LazyVStack で `KnowledgeCategoryRow` 列挙 + Divider 区切り。Empty State は `ContentUnavailableView`「カテゴリーがありません」(`accessibilityIdentifier("aibrain.category_list.empty")`)。
- [x] T014 [US1] `KnowledgeTree/KnowledgeTreeApp.swift` の `bootstrap()` を改修:
  - `let categoryClassifier: AutoCategoryClassifier = FoundationModelsAutoCategoryClassifier()` 構築
  - `tagStore` 構築時 or 直後に `tagStore.categoryClassifier = categoryClassifier` を inject (TagStore に optional property を追加するか、init に追加)
  - bootstrap 末尾の `await backfillRunner.run()` (spec 013) の後に `let categoryBackfillRunner = AutoCategoryBackfillRunner(context: context, classifier: categoryClassifier, processingMonitor: processingMonitor); await categoryBackfillRunner.run()` を追加

**Checkpoint**: T008 + T010-T014 完了で v2 UI が表示可能。実機 quickstart 検証 1-2 で確認。

---

## Phase 4: User Story 2 - Category タップ遷移 (Priority: P1)

**Goal**: Category 行タップ → TagFilteredListView へ 0.5 秒以内遷移。

**Independent Test**: 実機 quickstart 検証 3 (UI test に統合済の `testCategoryListPresent` 内で識別子確認、遷移は実機検証のみ)。

### Implementation for User Story 2

- [x] T015 [US2] **実装変更なし** — T012 の `KnowledgeCategoryRow` 内 `NavigationLink(value: TagFilteredDestination)` で完結。AIBrainView の `.navigationDestination(for: TagFilteredDestination.self)` (spec 011 既存) を再利用。タスクとしてはクラス間連携の動作確認のみ。

**Checkpoint**: 実機タップで TagFilteredListView 表示確認。

---

## Phase 5: User Story 3 - Apple-quiet 視覚 (Priority: P1)

**Goal**: 全 view で interactive 要素が Action Blue 単一色、gradient / 多色 phase tint 全廃。

**Independent Test**: 実機 quickstart 検証 8 + 既存テスト全 pass (token 名変更で挙動変わらず)。

### Implementation for User Story 3

- [x] T016 [US3] `KnowledgeTree/Views/ArticleRow.swift` の token 参照を更新: leading edge accent の `DS.Color.aiBrandEnd` → `DS.Color.actionBlue`、AI バッジの `DS.Color.aiBrandEnd.opacity(0.08)` → `DS.Color.actionBlue.opacity(0.08)` 等。alias で旧 token も動くが新 token 名で一貫性確保。
- [x] T017 [US3] **実装変更なし** — Phase 2 の T006 (DesignSystem 9 alias 残し) + T007 (BottomStatusBar phase tint 統一) で完了済。廃止 view (PowerGaugeCard / KnowledgeMapView / RecentActivityCards) は AIBrainView から外れる (T013 で完了) ため alias 経由で従来動作維持。タスクとしては動作確認のみ。

**Checkpoint**: ライブラリタブ + AI ブレインタブで gradient / 多色なし、Action Blue 単一色。

---

## Phase 6: User Story 4 - 自動 Category 分類 (Priority: P2)

**Goal**: 新規 Tag 作成時 + bootstrap で 既存 Tag に Category を自動付与。

**Independent Test**: T018-T019 単体テスト pass + 実機 quickstart 検証 5-6。

### Tests for User Story 4

- [x] T018 [P] [US4] `KnowledgeTreeTests/AutoCategoryBackfillRunnerTests.swift` を新規作成: contracts/auto-category-backfill-runner.md の 7 ケース全実装 (testFlagFalseRunsBackfill / testFlagTrueSkipsBackfill / testOnlyTargetsTagsWithNilCategoryRaw / testHandlesEmptyDatabase / testFallbackToOtherWhenClassifierReturnsOther / testProcessesAllCandidatesEvenOnPartialFailure / testRunSetsFlagEvenWhenAllFail)。in-memory ModelContainer + `private typealias Tag = KnowledgeTree.Tag` + InMemoryBackfillFlagStore + InMemoryAutoCategoryClassifier。

### Implementation for User Story 4

- [x] T019 [US4] `KnowledgeTree/Services/AutoCategoryBackfillRunner.swift` を新規作成。contracts/auto-category-backfill-runner.md 準拠。`@MainActor final class AutoCategoryBackfillRunner`。アルゴリズムは spec 013 AutoTagBackfillRunner と完全同パターン: flag check → predicate `categoryRaw == nil` で fetch → ProcessingMonitor.start(.categoryClassifying, ...) → 各候補 Tag を `await classifier.classify(tagName:)` → `tag.categoryRaw = result; try? context.save()` → `processingMonitor.updateProgress(...)` → 全完了で `processingMonitor.finish + flagStore.markCompleted()`。固定 UUID `00000000-0000-0000-0000-CA7E0CEAA70F`。
- [x] T020 [US4] `KnowledgeTree/Services/TagStore.swift` を改修: イニシャライザに `classifier: AutoCategoryClassifier? = nil` を追加。`addTag(rawName:to:)` 内、新規 Tag 作成 (= 既存 Tag が見つからず insert する分岐) のみで `if let classifier { Task { [weak self] in let cat = await classifier.classify(tagName: tag.name); await MainActor.run { tag.categoryRaw = cat; try? self?.context.save(); self?.refreshTrigger?.bump() } } }` の fire-and-forget Task を起動。既存 Tag の場合は何もしない (categoryRaw 既値を尊重)。

**Checkpoint**: T018 unit test pass + 実機で新記事保存 → 60 秒以内に Category List 反映確認。

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T021 [P] 既存全テスト回帰: `xcodebuild test -only-testing:KnowledgeTreeTests` で 既存 KnowledgeMapBuilder 11 + RecentActivitySnapshotBuilder 7 + AutoTagApplier 7 + AutoTagBackfillRunner 7 + その他 + 新規 AutoCategoryClassifier 5 + AutoCategoryBackfillRunner 7 全 PASS 確認 (合計 ~70 ケース)。
- [ ] T022 [P] UI test 回帰: `xcodebuild test -only-testing:KnowledgeTreeUITests/AIBrainTabUITests` で T009 で書き換えた 6 ケース (旧 2 + 新 4) が pass 確認。実機 / Simulator UI test sandbox launch issue (spec 011 で既知) があれば skip 可。
- [ ] T023 quickstart.md 検証 1〜12 を実機 (iPhone 17 Pro) で実行:
  - 検証 1: タグ 0 件空状態
  - 検証 2: 30 記事 Stats Row + Category List
  - 検証 3: Category タップ遷移
  - 検証 4: 新記事保存 → 60 秒以内反映
  - 検証 5: bootstrap backfill 進捗表示
  - 検証 6: AutoCategoryClassifier 精度 (Foundation Models)
  - 検証 7: Reduce Motion 全停止
  - 検証 8: Apple-quiet 視覚 (gradient / 多色 phase なし)
  - 検証 9: Dark Mode
  - 検証 10: ライブラリ完全保持
  - 検証 11: VoiceOver
  - 検証 12: Dynamic Type 最大
- [x] T024 [P] `CLAUDE.md` の SPECKIT セクションを更新し spec 015 を「✅ 実装 + commit `<sha>`」に書き換え。
- [x] T025 [P] 最終 build 警告ゼロ確認 (`xcodebuild build` で本 spec 起因 warning 0)。

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: 即着手可
- **Phase 2 (Foundational)**: Phase 1 完了後、全 US の前提
- **Phase 3 (US1)**: Phase 2 完了後、AI brain v2 UI 本実装
- **Phase 4 (US2)**: Phase 3 の T012 完了後 (KnowledgeCategoryRow の NavigationLink で完結、実装変更なし)
- **Phase 5 (US3)**: Phase 2 完了後 (token alias で既存 view は維持、ArticleRow は token 名変更のみ)
- **Phase 6 (US4)**: Phase 2 + Phase 3 の T014 (bootstrap inject) 完了後
- **Phase 7 (Polish)**: 全 US 完了後

### User Story Dependencies

- **US1 (P1, 知識分野俯瞰)**: Foundational のみ依存。本 spec の core
- **US2 (P1, タップ遷移)**: US1 の T012 (KnowledgeCategoryRow) に依存、実装変更なし
- **US3 (P1, Apple-quiet)**: Foundational のみ依存、token 名のみ更新
- **US4 (P2, 自動分類)**: US1 の T014 (bootstrap inject) に依存

### 共通ファイル順序制約

- `Tag.swift`: T002 のみ
- `DesignSystem.swift`: T006 のみ
- `ProcessingMonitor.swift`: T005 のみ
- `BottomStatusBar.swift`: T007 のみ
- `CategorySeed.swift`: T003 のみ (新規)
- `AutoCategoryClassifier.swift`: T004 のみ (新規)
- `AutoCategoryBackfillRunner.swift`: T019 のみ (新規)
- `AIBrainView.swift`: T013 のみ (完全書き換え)
- `AIBrainStatsRow.swift` / `AIInsightCard.swift` / `KnowledgeCategoryRow.swift`: T010 / T011 / T012 (各新規、並列可)
- `ArticleRow.swift`: T016 のみ (token 名更新)
- `TagStore.swift`: T020 のみ (classifier inject)
- `KnowledgeTreeApp.swift`: T014 のみ (bootstrap 改修)
- `Localizable.xcstrings`: T001 のみ
- `AutoCategoryClassifierTests.swift`: T008 (新規)
- `AutoCategoryBackfillRunnerTests.swift`: T018 (新規)
- `AIBrainTabUITests.swift`: T009 (改修)

---

## Parallel Opportunities

### Setup Phase (Phase 1)

```text
T001 [P] (Localizable) 単独
```

### Foundational Phase (Phase 2)

```text
T002 (Tag.swift) / T003 [P] (CategorySeed 新規) / T004 [P] (AutoCategoryClassifier 新規) は別ファイル → 並列可
T005 (ProcessingMonitor) / T006 (DesignSystem) / T007 (BottomStatusBar) は順次 (T005 → T007 BottomStatusBar が phase enum case を必要)
```

### US1 並列 (Phase 3)

```text
T008 [P] [US1] (Test) / T010 [P] [US1] (StatsRow) / T011 [P] [US1] (InsightCard) / T012 [P] [US1] (CategoryRow) は別ファイル → 並列
T013 [US1] (AIBrainView 書き換え) は T010-T012 完了後
T014 [US1] (bootstrap 改修) は T004 + T019 完了後 (classifier + backfillRunner 必要)
```

### Polish (Phase 7)

```text
T021 [P] / T022 [P] / T024 [P] / T025 [P] 全部独立、並列可
T023 (実機検証) は T021/T022 後の order
```

---

## Implementation Strategy

### MVP First (US1 + US3 のみ)

1. Phase 1 (Setup): T001 完了
2. Phase 2 (Foundational): T002-T007 完了
3. Phase 3 (US1): T008-T013 完了 + T014 (US4 のため classifier inject 含む)
4. Phase 5 (US3): T016 完了
5. Phase 4 (US2): T015 ロジック確認のみ
6. **STOP and VALIDATE**: T008 unit test + T009 UI test pass → 実機 quickstart 検証 1-3 + 8 → MVP demo OK
7. US4 と Polish は次フェーズ

### Incremental Delivery

1. MVP (上記) → 実機検証 → 中間 commit
2. US4 (T018-T020): 新規 Tag 作成時の自動分類 + bootstrap backfill → 実機検証 4-6 → commit
3. Polish (T021-T025): 全テスト回帰 + 実機 quickstart 全 12 → PR

### Solo Dev Strategy

- 個人開発、test-first → 実装 → 検証 のループ
- Constitution テストゲート遵守: 各 US の Tests を先に書いて FAIL 確認 (実機なくても type check で )
- 各 US の Checkpoint で git commit (推奨 4 コミット: Phase 2 / US1 / US4 / Polish)

---

## Notes

- [P] = 異なるファイル / 依存なし、並列可
- [Story] = US1〜US4 ラベル
- 各 US は独立完成 + 独立テスト可能
- 既存スキーマは Tag.categoryRaw 1 attribute 追加のみ (lightweight migration)
- 既存 view (PowerGaugeCard / KnowledgeMapView / RecentActivityCards) は **コード残存**、AIBrainView 参照外し + DesignSystem alias で compile 維持
- 新 service / 新 view は protocol / struct で薄い境界に分離
- AutoCategoryClassifier mock で test 環境では Foundation Models 不要
- 改修対象は: 新規 6 ファイル (CategorySeed / AutoCategoryClassifier / AutoCategoryBackfillRunner / AIBrainStatsRow / AIInsightCard / KnowledgeCategoryRow + tests 2) + 改修 9 ファイル (Tag / DesignSystem / ProcessingMonitor / BottomStatusBar / AIBrainView / ArticleRow / TagStore / KnowledgeTreeApp / Localizable.xcstrings + UI test 1) の合計 ~17 ファイル

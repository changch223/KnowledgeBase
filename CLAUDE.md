<!-- SPECKIT START -->
Active features in flight:
- spec 001-008 — ✅ 実装 + main マージ済 (spec 001-005 commit `0fad9fd` / spec 006 `74d167b` / spec 007 `640c89c` / spec 008 `8f3ce4a` + hot-fix `fbcde69`).
- spec 009-010 — ✅ 実装 + commit `adc2221` (BGTaskScheduler incremental save + 階層的 chunked summarization).
- spec 011 — UI リブランディング + AI ブレインタブ追加 — ✅ 実装 + commit `8b8671e` (本ブランチ `011-ai-brain-tab`、未マージ)。Tab 化 / PowerGauge / KnowledgeMap (Canvas + force-directed) / RecentActivity / 知積リブランディング 全部完成。Unit テスト 18/18 PASS。実機検証 (quickstart.md SC-001〜SC-008) と Instruments 60fps 計測のみ未実施。
- spec 012 — タグ自動付与 (AI Auto-Tag) — ✅ 実装 + commit `0e6e299` (本ブランチ `012-auto-tag`、未マージ)。AutoTagApplier 純粋関数 + KnowledgeExtractionService の hook 2 箇所 + bootstrap で TagStore inject。新 schema ゼロ。Unit テスト 7/7 PASS、既存テスト全回帰 PASS。
- spec 013 — 既存記事への auto-tag backfill — ✅ 実装 + commit `dc877bd` + main マージ済 (PR #2 / merge `47a9338`)。AutoTagBackfillRunner + BackfillFlagStore + ProcessingMonitor.Phase `.tagBackfilling`。Unit テスト 7/7 PASS。
- spec 014 — 統一デザインシステム + Phase 3/4 視覚改善 — ✅ 実装 + commit `b78c2f4` + PR #3 OPEN (本ブランチ `014-design-system`)。
- spec 015 — AI ブレイン v2 + DesignSystem migration + Category 階層 — ✅ 実装 (本ブランチ `015-ai-brain-v2-categories`、未 commit)。AIBrainView v2 (Stats Row + Insight Card + Category List) + DESIGN.md target に DesignSystem 移行 (9 token alias 残し + 5 token 追加) + Tag.categoryRaw lightweight migration + AutoCategoryClassifier + AutoCategoryBackfillRunner + ProcessingMonitor.Phase `.categoryClassifying` + BottomStatusBar phase tint actionBlue 統一。Unit テスト 12/12 PASS、既存テスト全回帰 PASS。実機検証で B1 バグ + 4 UX 要望が判明 → spec 016 へ。
- spec 016 — Category 詳細画面 + ArticleRow 時間軸 + 本文折りたたみ — ✅ 実装 (本ブランチ `016-category-detail-view`、未 commit)。CategoryFilteredListView 新設 + CategoryFilter 純関数 enum で B1 バグ根本解決 (タップ先 = Category 全 Tag union 記事一覧、数字 = 実体一致) + タグフィルター OR (上位 5 + 「+N ▼」展開) + ArticleRow に SavedAtFormatter 時間軸表示 (今日/昨日/N 日前/絶対) + ArticleDetailView bodySection を DisclosureGroup 折りたたみ + KnowledgeCategoryRow.topTagName 削除。Unit テスト 15/15 PASS (CategoryFilteredListViewTests 9 + ArticleRowSavedAtTests 6)。既存テスト全回帰 PASS (BodyExtractorTests 2 件は spec 016 前から既存 FAIL、本 spec 起因ではない)。実機検証 (quickstart SC-001〜SC-009) のみ未実施。

Read these first for the current planning context (spec 016 = newest plan):

**spec 016 (Category 詳細画面 + ArticleRow 時間軸 + 本文折りたたみ)**:
- plan: `specs/016-category-detail-view/plan.md` — 新規 1 view + 改修 5 view + Hashable destination 1 つ / Constitution Check 全 PASS
- research: `specs/016-category-detail-view/research.md` — R1〜R10 (destination 配置 / +N 展開 UX / savedAt フォーマット / DisclosureGroup 位置 / Tag 集計 / カウント仕様 / テスト戦略 / xcstrings / navigationDestination / topTagName 削除)
- data-model: `specs/016-category-detail-view/data-model.md` — 既存 @Model 再利用 + transient struct 1 つ (CategoryFilteredDestination)
- contracts: `specs/016-category-detail-view/contracts/{category-filtered-list-view, category-filtered-destination, article-row-saved-at, article-detail-body-disclosure}.md`
- quickstart: `specs/016-category-detail-view/quickstart.md` — 9 検証シナリオ (B1 修正 / OR フィルター / +N 展開 / 60 秒以内反映 / savedAt 表示 / 本文折りたたみ / Reduce Motion / 既存回帰 / unit test)

**spec 015 (AI ブレイン v2 + DesignSystem migration + Category)**:
- plan: `specs/015-ai-brain-v2-categories/plan.md`
- research: `specs/015-ai-brain-v2-categories/research.md` (R1〜R10)
- data-model: `specs/015-ai-brain-v2-categories/data-model.md`
- contracts: `specs/015-ai-brain-v2-categories/contracts/{auto-category-classifier, auto-category-backfill-runner, ai-brain-stats-row, ai-insight-card, knowledge-category-row}.md`
- quickstart: `specs/015-ai-brain-v2-categories/quickstart.md` (12 検証シナリオ)

**spec 013 (既存記事への auto-tag backfill)**:

**spec 013 (既存記事への auto-tag backfill)**:
- plan: `specs/013-auto-tag-backfill/plan.md` — bootstrap 末尾 1 ブロック / 純 UI 拡張 / 新 service 1 つ + protocol 1 つ
- research: `specs/013-auto-tag-backfill/research.md` — R1〜R5 (ProcessingMonitor.Phase 拡張 / UserDefaults キー / MainActor 並行性 / fetch 戦略 / テスト隔離)
- data-model: `specs/013-auto-tag-backfill/data-model.md` — 既存 @Model 再利用 + UserDefaults キー 1 つ + Phase enum 拡張
- contracts: `specs/013-auto-tag-backfill/contracts/{auto-tag-backfill-runner,backfill-flag-store}.md`
- quickstart: `specs/013-auto-tag-backfill/quickstart.md` — 7 検証シナリオ (1 度限り backfill / 2 回目 early return / 100 件 30 秒 / 整理済保持 / 新記事競合 / 強制終了復帰 / 新規インストール)

**spec 012 (タグ自動付与 / AI Auto-Tag)**:
- plan: `specs/012-auto-tag/plan.md` — KnowledgeExtractionService への hook 2 箇所 / 新 service ゼロ / Constitution Check 全 pass
- research: `specs/012-auto-tag/research.md` — R1〜R5 (hook 位置 / API 形 / early return / DI / テスト戦略)
- data-model: `specs/012-auto-tag/data-model.md` — 既存 @Model 再利用、transient struct ゼロ
- contracts: `specs/012-auto-tag/contracts/{auto-tag-applier,knowledge-extraction-service-hook}.md`
- quickstart: `specs/012-auto-tag/quickstart.md` — 7 検証シナリオ (新規 5 タグ付与 / 既存タグ skip / 全削除復活 / 失敗時非付与 / spec 011 波及 / 既存挙動回帰 / 100 件取りこぼし)

**spec 011 (UI リブランディング + AI ブレインタブ)**:

**spec 011 (UI リブランディング + AI ブレインタブ)**:
- plan: `specs/011-ai-brain-tab/plan.md` — TabView 化 / 純 UI 拡張 / 新 @Model ゼロ / Constitution Check 全 pass
- research: `specs/011-ai-brain-tab/research.md` — R1〜R8 (TabView 環境注入、Canvas force-directed、@Query 集計、7 日 predicate、CFBundleDisplayName、エッジ計算、新繋がり判定)
- data-model: `specs/011-ai-brain-tab/data-model.md` — 既存 @Model 再利用 + transient 型 (MapNode / MapEdge / MapGraph / RecentActivitySnapshot)
- contracts: `specs/011-ai-brain-tab/contracts/{ai-brain-view,knowledge-map-builder,power-gauge-card,recent-activity-cards}.md`
- quickstart: `specs/011-ai-brain-tab/quickstart.md` — 7 検証シナリオ (空状態 / カウントアップ / 60fps / live update / 既存回帰 / タブステート保持 / a11y)

**spec 009 / 010 (実装済)**:
- spec 009 plan: `specs/009-background-extraction/plan.md`
- spec 010 plan: `specs/010-hierarchical-summary/plan.md`

For spec 006-008 reference:
- spec 006 plan: `specs/006-chunked-summarize/plan.md`
- spec 007 plan: `specs/007-multipage-fetch/plan.md`
- spec 008 plan: `specs/008-search-tags-graph/plan.md`

For spec 001 〜 005 reference:
- spec 001 plan: `specs/001-save-article/plan.md`
- spec 005 spec + quickstart: `specs/005-detail-status-ui/spec.md` + `quickstart.md`

Project constitution: `.specify/memory/constitution.md` (v1.0.0, 7 Japanese-first
product principles + secondary engineering quality gates).
<!-- SPECKIT END -->

<!-- SPECKIT START -->
Active features in flight:
- spec 001-008 — ✅ 実装 + main マージ済 (spec 001-005 commit `0fad9fd` / spec 006 `74d167b` / spec 007 `640c89c` / spec 008 `8f3ce4a` + hot-fix `fbcde69`).
- spec 009-010 — ✅ 実装 + commit `adc2221` (BGTaskScheduler incremental save + 階層的 chunked summarization).
- spec 011 — UI リブランディング + AI ブレインタブ追加 — ✅ 実装 + commit `8b8671e` (本ブランチ `011-ai-brain-tab`、未マージ)。Tab 化 / PowerGauge / KnowledgeMap (Canvas + force-directed) / RecentActivity / 知積リブランディング 全部完成。Unit テスト 18/18 PASS。実機検証 (quickstart.md SC-001〜SC-008) と Instruments 60fps 計測のみ未実施。
- spec 012 — タグ自動付与 (AI Auto-Tag) — ✅ 実装 + commit `0e6e299` (本ブランチ `012-auto-tag`、未マージ)。AutoTagApplier 純粋関数 + KnowledgeExtractionService の hook 2 箇所 + bootstrap で TagStore inject。新 schema ゼロ。Unit テスト 7/7 PASS、既存テスト全回帰 PASS。
- spec 013 — 既存記事への auto-tag backfill — ✅ 実装 + commit `dc877bd` + main マージ済 (PR #2 / merge `47a9338`)。AutoTagBackfillRunner + BackfillFlagStore + ProcessingMonitor.Phase `.tagBackfilling`。Unit テスト 7/7 PASS。
- spec 014 — 統一デザインシステム + Phase 3/4 視覚改善 — ✅ 実装 (遡及 spec、本ブランチ `014-design-system`、未 commit)。`DesignSystem.swift` 新規 + 18 view DS.* 適用 + AI ブレイン系再設計 (PowerGauge/KnowledgeMap/RecentActivity) + ArticleRow / Detail / EmptyStateView polish + Reduce Motion 対応。19 file changed +413/-248 行、新 schema ゼロ。実機検証 (quickstart SC-001〜SC-007) のみ未実施。

Read these first for the current planning context (spec 013 = newest plan):

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

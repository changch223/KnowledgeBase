<!-- SPECKIT START -->
Active features in flight:
- spec 001-008 — ✅ 実装 + main マージ済 (spec 001-005 commit `0fad9fd` / spec 006 `74d167b` / spec 007 `640c89c` / spec 008 `8f3ce4a` + hot-fix `fbcde69`).
- spec 009-010 — ✅ 実装 + commit `adc2221` (BGTaskScheduler incremental save + 階層的 chunked summarization).
- spec 011 — UI リブランディング + AI ブレインタブ追加 — ✅ 実装 + commit `8b8671e` (本ブランチ `011-ai-brain-tab`、未マージ)。Tab 化 / PowerGauge / KnowledgeMap (Canvas + force-directed) / RecentActivity / 知積リブランディング 全部完成。Unit テスト 18/18 PASS。実機検証 (quickstart.md SC-001〜SC-008) と Instruments 60fps 計測のみ未実施。
- spec 012 — タグ自動付与 (AI Auto-Tag) — ✅ 実装 (本ブランチ `012-auto-tag`、未 commit)。AutoTagApplier 純粋関数 + KnowledgeExtractionService の hook 2 箇所 + bootstrap で TagStore inject。新 schema ゼロ。Unit テスト 7/7 PASS、既存テスト全回帰 PASS。実機検証 (quickstart SC-001〜SC-007) のみ未実施。

Read these first for the current planning context (spec 012 = newest plan):

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

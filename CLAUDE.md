<!-- SPECKIT START -->
Active features in flight:
- spec 001-005 — ✅ 実装 + main マージ済 + commit `0fad9fd`。
- spec 006 — 長文記事の Chunked Summarization — ✅ 実装 + commit `74d167b` (origin/008-search-tags-graph)。
- spec 007 — マルチページ記事の自動追跡 + 本文統合 — ✅ 実装 + commit `640c89c`。
- spec 008 — 振り返り支援 (検索 + タグ + エンティティ横断 + 自動提案) — ✅ 実装 + commit `8f3ce4a` + 続く `fbcde69` で stale `.extracting` 自動回復 hot-fix。
- spec 009 — バックグラウンド AI 抽出継続 (BGTaskScheduler + incremental save) — 📐 spec + plan + research + data-model + contracts + quickstart 完了 (未実装)。
- spec 010 — 階層的 chunked summarization (超長文 30000 文字対応) — 📐 spec + plan + research + data-model + contracts + quickstart 完了 (未実装)。

Read these first for the current planning context:

**spec 009 (background extraction)**:
- plan: `specs/009-background-extraction/plan.md`
- research: `specs/009-background-extraction/research.md` (R1〜R10)
- data-model: `specs/009-background-extraction/data-model.md`
- contracts: `specs/009-background-extraction/contracts/{chunk-progress-store,background-scheduler,background-runner,knowledge-extraction-service}.md`
- quickstart: `specs/009-background-extraction/quickstart.md`

**spec 010 (hierarchical summarization)**:
- plan: `specs/010-hierarchical-summary/plan.md`
- research: `specs/010-hierarchical-summary/research.md`
- data-model: `specs/010-hierarchical-summary/data-model.md`
- contracts: `specs/010-hierarchical-summary/contracts/`
- quickstart: `specs/010-hierarchical-summary/quickstart.md`

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

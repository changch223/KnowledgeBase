<!-- SPECKIT START -->
Active features in flight:
- spec 001 — 記事保存 (Share Sheet 経由) — ✅ 実装 + コミット済 (commit 0fad9fd)。
- spec 002 — 本文取得・メタデータエンリッチメント — ✅ 実装 + コミット済 (Shift-JIS 対応含む)。
- spec 003 — 本文抽出 (Reader View) — ✅ 実装 + コミット済 (article/main/density 3 段階抽出)。
- spec 004 — 知識抽出 + 要約 (Apple Foundation Models) — ✅ 実装 + コミット済。
- spec 005 — Detail/Status UI + Live Update — ✅ 実装 + コミット済 (5 並列メカニズム + Schema 統一)。
- spec 006 — 長文記事の Chunked Summarization — 📐 spec + plan + research + data-model +
  contracts + quickstart 完了 (未実装)。本文 1000 文字超を最大 10 chunk + meta-summary に分割。
- spec 007 — マルチページ記事の自動追跡 + 本文統合 — 📐 spec + plan + research + data-model +
  contracts + quickstart 完了 (未実装)。rel=next / class=next / URL パターンを 3 段階優先順位で
  検出、最大 5 ページ、同一ホスト限定、1 秒遅延。
- spec 008 — 振り返り支援 (検索 + タグ + エンティティ横断 + 自動提案) — 📐 spec + plan +
  research + data-model + contracts + quickstart 完了 (未実装)。1000 記事で 200ms 検索、
  Tag 多対多、関連記事 5 件、自動タグ提案 (salience 4 以上)。

Read these first for the current planning context:

**spec 006 (chunked summarization)**:
- plan: `specs/006-chunked-summarize/plan.md`
- research: `specs/006-chunked-summarize/research.md` (R1〜R8)
- data-model: `specs/006-chunked-summarize/data-model.md` (ExtractedKnowledge 列追加)
- contracts: `specs/006-chunked-summarize/contracts/{chunk-splitter,chunked-aggregator,knowledge-extractor}.md`
- quickstart: `specs/006-chunked-summarize/quickstart.md`

**spec 007 (multi-page fetch)**:
- plan: `specs/007-multipage-fetch/plan.md`
- research: `specs/007-multipage-fetch/research.md` (R1〜R8)
- data-model: `specs/007-multipage-fetch/data-model.md` (ArticleEnrichment 列追加 +
  PaginationLink/PageCrawlSession/CrawlResult)
- contracts: `specs/007-multipage-fetch/contracts/{pagination-detector,multipage-crawler,enrichment-service}.md`
- quickstart: `specs/007-multipage-fetch/quickstart.md`

**spec 008 (search + tags + graph)**:
- plan: `specs/008-search-tags-graph/plan.md`
- research: `specs/008-search-tags-graph/research.md` (R1〜R9)
- data-model: `specs/008-search-tags-graph/data-model.md` (Tag @Model 新規 +
  Article.tags 多対多、SearchHighlight/RelatedArticle/SuggestedTag transient)
- contracts: `specs/008-search-tags-graph/contracts/{tag-store,search-predicate,related-article-finder,views}.md`
- quickstart: `specs/008-search-tags-graph/quickstart.md`

For spec 001 〜 005 reference:
- spec 001 plan: `specs/001-save-article/plan.md`
- spec 002 plan: `specs/002-fetch-content/plan.md`
- spec 003 plan: `specs/003-extract-body/plan.md`
- spec 004 plan: `specs/004-summarize/plan.md`
- spec 005 spec + quickstart: `specs/005-detail-status-ui/spec.md` + `quickstart.md`

Project constitution: `.specify/memory/constitution.md` (v1.0.0, 7 Japanese-first
product principles + secondary engineering quality gates).
<!-- SPECKIT END -->

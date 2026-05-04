<!-- SPECKIT START -->
Active features in flight:
- spec 001 — 記事保存 (Share Sheet 経由) — Round 1 実装済 (未コミット)、
  Xcode UI 作業 + 動作確認待ち。詳細は `specs/001-save-article/xcode-setup.md`。
- spec 002 — 本文取得・メタデータエンリッチメント — spec + plan + design + tasks 完了
  (未実装)。spec 001 完成後に実装着手予定。
- spec 003 — 本文抽出 (Reader View) — spec + plan + design 完了 (未実装)。
  spec 002 完成後に実装着手予定。新規ネットワークなし (spec 002 のキャッシュ rawHTML を再利用)。

Read these first for the current planning context (spec 003 = newest plan):
- Implementation plan: `specs/003-extract-body/plan.md` — technical context,
  project structure, architecture decisions, Constitution Check status.
- Research: `specs/003-extract-body/research.md` — Phase 0 findings (extraction algorithm).
- Data model: `specs/003-extract-body/data-model.md` — ArticleBody + Article relationship.
- Contracts: `specs/003-extract-body/contracts/` — Extractor / Service / Store boundaries.
- Quickstart: `specs/003-extract-body/quickstart.md` — manual verification (Reader View + SVC fallback).

For spec 001 / spec 002 reference (still relevant):
- spec 001 plan: `specs/001-save-article/plan.md` + Xcode UI setup: `specs/001-save-article/xcode-setup.md`
- spec 002 plan: `specs/002-fetch-content/plan.md`

Project constitution: `.specify/memory/constitution.md` (v1.0.0, 7 Japanese-first
product principles + secondary engineering quality gates).
<!-- SPECKIT END -->

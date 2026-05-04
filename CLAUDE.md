<!-- SPECKIT START -->
Active features in flight:
- spec 001 — 記事保存 (Share Sheet 経由) — Round 1 実装済 (未コミット)、
  Xcode UI 作業 + 動作確認待ち。詳細は `specs/001-save-article/xcode-setup.md`。
- spec 002 — 本文取得・メタデータエンリッチメント — spec + plan + design + tasks 完了 +
  Round 2 で Swift コード実装済 (未コミット)。
- spec 003 — 本文抽出 (Reader View) — spec + plan + design + tasks 完了 +
  Round 2 で Swift コード実装済 (未コミット)。
- spec 004 — 知識抽出 + 要約 (Apple Foundation Models) — spec + plan + design 完了
  (未実装)。本プロジェクト初の Foundation Models 利用 spec。spec 001-003 commit 後に実装着手予定。

Read these first for the current planning context (spec 004 = newest plan):
- Implementation plan: `specs/004-summarize/plan.md` — technical context, project
  structure, Generable types vs @Model 型分離、Constitution Check status.
- Research: `specs/004-summarize/research.md` — Phase 0 (R1〜R8: Generable nested types,
  availability check, hallucination prompt, session lifecycle, error handling, mocking,
  performance, schema migration).
- Data model: `specs/004-summarize/data-model.md` — Generable types
  (ExtractedKnowledgeOutput, KeyFactOutput, KnowledgeEntityOutput) + @Model types
  (ExtractedKnowledge, KeyFact, KnowledgeEntity) + Article への relationship.
- Contracts: `specs/004-summarize/contracts/` — KnowledgeExtractor / Service / Store boundaries.
- Quickstart: `specs/004-summarize/quickstart.md` — Apple Intelligence 対応端末での手動検証
  (US1〜US3 + ハルシネーション sampling + ネットワーク監視).

For spec 001 / 002 / 003 reference:
- spec 001 plan: `specs/001-save-article/plan.md` + Xcode UI setup: `specs/001-save-article/xcode-setup.md`
- spec 002 plan: `specs/002-fetch-content/plan.md`
- spec 003 plan: `specs/003-extract-body/plan.md`

Project constitution: `.specify/memory/constitution.md` (v1.0.0, 7 Japanese-first
product principles + secondary engineering quality gates).
<!-- SPECKIT END -->

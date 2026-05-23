# Specification Quality Checklist: SavedAnswer (AI Chat 答えの永続化と概念ページへの紐付け)

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-05-23
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

> Note: spec.md は user-facing scenario と FR を中心に書き、実装詳細 (SwiftData @Model 構造 / @Relationship.nullify / ChatService hook 経路) は plan.md に分離。entity 名 (SavedAnswer / ConceptPage / ChatAnswerOutput) は spec.md に残存 — 知積プロジェクトの spec kit 運用上、entity 名がそのまま型名になるため許容。

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- spec.md は 7 user stories (P1×3, P2×3, P3×1) で MVP から拡張機能まで段階的に定義
- FR は 19 個、機能カテゴリ別 (データ層 / ConceptPage 紐付け / 編集 / 表示 / 検索 P3) に分類
- SC は 8 個、ユーザー視点で測定可能な指標
- Edge cases 7 個、fallback テキスト / 削除済 ChatSession / 引用記事全削除 / 同質問繰り返し / ConceptPage merge / 同質問 context 違い / 自動保存後の手動削除
- Assumptions 10 個、Apple Intelligence 必須 / ChatService 既存稼働 / ConceptPage 既存稼働 / silent fire-and-forget / 同 question 大文字小文字区別 等
- 規模見込み: 新規 5-6 ファイル + 改修 7-8 ファイル、~700-800 行 (実装 + テスト)、Phase A 2 週
- 依存 spec: 021 (ChatService - ChatAnswerOutput.citedArticleIDs 利用) / 042 (ConceptPage - file 先 + relatedConceptIDs 紐付け) / 037 (ConflictProposal - 同 defensive pattern)
- 範囲外: spec 044 WikiLint (isStale 答えの UI 提示) / spec 045 EntityCommunity (community 統合) / spec 046 Understanding Chat (カード surface) / Widget (spec 048)

## Validation Results

すべてのチェック項目が pass。spec.md は `/speckit-plan` に進める品質。

主要決定事項 (plan で具体化する点):

1. **SavedAnswer @Model**: 12 フィールド、@Relationship.nullify for citedArticles (片方向、Article 側 inverse 追加なし)
2. **ChatService.ask() hook**: 末尾に `await savedAnswerService?.captureIfWorthy(...)` を fire-and-forget Task で配置
3. **ConceptPage 紐付け**: 引用記事 → 関連 ConceptPage を fetch → mentionCount or 関連記事数の多い順 5 件
4. **重複防止**: 同 question (空白 trim 後完全一致) の既存 SavedAnswer がある場合 skip
5. **isStale 連動**: ConceptPage.isStale 化時に紐付く SavedAnswer も isStale=true (KnowledgeExtractionService hook 経由)
6. **履歴画面**: 専用 view を新規 (or ChatTabView に sub-tab) — plan で UI 階層を確定

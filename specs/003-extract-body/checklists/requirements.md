# Specification Quality Checklist: 本文抽出 (Reader View)

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-05-04
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

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

- **新規ネットワークアクセスなし**: 本 spec は spec 002 がキャッシュ済の `ArticleEnrichment.rawHTML` のみを入力に取るため、Constitution Principle I の「Network Access Justification」セクションは不要。Principle I を violate することなく Reader View 体験を実現する。
- **抽出品質目標 70%** (SC-003) は Foundation 標準 API + ヒューリスティックの現実的な上限を踏まえた設定。残り 30% (抽出失敗) は SVC フォールバック (US2) で UX を破壊しない設計に組み込まれている。
- **画像・動画・iframe を表示しない** 判断 (FR-009) は MVP first を厳格適用。画像インライン Reader は将来「Reader View Phase 2」で扱う。
- **Reader UI controls (フォントサイズ・テーマ等) を持たない** 判断 (Out of Scope) も MVP first。OS Dynamic Type / Dark Mode に従うことで Constitution Principle V (落ち着いた UX) と一貫。
- 用語ポリシーは spec 001 / 002 と同じ: ユーザー視点の OS 機能名 (Reader View、Dark Mode、Dynamic Type、SFSafariViewController) は記述、フレームワーク識別子 (`UIViewControllerRepresentable`、`Text` modifier 詳細等) は plan.md / tasks.md 側で扱う。
- データモデル変更 (`ArticleBody` 追加) は spec 001 の `Article` には変更なし、spec 002 の `ArticleEnrichment` にも変更なし。新エンティティが Article への non-optional 参照を持つ (Principle III) ことだけ data-model.md で固定する。
- spec 003 の入力 (rawHTML) は spec 002 のキャッシュに依存するため、spec 003 を本格実装する前に spec 001 + spec 002 が production-ready である必要がある。

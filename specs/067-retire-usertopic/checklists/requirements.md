# Specification Quality Checklist: UserTopic 退役

**Created**: 2026-05-31 | **Feature**: [spec.md](../spec.md)

## Content Quality
- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness
- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Notes
- ユーザー選択「UserTopic だけ削除」+ CloudKit 不破壊の両立 → 死蔵コードのみ削除、@Model 残置。
- GraphNode/KnowledgeDigest は表示で使用中ゆえ対象外。
- orphan 確認済 (UserTopicCandidateRow/DetailView は呼び出し元ゼロ)。

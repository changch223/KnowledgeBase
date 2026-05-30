# Specification Quality Checklist: RecentDigest token 超過修正 + SchemaLoader bundle 同梱

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-05-30
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

- 両問題は実コードで root cause verified (RecentDigestService.buildPrompt が 30 件列挙、SchemaLoader が docs/ = bundle 外参照)。
- SchemaLoader の修正方針はユーザー確定: schema.md をアプリ bundle 同梱。
- spec は WHAT/WHY に集中、HOW (件数 prefix / token 概算 / Resources 配置 / pbxproj) は plan へ委譲。
- [NEEDS CLARIFICATION] ゼロ。

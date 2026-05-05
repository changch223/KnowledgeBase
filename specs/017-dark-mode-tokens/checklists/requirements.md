# Specification Quality Checklist: Dark/Light Mode 自動切り替え対応

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-05-05
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs) — SwiftUI 用語 (DisclosureGroup / Color.adaptive) は登場するが既存 spec の確立済モジュール参照のため許容
- [x] Focused on user value and business needs (Dark Mode で自然な視認性 + Light Mode 完全保持)
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable (SC-001 SC-010 全て検証可能)
- [x] Success criteria are technology-agnostic
- [x] All acceptance scenarios are defined (US1-US4 各受け入れ基準明記)
- [x] Edge cases are identified (廃止 view / alias / Reduce Transparency / Share Extension / iPad / 急速切替)
- [x] Scope is clearly bounded (DesignSystem 一元 + DESIGN.md 更新、view 改修ゼロ)
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows (Dark / Light / Auto / Reduce Transparency)
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- 4 ユーザストーリー (US1 Dark 視覚 P1 / US2 Light 保持 P1 / US3 自動切替 P1 / US4 Reduce Transparency P2)
- 20 FR を 5 セクションに分類 (DesignSystem / DESIGN.md / view 改修ゼロ / テスト / Apple-quiet 維持)
- 10 SC で Light/Dark 切替速度 / view 別視覚 / Reduce Transparency / 既存回帰 を測定可能化
- 確定済方針 (Q&A 経由 8 点):
  - Q1: Color(light:dark:) initializer 一元 (Asset Catalog / Environment 散らかし回避)
  - Q2: parchment Dark = #1c1c1e (iOS 標準 secondarySystemBackground 同等)
  - Q3: actionBlue Dark = #3a8eef (DESIGN.md primary-on-dark 既定義)
  - Q4: tagFill #2c2c2e / actionBlueFocus #5aa3f5 / knowledgeTile #2a2a2c
  - Q5: Reduce Transparency 自動対応のみ (gradient/shadow 全廃済)
  - Q6: 全 18 view 検証 (token 一元なので 1 度で対応)
  - Q7: Dynamic Type は別 spec (本 spec は Dark Mode 集中)
  - Q8: iPad/iPhone 同 token (Apple-quiet 統一)
- 新規 @Model / 新 schema migration / 新 service / view 改修 ゼロ (DesignSystem 一元のみ)
- Light Mode 完全保持 (回帰リスク極小)
- DESIGN.md Known Gaps「Dark Mode 未文書化」を本 spec で解決

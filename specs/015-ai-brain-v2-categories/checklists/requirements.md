# Specification Quality Checklist: AI ブレインタブ v2 + DesignSystem migration + Category 階層

**Purpose**: Validate specification completeness and quality
**Created**: 2026-05-05
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs) — Foundation Models / SwiftData は登場するが既存 spec の確立済モジュール参照のため許容
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic
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

- 4 ユーザストーリー (US1 知識分野俯瞰 P1 / US2 Category タップ遷移 P1 / US3 Apple-quiet 視覚 P1 / US4 自動 Category 分類 P2)
- 50 FR を 8 セクションに分類 (UI v2 / Stats Row / Insight Card / Category List / Category 階層 / DesignSystem refactor / ストレスゼロ / 既存保持)
- 9 SC で UI 起動時間 / Reduce Motion / 4 phase 統一 / 既存回帰 / Category 反映時間 を測定可能化
- 確定済方針 (Q&A 経由):
  - Category: シードカテゴリー静的 mapping (Foundation Models で 1 回推論、`Tag.categoryRaw` 永続化)
  - spec scope: 1 spec に集約 (v2 UI + DesignSystem refactor + Category)
  - Format: Apple template DESIGN.md と整合
- 廃止 view (PowerGaugeCard / KnowledgeMapView / RecentActivityCards) は **コード残存**、AIBrainView 参照外しのみ (将来 spec で復活余地)
- DESIGN.md target に migration: 9 token 削除 + 5 token 追加 + 6 view token 入れ替え
- ストレスゼロ原則を FR-041〜046 で明文化 (gradient / shadow / push 通知 / トースト / ストリーク 全廃)
- 既存 spec 005-014 の機能挙動は変更なし (FR-047〜050)

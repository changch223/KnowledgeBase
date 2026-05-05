# Specification Quality Checklist: Category 詳細画面 + ArticleRow 時間軸 + 本文折りたたみ

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-05-05
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs) — SwiftUI 用語 (DisclosureGroup) 等は登場するが既存 spec の確立済モジュール参照のため許容
- [x] Focused on user value and business needs (B1 バグ修正 + UX 改善 4 件)
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified (Category 内 Tag 0/1/5/6+ 件、未来 savedAt、本文なし、Reduce Motion 等)
- [x] Scope is clearly bounded (B1 修正 + UX 改善 4 件、AND/NOT フィルターは将来)
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- **B1 バグ起因**: spec 015 実機検証で Category List 数字 ≠ TagFilteredListView 表示数の不一致を発見。原因は単一 Tag 表示 vs 全 Tag union 集計のズレ。CategoryFilteredListView 新設で根本解決
- 4 ユーザストーリー (US1 全記事+フィルター P1 / US2 OR 条件 P1 / US3 時間軸 P1 / US4 本文折りたたみ P2)
- 38 FR を 6 セクションに分類 (CategoryFilteredListView / AIBrainView 改修 / ArticleRow 時間軸 / 本文折りたたみ / ストレスゼロ / 既存保持)
- 9 SC で B1 修正 / フィルター速度 / 60 秒以内反映 / 既存回帰 を測定可能化
- 確定済方針 (Q&A 経由 3 点):
  - 日付形式: 今日/昨日 = 相対、それ以上 = ハイブリッド
  - タグフィルター: 上位 5 個 + 「+N」ボタン
  - 本文折りたたみ: DisclosureGroup「本文を読む」
- 新規 @Model / 新 schema migration / 新 service ゼロ
- 既存 spec 015 (Category 階層) を活用、Tag 階層は既存維持
- B1 修正によりユーザーが期待する「数字 = 実体」が成立、信頼性向上

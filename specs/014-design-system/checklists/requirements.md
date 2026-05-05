# Specification Quality Checklist: 統一デザインシステム + Phase 3/4 視覚改善

**Purpose**: Validate specification completeness and quality
**Created**: 2026-05-05
**Feature**: [spec.md](../spec.md)
**Status**: Retroactive — 実装後の遡及 spec、checklist は事後評価

## Content Quality

- [x] No implementation details (languages, frameworks, APIs) — DS.Color / Spacing 等は実装テクニカルだが、本 spec は遡及 documentation のため記述許容
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders — トークン table はやや技術的、ただし「マジックナンバー駆逐」の business value 中心
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic — 一部 SwiftUI / Material 名は登場するが既存 spec 005-013 の確立済モジュール参照のため許容
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification — 例外: 遡及 spec のため詳細実装が文章に含まれる

## Notes

- 遡及 spec として作成: working tree に既に Phase 1-4 実装が存在する状態で、後追いで spec docs 化
- Constitution Spec-driven workflow の「順序遵守」例外として記録
- 4 ユーザストーリー (US1 AI ブレイン視覚密度 P1 / US2 Reduce Motion P1 / US3 ArticleRow leading edge accent P2 / US4 EmptyStateView 入場/ボブ P2)
- 31 FR を 6 セクションに分類 (DS namespace / 18 view 適用 / Phase 3 視覚再設計 / Phase 4 polish / アクセシビリティ / データ層保持)
- 7 SC で magic number 駆逐 / 視覚層構造 / Reduce Motion / 既存テスト pass / build 警告 0 を測定可能化
- 既存スキーマで全要件達成、新 @Model / Service / migration / transient struct ゼロ
- DS.Animation.ifMotionAllowed で UIAccessibility.isReduceMotionEnabled gate を一元化
- DS namespace + 2 ViewModifier の抽象化は 18 view 中で再利用済 (Constitution コード品質ゲート「2 箇所以上の利用」要件 OK)

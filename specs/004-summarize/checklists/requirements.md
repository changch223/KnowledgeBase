# Specification Quality Checklist: 要約 (Apple Foundation Models)

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

- **本プロジェクト初の Apple Foundation Models 利用 spec**。Constitution Additional Constraints「AI: Apple Foundation Models」を初実装。
- **新規ネットワーク非依存**: Foundation Models はオンデバイス実行のため、Constitution Principle I の Network Access Justification セクションは不要。spec 002 の justification はそのまま継続有効。
- **Apple Intelligence 不可能時のフォールバック (US3)** は Constitution Principle IV と Principle V の両方が要求する graceful degradation。「設定で有効化してください」の押しつけ表示は禁止 (Principle V)。
- **「AI 生成」ラベル必須 (FR-008)** は Constitution Principle III「ソースに基づいた知識生成」の透明性要件を実装に落とした規約。grep で網羅性を audit 可能 (SC-007)。
- **ハルシネーション検出は MVP 外** (Out of Scope)。代替: 「AI 生成」ラベル + ユーザーが元記事を確認できる動線 (Reader View 内の本文表示 + 元記事を開くボタン from spec 003)。
- **要約品質目標 90%** (SC-003) は Apple Foundation Models 単独の現実的目標。クラウド大モデル (ChatGPT 等) に劣る可能性は assumptions に明示。残り 10% (生成失敗) は UI 上に何も出さない (Principle V) で UX を保護。
- **streaming 表示は本 spec では行わない** (バックグラウンド生成のため)。`PartiallyGenerated<T>` 経由のリアルタイム streaming UI は将来 AI チャット spec で初導入。
- 用語ポリシーは spec 001-003 と同じ: ユーザー視点の機能名 (Apple Intelligence、要約、Reader View) は記述、フレームワーク識別子 (`SystemLanguageModel`、`LanguageModelSession`、`@Generable` 等) は plan.md / tasks.md で扱う。
- 設定画面 (要約 ON/OFF、enrichment ON/OFF 含む) は別 spec。本 spec は OS の Apple Intelligence 設定状態に従うのみ。

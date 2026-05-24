# Specification Quality Checklist: Understanding Chat (家庭教師ループ + 学習タブ)

**Purpose**: 仕様完成度と品質をクオリティ・ゲートで保証
**Created**: 2026-05-23
**Feature**: [spec.md](../spec.md)

## Content Quality

- [X] No implementation details (languages, frameworks, APIs) — UI/Service 抽象のみ、Swift/SwiftData は data-model.md で扱う
- [X] Focused on user value and business needs — Karpathy「understanding は外部化できない」哲学を「学習タブ + 家庭教師 chat」に翻訳
- [X] Written for non-technical stakeholders — 「家庭教師」「✓ わかった」等の概念で説明、protocol 名は entities セクションのみ
- [X] All mandatory sections completed — User Scenarios / Requirements / Success Criteria / Assumptions すべて記載

## Requirement Completeness

- [X] No [NEEDS CLARIFICATION] markers remain — 仕様策定中の対話で全項目確定
- [X] Requirements are testable and unambiguous — FR 24 件すべて binary check 可能 (MUST + 数値 / clamp / non-goal 明示)
- [X] Success criteria are measurable — SC-001〜SC-010 全て時間 / 状態 / count で測定可能
- [X] Success criteria are technology-agnostic — fps / 秒 / 件数 / on/off で表現、framework 名なし
- [X] All acceptance scenarios are defined — 10 User Story 全てに Given/When/Then 1-3 件
- [X] Edge cases are identified — 7 件 (空状態 / 全 max / 短文 unknown / Foundation 不可 / 連打 / merge/delete / 連続同概念)
- [X] Scope is clearly bounded — Out of Scope は spec input (Widget / icon / dashboard / streak / テスト UI) で明示分離
- [X] Dependencies and assumptions identified — Assumptions 10 件 + spec 042/043/021/040/008 依存明示

## Feature Readiness

- [X] All functional requirements have clear acceptance criteria — FR-001〜FR-024 全て User Story acceptance scenario に紐付け
- [X] User scenarios cover primary flows — P1 5 件 (surface / 起動 / chat / ✓ / 🤔)、P2 4 件 (+N / ✗ / surfaceからのSavedAnswer / ConceptPage導線)、P3 1 件 (統計)
- [X] Feature meets measurable outcomes defined in Success Criteria — SC-001〜SC-010 と FR-001〜FR-024 全て一対多 mapping (例: SC-001 ↔ FR-003、SC-005 ↔ FR-002、SC-009 ↔ FR-022/023/024)
- [X] No implementation details leak into specification — 「ChatService.createSession 流用」「家庭教師 prompt」等は entities + assumptions に留め、FR 本文は behavior 抽象

## Constitution Alignment (project-specific)

- [X] **I. プライバシーファースト** — 完全 on-device、Foundation Models のみ、外部送信ゼロ (FR-008 prompt 注入は local LM)
- [X] **II. MVP ファースト** — P1 5 件 = MVP (学習タブ + surface + 深掘り chat + ✓/🤔 + 起動 default)、P2/P3 で incremental
- [X] **III. ソース追跡** — 深掘り chat の引用記事は既存 ChatService 経由 (spec 021)、SavedAnswer は spec 043 経由で原典保持
- [X] **IV. iOS 実現可能性** — SwiftData 標準 + 既存 ChatService 流用、新 API ゼロ
- [X] **V. シンプルで落ち着いた UX** — FR-022/023/024 で streak/バッジ/通知 完全禁止、SC-009 で測定可能、Edge Case で 「学習しなさい」push 通知禁止明示
- [X] **VI. SwiftUI アーキテクチャ** — entities セクションで UnderstandingCard (transient) + UnderstandingInteraction (新 @Model) 分離、既存 protocol + DI パターン継承
- [X] **VII. 日本語ファースト** — UI 文言全て日本語 (「✓ わかった」「🤔 もっと」「✗ 違う」「新しい知識」「更新が必要」等)、xcstrings 編集前提

## Notes

- spec 044 は iKnow V1 Phase A の **核心ロジック完成 spec** — 「秘書ループ (spec 021+042+043) + 家庭教師ループ (spec 044)」が揃って V1 出荷可能
- US10 (P3) AI ブレインタブ統計は 0 件で非表示 (SC-010)、calm UX 完全遵守
- streak / バッジ / 通知 / 効果音 / 正解不正解 UI は **永久に non-goal** (Constitution V + VISION 明示)
- 規模見込み: 新規 10 + 改修 7-8 = ~1500-1800 行、期間 3-4 週間、Phase A 最大 spec
- 全 12 checklist item PASS → /speckit-plan に進行可能

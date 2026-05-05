# Implementation Plan: 統一デザインシステム + Phase 3/4 視覚改善

**Branch**: `014-design-system` | **Date**: 2026-05-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/014-design-system/spec.md`
**Status**: Retroactive — 実装は既に working tree にあり、本 plan は documentation

## Summary

`KnowledgeTree/DesignSystem.swift` に統一デザイントークン namespace を新設し、18 view (PowerGaugeCard / KnowledgeMapView / RecentActivityCards / AIBrainView / ArticleRow / ArticleDetailView / ArticleListView / EmptyStateView 他) でマジックナンバーを駆逐 + AI ブレイン系の視覚再設計 + 一覧/詳細 polish を一括実施。新 @Model / 新 schema / 新 service ゼロ、機能挙動完全保持。Reduce Motion 対応で全装飾アニメをガード。

## Technical Context

**Language/Version**: Swift 6 (`@MainActor` isolation)
**Primary Dependencies**: SwiftUI 6 (Material / LinearGradient / RadialGradient / Capsule / RoundedRectangle / shadow / scaleEffect / contentTransition)、UIKit (UIAccessibility.isReduceMotionEnabled)
**Storage**: 既存 SwiftData (改修なし)
**Testing**: 既存 KnowledgeTreeTests (66 ケース) が pass し続けることを確認、新規テスト追加なし (View 層のため snapshot test は本 spec では入れない)
**Target Platform**: iOS 26+ / iPadOS 26+
**Project Type**: iOS native app (mobile)
**Performance Goals**: 既存 60fps 維持 (装飾増加でも GPU レンダリング、影響軽微)
**Constraints**: データ層完全無改修、calm UX 維持 (装飾の追加で push 通知 / トースト等は増えない)、Reduce Motion 対応必須
**Scale/Scope**: 18 view + 新規 1 ファイル + 1 xcstrings 追加 = 19 file 改修、合計 +413 / -248 行

## Constitution Check

*GATE: 遡及 spec のため、実装後に check 実施。*

Reference: `.specify/memory/constitution.md` (v1.0.0).

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — 視覚改善のみ、外部送信ゼロ。
- [x] **II. MVP ファースト開発** — Color asset 化 / iPad 専用レイアウト / DS token unit test は将来 spec として明記。
- [x] **III. ソースに基づいた知識生成** — AI 生成物の表示 (PowerGauge / KnowledgeMap) は spec 011 既存の `KnowledgeEntity` → `Article` トレース維持。新規 AI 呼び出しなし。
- [x] **IV. iOS の実現可能性を重視する** — iOS 26+ Material / Canvas / scrollIndicators 等の純正 API のみ使用、依存追加なし。
- [x] **V. シンプルで落ち着いた UX** — calm UX 維持。装飾は静かなパルス (shadow radius) / 入場アニメ (scale 0.8→1.0) のみで、push 通知 / バッジ / トーストは導入しない。Reduce Motion で全停止。
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — `enum DS` 1 つで全トークン集約、新規抽象化は ViewModifier 2 つのみ (両方とも 18 view で再利用)。Constitution コード品質ゲートの「2 箇所以上の利用」を満たす。
- [x] **VII. 日本語ファースト** — 新規文言 1 件 (EmptyStateView「Safari で記事を開いて「共有」→ アプリ名 で保存できます」) は日本語。

### Quality Gates (二次ゲート)

- [x] **コード品質** — Swift API Design Guidelines 準拠、`fatalError` / `try!` 不使用、`@MainActor` 注釈なし (View 構造体は body 内自動 MainActor)。
- [x] **テスト** — 既存 66 unit テストが pass、本 spec では Snapshot Test を導入しない (View 層なので manual visual review で代用、将来 spec で導入検討)。
- [x] **アクセシビリティ・UX 一貫性** — `DS.Animation.ifMotionAllowed` で Reduce Motion 全 guard、leading edge accent 等装飾要素に `accessibilityHidden(true)`、Dynamic Type / Dark Mode 確認は実機検証で。
- [x] **パフォーマンス** — Material / Canvas は GPU、装飾追加でも 60fps 維持の想定。

### 結果

✅ 全 11 ゲート PASS。

### 遡及 spec の補足

通常は spec → plan → impl の順だが、本 spec は impl が先で spec docs が後。Constitution Spec-driven workflow の例外として記録。今後は重大な視覚改修は事前 spec 化する方針。

## Project Structure

### Documentation (this feature)

```text
specs/014-design-system/
├── plan.md              # This file
├── spec.md              # 機能仕様
├── research.md          # Phase 0 (採用したアプローチの根拠)
├── data-model.md        # Phase 1 (DS namespace のトークン table)
├── quickstart.md        # 実機検証手順
├── contracts/
│   └── design-system.md # DS namespace の API contract
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # (将来 /speckit-tasks で生成、本 spec は遡及なので省略可)
```

### Source Code (repository root)

```text
KnowledgeTree/
├── DesignSystem.swift                           ← 新規 (121 行、enum DS + ViewModifier)
├── Localization/
│   └── Localizable.xcstrings                    ← 改修 (+9 行、auto-extract + 案内文)
└── Views/
    ├── AIBrainView.swift                        ← 改修 (±46)
    ├── ArticleDetailView.swift                  ← 改修 (±71)
    ├── ArticleListView.swift                    ← 改修 (±10)
    ├── ArticleRow.swift                         ← 改修 (±145)
    ├── BottomStatusBar.swift                    ← 改修 (±22)
    ├── EmptyStateView.swift                     ← 改修 (±33)
    ├── EnrichmentStatusBadge.swift              ← 改修 (±2)
    ├── EntityChip.swift                         ← 改修 (±14)
    ├── KeyFactRow.swift                         ← 改修 (±2)
    ├── KnowledgeMapView.swift                   ← 改修 (±54)
    ├── KnowledgeSummaryView.swift               ← 改修 (±18)
    ├── PowerGaugeCard.swift                     ← 改修 (±122)
    ├── ReaderView.swift                         ← 改修 (±12)
    ├── RecentActivityCards.swift                ← 改修 (±63)
    ├── RelatedArticlesSection.swift             ← 改修 (±18)
    ├── TagChip.swift                            ← 改修 (±12)
    ├── TagInputField.swift                      ← 改修 (±2)
    └── ThumbnailView.swift                      ← 改修 (±6)
```

合計: 19 file changed、+413 / -248 行。

**Structure Decision**: iOS native app の単一ターゲット構成。本 spec は **新規 1 ファイル + 既存 18 ファイル改修 + Localizable +9 行** で完結。データ層 / Service 層 / @Model / Schema / Migration はすべて無改修。

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| `enum DS` namespace 全 5 トークン | 18 view で magic number を駆逐するため | view 個別で extension Color / Spacing 等を持つ → 散在、保守性悪化 |
| `dsCardBackground()` / `dsAIGradientBackground()` ViewModifier | 18 view で再利用、修正は 1 箇所で済む | View body 内で直接 `.background(.ultraThinMaterial, in: ...)` を毎回書く → 重複、ミス誘発 |

両抽象化とも 2 箇所以上で利用 (Constitution コード品質ゲート「2 箇所以上の利用」要件を満たす)。

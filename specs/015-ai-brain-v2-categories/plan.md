# Implementation Plan: AI ブレインタブ v2 + DesignSystem migration + Category 階層

**Branch**: `015-ai-brain-v2-categories` | **Date**: 2026-05-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/015-ai-brain-v2-categories/spec.md`

## Summary

3 つの連動した変更を 1 spec で実装:
1. **AI ブレインタブ v2 UI**: spec 014 の PowerGauge / KnowledgeMap / RecentActivity を AIBrainView から外し、Stats Row + AI Insight Card + Category List の縦スクロール 1 本ダッシュボードへ
2. **DesignSystem.swift refactor**: DESIGN.md (project root) target に migration、9 token 削除 + 5 token 追加 + 廃止 view の compile 維持のため alias 残し
3. **Category 階層**: `Tag.categoryRaw: String?` 属性追加 (lightweight migration) + `CategorySeed` 10 個のシード + Apple Foundation Models で Tag → Category 推論 (1 回/Tag、永続化) + bootstrap backfill

## Technical Context

**Language/Version**: Swift 6 (`@MainActor` isolation)
**Primary Dependencies**: SwiftUI 6 (Canvas / Material) / SwiftData (VersionedSchema migration) / Foundation Models (`@Generable` for AutoCategoryClassifier)
**Storage**: SwiftData (既存 + `Tag.categoryRaw: String?` 1 attribute 追加、lightweight migration) + UserDefaults (`auto_category_backfill_v1_done` フラグ)
**Testing**: Swift Testing (`KnowledgeTreeTests/`) で 4 新規テストファイル + 既存 UI tests の更新
**Target Platform**: iOS 26+ / iPadOS 26+
**Project Type**: iOS native app (mobile)
**Performance Goals**: AIBrainView 起動 ≤1 秒 / Stats Row カウントアップ 0.5 秒 / Category タップ → 遷移 ≤0.5 秒 / bootstrap backfill 100 Tag ≤60 秒、500 Tag ≤5 分
**Constraints**: オフライン動作必須、メイン処理は `@MainActor`、依存追加なし (Foundation Models on-device)、calm UX (gradient / shadow / push 通知 / トースト 全廃)
**Scale/Scope**: 1000 Tag 規模で全件 Category List 集計 ≤300ms、新規 6 ファイル + 改修 8 ファイル + schema migration 1 個

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Reference: `.specify/memory/constitution.md` (v1.0.0).

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — Foundation Models on-device 推論、外部送信ゼロ。Tag.categoryRaw も local SwiftData に格納。
- [x] **II. MVP ファースト開発** — Category 編集 UI / 動的分類 / KnowledgeMap 復活は将来 spec として明示。シードカテゴリー 10 個固定。
- [x] **III. ソースに基づいた知識生成** — Tag.categoryRaw は Tag (= Article 経由) に追跡可能、AI 生成物としての追跡性を維持。
- [x] **IV. iOS の実現可能性を重視する** — iOS 26+ 限定、Apple Intelligence 利用不可時は categoryRaw = "その他" fallback。
- [x] **V. シンプルで落ち着いた UX** — calm UX 厳格遵守。FR-041〜046 で gradient / shadow / push / バッジ / トースト 全廃を明文化。
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — `AutoCategoryClassifier` protocol で差し替え可能、新 view 3 個と Category service 2 個は薄い境界に分離。
- [x] **VII. 日本語ファースト** — Category 名は日本語 (テクノロジー / 経済 / etc)、englishName は将来 i18n 用。

### Quality Gates (二次ゲート)

- [x] **コード品質** — Swift API Design Guidelines 準拠、`fatalError` / `try!` 不使用、新規抽象化 (AutoCategoryClassifier protocol、CategorySeed struct) は 2 箇所以上利用要件 OK。
- [x] **テスト** — `AutoCategoryClassifierTests` (mock 経由) / `AutoCategoryBackfillRunnerTests` (in-memory) / View accessibility tests / UI test 更新。in-memory ModelContainer + `private typealias Tag = KnowledgeTree.Tag`。
- [x] **アクセシビリティ・UX 一貫性** — Stats Row `accessibilityElement(.combine)`、Category 行に accessibilityLabel、Reduce Motion ガード、Dynamic Type / Dark Mode 対応。
- [x] **パフォーマンス** — 1000 Tag in-memory 集計 ≤300ms、Stats Row 集計 `@Query<Tag>` 全件取得は 100ms 以内 (spec 011 PowerGauge と同等)。

### 結果

✅ 全ゲート PASS、Complexity Tracking 1 件 (廃止 view の token alias 残しを正当化)。

## Project Structure

### Documentation (this feature)

```text
specs/015-ai-brain-v2-categories/
├── plan.md              # This file
├── spec.md              # 機能仕様
├── research.md          # Phase 0 (R1〜R10 の決定)
├── data-model.md        # Phase 1 (Tag schema migration + Category struct + transient types)
├── quickstart.md        # 実機検証手順 (9 シナリオ)
├── contracts/
│   ├── auto-category-classifier.md
│   ├── auto-category-backfill-runner.md
│   ├── ai-brain-stats-row.md
│   ├── ai-insight-card.md
│   └── knowledge-category-row.md
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks 出力)
```

### Source Code (repository root)

```text
KnowledgeTree/
├── DesignSystem.swift                           ← refactor (delete 9 + add 5 + alias for deprecated views)
├── Localization/
│   └── Localizable.xcstrings                    ← v2 strings + Category 名 + status.phase.categoryClassifying
├── Models/
│   └── Tag.swift                                ← `categoryRaw: String?` attribute 追加
├── Services/
│   ├── AutoCategoryClassifier.swift             ← 新規 (protocol + Foundation / InMemory 2 実装)
│   ├── AutoCategoryBackfillRunner.swift         ← 新規 (spec 013 同パターン)
│   ├── BackfillFlagStore.swift                  ← 改修 (auto_category_backfill_v1_done キー追加)
│   ├── CategorySeed.swift                       ← 新規 (10 個のシードカテゴリー)
│   ├── ProcessingMonitor.swift                  ← 改修 (`.categoryClassifying = 4` 追加)
│   ├── TagStore.swift                           ← 改修 (addTag 内で classifier 呼び出し)
│   └── ...
├── SharedSchema.swift                           ← schema バージョン bump
├── Views/
│   ├── AIBrainView.swift                        ← 完全書き換え (3 セクション)
│   ├── AIBrainStatsRow.swift                    ← 新規
│   ├── AIInsightCard.swift                      ← 新規
│   ├── KnowledgeCategoryRow.swift               ← 新規
│   ├── BottomStatusBar.swift                    ← 改修 (phase tint 統一 + categoryClassifying ケース追加)
│   ├── ArticleRow.swift                         ← 改修 (token 名 aiBrandEnd → actionBlue)
│   ├── PowerGaugeCard.swift                     ← コード残存、AIBrainView から参照外し
│   ├── KnowledgeMapView.swift                   ← 同上
│   └── RecentActivityCards.swift                ← 同上
└── KnowledgeTreeApp.swift                       ← bootstrap 末尾に AutoCategoryBackfillRunner.run() 追加

KnowledgeTreeTests/
├── AutoCategoryClassifierTests.swift            ← 新規 (5 ケース)
├── AutoCategoryBackfillRunnerTests.swift        ← 新規 (7 ケース)
└── 既存テストは無傷で pass する想定

KnowledgeTreeUITests/
└── AIBrainTabUITests.swift                      ← 改修 (v2 layout 用 identifier に書き換え)
```

**Structure Decision**: iOS native app の単一ターゲット。新規 6 ファイル + 改修 9 ファイル (Localizable / SharedSchema / Tag / DesignSystem + 5 view/service)。schema migration 1 個 (Tag.categoryRaw 追加)。データ層への影響は **最小限の追加のみ**。

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| 廃止 view の token alias 残し | PowerGauge / KnowledgeMap / RecentActivityCards のコードは残存させる方針 (FR-039)。それらが旧 token (`aiBrandStart` 等) を参照しているので、削除すると compile error | 案 A: 旧 token 参照を view 側で hardcoded Color literal に置換 → 廃止 view を触る必要があり、本 spec のスコープに反する。alias の方が view 無改修で済む |
| `AutoCategoryClassifier` + `CategorySeed` の 2 抽象化 | classifier は Foundation Models / InMemory 差し替え可能 (test 容易化)。CategorySeed は 10 個の固定リストを type-safe に管理 | 全部 enum に集約 → enum case の追加に compile が連鎖する、struct + static let の方が拡張性高い |

両 violation とも spec.md の MVP 範囲とアーキテクチャ原則 (Principle II / VI) で正当化される。

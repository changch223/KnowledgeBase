# Implementation Plan: UI リブランディング + AI ブレインタブ追加

**Branch**: `011-ai-brain-tab` | **Date**: 2026-05-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/011-ai-brain-tab/spec.md`

## Summary

「KnowledgeTree」を **「知積」** にリブランディングし、現状のシングル画面構成を **2 タブ (ライブラリ 📚 / AI ブレイン 🧠)** に再構成する。AI ブレインタブで蓄積知識を **PowerGauge / KnowledgeMap / RecentActivityCards** の 3 セクションで可視化し、「自分の AI が育っている」体感を提供する。既存スキーマ無改修・新 service ゼロ・新 migration ゼロで実現する純 UI 拡張。Constitution Principle V (calm UX) を強く遵守し、レベル / バッジ / ストリーク等の不安喚起 UI は導入しない。

## Technical Context

**Language/Version**: Swift 6 (Swift 6 mode、main app `@MainActor` isolation)
**Primary Dependencies**: SwiftUI 6 (TabView / NavigationStack / Canvas / TimelineView / GeometryReader / MagnificationGesture / DragGesture)、SwiftData (`@Query`、既存 `@Model`)、Foundation (Date 算術)
**Storage**: SwiftData (既存 `Article` / `Tag` / `KnowledgeEntity` / `KeyFact` / `ExtractedKnowledge` のみ。新 @Model なし、migration なし)
**Testing**: XCTest (`KnowledgeTreeTests`) で `KnowledgeMapBuilder` 純粋関数の単体テスト、`KnowledgeTreeUITests` でタブ切替 + ノードタップ → 遷移の UI テスト。in-memory ModelContainer 使用
**Target Platform**: iOS 26+ / iPadOS 26+ (Constitution: Apple Intelligence 対応端末)
**Project Type**: iOS native app (mobile)
**Performance Goals**: AIBrainView 起動 ≤1 秒 (空状態) / PowerGauge カウントアップ 0.6 秒 / KnowledgeMap force-directed 反復 ≤200ms (100 タグ) / Canvas 描画 60fps / ノードタップ → TagFilteredListView 遷移 ≤0.5 秒 / 新記事 knowledge 抽出後 PowerGauge 更新 ≤1 秒
**Constraints**: オフライン動作必須 (Constitution Principle II)、メイン処理は `@MainActor`、依存追加なし (Canvas + GeometryReader は SwiftUI 標準)、calm UX (レベル / バッジ / ストリーク / ランキング / 解放ポップアップ ゼロ)
**Scale/Scope**: 想定タグ数 100+、エッジ数 200+ (force-directed 反復 5-10 回で安定化)、AIBrainView の 3 セクション、新規 4 view + 1 純粋関数

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Reference: `.specify/memory/constitution.md` (v1.0.0).

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — KnowledgeMap / PowerGauge / RecentActivity のすべてのデータは既存 SwiftData (App Group container) からの読み取り。外部送信ゼロ。本 spec で新規ネットワーク送信なし。
- [x] **II. MVP ファースト開発** — MVP は spec 011 単体。レベル数字 / バッジ / ストリーク / ランキング / Safari 自動取り込みは将来 spec として spec.md に明示。エッジ重みづけ・force-directed 高度化も将来扱い。
- [x] **III. ソースに基づいた知識生成** — AI 生成物は本 spec で新規生成しない (spec 004 / 006 / 010 の生成済データを **読み取り専用** で表示するのみ)。各 KnowledgeEntity / KeyFact は既存 `extractedKnowledge.article` 経由で元 URL に追跡可能、UI 表示時もこの参照を保持。
- [x] **IV. iOS の実現可能性を重視する** — iOS 26+ / iPadOS 26+ のみ。Apple Intelligence 対応端末前提 (新規 AI 呼び出しなし、Apple Intelligence 未有効端末でも UI は動作)。Share Sheet / Shortcuts / Safari Extension のスコープには触れない。
- [x] **V. シンプルで落ち着いた UX** — calm UX を最優先。FR-043〜048 でレベル / バッジ / ストリーク / ランキング / 解放ポップアップを **明示的に禁止**。PowerGauge は累計増加のみ、新ノードは静かなフェードイン、パルスアニメーションは scale 1.0↔1.02 / 周期 2 秒で過剰演出ゼロ。
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — 4 view (`AIBrainView` / `PowerGaugeCard` / `KnowledgeMapView` / `RecentActivityCards`) と 1 純粋関数モジュール (`KnowledgeMapBuilder`) に分離。グラフ計算 (force-directed) は View から独立した純粋関数で単体テスト可能。Service / Store 層は無改修。
- [x] **日本語ファースト** — UI 文言はすべて `Localizable.xcstrings` 経由 (例: 「AI ブレイン」「○件 新たに吸収」「最近育ったテーマ」)。例外は PowerGauge の `"Your AI is growing"` (固定英文、ブランド演出として spec.md に根拠あり)。

### Quality Gates (二次ゲート)

- [x] **コード品質** — Swift API Design Guidelines。`fatalError` / `try!` 新規禁止。新規抽象化は `KnowledgeMapBuilder` (純粋関数) のみで `MapNode` / `MapEdge` という transient 型を 1 箇所で利用 → 抽象化価値は force-directed のテスト容易性で正当化 (plan.md に根拠記載)。
- [x] **テスト** — `KnowledgeMapBuilder` の単体テスト: 0 タグ / 1 タグ / 2 タグ + 共通 entity / 100 タグ / 同一座標分散 / 反復で位置安定。`KnowledgeTreeUITests` でタブ切替 + ノードタップ → TagFilteredListView 遷移を accessibilityIdentifier で検証。in-memory ModelContainer 使用。決定論性のため force-directed テストは固定 seed 引数を受ける版を使用。
- [x] **アクセシビリティ・UX 一貫性** — 全インタラクティブ要素に `accessibilityIdentifier` (例: `tab.library` / `tab.aibrain` / `aibrain.power_gauge` / `aibrain.map.node.{name}` / `aibrain.recent.card.{index}`)。Dynamic Type / Dark Mode / VoiceOver 対応。VoiceOver ノードは「タグ {name}、{N} 記事」と読み上げる。SF Symbols (`books.vertical` / `brain`) のみ使用、カスタムコントロールなし。文字列は Localizable.xcstrings 経由 (`Your AI is growing` のみ生英文として spec.md に根拠記載)。
- [x] **パフォーマンス** — AIBrainView の `@Query<Article>` / `@Query<KnowledgeEntity>` / `@Query<KeyFact>` / `@Query<Tag>` は predicate なしの全件取得 (count / filter のみ) だが、既存スキーマで 1000 件 × 4 query が想定上限のため許容。100 タグ + 200 エッジで Instruments 60fps 計測を実機検証で添付。force-directed の `O(N^2)` 反発計算は N=200 程度なら 200ms 以内 (純粋関数のため計測しやすい)。

### 結果

✅ 全ゲート通過。Complexity Tracking なし。

## Project Structure

### Documentation (this feature)

```text
specs/011-ai-brain-tab/
├── plan.md              # This file
├── research.md          # Phase 0
├── data-model.md        # Phase 1 (transient types のみ)
├── quickstart.md        # Phase 1 (実機検証手順)
├── contracts/           # Phase 1
│   ├── ai-brain-view.md
│   ├── knowledge-map-builder.md
│   ├── power-gauge-card.md
│   └── recent-activity-cards.md
└── tasks.md             # Phase 2 (/speckit-tasks 出力 — 本 plan では生成しない)
```

### Source Code (repository root)

```text
KnowledgeTree/
├── KnowledgeTreeApp.swift                           ← TabView 化 (改修)
├── Views/
│   ├── ArticleListView.swift                        ← 改修なし
│   ├── ArticleDetailView.swift                      ← 改修なし
│   ├── TagListView.swift                            ← 改修なし
│   ├── TagFilteredListView.swift                    ← 改修なし (本 spec の遷移先として再利用)
│   ├── EntityFilteredListView.swift                 ← 改修なし
│   ├── BottomStatusBar.swift                        ← 改修なし (TabView overlay として再利用)
│   ├── AIBrainView.swift                            ← 新規
│   ├── PowerGaugeCard.swift                         ← 新規
│   ├── KnowledgeMapView.swift                       ← 新規
│   └── RecentActivityCards.swift                    ← 新規
├── Services/
│   ├── KnowledgeMapBuilder.swift                    ← 新規 (純粋関数 + transient types)
│   ├── RefreshTrigger.swift                         ← 改修なし (既存環境注入を再利用)
│   ├── ProcessingMonitor.swift                      ← 改修なし
│   └── ServiceContainer.swift                       ← 改修なし
├── Models/                                          ← 改修なし (新 @Model ゼロ)
├── SharedSchema.swift                               ← 改修なし
└── Localization/
    └── Localizable.xcstrings                        ← AI ブレイン関連文言追加 (改修)

KnowledgeTreeTests/
└── KnowledgeMapBuilderTests.swift                   ← 新規 (純粋関数の単体テスト)

KnowledgeTreeUITests/
└── AIBrainTabUITests.swift                          ← 新規 (タブ切替 + ノードタップ遷移)

KnowledgeTree.xcodeproj/                             ← INFOPLIST_KEY_CFBundleDisplayName = 知積 (build setting 改修)
```

**Structure Decision**: iOS native app の単一ターゲット構成 (mobile / Option 3 から ios/ ディレクトリ部分のみ)。本 spec は **View 層 + 純粋関数モジュール 1 つ + xcodeproj build setting 1 行 + Localizable.xcstrings 追加** で完結。Service / Store / Model 層は完全無改修。spec 005 が確立した RefreshTrigger / NotificationCenter listen / scenePhase / Timer fallback は TabView root に 1 回配置することで両タブに伝播する。

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (なし) | — | — |

新規抽象化 `KnowledgeMapBuilder` は純粋関数モジュール (`buildGraph` / `step`) で、AIBrainView と KnowledgeMapBuilderTests の 2 箇所で利用するため、Constitution コード品質ゲートの「2 箇所以上の利用」を満たす。

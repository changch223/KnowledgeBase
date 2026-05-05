# Phase 1 Data Model: spec 014 (デザインシステム + Phase 3/4 視覚改善)

**Created**: 2026-05-05
**Status**: Retroactive

## 概要

本 spec は **新規 SwiftData @Model / 新 schema migration / transient model のいずれもゼロ**。

`enum DS` namespace に static let で定義された **デザイントークン** のみが新規追加される (永続化対象外、ビルド時定数)。

## Section A: DS Token Catalog

### A-1. `DS.Color` (16 種)

| トークン | 値 | 用途 |
|---|---|---|
| `surfacePrimary` | `Color(.systemBackground)` | View 背景の主色 (adaptive) |
| `surfaceSecondary` | `Color(.secondarySystemBackground)` | カード背景 (adaptive) |
| `overlaySubtle` | `Color.primary.opacity(0.06)` | 微細な区切り |
| `overlayLight` | `Color.primary.opacity(0.10)` | 軽い分離 |
| `overlayMedium` | `Color.primary.opacity(0.15)` | 中程度の分離 |
| `aiBrandStart` | `Color.accentColor.opacity(0.15)` | AI gradient 始点 |
| `aiBrandEnd` | `Color.purple.opacity(0.15)` | AI gradient 終点 |
| `aiBrandEdge` | `Color.secondary.opacity(0.25)` | KnowledgeMap エッジ |
| `aiBrandNodeFill` | `Color.accentColor.opacity(0.15)` | KnowledgeMap ノード fill |
| `aiBrandNodeStroke` | `Color.accentColor.opacity(0.55)` | KnowledgeMap ノード stroke |
| `phaseEnrichment` | `Color.secondary` | BottomStatusBar enrichment phase |
| `phaseBody` | `Color.blue` | body phase |
| `phaseKnowledge` | `Color.purple` | knowledge phase |
| `phaseTagging` | `Color.green` | tag backfill phase (spec 013) |
| `textEmphasis` | `Color.primary.opacity(0.85)` | 強調テキスト |

### A-2. `DS.Spacing` (9 段階)

| トークン | 値 (CGFloat) | 用途 |
|---|---:|---|
| `xxs` | 2 | 文字組内の最小余白 |
| `xs` | 4 | アイコンとラベル間 |
| `sm` | 6 | chip / 短い余白 |
| `md` | 8 | デフォルト余白 |
| `lg` | 10 | 中程度 |
| `xl` | 12 | カード内パディング |
| `xxl` | 16 | section 間 |
| `xxxl` | 20 | 大きいセクション |
| `section` | 24 | 最外余白 |

### A-3. `DS.Radius` (4 段階)

| トークン | 値 (CGFloat) | 用途 |
|---|---:|---|
| `thumb` | 8 | サムネイル / 小要素 |
| `chip` | 12 | EntityChip / TagChip |
| `card` | 16 | RecentActivityCards / 通常カード |
| `hero` | 20 | PowerGaugeCard 等 大型カード |

### A-4. `DS.Typography` (10 種 + 1 spacing)

| トークン | 値 | 用途 |
|---|---|---|
| `heroCounter` | `.title.bold()` | PowerGauge メイン数字 |
| `heroSubtitle` | `.subheadline` | PowerGauge サブテキスト |
| `heroBrand` | `.caption.italic()` | "Your AI is growing" |
| `sectionTitle` | `.title3.bold()` | Section ヘッダ |
| `rowTitle` | `.body` | ArticleRow タイトル |
| `aiLabel` | `.caption2` | AI 生成バッジ |
| `chipLabel` | `.caption` | Chip 内テキスト |
| `chipIcon` | `.caption2` | Chip 内アイコン |
| `mapNodeLabel` | `.caption.weight(.medium)` | KnowledgeMap ノードラベル |
| `bodyLineSpacing` | `8` (CGFloat) | 本文行間 |

### A-5. `DS.Animation` (7 種 + 1 関数)

| トークン | 値 | 用途 |
|---|---|---|
| `standard` | `.spring(response: 0.35, dampingFraction: 0.8)` | 汎用 |
| `counterAppear` | `.easeOut(duration: 0.55)` | 起動時 0 → 実数 カウントアップ |
| `counterUpdate` | `.easeOut(duration: 0.35)` | 実数更新時 (新記事保存後) |
| `pulseLoop` | `.easeInOut(duration: 2.0).repeatForever(autoreverses: true)` | パルス / ボブ |
| `nodeAppear` | `.spring(response: 0.4, dampingFraction: 0.75)` | KnowledgeMap 新ノード fade-in |
| `statusBar` | `.spring(response: 0.3, dampingFraction: 0.85)` | BottomStatusBar 出現 / 消失 |
| `interactive` | `.spring(response: 0.25, dampingFraction: 0.9)` | tap / drag フィードバック |
| `ifMotionAllowed(_:)` | 関数 | Reduce Motion ON で nil 返却 |

## Section B: ViewModifier (2 種)

### B-1. `dsCardBackground(radius:)`

```swift
func dsCardBackground(radius: CGFloat = DS.Radius.card) -> some View
```

- 用途: カード背景に `surfaceSecondary` の `RoundedRectangle` を fill
- 使用箇所: 18 view 中 5 箇所程度 (RecentActivityCards / 各 chip 系)

### B-2. `dsAIGradientBackground(radius:)`

```swift
func dsAIGradientBackground(radius: CGFloat = DS.Radius.hero) -> some View
```

- 用途: AI gradient (`aiBrandStart → aiBrandEnd`) を topLeading → bottomTrailing で `RoundedRectangle` に fill
- 使用箇所: PowerGaugeCard 等 AI ブレイン系

## Section C: 永続化なし宣言

本 spec で **新規 SwiftData @Model は追加しない**。`SharedSchema.all` の改修不要、migration 走らない。

`enum DS` の static let は **ビルド時定数** で、メモリ上に flyweight 1 個だけ存在。Color / Animation / Spacing 等は SwiftUI / Foundation の値型なので copy-on-modify。

## Section D: 既存 @Model / Service への影響

**ゼロ**。spec 001-013 のすべての @Model (Article / Tag / KnowledgeEntity / KeyFact / ExtractedKnowledge / ArticleEnrichment / ArticleBody / KnowledgeChunkProgress / BackgroundExtractionQueueEntry) は完全無改修。

すべての Service (ArticleSavingService / EnrichmentService / BodyExtractionService / KnowledgeExtractionService / TagStore / SuggestedTagFinder / TagNormalizer / AutoTagApplier / AutoTagBackfillRunner / BackfillFlagStore / BackgroundExtractionRunner / BackgroundExtractionScheduler / etc.) は完全無改修。

## Section E: 関係性ダイアグラム (本 spec の関連)

```
Constitution Principle V (calm UX)
        │
        ↓ guide
DS.Animation.ifMotionAllowed(_:) ─────→ UIAccessibility.isReduceMotionEnabled
        ↑                              ↑
        │ used by                       │ checked at runtime
        │
18 Views (PowerGaugeCard / KnowledgeMapView / EmptyStateView / ...)
        │
        │ apply
        ↓
DS.Color / Spacing / Radius / Typography / Animation
        │
        │ defined in
        ↓
KnowledgeTree/DesignSystem.swift (single source of truth)
        │
        │ no SwiftData dep
        ↓
Share Extension (KnowledgeTreeShareExtension/) — 将来再利用可能
```

`enum DS` は **single source of truth**。修正は `DesignSystem.swift` の 1 ファイルのみ、波及は build re-compile で 18 view 全部に伝播。

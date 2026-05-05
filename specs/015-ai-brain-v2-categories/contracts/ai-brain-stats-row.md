# Contract: AIBrainStatsRow

**File**: `KnowledgeTree/Views/AIBrainStatsRow.swift`

## 責務

AI ブレインタブ Section 1。3 列 (記事 / 知識 / ファクト) の統計を `.title2.bold` 数字 + `.caption` ラベルで表示。起動時 0 → 実数 0.5 秒カウントアップ (Reduce Motion 対応)。

## 構造

```swift
struct AIBrainStatsRow: View {
    @Query private var articles: [Article]
    @Query private var entities: [KnowledgeEntity]
    @Query private var keyFacts: [KeyFact]

    @State private var animatedArticleCount: Int = 0
    @State private var animatedEntityCount: Int = 0
    @State private var animatedFactCount: Int = 0

    private var entityCount: Int {
        Set(entities.map {
            $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }).count
    }

    var body: some View {
        HStack(spacing: 0) {
            statColumn(value: animatedArticleCount, label: "aibrain.stats.articles")
            Divider().frame(height: 32)
            statColumn(value: animatedEntityCount,  label: "aibrain.stats.entities")
            Divider().frame(height: 32)
            statColumn(value: animatedFactCount,    label: "aibrain.stats.facts")
        }
        .padding(.vertical, DS.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .dsCardBackground()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("aibrain.stats_row")
        .accessibilityLabel(
            Text("AI パワー: \(articles.count) 記事、\(entityCount) 知識、\(keyFacts.count) ファクト")
        )
        .onAppear {
            withAnimation(DS.Animation.ifMotionAllowed(DS.Animation.counterAppear)) {
                animatedArticleCount = articles.count
                animatedEntityCount  = entityCount
                animatedFactCount    = keyFacts.count
            }
        }
        .onChange(of: articles.count) { _, new in
            withAnimation(DS.Animation.ifMotionAllowed(DS.Animation.counterUpdate)) {
                animatedArticleCount = new
            }
        }
        // 同様に entityCount / keyFacts.count の onChange
    }

    @ViewBuilder
    private func statColumn(value: Int, label: LocalizedStringKey) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text("\(value)")
                .font(.title2.bold().monospacedDigit())
                .contentTransition(.numericText(countsDown: false))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
```

## アクセシビリティ

| Element | accessibilityIdentifier | VoiceOver Label |
|---|---|---|
| Card root | `aibrain.stats_row` | "AI パワー: N 記事、N 知識、N ファクト" (集約) |

## アニメーション

| トリガー | 効果 | 持続 |
|---|---|---|
| onAppear | 0 → 実数 (3 数字同時) | 0.5 秒 (`DS.Animation.counterAppear`) |
| 数字変化 (新記事保存等) | 旧 → 新 | 0.35 秒 (`DS.Animation.counterUpdate`) |

両方とも `DS.Animation.ifMotionAllowed(_:)` で Reduce Motion ガード。

## ローカライゼーション

- `aibrain.stats.articles` → "記事"
- `aibrain.stats.entities` → "知識"
- `aibrain.stats.facts` → "ファクト"
- "AI パワー: %lld 記事、%lld 知識、%lld ファクト" (VoiceOver、既存 spec 011 から流用可)

## 依存

- `Article`, `KnowledgeEntity`, `KeyFact` (`@Query`)
- `DS.Spacing` / `DS.Animation` / `dsCardBackground` (DesignSystem)

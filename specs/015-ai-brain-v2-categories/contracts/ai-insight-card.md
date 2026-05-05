# Contract: AIInsightCard

**File**: `KnowledgeTree/Views/AIInsightCard.swift`

## 責務

AI ブレインタブ Section 2。タグ 1 件以上ならトップ Category と記事数を表示、0 件なら「Safari から記事を保存しましょう」。タップ不可 (情報表示のみ)。

## 構造

```swift
struct AIInsightCard: View {
    let tags: [Tag]

    private var topCategoryEntry: (Category, Int)? {
        let grouped = Dictionary(grouping: tags) {
            CategorySeed.category(for: $0.categoryRaw)
        }
        let entries = grouped.map { (cat, tags) in
            let articleCount = Set(tags.flatMap { $0.articles.map(\.id) }).count
            return (cat, articleCount)
        }
        .filter { $0.1 > 0 }
        return entries.sorted { ($0.1, -$0.0.order) > ($1.1, -$1.0.order) }.first
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xl) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(DS.Color.actionBlue)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(headline)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                if let subtext = subtextLine {
                    Text(subtext)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(DS.Spacing.xxl)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.Color.actionBlue.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Color.actionBlue.opacity(0.20), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("aibrain.insight_card")
    }

    private var iconName: String {
        topCategoryEntry == nil ? "tray.and.arrow.down.fill" : "sparkles"
    }

    private var headline: String {
        if let entry = topCategoryEntry {
            return "最も読んでいる分野: \(entry.0.name)"
        } else {
            return "Safari から記事を保存しましょう"
        }
    }

    private var subtextLine: String? {
        if let entry = topCategoryEntry {
            return "\(entry.1) 記事"
        } else {
            return "Share Sheet で「知積」を選択"
        }
    }
}
```

## アクセシビリティ

| Element | accessibilityIdentifier | VoiceOver Label |
|---|---|---|
| Card root | `aibrain.insight_card` | (children combined) "最も読んでいる分野: テクノロジー、12 記事" |

## ローカライゼーション

- `aibrain.insight.empty.headline` → "Safari から記事を保存しましょう"
- `aibrain.insight.empty.subtext` → "Share Sheet で「知積」を選択"
- `aibrain.insight.top.headline %@` → "最も読んでいる分野: %@"
- `aibrain.insight.top.subtext %lld` → "%lld 記事"

## 入力契約

`tags: [Tag]` — `@Query<Tag>` から AIBrainView 経由で渡される。Tag 内の `categoryRaw` を読む。

## 副作用

なし。read-only computed property のみ。

## 依存

- `Tag`, `Category`, `CategorySeed`
- `DS.Color.actionBlue` / `DS.Spacing` / `DS.Radius` (DesignSystem)
- SF Symbol `tray.and.arrow.down.fill` / `sparkles`

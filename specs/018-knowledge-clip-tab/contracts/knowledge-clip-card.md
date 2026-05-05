# Contract: KnowledgeClipCard (1 カード = 1 KnowledgeDigest)

`KnowledgeTree/Views/KnowledgeClipCard.swift` (新規)。1 つの KnowledgeDigest を表示するカード view。

## 定義

```swift
struct KnowledgeClipCard: View {
    let digest: KnowledgeDigest

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            headerSection
            summarySection
            keyFactsSection
            entityChipsSection
        }
        .padding(DS.Spacing.xxl)
        .dsCardBackground()
        .accessibilityIdentifier("clip.card.\(digest.categoryRaw).\(digest.cardIndex)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(combinedAccessibilityLabel)
    }
}
```

## View Sections

### headerSection

```swift
HStack(alignment: .top, spacing: DS.Spacing.md) {
    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text(digest.categoryRaw)
            .font(DS.Typography.sectionTitle)
        HStack(spacing: DS.Spacing.sm) {
            Text("\(digest.sourceArticles.count) 記事から")
                .font(.caption)
            if let latestSavedAt = digest.sourceArticles.map(\.savedAt).max() {
                Text("·")
                    .font(.caption)
                Text(SavedAtFormatter.format(latestSavedAt))
                    .font(.caption)
            }
        }
        .foregroundStyle(.secondary)
    }
    Spacer()
    if digest.isStale {
        Text("clip.card.staleLabel")  // "更新あり"
            .font(.caption2)
            .foregroundStyle(DS.Color.actionBlue)
            .accessibilityIdentifier("clip.card.staleMark")
    }
    if let ogURL = digest.sourceArticles.compactMap(\.enrichment?.ogImageURL).first {
        ThumbnailView(urlString: ogURL)
            .frame(width: 48, height: 48)
    }
}
```

### summarySection

```swift
Text(digest.summary)
    .font(.body)
    .lineSpacing(DS.Typography.bodyLineSpacing)
    .foregroundStyle(.primary)
    .frame(maxWidth: .infinity, alignment: .leading)
```

### keyFactsSection (digest.topKeyFacts.count > 0 のとき)

```swift
if !digest.topKeyFacts.isEmpty {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
        ForEach(digest.topKeyFacts, id: \.self) { fact in
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Text("・")
                    .font(.body)
                    .foregroundStyle(DS.Color.actionBlue)
                Text(fact)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
```

### entityChipsSection (digest.topEntityNames.count > 0 のとき)

```swift
if !digest.topEntityNames.isEmpty {
    ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: DS.Spacing.sm) {
            ForEach(digest.topEntityNames, id: \.self) { name in
                Text(name)
                    .font(DS.Typography.chipLabel)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Color.tagFill, in: Capsule())
                    .foregroundStyle(.primary)
            }
        }
    }
}
```

## Accessibility

```swift
private var combinedAccessibilityLabel: String {
    var parts: [String] = []
    parts.append(digest.categoryRaw)
    parts.append("\(digest.sourceArticles.count) 記事")
    if digest.isStale {
        parts.append("更新あり")
    }
    parts.append(digest.summary)
    if !digest.topKeyFacts.isEmpty {
        parts.append("ポイント: " + digest.topKeyFacts.joined(separator: "、"))
    }
    return parts.joined(separator: ", ")
}
```

## Identifier 命名

- `clip.card.<categoryRaw>.<cardIndex>` (カード全体、ScrollView から特定可能)
- `clip.card.staleMark` (stale 表示時のみ存在)

## 表示要素まとめ

| 位置 | 要素 |
|---|---|
| Header 上 | Category 名 (sectionTitle) |
| Header 下 | 元記事数 + savedAt + stale マーク + 小 OG 画像 (右) |
| Body | 統合 summary (~150 字) |
| List | KeyFact 3 個 (・bullet) |
| Bottom | EntityChip 3 個 (横スクロール) |

## エラー処理

- `digest.summary` 空文字 → そのまま空 Text 表示 (Fallback で必ず生成されるはずなので発生稀)
- `digest.sourceArticles.isEmpty` → 元記事数 "0 記事から" 表示 (発生稀、service 側で空はスキップする)
- OG 画像 URL 取得失敗 → ThumbnailView がプレースホルダ表示 (既存挙動)

## 互換性

- spec 016 `SavedAtFormatter` 再利用
- spec 014 `ThumbnailView` 再利用
- spec 014 `dsCardBackground` modifier 再利用
- DS.Color.* 経由で spec 017 Dark Mode 自動対応

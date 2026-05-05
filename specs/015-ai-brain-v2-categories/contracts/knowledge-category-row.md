# Contract: KnowledgeCategoryRow

**File**: `KnowledgeTree/Views/KnowledgeCategoryRow.swift`

## 責務

AI ブレインタブ Section 3 の 1 行。Category 名 + プログレスバー + 記事数。タップで `TagFilteredListView` へ遷移。

## 構造

```swift
struct KnowledgeCategoryRow: View {
    let category: Category
    let articleCount: Int
    let maxCount: Int
    let topTagName: String  // Category 内最も記事多い Tag (タップ遷移先)

    private var ratio: Double {
        guard maxCount > 0 else { return 0 }
        return Double(articleCount) / Double(maxCount)
    }

    var body: some View {
        NavigationLink(value: TagFilteredDestination(tagName: topTagName)) {
            HStack(spacing: DS.Spacing.xl) {
                Text(category.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(width: 80, alignment: .leading)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(DS.Color.tagFill)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(DS.Color.actionBlue)
                            .frame(width: geo.size.width * ratio, height: 8)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 8)
                .frame(maxWidth: .infinity)

                Text("\(articleCount) 記事")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.vertical, DS.Spacing.xl)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("aibrain.category_row.\(category.englishName.lowercased())")
        .accessibilityLabel(Text("\(category.name)、\(articleCount) 記事"))
        .accessibilityHint(Text("タップで該当記事一覧へ遷移"))
    }
}
```

## アクセシビリティ

| Element | accessibilityIdentifier | VoiceOver Label |
|---|---|---|
| Row | `aibrain.category_row.{englishName_lowercased}` (例: `aibrain.category_row.technology`) | "テクノロジー、12 記事。タップで該当記事一覧へ遷移" |

## 入力契約

| パラメータ | 型 | 制約 |
|---|---|---|
| `category` | `Category` | `CategorySeed.allSeeds` のいずれか |
| `articleCount` | `Int` | `>= 1` (0 の Category は表示しない) |
| `maxCount` | `Int` | `>= articleCount` (Section 内最多 Category の count) |
| `topTagName` | `String` | Category 内で最も記事数が多い Tag 名 (タップ遷移先) |

## アルゴリズム (プログレスバー)

```
ratio = articleCount / maxCount      (max 1.0)
fillWidth = geo.size.width * ratio
```

最多 Category は `ratio = 1.0` で full width。

## ローカライゼーション

- `aibrain.category.row.count %lld` → "%lld 記事"
- `aibrain.category.row.voiceover %@ %lld` → "%@、%lld 記事"
- `aibrain.category.row.hint` → "タップで該当記事一覧へ遷移"

## 副作用

タップで `TagFilteredDestination(tagName: topTagName)` を NavigationStack に push。

## 依存

- `Category` / `CategorySeed`
- `TagFilteredDestination` (spec 008 既存)
- `DS.Color.actionBlue` / `DS.Color.tagFill` / `DS.Spacing`

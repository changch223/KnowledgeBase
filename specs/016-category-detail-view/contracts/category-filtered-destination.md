# Contract: CategoryFilteredDestination

NavigationStack の `.navigationDestination(for:)` 用 Hashable 型。AIBrainView の Category 行タップ → CategoryFilteredListView 遷移を type-safe に行う。

## 配置

`KnowledgeTree/Views/ArticleListView.swift` の末尾、既存 `TagFilteredDestination` の隣。

## 定義

```swift
struct CategoryFilteredDestination: Hashable {
    let category: Category
}
```

## 利用箇所

### AIBrainView

```swift
// KnowledgeCategoryRow を NavigationLink で wrap
NavigationLink(value: CategoryFilteredDestination(category: entry.category)) {
    KnowledgeCategoryRow(
        category: entry.category,
        articleCount: entry.articleCount,
        // topTagName 削除
    )
}
.buttonStyle(.plain)

// NavigationStack に destination 追加
.navigationDestination(for: CategoryFilteredDestination.self) { dest in
    CategoryFilteredListView(category: dest.category)
}
```

### CategoryFilteredListView

呼び出し側のみ。view 内では使用しない。

## Hashable 要件

- `Category` struct (CategorySeed.swift:14) が既に Hashable + Sendable
- `CategoryFilteredDestination` は単一フィールド `category` のみ → auto-synthesized で OK

## アクセシビリティ

destination 自体は表示要素ではないため、アクセシビリティ要件なし。遷移先 `CategoryFilteredListView` で対応。

## 互換性

- 既存 `TagFilteredDestination` / `EntityFilteredDestination` / `TagListDestination` と並列、衝突なし
- AIBrainView の既存 `.navigationDestination(for: TagFilteredDestination.self)` / `.navigationDestination(for: EntityFilteredDestination.self)` は保持

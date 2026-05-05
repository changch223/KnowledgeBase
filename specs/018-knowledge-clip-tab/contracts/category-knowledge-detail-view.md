# Contract: CategoryKnowledgeDetailView (Category 知識総まとめ詳細画面)

`KnowledgeTree/Views/CategoryKnowledgeDetailView.swift` (新規)。KnowledgeClipCard タップ時の遷移先、Category 内の知識を包括的に表示。

## 定義

```swift
struct CategoryKnowledgeDetailView: View {
    let category: Category

    @Query private var allDigests: [KnowledgeDigest]
    @Query private var allArticles: [Article]
    @Environment(ServiceContainer.self) private var services
    @State private var presentedArticle: Article?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                aggregatedSummarySection
                Divider()
                topKeyFactsSection
                Divider()
                topEntitiesSection
                Divider()
                articlesListSection
            }
            .padding(DS.Spacing.xxl)
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("clip.detail.\(category.name)")
        .sheet(item: $presentedArticle) { article in
            ArticleDetailView(article: article)
        }
        .refreshable {
            try? await services.digestService?.regenerate(for: category)
        }
    }
}
```

## Computed Properties

### digestsForCategory: [KnowledgeDigest]

```swift
var digestsForCategory: [KnowledgeDigest] {
    allDigests
        .filter { $0.categoryRaw == category.name }
        .sorted { $0.cardIndex < $1.cardIndex }
}
```

### articlesForCategory: [Article]

```swift
var articlesForCategory: [Article] {
    allArticles
        .filter { article in
            article.tags.contains { $0.categoryRaw == category.name }
        }
        .sorted { $0.savedAt > $1.savedAt }
}
```

### aggregatedSummary: String (案 A: 結合)

```swift
var aggregatedSummary: String {
    digestsForCategory.map(\.summary).joined(separator: "\n\n")
}
```

### topKeyFactsAggregated: [(String, Int)] (頻度順 top 10)

```swift
var topKeyFactsAggregated: [(String, Int)] {
    let allFacts = articlesForCategory
        .flatMap { $0.extractedKnowledge?.keyFacts ?? [] }
        .map(\.text)
    let counts = Dictionary(grouping: allFacts, by: { $0 }).mapValues(\.count)
    return counts.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
}
```

### topEntitiesAggregated: [(String, Int)] (頻度順 top 5)

```swift
var topEntitiesAggregated: [(String, Int)] {
    let allEntities = articlesForCategory
        .flatMap { $0.extractedKnowledge?.entities ?? [] }
        .map(\.name)
    let counts = Dictionary(grouping: allEntities, by: { $0 }).mapValues(\.count)
    return counts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
}
```

## View Sections

### aggregatedSummarySection

```swift
VStack(alignment: .leading, spacing: DS.Spacing.md) {
    Text("clip.detail.summary.title")  // "総まとめ"
        .font(DS.Typography.sectionTitle)
    Text(aggregatedSummary)
        .font(.body)
        .lineSpacing(DS.Typography.bodyLineSpacing)
}
```

### topKeyFactsSection

```swift
VStack(alignment: .leading, spacing: DS.Spacing.md) {
    Text("clip.detail.keyFacts.title")  // "重要ポイント"
        .font(DS.Typography.sectionTitle)
    ForEach(topKeyFactsAggregated, id: \.0) { fact, count in
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Text("・")
                .foregroundStyle(DS.Color.actionBlue)
            Text(fact)
                .frame(maxWidth: .infinity, alignment: .leading)
            if count > 1 {
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

### topEntitiesSection

```swift
VStack(alignment: .leading, spacing: DS.Spacing.md) {
    Text("clip.detail.entities.title")  // "関連する概念"
        .font(DS.Typography.sectionTitle)
    ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: DS.Spacing.sm) {
            ForEach(topEntitiesAggregated, id: \.0) { name, count in
                Text(name + (count > 1 ? " ×\(count)" : ""))
                    .font(DS.Typography.chipLabel)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Color.tagFill, in: Capsule())
            }
        }
    }
}
```

### articlesListSection

```swift
VStack(alignment: .leading, spacing: DS.Spacing.md) {
    Text("clip.detail.articles.title")  // "元記事"
        .font(DS.Typography.sectionTitle)
    ForEach(articlesForCategory, id: \.id) { article in
        Button {
            presentedArticle = article
        } label: {
            ArticleRow(article: article)
        }
        .buttonStyle(.plain)
        Divider().padding(.leading, DS.Spacing.xxl)
    }
}
```

## Identifier 命名

- `clip.detail.<categoryName>` (画面 root)
- `clip.detail.summary` (総まとめセクション)
- `clip.detail.keyFacts` (重要ポイントセクション)
- `clip.detail.entities` (関連概念セクション)
- `clip.detail.articles` (元記事セクション)

## Accessibility

- NavigationTitle = `category.name`
- 各セクションは accessibility 既存パターン (`accessibilityElement(children: .combine)` で集約)
- 元記事 ArticleRow は既存 accessibilityLabel を保持

## エラー処理

- `digestsForCategory.isEmpty` → 「ダイジェストなし」表示 (まだ集約されていない、稀)
- `articlesForCategory.isEmpty` → 元記事セクション非表示
- `topKeyFacts.isEmpty` → 重要ポイントセクション非表示

## 互換性

- spec 016 `ArticleRow` 再利用 (savedAt 時間軸表示込み)
- spec 015 `Category` / `CategorySeed` 再利用
- 既存 `ArticleDetailView` を sheet で表示 (spec 005)
- DS.Color.* 経由で spec 017 Dark Mode 自動対応

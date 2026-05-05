# Contract: KnowledgeClipView (3rd タブ root)

`KnowledgeTree/Views/KnowledgeClipView.swift` (新規)。「知識 Clip」タブの root view、Category 別ダイジェストカードを縦スクロール表示。

## 定義

```swift
struct KnowledgeClipView: View {
    @Query(sort: \KnowledgeDigest.cardIndex) private var allDigests: [KnowledgeDigest]
    @Environment(ServiceContainer.self) private var services
    @State private var period: TimeFilter = .all
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: DS.Spacing.xxl) {
                    timeFilterChips
                    digestsContent
                }
                .padding(DS.Spacing.xxl)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("clip.tab.title")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: CategoryDigestDetailDestination.self) { dest in
                CategoryKnowledgeDetailView(category: dest.category)
            }
            .refreshable {
                try? await services.digestService?.regenerateAllStale()
            }
            .accessibilityIdentifier("clip.scroll")
        }
        .accessibilityIdentifier("clip.root")
    }
}
```

## State

| State | 型 | 用途 |
|---|---|---|
| `allDigests` | `[KnowledgeDigest]` | `@Query` で SwiftData 監視 |
| `period` | `TimeFilter` | 期間フィルター (all / days7 / days30) |
| `path` | `NavigationPath` | NavigationStack push スタック |

## Computed Property

### `digestsByCategory: [(Category, [KnowledgeDigest])]`

```swift
private var digestsByCategory: [(Category, [KnowledgeDigest])] {
    let cutoff: Date? = period.cutoffDate
    let filtered = cutoff.map { date in
        allDigests.filter { digest in
            digest.sourceArticles.contains { $0.savedAt >= date }
        }
    } ?? allDigests

    let grouped = Dictionary(grouping: filtered) { $0.categoryRaw }
    return grouped
        .compactMap { (rawName, digests) -> (Category, [KnowledgeDigest])? in
            guard let category = CategorySeed.allSeeds.first(where: { $0.name == rawName })
                ?? Optional(CategorySeed.otherCategory) else { return nil }
            return (category, digests.sorted { $0.cardIndex < $1.cardIndex })
        }
        .sorted { lhs, rhs in
            // Category 内最新 savedAt desc
            let lhsLatest = lhs.1.flatMap(\.sourceArticles).map(\.savedAt).max() ?? .distantPast
            let rhsLatest = rhs.1.flatMap(\.sourceArticles).map(\.savedAt).max() ?? .distantPast
            return lhsLatest > rhsLatest
        }
}
```

## View Sections

### timeFilterChips

```swift
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: DS.Spacing.sm) {
        ForEach(TimeFilter.allCases, id: \.self) { filter in
            Button {
                withAnimation { period = filter }
            } label: {
                Text(filter.labelKey)
                    .font(DS.Typography.chipLabel)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(period == filter ? DS.Color.actionBlue : DS.Color.tagFill, in: Capsule())
                    .foregroundStyle(period == filter ? Color.white : .primary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("clip.filter.\(filter.rawValue)")
        }
    }
}
.accessibilityIdentifier("clip.timeFilter")
```

### digestsContent

```swift
if allDigests.isEmpty {
    // Empty state (記事 0 件 or 全 essence 抽出中)
    ContentUnavailableView(
        "clip.empty.title",
        systemImage: "lightbulb",
        description: Text("clip.empty.description")
    )
    .accessibilityIdentifier("clip.empty")
} else {
    ForEach(digestsByCategory, id: \.0) { category, digests in
        ForEach(digests, id: \.id) { digest in
            NavigationLink(value: CategoryDigestDetailDestination(category: category)) {
                KnowledgeClipCard(digest: digest)
            }
            .buttonStyle(.plain)
        }
    }
}
```

## Identifier 命名

- `clip.root` (root)
- `clip.scroll` (ScrollView 全体)
- `clip.timeFilter` (フィルター行)
- `clip.filter.<all|days7|days30>` (各チップ)
- `clip.empty` (Empty state)
- `clip.card.<categoryRaw>.<cardIndex>` (各カード、KnowledgeClipCard 側で設定)

## エラー処理

- `digestService?` が nil (bootstrap 未完了 or test 環境) → pull-to-refresh は no-op
- `@Query` 失敗時 → SwiftData が空配列を返す、ContentUnavailableView 表示
- AI 失敗時 → KnowledgeDigestService 内で Fallback、外部には影響なし

## 互換性

- 既存 `ServiceContainer` を再利用 (spec 005)
- 既存 `RefreshTrigger` は本 view では未使用 (`@Query` で十分、SwiftData 自動更新)
- 既存 TabView (Library + AI ブレイン) と並列、3rd タブとして配置

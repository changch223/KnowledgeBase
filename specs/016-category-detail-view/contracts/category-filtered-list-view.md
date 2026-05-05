# Contract: CategoryFilteredListView

新規 SwiftUI view (`KnowledgeTree/Views/CategoryFilteredListView.swift`)。Category 内全 Tag の Article union を、タグフィルターチップ (上位 5 + 「+N」展開) で OR 絞り込みできる詳細画面。

## 入力

```swift
let category: Category   // CategorySeed.allSeeds のいずれか
```

## 内部 State

```swift
@Query private var allTags: [Tag]
@State private var selectedTagNames: Set<String> = []
@State private var showsAllTags: Bool = false
```

## Computed Property 仕様

### `categoryTags: [Tag]`

- 入力: `allTags`, `category`
- 出力: Category 内の Tag を、`articles.count` 降順で sort した array
- フィルター条件: `CategorySeed.category(for: tag.categoryRaw).name == category.name`
- 安定 sort 不要 (記事数同数のタグは順序未保証で OK)

### `displayedTags: [Tag]`

- 入力: `categoryTags`, `showsAllTags`
- 出力:
  - `showsAllTags == true` → `categoryTags` 全件
  - `showsAllTags == false` → `categoryTags.prefix(5)` の Array

### `hiddenTagCount: Int`

- 入力: `categoryTags`
- 出力: `max(0, categoryTags.count - 5)`
- 用途: 「+%lld ▼」ボタンの数値

### `filteredArticles: [Article]`

- 入力: `categoryTags`, `selectedTagNames`
- 出力: 重複排除した Article 配列、`savedAt` 降順
- ロジック (R5):
  1. プール = `selectedTagNames` 空 → categoryTags、それ以外 → categoryTags の中で name が `selectedTagNames` に含まれるもの
  2. プール内 Tag の `articles` を順に走査、`Set<PersistentIdentifier>` で重複排除
  3. 結果を `savedAt > savedAt` でソート

## View 構造

```
NavigationView 配下:
  ScrollView (vertical):
    LazyVStack(spacing: DS.Spacing.section):
      [タグフィルター行]
        ScrollView(.horizontal):
          LazyHStack(spacing: DS.Spacing.sm):
            ForEach(displayedTags): TagFilterChip(...)
            if hiddenTagCount > 0:
              Button("+%lld ▼" or "閉じる ▲"): toggle showsAllTags
      [Article リスト]
        if filteredArticles.isEmpty:
          ContentUnavailableView("該当記事がありません", systemImage: "doc.text.magnifyingglass")
        else:
          ForEach(filteredArticles):
            NavigationLink + ArticleRow

.navigationTitle(category.name)
.navigationBarTitleDisplayMode(.large)
```

## TagFilterChip (private inline view)

```swift
struct TagFilterChip: View {
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(tag.name)
                Text("(\(tag.articles.count))")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white : .secondary)
            }
            .font(DS.Typography.tagChip)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                isSelected ? DS.Color.actionBlue : DS.Color.tagFill,
                in: Capsule()
            )
            .foregroundStyle(isSelected ? .white : DS.Color.ink)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tag.name)、\(tag.articles.count) 件\(isSelected ? "、選択中" : "")")
        .accessibilityIdentifier("category.detail.tagChip.\(tag.name)")
    }
}
```

## アクセシビリティ

- NavigationTitle: `category.name` (例: 「テクノロジー」)
- 各 chip: `accessibilityLabel("\(tag.name)、\(count) 件、選択中?")`
- 「+N ▼」: `accessibilityLabel("\(hiddenTagCount) 件のタグを展開")`
- ContentUnavailableView: 標準アクセシビリティ

## Identifier 命名 (UI test 用、本 spec では UI test なしだが将来用)

- `category.detail.list` (LazyVStack 全体)
- `category.detail.tagFilter` (タグフィルター行)
- `category.detail.tagChip.<tagName>` (各チップ)
- `category.detail.expandButton` (「+N ▼」)
- `category.detail.empty` (ContentUnavailableView)

## エラー処理

なし (純表示 view、副作用ゼロ)。

## テストケース (CategoryFilteredListViewTests)

| # | ケース | 検証内容 |
|---|---|---|
| 1 | `categoryTags` 並び順 | Tag.articles.count 降順 |
| 2 | `categoryTags` Category フィルター | 違う categoryRaw の Tag は除外 |
| 3 | `displayedTags` (showsAllTags=false, 6 個) | 上位 5 個のみ |
| 4 | `displayedTags` (showsAllTags=true, 6 個) | 6 個すべて |
| 5 | `filteredArticles` (selected=空) | Category 内全記事 (重複排除済み) |
| 6 | `filteredArticles` (selected=1 個) | その Tag の記事のみ |
| 7 | `filteredArticles` (selected=2 個 OR) | 2 Tag の和集合 |
| 8 | `filteredArticles` sort | savedAt desc 順 |

(8 ケース、テスト fixture は in-memory ModelContainer + Tag/Article)

# Contract: LibraryGroupedView + LibraryFilterPills

## Purpose

ライブラリタブを Apple Photos 風の日付別 grouping + 上部検索/フィルター pill に再構成。

## LibraryGroupedView 構造

```swift
struct LibraryGroupedView: View {
    @Query(sort: \Article.savedAt, order: .reverse)
    private var allArticles: [Article]
    @State private var searchText = ""
    @State private var selectedCategories: Set<String> = []
    @State private var selectedTags: Set<String> = []
    @State private var showAddArticle = false
    
    private var filteredArticles: [Article] {
        allArticles
            .filter { searchMatches($0, searchText) }
            .filter { categoryMatches($0, selectedCategories) }
            .filter { tagMatches($0, selectedTags) }
    }
    
    private var grouped: [(LibraryDateGroup, [Article])] {
        LibraryDateGrouper.group(filteredArticles)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                LibraryFilterPills(
                    selectedCategories: $selectedCategories,
                    selectedTags: $selectedTags
                )
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(grouped, id: \.0) { (group, articles) in
                            Section {
                                ForEach(articles) { article in
                                    ArticleRow(article: article)
                                        .swipeActions(...) { ... }
                                        .contextMenu { ... }
                                }
                            } header: {
                                Text(group.localizedTitle)
                                    .font(.headline)
                                    .padding(.leading)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("library.tab.title")
            .overlay(alignment: .bottomTrailing) {
                FABButton(icon: "plus") { showAddArticle = true }
            }
            .sheet(isPresented: $showAddArticle) {
                AddArticleSheet()
            }
        }
        .accessibilityIdentifier("tab.library")
    }
}
```

## LibraryFilterPills

```swift
struct LibraryFilterPills: View {
    @Binding var selectedCategories: Set<String>
    @Binding var selectedTags: Set<String>
    
    var body: some View {
        HStack {
            FilterPillMenu(
                title: "library.filter.categories",
                selectedItems: $selectedCategories,
                allItems: allCategoryNames
            )
            FilterPillMenu(
                title: "library.filter.tags",
                selectedItems: $selectedTags,
                allItems: allTagNames
            )
            Spacer()
        }
        .padding(.horizontal)
    }
}
```

## Search Behavior

`searchMatches(article, text)` の仕様:
- text empty → 全 match
- title / essence / KeyFact / entity 内 substring match (case-insensitive)
- 既存 SearchService (spec 044) 流用

## Filter Behavior

- categories: Article.categoryRaw が selectedCategories に含まれる
- tags: Article.tags のいずれかが selectedTags に含まれる
- 両 filter は AND (Category AND Tag)
- Empty selection = 全 match

## アクセシビリティ

- `tab.library` — タブ
- `library.filter.categories.pill`
- `library.filter.tags.pill`
- `library.dateGroup.{group}` — section header

## 旧 ArticleListView との関係

- `ArticleListView.swift` を `LibraryGroupedView.swift` に置き換え (or rename + 再構成)
- KnowledgeTreeApp の library tab assign を変更
- 既存 swipe + contextMenu (spec 022/030) は ArticleRow ベースで継続

## xcstrings 追加

- `library.tab.title` = "ライブラリ"
- `library.filter.categories` = "分野で絞る"
- `library.filter.tags` = "タグで絞る"

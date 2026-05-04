# Contract: 新規 Views (TagListView / TagFilteredListView / EntityFilteredListView / RelatedArticlesSection / TagInputField / TagChip)

**Files**:
- `KnowledgeTree/Views/TagListView.swift` (新規)
- `KnowledgeTree/Views/TagFilteredListView.swift` (新規)
- `KnowledgeTree/Views/EntityFilteredListView.swift` (新規)
- `KnowledgeTree/Views/RelatedArticlesSection.swift` (新規)
- `KnowledgeTree/Views/TagInputField.swift` (新規)
- `KnowledgeTree/Views/TagChip.swift` (新規)

## TagListView

### 責務
全 Tag を name 昇順 (or articleCount 降順) でリスト表示する画面。タグタップで該当記事一覧画面へ遷移。

### 構成

```swift
struct TagListView: View {
    @Query(sort: \Tag.name, order: .forward) private var tags: [Tag]
    @State private var selectedTagName: String?

    var body: some View {
        List(tags) { tag in
            NavigationLink(value: tag.name) {
                HStack {
                    Text(tag.name)
                    Spacer()
                    Text("\(tag.articles.count)")
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("tagListRow-\(tag.name)")
        }
        .navigationTitle("tag.list.title")    // "タグ一覧"
        .overlay {
            if tags.isEmpty {
                ContentUnavailableView(
                    "tag.list.empty.title",   // "まだタグがありません"
                    systemImage: "tag"
                )
            }
        }
        .navigationDestination(for: String.self) { tagName in
            TagFilteredListView(tagName: tagName)
        }
    }
}
```

### 不変条件
- tags が空なら ContentUnavailableView 表示
- ナビゲーション title は localized
- 各 row に articleCount (右側 secondary text)

---

## TagFilteredListView

### 責務
特定 Tag を持つ Article のみ表示する一覧画面。

### 構成

```swift
struct TagFilteredListView: View {
    let tagName: String

    var body: some View {
        TagFilteredListContent(tagName: tagName)
            .navigationTitle("tag.filtered.title \(tagName)")   // "tag: \(tagName)"
    }
}

private struct TagFilteredListContent: View {
    @Query private var articles: [Article]
    @State private var selectedArticle: Article?

    init(tagName: String) {
        _articles = Query(
            filter: #Predicate<Article> { article in
                article.tags.contains { $0.name == tagName }
            },
            sort: \Article.savedAt,
            order: .reverse
        )
    }

    var body: some View {
        List(articles) { article in
            Button {
                selectedArticle = article
            } label: {
                ArticleRow(article: article)
            }
            .buttonStyle(.plain)
        }
        .sheet(item: $selectedArticle) { article in
            ArticleDetailView(article: article)
        }
        .overlay {
            if articles.isEmpty {
                ContentUnavailableView(
                    "tag.filtered.empty.title",
                    systemImage: "tag.slash"
                )
            }
        }
    }
}
```

### 不変条件
- ArticleRow を流用 (検索ハイライトは無効、searchQuery 渡さない)
- saved 日時降順
- 該当記事 0 件なら ContentUnavailableView

---

## EntityFilteredListView

### 責務
特定 Entity name を含む Article のみ表示する一覧画面。

### 構成

```swift
struct EntityFilteredListView: View {
    let entityName: String

    var body: some View {
        EntityFilteredListContent(entityName: entityName)
            .navigationTitle("entity.filtered.title \(entityName)")
    }
}

private struct EntityFilteredListContent: View {
    @Query private var articles: [Article]
    @State private var selectedArticle: Article?

    init(entityName: String) {
        let normalized = entityName.lowercased()
        _articles = Query(
            filter: #Predicate<Article> { article in
                article.extractedKnowledge?.entities.contains { entity in
                    entity.name.lowercased() == normalized
                } ?? false
            },
            sort: \Article.savedAt,
            order: .reverse
        )
    }

    var body: some View {
        List(articles) { article in
            Button {
                selectedArticle = article
            } label: {
                ArticleRow(article: article)
            }
            .buttonStyle(.plain)
        }
        .sheet(item: $selectedArticle) { article in
            ArticleDetailView(article: article)
        }
    }
}
```

注意: SwiftData Predicate で `entity.name.lowercased() == normalized` が動かない場合は post-filter フォールバック。

---

## RelatedArticlesSection

### 責務
ArticleDetailView 内で表示する「関連記事」セクション。

### 構成

```swift
struct RelatedArticlesSection: View {
    let article: Article
    @Query private var allArticles: [Article]

    private var relatedArticles: [RelatedArticle] {
        RelatedArticleFinder.find(for: article, in: allArticles, limit: 5)
    }

    var body: some View {
        if !relatedArticles.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("detail.related.heading")
                    .font(.title3.bold())

                ForEach(relatedArticles) { related in
                    NavigationLink(value: related.article) {
                        RelatedArticleRow(related: related)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct RelatedArticleRow: View {
    let related: RelatedArticle

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(related.article.title)
                    .font(.body)
                    .lineLimit(2)
                if !related.commonEntities.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(related.commonEntities, id: \.self) { name in
                            Text(name)
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.tertiary, in: Capsule())
                        }
                    }
                }
            }
            Spacer()
            Text("\(related.commonEntityCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
```

### 不変条件
- relatedArticles が空ならセクション全体非表示
- 各 row はタップで `NavigationLink` 経由で Detail (sheet ではなく push? 既存 sheet パターンと整合させる必要あり)

実装時 Note: ArticleDetailView は sheet で表示されるので、その中の関連記事タップは sheet を変える必要がある。最もシンプルなのは `selectedArticle` を変更して既存の sheet を 上書き再表示する方法。

---

## TagInputField

### 責務
ArticleDetailView 内で raw タグ名を入力する小さなフィールド。

### 構成

```swift
struct TagInputField: View {
    let onAdd: (String) -> Void
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            TextField("tag.input.placeholder", text: $text)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .focused($focused)
                .onSubmit {
                    let raw = text
                    text = ""
                    onAdd(raw)
                    focused = true  // 連続入力可能
                }
            Button("tag.input.add") {
                let raw = text
                text = ""
                onAdd(raw)
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
```

### 不変条件
- onAdd には raw text (正規化前) を渡す。正規化は呼び出し側 TagStore.addTag に任せる
- submit / button タップ後に text をクリア

---

## TagChip

### 責務
ArticleDetailView 内で既存 / 提案タグを表示するチップ。

### 構成

```swift
struct TagChip: View {
    let name: String
    let onRemove: (() -> Void)?    // nil なら削除ボタン非表示 (提案チップ用)
    let isSuggested: Bool          // 提案チップは + アイコン

    var body: some View {
        HStack(spacing: 4) {
            if isSuggested {
                Image(systemName: "plus")
                    .font(.caption2)
            }
            Text(name)
                .font(.caption)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(isSuggested ? .quaternary : .tertiary, in: Capsule())
        .accessibilityIdentifier(isSuggested ? "tagChipSuggested-\(name)" : "tagChip-\(name)")
    }
}
```

### 不変条件
- onRemove == nil → 削除ボタン非表示 (提案チップ)
- isSuggested ? quaternary 背景 : tertiary 背景 (UI で区別)

---

## ArticleListView の変更点 (既存修正)

```swift
struct ArticleListView: View {
    @State private var searchQuery: String = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ArticleListContent(searchQuery: searchQuery)
                BottomStatusBar(...)   // 既存
            }
            .searchable(
                text: $searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "search.placeholder"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: TagListDestination()) {
                        Image(systemName: "tag")
                    }
                    .accessibilityIdentifier("tagListNavigationButton")
                }
            }
            .navigationDestination(for: TagListDestination.self) { _ in
                TagListView()
            }
        }
        // 既存環境 + 既存通知 listen
    }
}

private struct ArticleListContent: View {
    let searchQuery: String
    @Query private var articles: [Article]

    init(searchQuery: String) {
        self.searchQuery = searchQuery
        let predicate = SearchPredicate.make(query: searchQuery)
        _articles = Query(
            filter: predicate,
            sort: \Article.savedAt,
            order: .reverse
        )
    }

    var body: some View {
        // 既存 List + ForEach (但し ArticleRow に searchQuery 渡す)
    }
}

struct TagListDestination: Hashable {}
```

---

## ArticleDetailView の変更点 (既存修正)

```swift
struct ArticleDetailView: View {
    @Bindable var article: Article
    // 既存 + 新規:
    @Environment(TagStore.self) private var tagStore   // または ServiceContainer 経由
    @State private var tagInputVisible: Bool = false

    var body: some View {
        // ScrollView LazyVStack に追加:
        // headerSection (既存)
        // tagsSection (新規)            ← knowledge より前
        // knowledgeSection (既存)
        // relatedArticlesSection (新規) ← knowledge と body の間
        // bodySection (既存)
        // openOriginalButton (既存)
    }

    @ViewBuilder
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("detail.tags.heading")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if !article.tags.isEmpty {
                FlexibleHStack {
                    ForEach(article.tags) { tag in
                        TagChip(
                            name: tag.name,
                            onRemove: { try? tagStore.removeTag(normalizedName: tag.name, from: article) },
                            isSuggested: false
                        )
                    }
                }
            }
            // 自動提案セクション
            let existingNames = Set(article.tags.map(\.name))
            let suggestions = SuggestedTagFinder.find(for: article, existingTagNames: existingNames)
            if !suggestions.isEmpty {
                FlexibleHStack {
                    ForEach(suggestions) { suggestion in
                        Button {
                            try? tagStore.addTag(rawName: suggestion.displayName, to: article)
                        } label: {
                            TagChip(name: suggestion.displayName, onRemove: nil, isSuggested: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            // 入力フィールド
            TagInputField { rawText in
                try? tagStore.addTag(rawName: rawText, to: article)
            }
        }
    }
}
```

---

## ArticleRow の変更点 (既存修正)

```swift
struct ArticleRow: View {
    @Bindable var article: Article
    var refreshTick: Int = 0
    var searchQuery: String = ""    // 新規: 検索結果モード時のクエリ

    private var searchHighlight: SearchHighlight? {
        guard !searchQuery.isEmpty else { return nil }
        return SearchHighlighter.highlight(article: article, query: searchQuery)
    }

    var body: some View {
        // 既存 layout
        // search highlight が non-nil なら、行末に excerpt 追加表示
        if let highlight = searchHighlight {
            HStack {
                Text(highlight.fieldName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(highlight.excerpt)
                    .font(.caption)
                    .lineLimit(2)
            }
        }
    }
}
```

---

## navigation flow

```text
ArticleListView (root)
├── tagListNavigationButton tap
│   └── TagListView (push)
│       └── tag tap
│           └── TagFilteredListView (push)
│               └── article tap
│                   └── ArticleDetailView (sheet)
│                       └── tag chip tap
│                       └── related article tap (selectedArticle 経由で sheet 上書き)
│                       └── entity chip tap
│                           └── EntityFilteredListView (push)
│                               └── article tap
│                                   └── ArticleDetailView (sheet, 既存と同じ)
└── article tap
    └── ArticleDetailView (sheet)
```

NavigationStack 内に複数 destination が混在するので `navigationDestination(for:)` を root NavigationStack に集約する設計を採用。

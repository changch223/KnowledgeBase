//
//  CategoryFilteredListView.swift
//  KnowledgeTree
//
//  spec 016 — Category 詳細画面。
//
//  AI ブレインタブ Category 行タップ → 本 view へ遷移。
//  - 上部にタグフィルターチップ (Category 内 Tag を articles.count desc で sort、
//    上位 5 + 「+N ▼」展開)
//  - 下部に Category 内 Tag union 全記事 (savedAt desc、重複排除)、フィルター適用
//  - フィルター OR 条件 (1 つ以上選択 → そのいずれかを持つ記事)
//
//  spec 015 の B1 バグ (KnowledgeCategoryRow タップ先が単一 Tag だったため
//  数字 ≠ 表示数の不整合) を本 view で根本解決。
//

import SwiftUI
import SwiftData

struct CategoryFilteredListView: View {
    let category: Category

    @Query private var allTags: [Tag]
    @Environment(RefreshTrigger.self) private var refresh
    @State private var selectedTagNames: Set<String> = []
    @State private var showsAllTags: Bool = false
    @State private var presentedArticle: Article?
    @State private var refreshTick: Int = 0

    /// Category 内の Tag を articles.count desc で sort。
    var categoryTags: [Tag] {
        CategoryFilter.categoryTags(allTags, category: category)
    }

    /// 表示中のタグチップ (上位 5 個 or 全件)。
    var displayedTags: [Tag] {
        CategoryFilter.displayedTags(categoryTags, showsAll: showsAllTags)
    }

    /// 「+N ▼」ボタンに表示する隠れているタグ件数。
    var hiddenTagCount: Int {
        CategoryFilter.hiddenTagCount(categoryTags)
    }

    /// 選択中フィルター適用後の Article 一覧 (savedAt desc、重複排除)。
    var filteredArticles: [Article] {
        CategoryFilter.filteredArticles(categoryTags, selectedNames: selectedTagNames)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                tagFilterRow
                articleList
            }
            .padding(.vertical, DS.Spacing.xxl)
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("category.detail.root")
        .sheet(item: $presentedArticle) { article in
            ArticleDetailView(article: article)
        }
        .onChange(of: refresh.version) { _, _ in
            refreshTick &+= 1
        }
    }

    @ViewBuilder
    private var tagFilterRow: some View {
        if !categoryTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DS.Spacing.sm) {
                    ForEach(displayedTags, id: \.name) { tag in
                        TagFilterChip(
                            tag: tag,
                            isSelected: selectedTagNames.contains(tag.name),
                            onTap: { toggleSelection(tag.name) }
                        )
                    }
                    if hiddenTagCount > 0 {
                        Button {
                            withAnimation { showsAllTags.toggle() }
                        } label: {
                            Group {
                                if showsAllTags {
                                    Text("category.detail.tagFilter.collapse")
                                } else {
                                    Text("+\(hiddenTagCount) 件のタグ ▼")
                                }
                            }
                            .font(DS.Typography.chipLabel)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(DS.Color.tagFill, in: Capsule())
                            .foregroundStyle(DS.Color.actionBlue)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("category.detail.expandButton")
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)
            }
            .accessibilityIdentifier("category.detail.tagFilter")
        }
    }

    @ViewBuilder
    private var articleList: some View {
        if filteredArticles.isEmpty {
            ContentUnavailableView(
                "category.detail.empty.title",
                systemImage: "doc.text.magnifyingglass",
                description: Text("category.detail.empty.description")
            )
            .padding(.horizontal, DS.Spacing.xxl)
            .accessibilityIdentifier("category.detail.empty")
        } else {
            VStack(spacing: 0) {
                ForEach(filteredArticles, id: \.id) { article in
                    Button {
                        presentedArticle = article
                    } label: {
                        ArticleRow(article: article, refreshTick: refreshTick)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, DS.Spacing.xxl)
                }
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .accessibilityIdentifier("category.detail.list")
        }
    }

    private func toggleSelection(_ tagName: String) {
        withAnimation {
            if selectedTagNames.contains(tagName) {
                selectedTagNames.remove(tagName)
            } else {
                selectedTagNames.insert(tagName)
            }
        }
    }
}

/// CategoryFilteredListView の純関数ロジック (test 可能)。
enum CategoryFilter {
    /// Category 内の Tag を、categoryRaw match で抽出し articles.count desc で sort。
    static func categoryTags(_ allTags: [Tag], category: Category) -> [Tag] {
        allTags
            .filter { CategorySeed.category(for: $0.categoryRaw).name == category.name }
            .sorted { $0.articles.count > $1.articles.count }
    }

    /// 表示するタグチップ。showsAll = false なら上位 5 個まで。
    static func displayedTags(_ categoryTags: [Tag], showsAll: Bool) -> [Tag] {
        showsAll ? categoryTags : Array(categoryTags.prefix(5))
    }

    /// 隠れているタグ件数 (max(0, total - 5))。
    static func hiddenTagCount(_ categoryTags: [Tag]) -> Int {
        max(0, categoryTags.count - 5)
    }

    /// フィルター後の Article (savedAt desc、重複排除、選択 0 個なら全記事)。
    static func filteredArticles(_ categoryTags: [Tag], selectedNames: Set<String>) -> [Article] {
        let pool: [Tag] = selectedNames.isEmpty
            ? categoryTags
            : categoryTags.filter { selectedNames.contains($0.name) }
        var seen = Set<PersistentIdentifier>()
        var result: [Article] = []
        for tag in pool {
            for article in tag.articles where !seen.contains(article.persistentModelID) {
                seen.insert(article.persistentModelID)
                result.append(article)
            }
        }
        return result.sorted { $0.savedAt > $1.savedAt }
    }
}

/// タグフィルターチップ (選択 / 非選択 toggle)。
private struct TagFilterChip: View {
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.xxs) {
                Text(tag.name)
                Text("(\(tag.articles.count))")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
            }
            .font(DS.Typography.chipLabel)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                isSelected ? DS.Color.actionBlue : DS.Color.tagFill,
                in: Capsule()
            )
            .foregroundStyle(isSelected ? Color.white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(tag.name)、\(tag.articles.count) 件\(isSelected ? "、選択中" : "")"))
        .accessibilityIdentifier("category.detail.tagChip.\(tag.name)")
    }
}

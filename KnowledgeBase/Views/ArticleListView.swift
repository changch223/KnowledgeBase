//
//  ArticleListView.swift
//  KnowledgeTree
//
//  spec 001-005 / 008 — 一覧画面: 検索 / タグ一覧 / Detail sheet / BottomStatusBar /
//  live update 5 並列メカニズム
//

import SwiftUI
import SwiftData

struct ArticleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProcessingMonitor.self) private var monitor
    @Environment(RefreshTrigger.self) private var refresh
    @Environment(\.scenePhase) private var scenePhase
    @State private var searchQuery: String = ""
    @State private var selectedArticle: Article?
    @State private var refreshTick: Int = 0
    /// spec 056 Phase B: FAB tap で URL 入力 sheet
    @State private var showAddArticle: Bool = false
    /// 分野フィルター (複数選択 OR)
    @State private var selectedCategories: Set<String> = []
    /// タグフィルター (複数選択 OR)
    @State private var selectedTags: Set<String> = []

    // MARK: - 検索候補用データソース
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(filter: #Predicate<ConceptPage> { !$0.isHidden },
           sort: \ConceptPage.name) private var allConcepts: [ConceptPage]
    @State private var recentSearches: [String] = SearchSuggestionStore.shared.recent

    /// タグを記事数の多い順に最大5件
    private var topTags: [Tag] {
        allTags
            .sorted { ($0.articles?.count ?? 0) > ($1.articles?.count ?? 0) }
            .prefix(5)
            .map { $0 }
    }

    /// 概念ページを関連記事数の多い順に最大5件
    private var topConcepts: [ConceptPage] {
        allConcepts
            .filter { !($0.relatedArticles?.isEmpty ?? true) }
            .sorted { ($0.relatedArticles?.count ?? 0) > ($1.relatedArticles?.count ?? 0) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ArticleListContent(
                    searchQuery: searchQuery,
                    refreshTick: refreshTick,
                    selectedArticle: $selectedArticle,
                    monitorIsIdle: monitor.isIdle,
                    selectedCategories: $selectedCategories,
                    selectedTags: $selectedTags
                )
                .navigationTitle("list.title")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(DS.Color.washiBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        AvatarMenu()
                    }
                }
                .navigationDestination(for: TagListDestination.self) { _ in
                    TagListView()
                }
                .navigationDestination(for: TagFilteredDestination.self) { dest in
                    TagFilteredListView(tagName: dest.tagName)
                }
                .navigationDestination(for: EntityFilteredDestination.self) { dest in
                    EntityFilteredListView(entityName: dest.entityName)
                }
                .navigationDestination(for: ConceptPageDetailDestination.self) { dest in
                    ConceptPageDetailLoader(destinationID: dest.id)
                }
                .sheet(item: $selectedArticle) { article in
                    ArticleDetailView(article: article)
                }

                BottomStatusBar(monitor: monitor)
                    .animation(DS.Animation.statusBar, value: monitor.totalActiveCount)
                    .animation(DS.Animation.statusBar, value: monitor.current?.id)
            }
            // spec 056 Phase B: FAB (+ 追加) を右下に配置
            .overlay(alignment: .bottomTrailing) {
                FABButton(icon: "plus") {
                    showAddArticle = true
                }
                .accessibilityIdentifier("fab.addArticle.library")
            }
            .sheet(isPresented: $showAddArticle) {
                AddArticleSheet()
            }
            .searchable(
                text: $searchQuery,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: Text("search.placeholder")
            )
            .searchSuggestions {
                // クエリが空の時だけ候補を出す
                if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if !recentSearches.isEmpty {
                        Section(header: Text("search.suggestions.recent")) {
                            ForEach(recentSearches.prefix(5), id: \.self) { query in
                                Label(query, systemImage: "clock")
                                    .searchCompletion(query)
                            }
                        }
                    }
                    if !topTags.isEmpty {
                        Section(header: Text("search.suggestions.tags")) {
                            ForEach(topTags) { tag in
                                Label(tag.name, systemImage: "tag")
                                    .searchCompletion(tag.name)
                            }
                        }
                    }
                    if !topConcepts.isEmpty {
                        Section(header: Text("search.suggestions.concepts")) {
                            ForEach(topConcepts) { concept in
                                Label(concept.name, systemImage: "doc.text.fill")
                                    .searchCompletion(concept.name)
                            }
                        }
                    }
                }
            }
            // 検索実行 (Return キー or 候補選択) で最近の検索に記録
            .onSubmit(of: .search) {
                let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                if !q.isEmpty {
                    SearchSuggestionStore.shared.record(q)
                    recentSearches = SearchSuggestionStore.shared.recent
                }
            }
            // 検索クリア時に最近の検索リストを再読み込み
            .onChange(of: searchQuery) { _, new in
                if new.isEmpty {
                    recentSearches = SearchSuggestionStore.shared.recent
                }
            }
            .onChange(of: refresh.version) { _, _ in
                refreshTick &+= 1
            }
            .onReceive(
                NotificationCenter.default.publisher(for: ModelContext.didSave)
            ) { _ in
                refreshTick &+= 1
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("NSManagedObjectContextObjectsDidChange")
                )
            ) { _ in
                refreshTick &+= 1
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSNotification.Name("NSPersistentStoreRemoteChange")
                )
            ) { _ in
                refreshTick &+= 1
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    refreshTick &+= 1
                }
            }
        }
    }
}

/// inner View: searchQuery を init で受け取って動的 @Query を構築。
/// SwiftData の動的 Predicate 構築には inner View pattern が公式 recommended (research.md R4)。
private struct ArticleListContent: View {
    let searchQuery: String
    let refreshTick: Int
    @Binding var selectedArticle: Article?
    let monitorIsIdle: Bool
    @Binding var selectedCategories: Set<String>
    @Binding var selectedTags: Set<String>

    @Environment(\.modelContext) private var modelContext
    @Query private var articles: [Article]
    @Query(filter: #Predicate<ConceptPage> { !$0.isHidden },
           sort: \ConceptPage.updatedAt, order: .reverse) private var allConcepts: [ConceptPage]

    init(
        searchQuery: String,
        refreshTick: Int,
        selectedArticle: Binding<Article?>,
        monitorIsIdle: Bool,
        selectedCategories: Binding<Set<String>>,
        selectedTags: Binding<Set<String>>
    ) {
        self.searchQuery = searchQuery
        self.refreshTick = refreshTick
        self._selectedArticle = selectedArticle
        self.monitorIsIdle = monitorIsIdle
        self._selectedCategories = selectedCategories
        self._selectedTags = selectedTags
        _articles = Query(sort: \Article.savedAt, order: .reverse)
    }

    // MARK: - Filtered articles

    private var filteredArticles: [Article] {
        var base = articles
        if !selectedCategories.isEmpty {
            base = base.filter { article in
                (article.tags ?? []).contains { tag in
                    selectedCategories.contains(tag.categoryRaw ?? "")
                }
            }
        }
        if !selectedTags.isEmpty {
            base = base.filter { article in
                (article.tags ?? []).contains { tag in
                    selectedTags.contains(tag.name)
                }
            }
        }
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }
        return SearchService.search(query: q, in: base).map { $0.article }
    }

    /// 検索クエリが非空のとき Wiki ページを名前・要点・本文でフルテキスト検索 (上位 5 件)
    private var matchingConcepts: [ConceptPage] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return SearchService.searchConceptPages(query: q, in: allConcepts)
            .prefix(5)
            .map { $0.conceptPage }
    }

    private var hasActiveFilter: Bool {
        !selectedCategories.isEmpty || !selectedTags.isEmpty
    }

    // MARK: - Body

    var body: some View {
        let visible = filteredArticles
        return Group {
            if visible.isEmpty {
                // フィルター選択中は chip bar を上部に残す (フィルター解除できるように)
                if hasActiveFilter {
                    VStack(spacing: 0) {
                        FilterChipsBar(
                            selectedCategories: $selectedCategories,
                            selectedTags: $selectedTags
                        )
                        ContentUnavailableView(
                            "library.filter.empty.title",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text("library.filter.empty.description")
                        )
                    }
                } else if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    EmptyStateView()
                } else {
                    ContentUnavailableView(
                        "search.empty.title",
                        systemImage: "magnifyingglass"
                    )
                }
            } else {
                let grouped = LibraryDateGrouper.group(visible)
                List {
                    // フィルターチップを最初の行として配置 → リストと一緒にスクロールして隠れる
                    FilterChipsBar(
                        selectedCategories: $selectedCategories,
                        selectedTags: $selectedTags
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color(.systemBackground))

                    // Wiki ページ検索結果 (検索クエリが非空かつ hits あり)
                    if !matchingConcepts.isEmpty {
                        Section {
                            ForEach(matchingConcepts) { concept in
                                NavigationLink(value: ConceptPageDetailDestination(id: concept.id)) {
                                    ConceptSearchRow(concept: concept)
                                }
                            }
                        } header: {
                            Text("search.concepts.header")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(nil)
                        }
                    }

                    // 日付別グループ
                    ForEach(grouped, id: \.0) { (group, articlesInGroup) in
                        Section {
                            ForEach(articlesInGroup) { article in
                                Button {
                                    selectedArticle = article
                                } label: {
                                    ArticleRow(
                                        article: article,
                                        refreshTick: refreshTick,
                                        searchQuery: searchQuery
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("articleListRow")
                                .listRowSeparator(
                                    article.extractedKnowledge?.status == .succeeded ||
                                    article.extractedKnowledge?.status == .partiallySucceeded
                                        ? .hidden : .visible
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        delete(article)
                                    } label: {
                                        Label("list.deleteAction", systemImage: "trash")
                                    }
                                    .accessibilityIdentifier("articleDeleteAction")
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        delete(article)
                                    } label: {
                                        Label("list.deleteAction", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text(group.localizedTitle)
                                .accessibilityIdentifier("library.dateGroup.\(group.rawValue)")
                        }
                    }
                }
                .listStyle(.plain)
                .listSectionSpacing(.compact)
                .scrollContentBackground(.hidden)
                .background(DS.Color.washiBackground)
                .scrollDismissesKeyboard(.immediately)
                .safeAreaInset(edge: .bottom) {
                    if !monitorIsIdle {
                        Color.clear.frame(height: 60)
                    }
                }
            }
        }
    }

    private func delete(_ article: Article) {
        modelContext.delete(article)
        try? modelContext.save()
    }
}

// MARK: - FilterChipsBar
private struct FilterChipsBar: View {
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @Binding var selectedCategories: Set<String>
    @Binding var selectedTags: Set<String>

    private var hasSelections: Bool {
        !selectedCategories.isEmpty || !selectedTags.isEmpty
    }

    /// 分野チップ: categoryRaw 集計、記事数降順
    private var categoryChips: [(name: String, count: Int)] {
        var dict: [String: Int] = [:]
        for tag in allTags {
            guard let cat = tag.categoryRaw, !cat.isEmpty else { continue }
            dict[cat, default: 0] += (tag.articles?.count ?? 0)
        }
        return dict.map { ($0.key, $0.value) }.sorted { $0.count > $1.count }
    }

    /// タグチップ: 記事数降順 top 30
    private var tagChips: [(name: String, count: Int)] {
        allTags
            .filter { ($0.articles?.count ?? 0) > 0 }
            .sorted { ($0.articles?.count ?? 0) > ($1.articles?.count ?? 0) }
            .prefix(30)
            .map { ($0.name, $0.articles?.count ?? 0) }
    }

    var body: some View {
        if !categoryChips.isEmpty || !tagChips.isEmpty {
            // ZStack にすることで ScrollView が全幅を確保し、HStack 並列時の
            // クリップ境界による縦ラインが発生しない。✕ ボタンはオーバーレイ。
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    chipScrollRow(items: categoryChips, selected: $selectedCategories)
                    chipScrollRow(items: tagChips, selected: $selectedTags)
                }
                .padding(.vertical, DS.Spacing.xs)

                // 選択中のときだけ ✕ リセットを右端にオーバーレイ
                if hasSelections {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedCategories = []
                            selectedTags = []
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color(.tertiaryLabel))
                            .padding(DS.Spacing.xs)
                            .background(Color(.systemBackground))  // chip に被ったとき背景を揃える
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, DS.Spacing.sm)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .background(Color(.systemBackground))
        }
    }

    @ViewBuilder
    private func chipScrollRow(
        items: [(name: String, count: Int)],
        selected: Binding<Set<String>>
    ) -> some View {
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(items, id: \.name) { item in
                        let isSelected = selected.wrappedValue.contains(item.name)
                        Button {
                            if isSelected { selected.wrappedValue.remove(item.name) }
                            else          { selected.wrappedValue.insert(item.name) }
                        } label: {
                            HStack(spacing: 3) {
                                Text(item.name).font(.caption.weight(.medium))
                                Text("\(item.count)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(
                                        isSelected ? DS.Color.sumiInk.opacity(0.7) : Color(.tertiaryLabel)
                                    )
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(
                                isSelected ? DS.Color.sumiInk.opacity(0.15) : Color(.tertiarySystemFill),
                                in: Capsule()
                            )
                            .foregroundStyle(isSelected ? DS.Color.sumiInk : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, 3)
            }
        }
    }
}

// MARK: - ConceptSearchRow

/// Library 検索結果内の Wiki ページ行。名前 + 要点 or サマリー先頭1行。
private struct ConceptSearchRow: View {
    let concept: ConceptPage

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // 種別アイコン
            Image(systemName: concept.kind.symbolName)
                .font(.subheadline)
                .foregroundStyle(DS.Color.sumiInk)
                .frame(width: 28, height: 28)
                .background(DS.Color.sumiInk.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(concept.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                // 要点 or サマリーの冒頭をプレビュー
                let summaryPreview: String? = concept.summary.isEmpty ? nil : concept.summary
                if let preview = concept.crossSourceInsights.first ?? summaryPreview {
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("conceptSearchRow")
    }
}

// MARK: - Hashable destinations

/// NavigationLink 用 Hashable destination
struct TagListDestination: Hashable {}
struct TagFilteredDestination: Hashable { let tagName: String }
struct EntityFilteredDestination: Hashable { let entityName: String }
/// spec 016: AI ブレインタブの Category 行タップ → CategoryFilteredListView 遷移
struct CategoryFilteredDestination: Hashable { let category: Category }

#Preview("一覧") {
    let container = try! ModelContainer(
        for: Article.self, ArticleEnrichment.self, ArticleBody.self, Tag.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(Article(url: "https://example.com/a", title: "サンプル記事 A"))
    container.mainContext.insert(Article(url: "https://example.com/b", title: "サンプル記事 B"))
    return ArticleListView()
        .modelContainer(container)
        .environment(ProcessingMonitor())
        .environment(RefreshTrigger())
        .environment(ServiceContainer())
}

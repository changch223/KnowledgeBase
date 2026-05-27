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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ArticleListContent(
                    searchQuery: searchQuery,
                    refreshTick: refreshTick,
                    selectedArticle: $selectedArticle,
                    monitorIsIdle: monitor.isIdle
                )
                .navigationTitle("list.title")
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
                .navigationDestination(for: TagFilteredDestination.self) { dest in
                    TagFilteredListView(tagName: dest.tagName)
                }
                .navigationDestination(for: EntityFilteredDestination.self) { dest in
                    EntityFilteredListView(entityName: dest.entityName)
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
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("search.placeholder")
            )
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

    @Environment(\.modelContext) private var modelContext
    @Query private var articles: [Article]

    init(
        searchQuery: String,
        refreshTick: Int,
        selectedArticle: Binding<Article?>,
        monitorIsIdle: Bool
    ) {
        self.searchQuery = searchQuery
        self.refreshTick = refreshTick
        self._selectedArticle = selectedArticle
        self.monitorIsIdle = monitorIsIdle
        // 検索時は title contains の prefilter を SwiftData に投げる。
        // relationship target (enrichment / extractedKnowledge / tags) は body 内で post-filter。
        // 空クエリ時は全件 fetch (フィルター無し)。
        // ただし「relationship target 内マッチ」を担保するため、検索時も全件 fetch して
        // View 側で完全な matches() をかける (1000 記事規模で 200ms 以内想定)。
        _articles = Query(
            sort: \Article.savedAt,
            order: .reverse
        )
    }

    /// spec 044: 検索時は SearchService で score 降順、空クエリは savedAt desc。
    private var filteredArticles: [Article] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return articles }
        return SearchService.search(query: q, in: articles).map { $0.article }
    }

    var body: some View {
        let visible = filteredArticles
        return Group {
            if visible.isEmpty {
                if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    EmptyStateView()
                } else {
                    ContentUnavailableView(
                        "search.empty.title",
                        systemImage: "magnifyingglass"
                    )
                }
            } else {
                // spec 056 Phase B: 日付別 grouping (今日 / 昨日 / 今週 / 今月 / それ以前)
                let grouped = LibraryDateGrouper.group(visible)
                List {
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

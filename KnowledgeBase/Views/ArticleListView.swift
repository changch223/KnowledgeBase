//
//  ArticleListView.swift
//  KnowledgeTree
//
//  spec 001-005 / 008 — 一覧画面: タグ一覧 / Detail sheet / ProcessingInlineStatus /
//  live update 5 並列メカニズム
//  spec 104 — 検索は検索タブ (SearchTabView) に一本化。＋ は右上ツールバー、未開封フィルタ追加。
//

import SwiftUI
import SwiftData

struct ArticleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProcessingMonitor.self) private var monitor
    @Environment(RefreshTrigger.self) private var refresh
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedArticle: Article?
    @State private var refreshTick: Int = 0
    /// spec 104: 右上 ＋ tap で追加 sheet
    @State private var showAddArticle: Bool = false
    /// 分野フィルター (複数選択 OR)
    @State private var selectedCategories: Set<String> = []
    /// タグフィルター (複数選択 OR)
    @State private var selectedTags: Set<String> = []

    /// spec 104: 未開封のみ表示
    @State private var unopenedOnly: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // spec 103: 処理中は先頭に 1 行だけ表示 (旧 BottomStatusBar を廃止)
                ProcessingInlineStatus(monitor: monitor)
                    .animation(DS.Animation.statusBar, value: monitor.totalActiveCount)

                ArticleListContent(
                    refreshTick: refreshTick,
                    selectedArticle: $selectedArticle,
                    monitorIsIdle: monitor.isIdle,
                    selectedCategories: $selectedCategories,
                    selectedTags: $selectedTags,
                    unopenedOnly: $unopenedOnly
                )
                .navigationTitle("list.title")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(DS.Color.washiBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    // spec 104: ナレッジ・ライブラリ共通の右上 (＋ と設定)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAddArticle = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityIdentifier("toolbar.addArticle")
                        .accessibilityLabel(Text("addArticle.title"))
                    }
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
            }
            .sheet(isPresented: $showAddArticle) {
                AddArticleSheet()
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

/// inner View: 動的 @Query を構築 (SwiftData の動的 Predicate は inner View pattern)。
/// SwiftData の動的 Predicate 構築には inner View pattern が公式 recommended (research.md R4)。
private struct ArticleListContent: View {
    let refreshTick: Int
    @Binding var selectedArticle: Article?
    let monitorIsIdle: Bool
    @Binding var selectedCategories: Set<String>
    @Binding var selectedTags: Set<String>
    @Binding var unopenedOnly: Bool

    @Environment(\.modelContext) private var modelContext
    @Query private var articles: [Article]

    init(
        refreshTick: Int,
        selectedArticle: Binding<Article?>,
        monitorIsIdle: Bool,
        selectedCategories: Binding<Set<String>>,
        selectedTags: Binding<Set<String>>,
        unopenedOnly: Binding<Bool>
    ) {
        self.refreshTick = refreshTick
        self._selectedArticle = selectedArticle
        self.monitorIsIdle = monitorIsIdle
        self._selectedCategories = selectedCategories
        self._selectedTags = selectedTags
        self._unopenedOnly = unopenedOnly
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
        if unopenedOnly {
            base = base.filter { FeedBuilder.isUnopened($0) }
        }
        return base
    }

    private var hasActiveFilter: Bool {
        !selectedCategories.isEmpty || !selectedTags.isEmpty || unopenedOnly
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
                            selectedTags: $selectedTags,
                            unopenedOnly: $unopenedOnly
                        )
                        ContentUnavailableView(
                            "library.filter.empty.title",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text("library.filter.empty.description")
                        )
                    }
                } else {
                    EmptyStateView()
                }
            } else {
                let grouped = LibraryDateGrouper.group(visible)
                List {
                    // フィルターチップを最初の行として配置 → リストと一緒にスクロールして隠れる
                    FilterChipsBar(
                        selectedCategories: $selectedCategories,
                        selectedTags: $selectedTags,
                        unopenedOnly: $unopenedOnly
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color(.systemBackground))

                    // 日付別グループ
                    ForEach(grouped, id: \.0) { (group, articlesInGroup) in
                        Section {
                            ForEach(articlesInGroup) { article in
                                Button {
                                    selectedArticle = article
                                } label: {
                                    ArticleRow(
                                        article: article,
                                        refreshTick: refreshTick
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
    @Binding var unopenedOnly: Bool

    private var hasSelections: Bool {
        !selectedCategories.isEmpty || !selectedTags.isEmpty || unopenedOnly
    }

    /// spec 104: 最多分野が 7 割以上を占める等、絞り込みとして機能しないときは分野チップ行を隠す。
    private var visibleCategoryChips: [(name: String, count: Int)] {
        FeedBuilder.shouldShowCategoryChips(counts: categoryChips.map(\.count)) ? categoryChips : []
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
        Group {
            // ZStack にすることで ScrollView が全幅を確保し、HStack 並列時の
            // クリップ境界による縦ラインが発生しない。✕ ボタンはオーバーレイ。
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    unopenedRow
                    chipScrollRow(items: visibleCategoryChips, selected: $selectedCategories)
                    chipScrollRow(items: tagChips, selected: $selectedTags)
                }
                .padding(.vertical, DS.Spacing.xs)

                // 選択中のときだけ ✕ リセットを右端にオーバーレイ
                if hasSelections {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedCategories = []
                            selectedTags = []
                            unopenedOnly = false
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

    /// spec 104: 先頭の「未開封」トグルチップ (件数は出さない)。
    private var unopenedRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.xs) {
                Button {
                    unopenedOnly.toggle()
                } label: {
                    Text("library.filter.unopened")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(
                            unopenedOnly ? DS.Color.sumiInk.opacity(0.15) : Color(.tertiarySystemFill),
                            in: Capsule()
                        )
                        .foregroundStyle(unopenedOnly ? DS.Color.sumiInk : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("library.filter.unopened")
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, 3)
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

/// 検索タブの Wiki ページ (トピック) 行。名前 + 要点 or サマリー先頭1行。
struct ConceptSearchRow: View {
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

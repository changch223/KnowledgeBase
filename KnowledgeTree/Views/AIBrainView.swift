//
//  AIBrainView.swift
//  KnowledgeTree
//
//  spec 015 — AI ブレインタブ v2 / Category 階層対応。
//
//  縦スクロール 1 本のダッシュボード:
//  Section 1: AIBrainStatsRow (3 列統計)
//  Section 2: AIInsightCard (トップ Category 報告)
//  Section 3: Category List (CategorySeed でグループ化、記事数降順、プログレスバー付き)
//
//  各 Category 行をタップすると、その Category 内最多 Tag の記事一覧へ遷移。
//

import SwiftUI
import SwiftData

struct AIBrainView: View {
    @Environment(ProcessingMonitor.self) private var monitor

    @Query private var allTags: [Tag]

    @State private var path = NavigationPath()

    /// allTags を Category 別にグループ化、記事数降順で sort。
    /// 1 件以上の記事を持つ Category のみ。
    private var categoryEntries: [CategoryListEntry] {
        let grouped = Dictionary(grouping: allTags) {
            CategorySeed.category(for: $0.categoryRaw)
        }
        let entries: [CategoryListEntry] = grouped.compactMap { (category, tagsInCategory) in
            // Category 内の article 重複排除集計
            let articleIDs = Set(tagsInCategory.flatMap { ($0.articles ?? []).map(\.id) })
            let count = articleIDs.count
            guard count > 0 else { return nil }
            return CategoryListEntry(
                category: category,
                articleCount: count
            )
        }
        // 記事数 desc、同点は category.order asc
        return entries.sorted { lhs, rhs in
            if lhs.articleCount != rhs.articleCount {
                return lhs.articleCount > rhs.articleCount
            }
            return lhs.category.order < rhs.category.order
        }
    }

    private var maxCategoryCount: Int {
        categoryEntries.first?.articleCount ?? 1
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxl) {

                        AIBrainStatsRow()
                            .padding(.horizontal, DS.Spacing.xxl)

                        // spec 044 P3: 学習統計 (0 件で非表示、SC-010)
                        UnderstandingStatsSection()
                            .padding(.horizontal, DS.Spacing.xxl)

                        AIInsightCard(tags: allTags)
                            .padding(.horizontal, DS.Spacing.xxl)

                        Text("aibrain.categories.heading")
                            .font(DS.Typography.sectionTitle)
                            .padding(.horizontal, DS.Spacing.xxl)
                            .padding(.top, DS.Spacing.xs)

                        if categoryEntries.isEmpty {
                            ContentUnavailableView(
                                "aibrain.categories.empty.title",
                                systemImage: "square.grid.2x2",
                                description: Text("aibrain.categories.empty.body")
                            )
                            .padding(.horizontal, DS.Spacing.xxl)
                            .accessibilityIdentifier("aibrain.category_list.empty")
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(categoryEntries.enumerated()), id: \.element.category) { index, entry in
                                    NavigationLink(value: CategoryFilteredDestination(category: entry.category)) {
                                        KnowledgeCategoryRow(
                                            category: entry.category,
                                            articleCount: entry.articleCount,
                                            maxCount: maxCategoryCount,
                                            isLast: index == categoryEntries.count - 1
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .dsCardBackground(radius: DS.Radius.card)
                            .padding(.horizontal, DS.Spacing.xxl)
                            .accessibilityIdentifier("aibrain.category_list")
                        }
                    }
                    .padding(.vertical, DS.Spacing.xxl)
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("aibrain.scroll")
                .navigationTitle("aibrain.tab.title")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: TagFilteredDestination.self) { dest in
                    TagFilteredListView(tagName: dest.tagName)
                }
                .navigationDestination(for: EntityFilteredDestination.self) { dest in
                    EntityFilteredListView(entityName: dest.entityName)
                }
                .navigationDestination(for: CategoryFilteredDestination.self) { dest in
                    CategoryFilteredListView(category: dest.category)
                }
                .navigationDestination(for: SettingsDestination.self) { _ in
                    SettingsView()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(value: SettingsDestination()) {
                            Image(systemName: "gearshape")
                                .foregroundStyle(DS.Color.actionBlue)
                        }
                        .accessibilityIdentifier("settings.button")
                    }
                }

                BottomStatusBar(monitor: monitor)
                    .animation(DS.Animation.statusBar, value: monitor.totalActiveCount)
                    .animation(DS.Animation.statusBar, value: monitor.current?.id)
            }
        }
        .accessibilityIdentifier("aibrain.root")
    }
}

/// Category List 集計用の transient view-model。
private struct CategoryListEntry: Hashable, Sendable {
    let category: Category
    let articleCount: Int
}

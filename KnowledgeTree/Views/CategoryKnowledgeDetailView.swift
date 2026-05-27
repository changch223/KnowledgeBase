//
//  CategoryKnowledgeDetailView.swift
//  KnowledgeTree
//
//  spec 018 — 知識 Clip カードタップ時の遷移先。
//  Category 内の知識を包括的に表示 (総まとめ + Top KeyFact 10 + Top Entity 5 + 元記事一覧)。
//
//  contracts/category-knowledge-detail-view.md 準拠。
//  AI ブレインタブ Category タップ先 (CategoryFilteredListView) とは別画面 (Q19=B)。
//

import SwiftUI
import SwiftData

struct CategoryKnowledgeDetailView: View {
    let category: Category

    @Query private var allDigests: [KnowledgeDigest]
    @Query private var allArticles: [Article]
    @Environment(ServiceContainer.self) private var services
    @Environment(RefreshTrigger.self) private var refresh
    @Environment(\.modelContext) private var modelContext
    @State private var presentedArticle: Article?
    @State private var refreshTick: Int = 0
    /// spec 041: ナレッジグラフ表示 toggle (Settings から制御、default OFF)
    @AppStorage("settings.graphVisible") private var graphVisible: Bool = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                if graphVisible {
                    CategoryGraphView(categoryRaw: category.name)
                    Divider()
                }
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
        .navigationDestination(for: GraphNodeDetailDestination.self) { destination in
            GraphNodeDetailDestinationLoader(nodeID: destination.nodeID)
        }
        .refreshable {
            try? await services.digestService?.regenerate(for: category)
        }
        .onChange(of: refresh.version) { _, _ in
            refreshTick &+= 1
        }
    }

    // MARK: - Computed Properties

    private var digestsForCategory: [KnowledgeDigest] {
        allDigests
            .filter { $0.categoryRaw == category.name }
            .sorted { $0.cardIndex < $1.cardIndex }
    }

    private var articlesForCategory: [Article] {
        allArticles
            .filter { article in
                article.tags?.contains { $0.categoryRaw == category.name } ?? false
            }
            .sorted { $0.savedAt > $1.savedAt }
    }

    private var aggregatedSummary: String {
        digestsForCategory.map(\.summary).joined(separator: "\n\n")
    }

    private var topKeyFactsAggregated: [(String, Int)] {
        let allFacts = articlesForCategory
            .flatMap { $0.extractedKnowledge?.keyFacts ?? [] }
            .map(\.statement)
        let counts = Dictionary(grouping: allFacts, by: { $0 }).mapValues(\.count)
        return counts
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { ($0.key, $0.value) }
    }

    private var topEntitiesAggregated: [(String, Int)] {
        let allEntities = articlesForCategory
            .flatMap { $0.extractedKnowledge?.entities ?? [] }
            .map(\.name)
        let counts = Dictionary(grouping: allEntities, by: { $0 }).mapValues(\.count)
        return counts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { ($0.key, $0.value) }
    }

    // MARK: - Sections

    @ViewBuilder
    private var aggregatedSummarySection: some View {
        if !aggregatedSummary.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("clip.detail.summary.title")
                    .font(DS.Typography.sectionTitle)
                Text(aggregatedSummary)
                    .font(.body)
                    .lineSpacing(DS.Typography.bodyLineSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("clip.detail.summary")
        }
    }

    @ViewBuilder
    private var topKeyFactsSection: some View {
        let facts = topKeyFactsAggregated
        if !facts.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("clip.detail.keyFacts.title")
                    .font(DS.Typography.sectionTitle)
                ForEach(Array(facts.enumerated()), id: \.offset) { _, entry in
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Text("・")
                            .foregroundStyle(DS.Color.actionBlue)
                        Text(entry.0)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if entry.1 > 1 {
                            Text("\(entry.1)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .accessibilityIdentifier("clip.detail.keyFacts")
        }
    }

    @ViewBuilder
    private var topEntitiesSection: some View {
        let entities = topEntitiesAggregated
        if !entities.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("clip.detail.entities.title")
                    .font(DS.Typography.sectionTitle)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: DS.Spacing.sm) {
                        ForEach(Array(entities.enumerated()), id: \.offset) { _, entry in
                            Text(entry.1 > 1 ? "\(entry.0) ×\(entry.1)" : entry.0)
                                .font(DS.Typography.chipLabel)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(DS.Color.tagFill, in: Capsule())
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .accessibilityIdentifier("clip.detail.entities")
        }
    }

    @ViewBuilder
    private var articlesListSection: some View {
        if !articlesForCategory.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("clip.detail.articles.title")
                    .font(DS.Typography.sectionTitle)
                ForEach(articlesForCategory, id: \.id) { article in
                    Button {
                        presentedArticle = article
                    } label: {
                        ArticleRow(article: article, refreshTick: refreshTick)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            delete(article)
                        } label: {
                            Label("list.deleteAction", systemImage: "trash")
                        }
                    }
                    Divider()
                }
            }
            .accessibilityIdentifier("clip.detail.articles")
        }
    }

    private func delete(_ article: Article) {
        modelContext.delete(article)
        try? modelContext.save()
    }
}

//
//  ConceptPageDetailView.swift
//  KnowledgeTree
//
//  spec 042 — ConceptPage 詳細画面。
//  5 セクション (header / summary / crossSourceInsights / relatedArticles / relatedConcepts)
//  + toolbar (pin Toggle + 編集 ⋯)。
//

import SwiftUI
import SwiftData

struct ConceptPageDetailView: View {
    @Bindable var conceptPage: ConceptPage
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ServiceContainer.self) private var services
    @State private var showEditSheet: Bool = false
    /// 削除/merge で page が消えた瞬間に空配列になる reactive guard。
    /// body 冒頭で `liveMatches.isEmpty` を見て短絡することで、@Bindable conceptPage の
    /// プロパティ (crossSourceInsights / relatedArticles 等) を一切読まず crash 回避。
    @Query private var liveMatches: [ConceptPage]

    init(conceptPage: ConceptPage) {
        self.conceptPage = conceptPage
        let id = conceptPage.id
        _liveMatches = Query(filter: #Predicate<ConceptPage> { $0.id == id })
    }

    /// page がまだ DB に存在しているか (削除 / merge で消えた直後は false)。
    private var isAlive: Bool { !liveMatches.isEmpty }

    /// 「つながる人物・モノ」セクションで表示する他 ConceptPage を resolve。
    /// relatedConceptIDs 配列を fetch、最大 8 件まで。
    private func relatedConcepts() -> [ConceptPage] {
        guard !conceptPage.relatedConceptIDs.isEmpty else { return [] }
        let ids = Set(conceptPage.relatedConceptIDs)
        let descriptor = FetchDescriptor<ConceptPage>(
            predicate: #Predicate<ConceptPage> { ids.contains($0.id) },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        var bounded = descriptor
        bounded.fetchLimit = 8
        return (try? context.fetch(bounded)) ?? []
    }

    /// pin Toggle binding — store 経由で永続化。
    private var pinBinding: Binding<Bool> {
        Binding(
            get: { conceptPage.isFollowing },
            set: { newValue in
                if let store = services.conceptPageStore {
                    try? store.setFollowing(conceptPage, isFollowing: newValue)
                } else {
                    conceptPage.isFollowing = newValue
                }
            }
        )
    }

    var body: some View {
        // page が削除/merge で消えた瞬間に短絡 → conceptPage プロパティ参照を一切させない (crash 防止)
        // Loader 側の @Query auto-pop で navigation も pop されるので、ここは描画スキップだけで OK
        if !isAlive {
            Color.clear
                .onAppear { dismiss() }
        } else {
            aliveBody
        }
    }

    @ViewBuilder
    private var aliveBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.section) {
                headerSection
                summarySection
                crossSourceInsightsSection
                relatedArticlesSection
                // spec 043: この概念についての質問と答え (SavedAnswer セクション)
                SavedAnswerSection(conceptPageID: conceptPage.id)
                relatedConceptsSection
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.vertical, DS.Spacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(conceptPage.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle(isOn: pinBinding) {
                    Image(systemName: conceptPage.isFollowing ? "pin.fill" : "pin")
                }
                .toggleStyle(.button)
                .accessibilityIdentifier("conceptPageDetail_pinToggle")
                .accessibilityLabel(String(localized: "ConceptPage.editSheet.pin"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("conceptPageDetail_editButton")
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let store = services.conceptPageStore {
                ConceptPageEditSheet(
                    conceptPage: conceptPage,
                    store: store,
                    onSourceGone: {
                        // merge / delete で source page が消えた → sheet 閉じ
                        // (DetailView の short-circuit + Loader auto-pop で navigation 戻る)
                        showEditSheet = false
                    }
                )
            }
        }
        .accessibilityIdentifier("conceptPageDetail_root")
    }

    // MARK: - Sections

    private var categoryDisplay: String {
        CategorySeed.category(for: conceptPage.categoryRaw).name
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(conceptPage.name)
                .font(.largeTitle.bold())
                .lineLimit(2)

            HStack(spacing: DS.Spacing.md) {
                Text(categoryDisplay)
                    .font(.caption)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(DS.Color.tagFill, in: Capsule())
                Text(String(format: String(localized: "ConceptPage.card.relatedCount"), conceptPage.relatedArticles.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(SavedAtFormatter.format(conceptPage.updatedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("conceptPageDetail_header")
    }

    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("ConceptPage.detail.summary.title")
                .font(.title3.bold())
            if conceptPage.isSynthesisInProgress {
                HStack(spacing: DS.Spacing.md) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("ConceptPage.detail.synthesisInProgress")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(conceptPage.summary)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineSpacing(DS.Typography.bodyLineSpacing)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityIdentifier("conceptPageDetail_summarySection")
    }

    @ViewBuilder
    private var crossSourceInsightsSection: some View {
        if !conceptPage.crossSourceInsights.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("ConceptPage.detail.crossSourceInsights.title")
                    .font(.title3.bold())
                ForEach(Array(conceptPage.crossSourceInsights.enumerated()), id: \.offset) { _, insight in
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Text("•")
                            .font(.body)
                            .foregroundStyle(DS.Color.actionBlue)
                        Text(insight)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .accessibilityIdentifier("conceptPageDetail_crossSourceInsightsSection")
        }
    }

    @ViewBuilder
    private var relatedArticlesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(String(format: String(localized: "ConceptPage.detail.relatedArticles.title") + " (%lld)", conceptPage.relatedArticles.count))
                .font(.title3.bold())
            if conceptPage.relatedArticles.isEmpty {
                Text("ConceptPage.detail.emptyRelatedArticles")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(conceptPage.relatedArticles.sorted(by: { $0.savedAt > $1.savedAt }), id: \.id) { article in
                    NavigationLink(value: article) {
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(article.title)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text(SavedAtFormatter.format(article.savedAt))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, DS.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
        .accessibilityIdentifier("conceptPageDetail_relatedArticlesSection")
    }

    @ViewBuilder
    private var relatedConceptsSection: some View {
        let others = relatedConcepts()
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text(String(format: String(localized: "ConceptPage.detail.relatedConcepts.title") + " (%lld)", others.count))
                    .font(.title3.bold())
                FlowingTagsLayout(spacing: DS.Spacing.sm) {
                    ForEach(others, id: \.id) { other in
                        NavigationLink(value: ConceptPageDetailDestination(id: other.id)) {
                            Text(other.name)
                                .font(.caption)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(DS.Color.tagFill, in: Capsule())
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .accessibilityIdentifier("conceptPageDetail_relatedConceptsSection")
        }
    }
}

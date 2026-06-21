//
//  TagManagementView.swift
//  KnowledgeTree
//
//  spec 024 — タグ管理画面。
//  全 Tag を article 数降順で List 表示、tap で TagEditSheet。
//  検索 (TagNormalizer 不要、表示名そのまま contain match)。
//

import SwiftUI
import SwiftData

struct TagManagementView: View {
    /// spec 075: タグ / 分野 の 2 セグメント。
    private enum Segment: Hashable { case tags, categories }

    @Query private var allTags: [Tag]
    // spec 075: 分野 (動的カテゴリ) も同画面で管理。order 昇順。
    @Query(sort: \CategoryDefinition.order) private var allCategories: [CategoryDefinition]

    @State private var segment: Segment = .tags
    @State private var selectedTag: Tag?
    @State private var selectedCategory: CategoryDefinition?
    @State private var searchQuery: String = ""

    // spec 097 Phase 2b: 分野の手修正 = 学習ストアへの記録トリガ。
    @Environment(\.modelContext) private var modelContext
    @Environment(ServiceContainer.self) private var services
    @Environment(RefreshTrigger.self) private var refresh

    private var filteredTags: [Tag] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let candidates = allTags
        let matched = trimmed.isEmpty
            ? candidates
            : candidates.filter { $0.name.lowercased().contains(trimmed) }
        // article count desc、同数なら name asc
        return matched.sorted { lhs, rhs in
            if (lhs.articles ?? []).count != (rhs.articles ?? []).count {
                return (lhs.articles ?? []).count > (rhs.articles ?? []).count
            }
            return lhs.name < rhs.name
        }
    }

    private var filteredCategories: [CategoryDefinition] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty
            ? allCategories
            : allCategories.filter { $0.name.lowercased().contains(trimmed) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("manage.segment.label", selection: $segment) {
                Text("manage.segment.tags").tag(Segment.tags)
                Text("manage.segment.categories").tag(Segment.categories)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.vertical, DS.Spacing.md)
            .accessibilityIdentifier("manage.segment.picker")

            switch segment {
            case .tags: tagList
            case .categories: categoryList
            }
        }
        .navigationTitle("manage.title")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchQuery, prompt: Text("tag.management.searchPlaceholder"))
        .sheet(item: $selectedTag) { tag in
            TagEditSheet(tag: tag, onCompletion: { selectedTag = nil })
        }
        .sheet(item: $selectedCategory) { category in
            CategoryEditSheet(category: category, onCompletion: { selectedCategory = nil })
        }
        .accessibilityIdentifier("tag.management.root")
    }

    @ViewBuilder
    private var tagList: some View {
        if allTags.isEmpty {
            ContentUnavailableView("tag.management.empty", systemImage: "tag.slash")
        } else {
            List {
                Section {
                    ForEach(filteredTags) { tag in
                        Button { selectedTag = tag } label: { TagRow(tag: tag) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("tag.management.row")
                            .contextMenu {
                                Menu("tag.management.changeCategory") {
                                    ForEach(allCategories.filter { !$0.isHidden }) { cat in
                                        Button(cat.name) { changeCategory(tag, to: cat.name) }
                                    }
                                }
                            }
                    }
                } header: {
                    Text("tag.management.hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
    }

    /// spec 097 Phase 2b: タグの分野をユーザーが手修正 → 学習ストアに正解例として記録し、
    /// 概念のカテゴリも再ヒール。次回以降の分類で few-shot として効く (精度向上ループ)。
    private func changeCategory(_ tag: Tag, to newCategory: String) {
        let old = tag.categoryRaw
        guard newCategory != (old ?? "") else { return }
        let contextSnippet = (tag.articles ?? []).first.map {
            [$0.title, $0.extractedKnowledge?.essence ?? ""].joined(separator: " ")
        } ?? ""
        services.correctionStore?.record(
            tagName: tag.name,
            contextSnippet: contextSnippet,
            wrongCategory: old,
            correctCategory: newCategory
        )
        tag.categoryRaw = newCategory
        tag.categoryConfidence = ClassificationConfidence.high.rawValue  // ユーザー確認済み
        try? modelContext.save()
        ConceptSynthesisCommon.healConcepts(forTag: tag, context: modelContext, refreshTrigger: refresh)
    }

    @ViewBuilder
    private var categoryList: some View {
        if allCategories.isEmpty {
            ContentUnavailableView("category.management.empty", systemImage: "square.grid.2x2")
        } else {
            List {
                Section {
                    ForEach(filteredCategories) { category in
                        Button { selectedCategory = category } label: { CategoryRow(category: category) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("category.management.row")
                    }
                } header: {
                    Text("category.management.hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
    }
}

private struct TagRow: View {
    let tag: Tag

    /// spec 097 Phase 2b: 確信度が低い (Low/Medium) or その他 = 要確認。
    private var isUncertain: Bool {
        let conf = tag.categoryConfidence
        return conf == ClassificationConfidence.low.rawValue
            || conf == ClassificationConfidence.medium.rawValue
            || (tag.categoryRaw ?? "") == CategorySeed.otherCategory.name
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                if let category = tag.categoryRaw, !category.isEmpty {
                    HStack(spacing: 6) {
                        Text(category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        // spec 097 Phase 2b: 確信度が低い (Low/Medium) タグは「要確認」表示。
                        if isUncertain {
                            Text("tag.management.needsReview")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            Spacer()
            Text("tag.management.row.articleCount \((tag.articles ?? []).count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

/// spec 075: 分野 (CategoryDefinition) の行。非表示は淡色 + サフィックス表示。
private struct CategoryRow: View {
    let category: CategoryDefinition

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Text(category.name)
                .font(.body)
                .foregroundStyle(category.isHidden ? .secondary : .primary)
            if category.isHidden {
                Text("category.management.hidden.suffix")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

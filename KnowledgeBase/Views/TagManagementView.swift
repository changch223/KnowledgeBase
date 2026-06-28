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

    // 分類確認セクション用
    private var uncertainTags: [Tag] {
        allTags
            .filter { CategoryReviewView.isUncertain($0) }
            .sorted { lhs, rhs in
                let lc = (lhs.articles ?? []).count, rc = (rhs.articles ?? []).count
                if lc != rc { return lc > rc }
                return lhs.name < rhs.name
            }
    }

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
                // 分類の確認 — 一番上
                if !uncertainTags.isEmpty {
                    TagCategoryReviewSection(
                        uncertainTags: uncertainTags,
                        allCategories: allCategories
                    )
                }
                // タグ一覧
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
        CategoryCorrectionApplier.apply(
            tag: tag, to: newCategory,
            store: services.correctionStore, context: modelContext, refresh: refresh
        )
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

// MARK: - 分類の確認インラインセクション

/// 確信度 Medium → Low の順でタグを表示し、ユーザーが分野を確定。
/// 確定後は isUncertain が false になり行が消える。
/// 「一括確定」= checkbox モードで checkmark が付いたものを high confidence として保存。
private struct TagCategoryReviewSection: View {
    let uncertainTags: [Tag]
    let allCategories: [CategoryDefinition]

    @Environment(\.modelContext) private var modelContext
    @Environment(ServiceContainer.self) private var services
    @Environment(RefreshTrigger.self) private var refresh

    @State private var isBulkMode: Bool = false
    @State private var bulkChecked: Set<PersistentIdentifier> = []

    // 確信度：中 → カテゴリ別グループ (名前昇順)
    private var mediumByCategory: [(category: String, tags: [Tag])] {
        let med = uncertainTags.filter {
            $0.categoryConfidence == ClassificationConfidence.medium.rawValue
        }
        var dict: [String: [Tag]] = [:]
        for tag in med {
            dict[tag.categoryRaw ?? CategorySeed.otherCategory.name, default: []].append(tag)
        }
        return dict.map { ($0.key, $0.value) }.sorted { $0.category < $1.category }
    }

    // 確信度：低 (medium 以外で uncertain なもの全て)
    private var lowTags: [Tag] {
        uncertainTags.filter {
            $0.categoryConfidence != ClassificationConfidence.medium.rawValue
        }
    }

    var body: some View {
        Group {
            // ヘッダー行: タイトル + 一括ボタン
            Section {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundStyle(.orange)
                    Text("分類の確認")
                        .font(.subheadline.weight(.semibold))
                    Text("(\(uncertainTags.count)件)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isBulkMode {
                        Button("キャンセル") { cancelBulk() }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("一括確定") { enterBulkMode() }
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.actionBlue)
                    }
                }
                .padding(.vertical, 2)

                // 一括モード時の「確定する」ボタン
                if isBulkMode {
                    Button {
                        confirmBulk()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("チェックしたものを確定 (\(bulkChecked.count)件)")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .foregroundStyle(.white)
                    .listRowBackground(DS.Color.actionBlue)
                    .disabled(bulkChecked.isEmpty)
                }
            }

            // 確信度：中 (カテゴリ別グループ)
            ForEach(mediumByCategory, id: \.category) { group in
                Section {
                    ForEach(group.tags) { tag in reviewRow(tag) }
                } header: {
                    Text("確信度：中 — \(group.category)")
                        .font(.caption).textCase(nil).foregroundStyle(.secondary)
                }
            }

            // 確信度：低
            if !lowTags.isEmpty {
                Section {
                    ForEach(lowTags) { tag in reviewRow(tag) }
                } header: {
                    Text("確信度：低")
                        .font(.caption).textCase(nil).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func reviewRow(_ tag: Tag) -> some View {
        HStack(spacing: DS.Spacing.md) {
            // 一括モード: チェックボックス
            if isBulkMode {
                let checked = bulkChecked.contains(tag.persistentModelID)
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(checked ? DS.Color.actionBlue : Color(.tertiaryLabel))
                    .font(.title3)
                    .onTapGesture { toggleBulk(tag) }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name).font(.body)
                Text(tag.categoryRaw ?? CategorySeed.otherCategory.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\((tag.articles ?? []).count)件")
                .font(.caption2).foregroundStyle(.secondary)

            // 通常モード: 分野選択 Menu
            if !isBulkMode {
                Menu {
                    ForEach(allCategories.filter { !$0.isHidden }) { cat in
                        Button(cat.name) { apply(tag, to: cat.name) }
                    }
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .foregroundStyle(DS.Color.actionBlue)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { if isBulkMode { toggleBulk(tag) } }
    }

    private func toggleBulk(_ tag: Tag) {
        if bulkChecked.contains(tag.persistentModelID) {
            bulkChecked.remove(tag.persistentModelID)
        } else {
            bulkChecked.insert(tag.persistentModelID)
        }
    }

    private func enterBulkMode() {
        isBulkMode = true
        bulkChecked = []
    }

    private func cancelBulk() {
        isBulkMode = false
        bulkChecked = []
    }

    private func confirmBulk() {
        for tag in uncertainTags where bulkChecked.contains(tag.persistentModelID) {
            tag.categoryConfidence = ClassificationConfidence.high.rawValue
        }
        try? modelContext.save()
        refresh.bump()
        isBulkMode = false
        bulkChecked = []
    }

    private func apply(_ tag: Tag, to category: String) {
        CategoryCorrectionApplier.apply(
            tag: tag, to: category,
            store: services.correctionStore, context: modelContext, refresh: refresh
        )
    }
}

// MARK: - TagRow

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

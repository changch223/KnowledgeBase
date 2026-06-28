//
//  CategoryFilterSheet.swift
//  KnowledgeTree
//
//  ライブラリタブのカテゴリフィルター選択シート。
//  記事を保持するカテゴリを記事数バッジ付きで一覧し、複数選択（OR）できる。
//  選択中カテゴリは Binding で ArticleListView に渡すため @Model 変更ゼロ。
//

import SwiftUI
import SwiftData

struct CategoryFilterSheet: View {
    @Binding var selectedCategories: Set<String>
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Article.savedAt, order: .reverse) private var allArticles: [Article]
    @Query(sort: \Tag.name) private var allTags: [Tag]

    /// 記事を持つカテゴリを (name, symbolName, articleCount) で返す。
    /// CategorySeed の順序を優先し、動的カテゴリはアルファベット末尾に追加。
    private var categoryRows: [CategoryRow] {
        // tag.categoryRaw → 記事 ID set (重複排除)
        var articleIDsByCategory: [String: Set<PersistentIdentifier>] = [:]
        for article in allArticles {
            for tag in article.tags ?? [] {
                guard let cat = tag.categoryRaw, !cat.isEmpty else { continue }
                articleIDsByCategory[cat, default: []].insert(article.persistentModelID)
            }
        }
        guard !articleIDsByCategory.isEmpty else { return [] }

        // CategorySeed 順で並べ、動的カテゴリを末尾に追加
        var rows: [CategoryRow] = []
        let seedNames = CategorySeed.allSeeds.map(\.name)
        for seed in CategorySeed.allSeeds {
            guard let ids = articleIDsByCategory[seed.name] else { continue }
            rows.append(CategoryRow(name: seed.name, symbolName: seed.symbolName, count: ids.count))
        }
        let dynamicNames = articleIDsByCategory.keys
            .filter { !seedNames.contains($0) }
            .sorted()
        for name in dynamicNames {
            let count = articleIDsByCategory[name]?.count ?? 0
            rows.append(CategoryRow(name: name, symbolName: "square.grid.2x2", count: count))
        }
        return rows
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(categoryRows) { row in
                    Button {
                        toggleCategory(row.name)
                    } label: {
                        HStack(spacing: DS.Spacing.lg) {
                            Image(systemName: row.symbolName)
                                .foregroundStyle(.secondary)
                                .frame(width: 22, alignment: .center)
                            Text(row.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(row.count)")
                                .foregroundStyle(.secondary)
                                .font(.subheadline.monospacedDigit())
                            Image(systemName: selectedCategories.contains(row.name)
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedCategories.contains(row.name)
                                    ? DS.Color.actionBlue : Color(.tertiaryLabel))
                                .font(.body)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("library.filter.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("library.filter.clear") {
                        selectedCategories.removeAll()
                    }
                    .foregroundStyle(DS.Color.actionBlue)
                    .disabled(selectedCategories.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("library.filter.done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func toggleCategory(_ name: String) {
        if selectedCategories.contains(name) {
            selectedCategories.remove(name)
        } else {
            selectedCategories.insert(name)
        }
    }
}

private struct CategoryRow: Identifiable {
    var id: String { name }
    let name: String
    let symbolName: String
    let count: Int
}

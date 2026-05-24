//
//  InterestingNextSection.swift
//  KnowledgeTree
//
//  spec 056 + spec 058 polish — 知識 Clip タブ 2 番目セクション「分野ごとの活動」。
//  Category 単位で「記事数 + 最新更新日」を card 表示、記事数多い順。
//  tap で CategoryFilteredListView (既存 spec 016) へ遷移。
//

import SwiftUI
import SwiftData

struct InterestingNextSection: View {
    @Environment(\.modelContext) private var context
    @Environment(RefreshTrigger.self) private var refreshTrigger

    /// Tag.categoryRaw でグループ化するため、全 Article を取得。
    @Query(sort: [SortDescriptor(\Article.savedAt, order: .reverse)])
    private var allArticles: [Article]

    /// (Category 名, 記事数, 最新 savedAt) を記事数多い順で算出。
    private var categoryStats: [(category: String, count: Int, latest: Date)] {
        // 各 Article の主 Category を解決 (Tag.categoryRaw 優先、なければ「未分類」)
        var grouped: [String: (count: Int, latest: Date)] = [:]
        for article in allArticles {
            let cat = primaryCategory(for: article)
            if let existing = grouped[cat] {
                grouped[cat] = (existing.count + 1, max(existing.latest, article.savedAt))
            } else {
                grouped[cat] = (1, article.savedAt)
            }
        }
        return grouped
            .map { (category: $0.key, count: $0.value.count, latest: $0.value.latest) }
            .sorted { $0.count > $1.count }
    }

    private var topCategories: [(category: String, count: Int, latest: Date)] {
        Array(categoryStats.prefix(5))
    }

    private var totalCategoryCount: Int { categoryStats.count }

    var body: some View {
        if categoryStats.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Text("knowledgeClip.section.categories")
                        .font(.headline)
                    Spacer()
                    if totalCategoryCount > 5 {
                        Text("knowledgeClip.categories.allCount \(totalCategoryCount)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)

                LazyVStack(spacing: DS.Spacing.md) {
                    ForEach(topCategories, id: \.category) { stat in
                        navigationLinkForCategory(stat)
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)
            }
            .accessibilityIdentifier("section.categories")
        }
    }

    @ViewBuilder
    private func navigationLinkForCategory(_ stat: (category: String, count: Int, latest: Date)) -> some View {
        let category = CategorySeed.category(for: stat.category)
        NavigationLink(value: CategoryFilteredDestination(category: category)) {
            CategoryStatRow(categoryName: stat.category, count: stat.count, latest: stat.latest)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("category.card.\(stat.category)")
    }

    /// Article の主 Category を解決 (関連 Tag の categoryRaw 中で最初の non-empty)。
    private func primaryCategory(for article: Article) -> String {
        let tags = article.tags ?? []
        for tag in tags {
            if let cat = tag.categoryRaw, !cat.isEmpty {
                return cat
            }
        }
        return "未分類"
    }
}

private struct CategoryStatRow: View {
    let categoryName: String
    let count: Int
    let latest: Date

    private var relativeLatest: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.localizedString(for: latest, relativeTo: .now)
    }

    private var iconName: String {
        // CategorySeed から symbolName 取得 (既存実装)
        CategorySeed.category(for: categoryName).symbolName
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(categoryName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: DS.Spacing.sm) {
                    Text("category.row.articleCount \(count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("category.row.latestUpdate \(relativeLatest)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(DS.Spacing.lg)
        .background(DS.Color.surfaceSecondary, in: .rect(cornerRadius: DS.Radius.chip))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.chip)
                .stroke(DS.Color.aiBrandEdge.opacity(0.3), lineWidth: 0.5)
        )
    }
}

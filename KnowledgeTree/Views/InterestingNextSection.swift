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

    /// (Category 名, 記事数, 最新 savedAt) を全 10 分野で算出。
    /// V3.0 polish (2026-05-28):
    ///   - 1 Article が複数 Tag (異なる Category) を持つ場合、両 Category にカウント (Tag union 一覧と一致)
    ///   - CategorySeed.allSeeds 10 分野を全部保証 (件数 0 でもリスト表示)
    ///   - 件数多い順 + 同件数なら最新 savedAt 順
    private var categoryStats: [(category: String, count: Int, latest: Date)] {
        // [Category 名: (記事 ID Set + 最新 savedAt)]
        var grouped: [String: (ids: Set<UUID>, latest: Date)] = [:]
        for article in allArticles {
            let categoriesOfArticle = categoriesFor(article)
            for cat in categoriesOfArticle {
                if let existing = grouped[cat] {
                    var newIDs = existing.ids
                    newIDs.insert(article.id)
                    grouped[cat] = (newIDs, max(existing.latest, article.savedAt))
                } else {
                    grouped[cat] = ([article.id], article.savedAt)
                }
            }
        }

        // CategorySeed.allSeeds 全 10 件を base に、件数 0 でも保証
        var stats: [(category: String, count: Int, latest: Date)] = []
        for seed in CategorySeed.allSeeds {
            if let data = grouped[seed.name] {
                stats.append((seed.name, data.ids.count, data.latest))
            } else {
                stats.append((seed.name, 0, .distantPast))
            }
        }
        // CategorySeed に無い分類 (例: 「未分類」) があれば末尾に追加
        for (name, data) in grouped where CategorySeed.allSeeds.first(where: { $0.name == name }) == nil {
            stats.append((name, data.ids.count, data.latest))
        }

        return stats.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.latest > rhs.latest
        }
    }

    /// 全分野リスト (件数多い順 + 0 件含む)。
    private var topCategories: [(category: String, count: Int, latest: Date)] {
        categoryStats
    }

    private var totalCategoryCount: Int { categoryStats.count }

    var body: some View {
        // V3.0 polish (2026-05-28): CategorySeed.allSeeds 10 件で常に non-empty、ガードは defensive。
        if categoryStats.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Text("knowledgeClip.section.categories")
                        .font(.headline)
                    Spacer()
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
    /// V3.0 polish 後は categoriesFor で複数 Category 集計するため、参照箇所が無くなった場合は保持目的。
    private func primaryCategory(for article: Article) -> String {
        let tags = article.tags ?? []
        for tag in tags {
            if let cat = tag.categoryRaw, !cat.isEmpty {
                return cat
            }
        }
        return "未分類"
    }

    /// V3.0 polish (2026-05-28): Article が属する全 Category 名を Set で返す。
    /// CategoryFilter.filteredArticles と件数を一致させるため、Tag.categoryRaw 全部を Category 名に解決。
    /// categoryRaw が無い / 全部空なら ["未分類"]。
    private func categoriesFor(_ article: Article) -> Set<String> {
        let categoryNames: Set<String> = Set(
            (article.tags ?? []).compactMap { tag in
                guard let raw = tag.categoryRaw, !raw.isEmpty else { return nil }
                return CategorySeed.category(for: raw).name
            }
        )
        return categoryNames.isEmpty ? ["未分類"] : categoryNames
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

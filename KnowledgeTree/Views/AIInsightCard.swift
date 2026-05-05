//
//  AIInsightCard.swift
//  KnowledgeTree
//
//  spec 015 — AI ブレインタブ Section 2: トップ Category を客観的に報告するインサイトカード。
//
//  contracts/ai-insight-card.md 準拠。
//  タグ 0 件: "Safari から記事を保存しましょう" + tray アイコン
//  タグ 1 件以上: "最も読んでいる分野: {Category 名}" + sparkles アイコン + N 記事 subtext
//

import SwiftUI

struct AIInsightCard: View {
    let tags: [Tag]

    /// Tag を categoryRaw でグループ化、各 Category の記事数集計、最多 1 件を返す。
    private var topCategoryEntry: (category: Category, articleCount: Int)? {
        let grouped = Dictionary(grouping: tags) {
            CategorySeed.category(for: $0.categoryRaw)
        }
        let entries = grouped.map { (category, tagsInCategory) -> (Category, Int) in
            let articleIDs = Set(tagsInCategory.flatMap { $0.articles.map(\.id) })
            return (category, articleIDs.count)
        }
        .filter { $0.1 > 0 }

        // 記事数 desc、同点は order asc
        return entries.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return lhs.0.order < rhs.0.order
        }.first.map { (category: $0.0, articleCount: $0.1) }
    }

    private var iconName: String {
        topCategoryEntry == nil ? "tray.and.arrow.down.fill" : "sparkles"
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xl) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(DS.Color.actionBlue)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                if let entry = topCategoryEntry {
                    Text("最も読んでいる分野")
                        .font(DS.Typography.chipLabel)
                        .foregroundStyle(.secondary)
                    Text("\(entry.category.name)（\(entry.articleCount)記事）")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                } else {
                    Text("aibrain.insight.empty.headline")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("aibrain.insight.empty.subtext")
                        .font(DS.Typography.chipLabel)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.xxl)
        .padding(.vertical, DS.Spacing.xl)
        .background(
            DS.Color.actionBlue.opacity(0.06),
            in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Color.actionBlue.opacity(0.20), lineWidth: 0.5)
        )
        .accessibilityIdentifier("aibrain.insight_card")
        .accessibilityElement(children: .combine)
    }
}

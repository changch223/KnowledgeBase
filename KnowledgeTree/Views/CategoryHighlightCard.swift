//
//  CategoryHighlightCard.swift
//  KnowledgeTree
//
//  spec 068 (iKnow フィード) — 縦フィードのバリエーション: カテゴリーハイライトカード。
//  例「📕 テクノロジー — 記事24 / Wiki5、今週 +3」。tap → そのカテゴリの記事一覧。
//  色は使わず SF Symbol アイコンで区別 (CategorySeed.symbolName)。
//

import SwiftUI

struct CategoryHighlightCard: View {
    let category: Category
    let articleCount: Int
    let wikiCount: Int
    /// 直近 7 日に追加された記事数 (0 なら「今週 +N」を出さない)。
    let recentCount: Int

    var body: some View {
        NavigationLink(value: CategoryFilteredDestination(category: category)) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: category.symbolName)
                    .font(.title2)
                    .foregroundStyle(DS.Color.actionBlue)
                    .frame(width: 36, height: 36)
                    .background(DS.Color.tagFill, in: RoundedRectangle(cornerRadius: DS.Radius.chip))

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(category.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(String(format: String(localized: "feed.category.counts"), articleCount, wikiCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if recentCount > 0 {
                    Text(String(format: String(localized: "feed.highlight.recent"), recentCount))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Color.actionBlue)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(DS.Color.tagFill, in: Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(DS.Spacing.md)
            .background(DS.Color.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
            .padding(.horizontal, DS.Spacing.xxl)
        }
        .buttonStyle(.plain)
    }
}

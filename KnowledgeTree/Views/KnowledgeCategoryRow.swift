//
//  KnowledgeCategoryRow.swift
//  KnowledgeTree
//
//  spec 015 — AI ブレインタブ Section 3: Category 別の記事数 + プログレスバー行。
//  spec 016 — タップで CategoryFilteredListView (Category 全 Tag union) へ遷移するように変更。
//             topTagName プロパティは廃止 (B1 バグ根本解決)。
//

import SwiftUI

struct KnowledgeCategoryRow: View {
    let category: Category
    let articleCount: Int
    let maxCount: Int
    let isLast: Bool

    private var ratio: Double {
        guard maxCount > 0 else { return 0 }
        return Double(articleCount) / Double(maxCount)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.xl) {
                Text(category.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(width: 80, alignment: .leading)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(DS.Color.tagFill)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(DS.Color.actionBlue)
                            .frame(width: proxy.size.width * ratio, height: 6)
                    }
                    .frame(height: proxy.size.height)
                }
                .frame(height: 6)
                .frame(maxWidth: .infinity)

                Text("\(articleCount)記事")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.vertical, DS.Spacing.xl)

            if !isLast {
                Divider()
                    .padding(.leading, DS.Spacing.xxl)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("aibrain.category_row.\(category.englishName.lowercased())")
        .accessibilityLabel(Text("\(category.name)、\(articleCount)記事"))
        .accessibilityHint(Text("タップで該当記事一覧へ遷移"))
    }
}

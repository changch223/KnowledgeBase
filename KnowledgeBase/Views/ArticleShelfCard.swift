//
//  ArticleShelfCard.swift
//  KnowledgeTree
//
//  japanese-ui-redesign: 写真削除・テキストのみ・細線ボーダーカード。
//  元に戻す場合は git checkout main -- KnowledgeBase/Views/ArticleShelfCard.swift
//

import SwiftUI

struct ArticleShelfCard: View {
    let article: Article

    static let cardWidth: CGFloat = 150

    var body: some View {
        NavigationLink(value: article) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Spacer(minLength: 0)

                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fontDesign(.serif)
                    .foregroundStyle(DS.Color.sumiInk)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                Rectangle()
                    .fill(DS.Color.sumiRule)
                    .frame(height: 0.5)

                Text(SavedAtFormatter.format(article.savedAt))
                    .font(.caption2)
                    .foregroundStyle(DS.Color.sumiLight)
            }
            .padding(DS.Spacing.lg)
            .frame(width: Self.cardWidth, height: 110, alignment: .leading)
            .background(DS.Color.washiCard,
                        in: RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                    .stroke(DS.Color.sumiRule, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

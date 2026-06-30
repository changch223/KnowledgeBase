//
//  ArticleShelfCard.swift
//  KnowledgeTree
//
//  japanese-ui-redesign: 写真あり (80px)・serif タイトル・細線ボーダー。
//  元に戻す場合は git checkout main -- KnowledgeBase/Views/ArticleShelfCard.swift
//

import SwiftUI

struct ArticleShelfCard: View {
    let article: Article

    static let cardWidth: CGFloat = 150
    static let imageHeight: CGFloat = 80

    private var imageURL: URL? {
        guard let raw = article.enrichment?.ogImageURL,
              let url = URL(string: raw), url.scheme == "https" else { return nil }
        return url
    }

    var body: some View {
        NavigationLink(value: article) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // 写真 (ある程度欲しい → 上部に配置)
                photo
                    .frame(width: Self.cardWidth, height: Self.imageHeight)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))

                Text(article.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .fontDesign(.serif)
                    .foregroundStyle(DS.Color.sumiInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: Self.cardWidth, alignment: .leading)

                Text(SavedAtFormatter.format(article.savedAt))
                    .font(.caption2)
                    .foregroundStyle(DS.Color.sumiLight)
                    .frame(width: Self.cardWidth, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var photo: some View {
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    fallback
                }
            }
        } else {
            fallback
        }
    }

    private var fallback: some View {
        ZStack {
            DS.Color.sumiRule.opacity(0.5)
            Image(systemName: "doc.text")
                .font(.title2)
                .foregroundStyle(DS.Color.sumiLight)
        }
    }
}

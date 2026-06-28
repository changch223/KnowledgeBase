//
//  ArticleShelfCard.swift
//  KnowledgeTree
//
//  spec 068 (iKnow フィード) — おすすめ横スクロール carousel の記事カード (コンパクト)。
//  縦用 ArticleFeedCard より小さい (~150pt 幅、写真上 + タイトル下)。tap → 記事詳細。
//

import SwiftUI

struct ArticleShelfCard: View {
    let article: Article

    /// 横カード幅。LazyHStack 内で固定。
    static let cardWidth: CGFloat = 150
    static let imageHeight: CGFloat = 100

    private var imageURL: URL? {
        guard let raw = article.enrichment?.ogImageURL,
              let url = URL(string: raw), url.scheme == "https" else { return nil }
        return url
    }

    var body: some View {
        NavigationLink(value: article) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                photo
                    .frame(width: Self.cardWidth, height: Self.imageHeight)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.chip))

                Text(article.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
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
            DS.Color.tagFill
            Image(systemName: "doc.text")
                .font(.title2)
                .foregroundStyle(DS.Color.sumiInk)
        }
    }
}

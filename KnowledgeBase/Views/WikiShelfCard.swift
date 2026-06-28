//
//  WikiShelfCard.swift
//  KnowledgeTree
//
//  spec 068 (iKnow フィード) — おすすめ横スクロール carousel の Wiki カード (コンパクト)。
//  関連記事から写真借用、無ければ kind アイコン + 色 fallback。tap → 概念詳細。
//

import SwiftUI

struct WikiShelfCard: View {
    let page: ConceptPage

    static let cardWidth: CGFloat = 150
    static let imageHeight: CGFloat = 100

    private var borrowedImageURL: URL? {
        let raw = (page.relatedArticles ?? []).compactMap { $0.enrichment?.ogImageURL }.first
        guard let raw, let url = URL(string: raw), url.scheme == "https" else { return nil }
        return url
    }

    var body: some View {
        NavigationLink(value: ConceptPageDetailDestination(id: page.id)) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                photo
                    .frame(width: Self.cardWidth, height: Self.imageHeight)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.chip))

                // spec 070: おすすめ横棚にも「まとめ」種別バッジ
                FeedTypeBadge(labelKey: "feed.badge.wiki", systemImage: page.kind.symbolName)

                Label(page.name, systemImage: page.kind.symbolName)
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
        if let borrowedImageURL {
            AsyncImage(url: borrowedImageURL) { phase in
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
            Image(systemName: page.kind.symbolName)
                .font(.title2)
                .foregroundStyle(DS.Color.sumiInk)
        }
    }
}

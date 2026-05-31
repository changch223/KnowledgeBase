//
//  RecommendCarousel.swift
//  KnowledgeTree
//
//  spec 068 (iKnow フィード) — 縦フィードの途中に挿入する「おすすめ」横スクロール carousel。
//  記事と Wiki が混在 (FeedBuilder.recommend で算出済の FeedItem を受け取る)。
//  控えめな見出し + LazyHStack で 60fps 横スクロール。
//

import SwiftUI

struct RecommendCarousel: View {
    let items: [FeedItem]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("feed.recommend.title")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DS.Spacing.xxl)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DS.Spacing.md) {
                    ForEach(items) { item in
                        switch item {
                        case .article(let article):
                            ArticleShelfCard(article: article)
                        case .wikiUpdate(let page):
                            WikiShelfCard(page: page)
                        case .periodicDigest:
                            EmptyView()  // carousel には digest は出さない
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)
            }
        }
        .padding(.vertical, DS.Spacing.sm)
    }
}

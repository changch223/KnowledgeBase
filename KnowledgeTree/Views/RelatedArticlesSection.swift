//
//  RelatedArticlesSection.swift
//  KnowledgeTree
//
//  spec 008 — Detail 画面下部に表示する「関連記事」セクション。
//  共通 KnowledgeEntity 数で sort、上位 5 件、共通 entity 0 件なら非表示。
//

import SwiftUI
import SwiftData

struct RelatedArticlesSection: View {
    let article: Article
    let onSelect: (Article) -> Void

    @Query private var allArticles: [Article]

    private var related: [RelatedArticle] {
        RelatedArticleFinder.find(for: article, in: allArticles, limit: 5)
    }

    var body: some View {
        if !related.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("detail.related.heading")
                    .font(.title3.bold())

                ForEach(related) { item in
                    Button {
                        onSelect(item.article)
                    } label: {
                        RelatedArticleRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("relatedArticleRow")
                }

                Divider().padding(.top, 4)
            }
            .accessibilityIdentifier("relatedArticlesSection")
        }
    }
}

private struct RelatedArticleRow: View {
    let item: RelatedArticle

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.article.title)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                if !item.commonEntities.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(item.commonEntities, id: \.self) { name in
                            Text(name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.tertiary, in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Text("\(item.commonEntityCount)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

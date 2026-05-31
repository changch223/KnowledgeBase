//
//  ArticleFeedCard.swift
//  KnowledgeTree
//
//  spec 066 (LLM Wiki) — News+ 風フィードの記事カード (大判写真 + 関連 Wiki チップ)。
//  カード本体 tap → 記事詳細、関連 Wiki チップ tap → 概念詳細 (親の navigationDestination で解決)。
//

import SwiftUI

struct ArticleFeedCard: View {
    let article: Article

    private var relatedConcepts: [ConceptPage] {
        Array((article.relatedConcepts ?? []).prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            NavigationLink(value: article) {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    // spec 070: 種別バッジ (アイコン + 文字)
                    FeedTypeBadge(labelKey: "feed.badge.article", systemImage: "doc.text.fill")

                    if let ogURL = article.enrichment?.ogImageURL,
                       let url = URL(string: ogURL), url.scheme == "https" {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            default:
                                Rectangle().fill(DS.Color.overlayMedium)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
                    }

                    Text(article.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let essence = article.extractedKnowledge?.essence, !essence.isEmpty {
                        Text(essence)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }

                    Text(SavedAtFormatter.format(article.savedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if !relatedConcepts.isEmpty {
                FlowingTagsLayout(spacing: DS.Spacing.xs) {
                    ForEach(relatedConcepts, id: \.id) { concept in
                        NavigationLink(value: ConceptPageDetailDestination(id: concept.id)) {
                            Label(concept.name, systemImage: concept.kind.symbolName)
                                .font(.caption)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(DS.Color.tagFill, in: Capsule())
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        .padding(.horizontal, DS.Spacing.xxl)
    }
}

//
//  WikiFeedCard.swift
//  KnowledgeTree
//
//  spec 066 (LLM Wiki) — News+ 風フィードの Wiki 更新カード + 周期ダイジェストカード。
//  写真は関連記事から借用 (KnowledgeClipCard 先例)、無ければ種別アイコン + 色 fallback。
//  カード tap → 概念詳細 (親の navigationDestination で解決)。
//

import SwiftUI

struct WikiFeedCard: View {
    let page: ConceptPage

    /// 関連記事から代表 OGP 画像を借用 (最初に見つかった https URL)。
    private var borrowedImageURL: URL? {
        let raw = (page.relatedArticles ?? []).compactMap { $0.enrichment?.ogImageURL }.first
        guard let raw, let url = URL(string: raw), url.scheme == "https" else { return nil }
        return url
    }

    private var preview: String {
        page.summary.isEmpty ? page.bodyMarkdown : page.summary
    }

    var body: some View {
        NavigationLink(value: ConceptPageDetailDestination(id: page.id)) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                photo
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))

                Label("feed.wiki.updated", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(DS.Color.actionBlue)

                Label(page.name, systemImage: page.kind.symbolName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if !preview.isEmpty {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                Text(SavedAtFormatter.format(page.updatedAt))
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

    @ViewBuilder
    private var photo: some View {
        if let borrowedImageURL {
            AsyncImage(url: borrowedImageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    fallbackPhoto
                }
            }
        } else {
            fallbackPhoto
        }
    }

    private var fallbackPhoto: some View {
        ZStack {
            DS.Color.tagFill
            Image(systemName: page.kind.symbolName)
                .font(.system(size: 44))
                .foregroundStyle(DS.Color.actionBlue)
        }
    }
}

// MARK: - 周期ダイジェストカード (P2)

/// 最近更新された複数 Wiki を束ねた「振り返り」カード。各行 tap で詳細へ。
struct PeriodicDigestCard: View {
    let pages: [ConceptPage]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Label("feed.digest.title", systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(DS.Color.actionBlue)

            ForEach(pages, id: \.id) { page in
                NavigationLink(value: ConceptPageDetailDestination(id: page.id)) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: page.kind.symbolName)
                            .foregroundStyle(DS.Color.actionBlue)
                        Text(page.name)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, DS.Spacing.xxs)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        .padding(.horizontal, DS.Spacing.xxl)
    }
}

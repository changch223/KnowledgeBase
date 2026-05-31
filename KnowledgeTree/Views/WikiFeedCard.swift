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

// MARK: - 周期ダイジェストカード (spec 068 v2: 1 枚サマリーカード)

/// 最近更新された複数 Wiki を束ねた「振り返り」を 1 枚のサマリーカードで表示する。
/// 代表サムネを重ねて横並び + 件数 + 「すべて見る」。tap で全 Wiki 一覧へ。
struct PeriodicDigestCard: View {
    let pages: [ConceptPage]

    /// 代表サムネ用に、関連記事から借用できる画像 URL を最大 4 件集める。
    private var thumbnailURLs: [URL] {
        var urls: [URL] = []
        for page in pages {
            guard urls.count < 4 else { break }
            if let raw = (page.relatedArticles ?? []).compactMap({ $0.enrichment?.ogImageURL }).first,
               let url = URL(string: raw), url.scheme == "https" {
                urls.append(url)
            }
        }
        return urls
    }

    var body: some View {
        NavigationLink(value: ConceptPageListDestination()) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Label("feed.digest.title", systemImage: "calendar")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Color.actionBlue)
                    Spacer()
                    Text(String(format: String(localized: "feed.digest.count"), pages.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 代表サムネを少し重ねて横並び (写真が無ければ kind アイコン)
                HStack(spacing: -DS.Spacing.md) {
                    ForEach(Array(pages.prefix(4).enumerated()), id: \.element.id) { idx, page in
                        thumbnail(for: page)
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.chip))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.chip)
                                    .stroke(DS.Color.surfaceSecondary, lineWidth: 2)
                            )
                            .zIndex(Double(4 - idx))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 代表ページ名 (先頭 2 件を「、」連結)
                Text(pages.prefix(2).map(\.name).joined(separator: "、"))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(DS.Spacing.md)
            .background(DS.Color.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
            .padding(.horizontal, DS.Spacing.xxl)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func thumbnail(for page: ConceptPage) -> some View {
        if let raw = (page.relatedArticles ?? []).compactMap({ $0.enrichment?.ogImageURL }).first,
           let url = URL(string: raw), url.scheme == "https" {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                default: kindFallback(page)
                }
            }
        } else {
            kindFallback(page)
        }
    }

    private func kindFallback(_ page: ConceptPage) -> some View {
        ZStack {
            DS.Color.tagFill
            Image(systemName: page.kind.symbolName)
                .foregroundStyle(DS.Color.actionBlue)
        }
    }
}

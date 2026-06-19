//
//  ConceptSummaryCard.swift
//  KnowledgeTree
//
//  spec 075 (iKnow 概念中心フィード) — 縦フィードの主役カード「超まとめ」。
//  広い概念 (or 孤立 specific) が複数記事を 1 つの答えに束ねて見せる:
//   kind アイコン + 名前 + 1-2 行サマリ + 子トピック名チップ + 記事数。
//  タップ → ConceptPageDetailView (子トピック・記事へドリルダウン)。AI 呼び出しゼロ。
//

import SwiftUI

struct ConceptSummaryCard: View {
    let entry: ConceptFeedEntry
    /// spec 080拡張: カードが表示されたら呼ぶ (既読マーク用)。
    var onSeen: () -> Void = {}

    /// 子トピックチップに出す最大件数。
    private static let maxChildChips = 4

    private var page: ConceptPage { entry.page }

    /// spec 080: カードの主役 = 要点 (crossSourceInsights) の上位 1-2 点。
    private var displayPoints: [String] {
        page.crossSourceInsights
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// 要点が無いとき用の 1-2 行サマリ。空なら関連記事の先頭 essence、それも無ければ「整理中…」。
    private var previewText: String {
        let summary = page.summaryPreview.trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty { return summary }
        if let essence = (page.relatedArticles ?? [])
            .compactMap({ $0.extractedKnowledge?.essence })
            .first(where: { !$0.isEmpty }) {
            return essence
        }
        return String(localized: "ConceptPage.card.synthesisInProgress")
    }

    var body: some View {
        NavigationLink(value: ConceptPageDetailDestination(id: page.id)) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                // spec 087: 左サムネイル (関連記事の OGP を概念ごとに固定で表示、無ければ種別アイコン)
                thumbnail
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    header
                    // spec 080: 答え先出し。要点があれば 1-2 点を箇条書き、無ければ従来のサマリ。
                    if !displayPoints.isEmpty {
                        keyPointsView
                    } else {
                        Text(previewText)
                            .font(.subheadline)
                            .foregroundStyle(page.isSynthesisInProgress ? .tertiary : .secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !entry.children.isEmpty {
                        childChips
                    }

                    footer
                }
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCardBackground()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DS.Spacing.xxl)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("conceptSummaryCard_\(page.id.uuidString)")
        .onAppear { onSeen() }  // spec 080拡張: 表示で既読マーク
    }

    /// spec 087: 概念ごとに固定の OGP サムネイル URL (再描画でちらつかない / 概念間でばらつく)。
    /// 関連記事のうち https の ogImageURL を持つものから、uuid 由来の決定的 index で 1 つ選ぶ。
    private var thumbnailURL: URL? {
        let urls = (page.relatedArticles ?? []).compactMap { article -> URL? in
            guard let raw = article.enrichment?.ogImageURL,
                  let url = URL(string: raw), url.scheme == "https" else { return nil }
            return url
        }
        guard !urls.isEmpty else { return nil }
        let seed = page.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return urls[seed % urls.count]
    }

    private var thumbnail: some View {
        Group {
            if let url = thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        kindIconTile
                    }
                }
            } else {
                kindIconTile
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }

    private var kindIconTile: some View {
        ZStack {
            DS.Color.tagFill
            Image(systemName: page.kind.symbolName)
                .font(.title3)
                .foregroundStyle(DS.Color.actionBlue)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Text(page.name)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
            if page.isFollowing {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.actionBlue)
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 0)
        }
    }

    /// spec 080: 最重要の要点 1-2 点を青•箇条書きで (答え先出し)。
    private var keyPointsView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ForEach(Array(displayPoints.prefix(2).enumerated()), id: \.offset) { _, point in
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    Text("•")
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.actionBlue)
                    Text(point)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        // spec 080拡張: クリック不要で読めるよう全文表示 (lineLimit 撤去)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var childChips: some View {
        FlowingTagsLayout(spacing: DS.Spacing.xs) {
            ForEach(entry.children.prefix(Self.maxChildChips), id: \.id) { child in
                chip(child.name)
            }
            if entry.children.count > Self.maxChildChips {
                chip("+\(entry.children.count - Self.maxChildChips)")
            }
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .lineLimit(1)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(DS.Color.tagFill, in: Capsule())
            .foregroundStyle(.secondary)
    }

    private var footer: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(String(format: String(localized: "feed.concept.articleCount"), entry.articleCount))
            if !entry.children.isEmpty {
                Text("·")
                Text(String(format: String(localized: "feed.concept.childCount"), entry.children.count))
            }
            Spacer(minLength: 0)
            Text(SavedAtFormatter.format(page.updatedAt))
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

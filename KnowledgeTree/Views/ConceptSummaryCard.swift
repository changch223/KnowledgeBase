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

    /// 子トピックチップに出す最大件数。
    private static let maxChildChips = 4

    private var page: ConceptPage { entry.page }

    /// 1-2 行サマリ。空なら関連記事の先頭 essence、それも無ければ「整理中…」。
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
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                header
                Text(previewText)
                    .font(.subheadline)
                    .foregroundStyle(page.isSynthesisInProgress ? .tertiary : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !entry.children.isEmpty {
                    childChips
                }

                footer
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCardBackground()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DS.Spacing.xxl)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("conceptSummaryCard_\(page.id.uuidString)")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Image(systemName: page.kind.symbolName)
                .font(.title3)
                .foregroundStyle(DS.Color.actionBlue)
                .accessibilityHidden(true)
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

//
//  TagHighlightCard.swift
//  KnowledgeTree
//
//  spec 068 (iKnow フィード) — 縦フィードのバリエーション: タグハイライトカード。
//  例「#AI 今週 +3」。tap → そのタグの記事一覧 (TagFilteredDestination)。
//

import SwiftUI

struct TagHighlightCard: View {
    let tag: Tag
    let totalCount: Int
    /// 直近 7 日に増えた記事数。
    let recentCount: Int

    var body: some View {
        NavigationLink(value: TagFilteredDestination(tagName: tag.name)) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "number")
                    .font(.title3)
                    .foregroundStyle(DS.Color.actionBlue)
                    .frame(width: 36, height: 36)
                    .background(DS.Color.tagFill, in: RoundedRectangle(cornerRadius: DS.Radius.chip))

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    // spec 070: 種別バッジ「タグ」
                    FeedTypeBadge(labelKey: "feed.badge.tag", systemImage: "number")
                    Text("#\(tag.name)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(String(format: String(localized: "feed.tag.total"), totalCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if recentCount > 0 {
                    Text(String(format: String(localized: "feed.highlight.recent"), recentCount))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Color.actionBlue)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(DS.Color.tagFill, in: Capsule())
                }

                Image(systemName: "chevron.right")
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
}

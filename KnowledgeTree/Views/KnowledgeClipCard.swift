//
//  KnowledgeClipCard.swift
//  KnowledgeTree
//
//  spec 018 — 1 つの KnowledgeDigest を表示するカード view。
//  Category 名 + 元記事数 + savedAt + stale マーク + 小 OG +
//  統合 summary + KeyFact 3 + EntityChip 3。
//
//  contracts/knowledge-clip-card.md 準拠。
//

import SwiftUI

struct KnowledgeClipCard: View {
    let digest: KnowledgeDigest

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            headerSection
            summarySection
            keyFactsSection
            entityChipsSection
        }
        .padding(DS.Spacing.xxl)
        .dsCardBackground()
        .accessibilityIdentifier("clip.card.\(digest.categoryRaw).\(digest.cardIndex)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(combinedAccessibilityLabel)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(digest.categoryRaw)
                    .font(DS.Typography.sectionTitle)
                    .foregroundStyle(.primary)

                HStack(spacing: DS.Spacing.sm) {
                    Text("\(digest.sourceArticles.count) 記事から")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let latestSavedAt = digest.sourceArticles.map(\.savedAt).max() {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(SavedAtFormatter.format(latestSavedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: DS.Spacing.sm)

            if digest.isStale {
                Text("clip.card.staleLabel")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.actionBlue)
                    .accessibilityIdentifier("clip.card.staleMark")
            }

            if let ogURL = digest.sourceArticles.compactMap(\.enrichment?.ogImageURL).first {
                ThumbnailView(urlString: ogURL)
                    .frame(width: 48, height: 48)
            }
        }
    }

    private var summarySection: some View {
        Text(digest.summary)
            .font(.body)
            .lineSpacing(DS.Typography.bodyLineSpacing)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var keyFactsSection: some View {
        if !digest.topKeyFacts.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                ForEach(digest.topKeyFacts, id: \.self) { fact in
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Text("・")
                            .font(.body)
                            .foregroundStyle(DS.Color.actionBlue)
                        Text(fact)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var entityChipsSection: some View {
        if !digest.topEntityNames.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DS.Spacing.sm) {
                    ForEach(digest.topEntityNames, id: \.self) { name in
                        Text(name)
                            .font(DS.Typography.chipLabel)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(DS.Color.tagFill, in: Capsule())
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    // MARK: - Accessibility

    private var combinedAccessibilityLabel: String {
        var parts: [String] = []
        parts.append(digest.categoryRaw)
        parts.append("\(digest.sourceArticles.count) 記事")
        if digest.isStale {
            parts.append("更新あり")
        }
        if !digest.summary.isEmpty {
            parts.append(digest.summary)
        }
        if !digest.topKeyFacts.isEmpty {
            parts.append("ポイント: " + digest.topKeyFacts.joined(separator: "、"))
        }
        return parts.joined(separator: ", ")
    }
}

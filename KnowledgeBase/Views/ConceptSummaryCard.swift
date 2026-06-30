//
//  ConceptSummaryCard.swift
//  KnowledgeTree
//
//  japanese-ui-redesign: 写真削除・タイトル大型化・余白増・内線追加。
//  元に戻す場合は git checkout main -- KnowledgeBase/Views/ConceptSummaryCard.swift
//

import SwiftUI

struct ConceptSummaryCard: View {
    let entry: ConceptFeedEntry
    var onSeen: () -> Void = {}

    private static let maxChildChips = 4
    private var page: ConceptPage { entry.page }

    private var displayPoints: [String] {
        page.crossSourceInsights
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var previewText: String {
        let summary = page.summaryPreview.trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty { return summary }
        if let essence = (page.relatedArticles ?? [])
            .compactMap({ $0.extractedKnowledge?.essence })
            .first(where: { !$0.isEmpty }) { return essence }
        return String(localized: "ConceptPage.card.synthesisInProgress")
    }

    var body: some View {
        NavigationLink(value: ConceptPageDetailDestination(id: page.id)) {
            VStack(alignment: .leading, spacing: 0) {

                // ── タイトル ──────────────────────────────
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    Text(page.name)
                        .font(.title2)
                        .fontDesign(.serif)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Color.sumiInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if page.isFollowing {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(DS.Color.sumiLight)
                            .accessibilityHidden(true)
                    }
                }

                Spacer().frame(height: DS.Spacing.lg)

                // ── 要点 ──────────────────────────────────
                if !displayPoints.isEmpty {
                    keyPointsView
                } else {
                    Text(previewText)
                        .font(.subheadline)
                        .foregroundStyle(page.isSynthesisInProgress
                            ? DS.Color.sumiLight : DS.Color.sumiMid)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // ── 子トピック ────────────────────────────
                if !entry.children.isEmpty {
                    Spacer().frame(height: DS.Spacing.md)
                    childChips
                }

                Spacer().frame(height: DS.Spacing.lg)

                // ── フッター（細線で区切る）──────────────
                Rectangle()
                    .fill(DS.Color.sumiRule)
                    .frame(height: 0.5)

                Spacer().frame(height: DS.Spacing.sm)

                footer
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.vertical, DS.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Color.washiCard,
                        in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(DS.Color.sumiRule, lineWidth: 0.5)
            )
            .overlay(alignment: .topTrailing) {
                Text("知")
                    .font(.system(size: 44, weight: .black, design: .serif))
                    .foregroundStyle(DS.Color.sumiInk.opacity(0.04))
                    .padding(.top, DS.Spacing.sm)
                    .padding(.trailing, DS.Spacing.lg)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DS.Spacing.xxl)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("conceptSummaryCard_\(page.id.uuidString)")
        .onAppear { onSeen() }
    }

    private var keyPointsView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(Array(displayPoints.prefix(2).enumerated()), id: \.offset) { _, point in
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    Text("•")
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.sumiMid)
                    Text(point)
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.sumiInk)
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
            .overlay(Capsule().stroke(DS.Color.sumiRule, lineWidth: 0.5))
            .foregroundStyle(DS.Color.sumiMid)
    }

    private var footer: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(String(format: String(localized: "feed.concept.articleCount"), entry.articleCount))
            if !entry.children.isEmpty {
                Text("·")
                Text(String(format: String(localized: "feed.concept.childCount"), entry.children.count))
            }
            Spacer(minLength: 0)
            Text(SavedAtFormatter.format(page.updatedAt))
        }
        .font(.caption2)
        .foregroundStyle(DS.Color.sumiLight)
    }
}

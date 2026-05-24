//
//  UnderstandingCardRow.swift
//  KnowledgeTree
//
//  spec 044 — 学習タブの統一カード UI (ConceptPage + SavedAnswer 両対応)。
//
//  - icon: ConceptPage = lightbulb.fill / SavedAnswer = quote.bubble.fill
//  - title: ConceptPage.name or SavedAnswer.question.prefix(80)
//  - label badge: 5 色 (newKnowledge=green / needsUpdate=orange / shallow=yellow / deepDive=blue / review=gray)
//  - lastInteractedAt: SavedAtFormatter (spec 016 流用) で相対時刻表示
//

import SwiftUI

struct UnderstandingCardRow: View {
    let card: UnderstandingCard

    var body: some View {
        HStack(spacing: DS.Spacing.xl) {
            iconView
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(card.titleText)
                    .font(DS.Typography.rowTitle)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: DS.Spacing.md) {
                    LabelBadge(label: card.label)
                    if let lastInteracted = card.lastInteractedAt {
                        Text(SavedAtFormatter.format(lastInteracted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.callout)
        }
        .padding(DS.Spacing.xl)
        .background(DS.Color.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        .accessibilityIdentifier("card.understanding.\(card.kindString).\(card.id.uuidString)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
    }

    @ViewBuilder
    private var iconView: some View {
        switch card.kind {
        case .conceptPage:
            Image(systemName: "lightbulb.fill")
        case .savedAnswer:
            Image(systemName: "quote.bubble.fill")
        }
    }

    private var iconColor: Color {
        switch card.kind {
        case .conceptPage: return DS.Color.actionBlue
        case .savedAnswer: return .orange
        }
    }

    private var accessibilityLabelText: String {
        let kindStr: String = (card.kindString == UnderstandingInteraction.Kind.conceptPage.rawValue) ? "概念" : "質問"
        return "\(kindStr): \(card.titleText)、\(card.label.voiceOverText)"
    }
}

// MARK: - LabelBadge

struct LabelBadge: View {
    let label: UnderstandingCardLabel

    var body: some View {
        Text(label.localizationKey)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(badgeColor.opacity(0.18))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }

    private var badgeColor: Color {
        switch label {
        case .newKnowledge: return .green
        case .needsUpdate:  return .orange
        case .shallow:      return .yellow
        case .deepDive:     return .blue
        case .review:       return .gray
        }
    }
}

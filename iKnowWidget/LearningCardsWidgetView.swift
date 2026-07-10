//
//  LearningCardsWidgetView.swift
//  iKnowWidget
//
//  spec 052 — Widget の見た目 (3 family 対応)。
//  - accessoryRectangular: Lockscreen、icon + title 1 行
//  - systemSmall: Homescreen 1×1、title + label badge
//  - systemMedium: Homescreen 2×1、上位 2 件
//  各カードは Widget Link で deep link `iknow://learning/card/{uuid}` 持ち、tap で iKnow 起動 + DeepDiveChat 遷移。
//

import WidgetKit
import SwiftUI

struct LearningCardsWidgetView: View {
    let entry: LearningCardsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            rectangularContent
        case .systemSmall:
            smallContent
        case .systemMedium:
            mediumContent
        default:
            smallContent
        }
    }

    // MARK: - accessoryRectangular (Lockscreen)

    @ViewBuilder
    private var rectangularContent: some View {
        if let card = entry.cards.first {
            Link(destination: card.deepLinkURL) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: card.symbolName)
                            .font(.caption)
                        Text("widget.today.title")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                    Text(card.title)
                        .font(.headline)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: "book.fill")
                    .foregroundStyle(.secondary)
                Text("widget.empty.title")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - systemSmall

    @ViewBuilder
    private var smallContent: some View {
        if let card = entry.cards.first {
            Link(destination: card.deepLinkURL) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: card.symbolName)
                            .font(.title3)
                            .foregroundStyle(card.iconColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text(card.title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    LabelBadge(text: card.labelText, color: card.labelColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            placeholderSmall
        }
    }

    private var placeholderSmall: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "book.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("widget.empty.title")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            Text("widget.empty.tapToStart")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - systemMedium

    @ViewBuilder
    private var mediumContent: some View {
        if entry.cards.isEmpty {
            placeholderMedium
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("widget.today.title")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                ForEach(entry.cards.prefix(2), id: \.id) { card in
                    Link(destination: card.deepLinkURL) {
                        HStack(spacing: 10) {
                            Image(systemName: card.symbolName)
                                .font(.callout)
                                .foregroundStyle(card.iconColor)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.title)
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                LabelBadge(text: card.labelText, color: card.labelColor)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var placeholderMedium: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "book.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("widget.empty.title")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("widget.empty.mediumHint")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - LabelBadge

private struct LabelBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

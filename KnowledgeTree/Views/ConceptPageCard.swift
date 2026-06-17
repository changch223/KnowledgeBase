//
//  ConceptPageCard.swift
//  KnowledgeTree
//
//  spec 042 — 知識 Clip タブ「あなたが追っている人物・モノ」セクションのカード。
//  タップで ConceptPageDetailView に遷移する (NavigationLink は親 view 側で配線)。
//

import SwiftUI

struct ConceptPageCard: View {
    @Bindable var conceptPage: ConceptPage

    /// 関連記事数。Card preview に表示。
    private var relatedCount: Int { (conceptPage.relatedArticles ?? []).count }

    /// 1 行表示用。spec 080: 答え先出しで先頭の要点 (crossSourceInsights) を優先、無ければ summary。
    /// 空 or stale 時は「整理中…」placeholder。
    private var previewText: String {
        if let point = conceptPage.crossSourceInsights
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return point
        }
        if conceptPage.isSynthesisInProgress {
            return String(localized: "ConceptPage.card.synthesisInProgress")
        }
        return conceptPage.summaryPreview
    }

    /// categoryRaw に応じた SF Symbol (簡易マッピング、デフォルトは tag.fill)。
    private var iconName: String {
        let category = CategorySeed.category(for: conceptPage.categoryRaw).englishName
        switch category {
        case "Technology": return "cpu"
        case "Economy":    return "chart.line.uptrend.xyaxis"
        case "Health":     return "heart.fill"
        case "Design":     return "paintbrush.fill"
        case "Academic":   return "book.fill"
        case "Art":        return "paintpalette.fill"
        case "News":       return "newspaper.fill"
        case "Sports":     return "figure.run"
        case "Entertainment": return "tv.fill"
        default:           return "tag.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(DS.Color.actionBlue)
                .frame(width: 32, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    Text(conceptPage.name)
                        .font(.body.bold())
                        .lineLimit(1)
                    if conceptPage.isFollowing {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(DS.Color.actionBlue)
                            .accessibilityHidden(true)
                    }
                    Spacer(minLength: DS.Spacing.xs)
                    Text(String(format: String(localized: "ConceptPage.card.relatedCount"), relatedCount))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(previewText)
                    .font(.caption)
                    .foregroundStyle(conceptPage.isSynthesisInProgress ? .tertiary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(SavedAtFormatter.format(conceptPage.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCardBackground()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(conceptPage.name), 関連記事 \(relatedCount) 件, \(previewText)")
        .accessibilityIdentifier("conceptPageCard_\(conceptPage.id.uuidString)")
    }
}

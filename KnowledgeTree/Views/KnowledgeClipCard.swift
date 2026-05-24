//
//  KnowledgeClipCard.swift
//  KnowledgeTree
//
//  spec 018 — 1 つの KnowledgeDigest を表示するカード view。
//  Category 名 + 元記事数 + savedAt + stale マーク + 小 OG +
//  統合 summary + KeyFact 3 + EntityChip 3。
//
//  spec 051 Phase A: CloudKit sync 環境で `digest.topKeyFacts` 等を直接アクセスすると
//  detached backing data crash が稀に発生 (CloudKit が SwiftData @Model を sync 中に
//  invalidate するタイミング)。defensive snapshot pattern で init 時に値を抜き出し、
//  body では snapshot だけを参照する (@Model 直接アクセスゼロ)。
//

import SwiftUI

struct KnowledgeClipCard: View {
    /// spec 051 Phase A: detached crash 回避のため init 時 snapshot。
    /// 元 KnowledgeDigest 参照は保持しない (CloudKit sync で invalidate されても影響なし)。
    private let snapshot: DigestSnapshot

    init(digest: KnowledgeDigest) {
        // SwiftData @Model のプロパティを init 時に値型に copy (defensive snapshot)
        self.snapshot = DigestSnapshot(
            categoryRaw: digest.categoryRaw,
            cardIndex: digest.cardIndex,
            isStale: digest.isStale,
            summary: digest.summary,
            topKeyFacts: digest.topKeyFacts,
            topEntityNames: digest.topEntityNames,
            sourceArticleCount: digest.sourceArticles.count,
            latestArticleSavedAt: digest.sourceArticles.map(\.savedAt).max(),
            firstOgImageURL: digest.sourceArticles.compactMap(\.enrichment?.ogImageURL).first
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            headerSection
            summarySection
            keyFactsSection
            entityChipsSection
        }
        .padding(DS.Spacing.xxl)
        .dsCardBackground()
        .accessibilityIdentifier("clip.card.\(snapshot.categoryRaw).\(snapshot.cardIndex)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(combinedAccessibilityLabel)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(snapshot.categoryRaw)
                    .font(DS.Typography.sectionTitle)
                    .foregroundStyle(.primary)

                HStack(spacing: DS.Spacing.sm) {
                    Text("\(snapshot.sourceArticleCount) 記事から")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let latestSavedAt = snapshot.latestArticleSavedAt {
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

            if snapshot.isStale {
                Text("clip.card.staleLabel")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.actionBlue)
                    .accessibilityIdentifier("clip.card.staleMark")
            }

            if let ogURL = snapshot.firstOgImageURL {
                ThumbnailView(urlString: ogURL)
                    .frame(width: 48, height: 48)
            }
        }
    }

    private var summarySection: some View {
        Text(snapshot.summary)
            .font(.body)
            .lineSpacing(DS.Typography.bodyLineSpacing)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var keyFactsSection: some View {
        if !snapshot.topKeyFacts.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                ForEach(snapshot.topKeyFacts, id: \.self) { fact in
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
        if !snapshot.topEntityNames.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DS.Spacing.sm) {
                    ForEach(snapshot.topEntityNames, id: \.self) { name in
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
        parts.append(snapshot.categoryRaw)
        parts.append("\(snapshot.sourceArticleCount) 記事")
        if snapshot.isStale {
            parts.append("更新あり")
        }
        if !snapshot.summary.isEmpty {
            parts.append(snapshot.summary)
        }
        if !snapshot.topKeyFacts.isEmpty {
            parts.append("ポイント: " + snapshot.topKeyFacts.joined(separator: "、"))
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Defensive snapshot (spec 051 Phase A)

/// KnowledgeDigest @Model の値を init 時に snapshot して view 内で使う構造体。
/// SwiftData @Model 直接アクセスゼロにすることで、CloudKit sync 中の
/// detached backing data crash を予防する。
private struct DigestSnapshot {
    let categoryRaw: String
    let cardIndex: Int
    let isStale: Bool
    let summary: String
    let topKeyFacts: [String]
    let topEntityNames: [String]
    let sourceArticleCount: Int
    let latestArticleSavedAt: Date?
    let firstOgImageURL: String?
}

//
//  InterestingNextSection.swift
//  KnowledgeTree
//
//  spec 056 — 知識 Clip タブ 2 番目セクション「続きが気になるもの」(For You)。
//  ConceptPage 深掘りカード (UnderstandingCardSurfaceService 経由) +
//  Topic Dashboard カード (KnowledgeDigest 統合) を MixedSurfaceCard で
//  1 list 内に混在表示。
//

import SwiftUI
import SwiftData

struct InterestingNextSection: View {
    @Environment(\.modelContext) private var context
    @Environment(ServiceContainer.self) private var services
    @Environment(RefreshTrigger.self) private var refreshTrigger

    @Query(
        sort: [SortDescriptor(\KnowledgeDigest.generatedAt, order: .reverse)]
    )
    private var allDigests: [KnowledgeDigest]

    @State private var understandingCards: [UnderstandingCard] = []
    @State private var isLoading: Bool = false

    /// 上位 5 件 (混在ソート、priorityScore 降順)。
    private var topCards: [MixedSurfaceCard] {
        let understanding = understandingCards.map { MixedSurfaceCard.understanding($0) }
        let digests = allDigests.prefix(10).map { MixedSurfaceCard.digest($0) }
        let combined = (understanding + digests)
            .sorted { $0.priorityScore > $1.priorityScore }
        return Array(combined.prefix(5))
    }

    private var totalCount: Int {
        understandingCards.count + allDigests.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("knowledgeClip.section.interestingNext")
                    .font(.headline)
                Spacer()
                if totalCount > 5 {
                    NavigationLink(value: UnderstandingCardListDestination()) {
                        Text("knowledgeClip.moreLink")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xxl)

            if topCards.isEmpty {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.xxl)
                } else {
                    ContentUnavailableView(
                        "knowledgeClip.empty.interestingNext",
                        systemImage: "lightbulb",
                        description: Text("knowledgeClip.empty.interestingNext.body")
                    )
                    .padding(.vertical, DS.Spacing.xxl)
                }
            } else {
                LazyVStack(spacing: DS.Spacing.md) {
                    ForEach(topCards) { card in
                        navigationLinkForCard(card)
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)
            }
        }
        .accessibilityIdentifier("section.interestingNext")
        .task {
            await refresh()
        }
        .onChange(of: refreshTrigger.version) { _, _ in
            Task { await refresh() }
        }
    }

    @ViewBuilder
    private func navigationLinkForCard(_ card: MixedSurfaceCard) -> some View {
        switch card {
        case .understanding(let understandingCard):
            NavigationLink(value: understandingCard) {
                MixedSurfaceCardRow(card: card)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("interestingNext.card.understanding.\(understandingCard.id.uuidString)")

        case .digest(let digest):
            let category = CategorySeed.category(for: digest.categoryRaw)
            NavigationLink(value: CategoryDigestDetailDestination(category: category)) {
                MixedSurfaceCardRow(card: card)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("interestingNext.card.digest.\(digest.id.uuidString)")
        }
    }

    private func refresh() async {
        guard let surface = services.understandingCardSurfaceService else { return }
        isLoading = true
        defer { isLoading = false }
        understandingCards = await surface.surfaceTopCards(limit: 10)
    }
}

private struct MixedSurfaceCardRow: View {
    let card: MixedSurfaceCard

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: card.iconName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(card.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                if !card.displaySubtitle.isEmpty {
                    Text(card.displaySubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(card.labelText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(DS.Spacing.lg)
        .background(DS.Color.surfaceSecondary, in: .rect(cornerRadius: DS.Radius.chip))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.chip)
                .stroke(DS.Color.aiBrandEdge.opacity(0.3), lineWidth: 0.5)
        )
    }
}

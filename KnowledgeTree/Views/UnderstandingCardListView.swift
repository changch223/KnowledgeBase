//
//  UnderstandingCardListView.swift
//  KnowledgeTree
//
//  spec 044 — 学習タブ「+N すべて見る」遷移先。全 surface 候補を LazyVStack で表示。
//

import SwiftUI

struct UnderstandingCardListView: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(RefreshTrigger.self) private var refreshTrigger

    @State private var cards: [UnderstandingCard] = []
    @State private var isLoading: Bool = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.xl) {
                if isLoading && cards.isEmpty {
                    ProgressView().padding(.top, DS.Spacing.xxxl)
                } else if cards.isEmpty {
                    ContentUnavailableView(
                        "interestingNext.empty.title",
                        systemImage: "lightbulb",
                        description: Text("interestingNext.empty.body")
                    )
                    .padding(.top, DS.Spacing.xxxl)
                } else {
                    ForEach(cards) { card in
                        NavigationLink(value: card) {
                            UnderstandingCardRow(card: card)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.vertical, DS.Spacing.xl)
        }
        .navigationTitle(Text("学ぶカード一覧"))
        .task { await refresh() }
        .refreshable { await refresh() }
        .onChange(of: refreshTrigger.version) { _, _ in
            Task { await refresh() }
        }
    }

    private func refresh() async {
        guard let surfaceService = services.understandingCardSurfaceService else { return }
        isLoading = true
        defer { isLoading = false }
        cards = await surfaceService.surfaceAllCards()
    }
}

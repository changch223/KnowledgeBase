//
//  UnderstandingTabView.swift
//  KnowledgeTree
//
//  spec 044 — 学習タブ (4 タブ構成の 1 番目、起動 default)。
//  Karpathy 家庭教師ループの入口。
//
//  - 上位 5 件の UnderstandingCard を surface
//  - 「+N すべて見る」で UnderstandingCardListView に遷移
//  - カードタップで DeepDiveChatView に遷移
//  - 候補ゼロで空状態 placeholder
//

import SwiftUI
import SwiftData

struct UnderstandingTabView: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(RefreshTrigger.self) private var refreshTrigger
    @Environment(\.modelContext) private var modelContext

    @State private var cards: [UnderstandingCard] = []
    @State private var allCount: Int = 0
    @State private var isLoading: Bool = false
    @State private var hasLoadedOnce: Bool = false
    /// spec 052: NavigationStack の path、Widget deep link で programmatic push に使う。
    @State private var path = NavigationPath()

    private let topLimit: Int = 5

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    // spec 048: AI 機能が使えない端末 / 状態の説明 banner
                    if let reason = services.availabilityChecker?.unavailabilityReason {
                        AppleIntelligenceBanner(reason: reason)
                    }
                    contentBody
                }
                .padding(.horizontal, DS.Spacing.xxl)
                .padding(.vertical, DS.Spacing.xl)
            }
            .navigationTitle(Text("学習"))
            .navigationDestination(for: UnderstandingCard.self) { card in
                DeepDiveChatView(card: card)
            }
            .navigationDestination(for: UnderstandingCardListDestination.self) { _ in
                UnderstandingCardListView()
            }
            .task {
                if !hasLoadedOnce {
                    await refresh()
                    hasLoadedOnce = true
                }
            }
            .refreshable {
                await refresh()
            }
            .onChange(of: refreshTrigger.version) { _, _ in
                Task { await refresh() }
            }
            // spec 052: Widget deep link で pendingDeepLinkCardID がセットされたら
            // 該当 ConceptPage / SavedAnswer を resolve → DeepDiveChatView を programmatic push。
            .onChange(of: services.pendingDeepLinkCardID) { _, new in
                guard let cardID = new else { return }
                if let card = resolveCard(id: cardID) {
                    path.append(card)
                }
                // consume (再 push 防止)
                services.pendingDeepLinkCardID = nil
            }
        }
    }

    /// spec 052: UUID から ConceptPage or SavedAnswer を fetch して UnderstandingCard に wrap。
    private func resolveCard(id: UUID) -> UnderstandingCard? {
        // ConceptPage を先に試す
        let pageDesc = FetchDescriptor<ConceptPage>(predicate: #Predicate { $0.id == id })
        if let page = (try? modelContext.fetch(pageDesc))?.first {
            return UnderstandingCard.fromConceptPage(page)
        }
        // SavedAnswer を試す
        let answerDesc = FetchDescriptor<SavedAnswer>(predicate: #Predicate { $0.id == id })
        if let answer = (try? modelContext.fetch(answerDesc))?.first {
            return UnderstandingCard.fromSavedAnswer(answer)
        }
        return nil
    }

    @ViewBuilder
    private var contentBody: some View {
        if isLoading && cards.isEmpty {
            ProgressView()
                .padding(.top, DS.Spacing.xxxl)
        } else if cards.isEmpty {
            UnderstandingEmptyState()
                .padding(.top, DS.Spacing.xxxl)
        } else {
            ForEach(cards) { card in
                NavigationLink(value: card) {
                    UnderstandingCardRow(card: card)
                }
                .buttonStyle(.plain)
            }
            if allCount > cards.count {
                NavigationLink(value: UnderstandingCardListDestination()) {
                    HStack {
                        Spacer()
                        Text("+\(allCount - cards.count) すべて見る")
                            .font(.callout)
                            .foregroundStyle(DS.Color.actionBlue)
                        Spacer()
                    }
                    .padding(.vertical, DS.Spacing.lg)
                }
                .accessibilityIdentifier("link.allCards")
            }
        }
    }

    private func refresh() async {
        guard let surfaceService = services.understandingCardSurfaceService else { return }
        isLoading = true
        defer { isLoading = false }
        let top = await surfaceService.surfaceTopCards(limit: topLimit)
        let all = await surfaceService.surfaceAllCards()
        cards = top
        allCount = all.count
    }
}

// MARK: - UnderstandingEmptyState

struct UnderstandingEmptyState: View {
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Image(systemName: "book.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("まだ学ぶカードがありません。記事を保存したり AI チャットで質問してみましょう")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xxl)
        }
        .accessibilityIdentifier("state.understanding.empty")
    }
}

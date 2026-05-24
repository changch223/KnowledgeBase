//
//  KnowledgeClipView.swift
//  KnowledgeTree
//
//  spec 056 — V3.0 redesign: 8 セクション → 3 セクションに削減。
//  「気になったものが、勝手に整理される」体験の中核タブ (Today)。
//
//  セクション順 (固定):
//   1. RecentArticlesSection — 最近の記事 (差分 3 件、cache 維持)
//   2. InterestingNextSection — 続きが気になるもの (ConceptPage 深掘り + Topic Dashboard 混在)
//   3. FollowingPeopleSection — 追っている人物・モノ (isFollowing + ⚠️ 更新が必要 badge)
//
//  右上 toolbar: AvatarMenu (Settings 遷移)
//  contracts/knowledge-clip-view.md 準拠。
//

import SwiftUI
import SwiftData

struct KnowledgeClipView: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(ProcessingMonitor.self) private var monitor
    @State private var path = NavigationPath()
    /// spec 035 + 056: タブ表示時に lock した「前回開いた時刻」(view ライフタイム中は固定)
    @State private var sinceForRecent: Date?
    /// spec 056: FAB tap で URL 入力 sheet
    @State private var showAddArticle: Bool = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: DS.Spacing.xxl) {
                    if let since = sinceForRecent {
                        RecentArticlesSection(since: since)
                    }
                    InterestingNextSection()
                    FollowingPeopleSection()
                }
                .padding(.vertical, DS.Spacing.xxl)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("clip.tab.title")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AvatarMenu()
                }
            }
            // 既存 navigationDestination (V2.5 から継承、機能維持)
            .navigationDestination(for: CategoryDigestDetailDestination.self) { dest in
                CategoryKnowledgeDetailView(category: dest.category)
            }
            .navigationDestination(for: Article.self) { article in
                ArticleDetailView(article: article, embedNavigationStack: false)
            }
            .navigationDestination(for: ConceptPageDetailDestination.self) { dest in
                ConceptPageDetailLoader(destinationID: dest.id)
            }
            .navigationDestination(for: ConceptPageListDestination.self) { _ in
                ConceptPageListView()
            }
            .navigationDestination(for: SavedAnswerDetailDestination.self) { dest in
                SavedAnswerDetailLoader(destinationID: dest.id)
            }
            .navigationDestination(for: SavedAnswerListByConceptDestination.self) { _ in
                SavedAnswerHistoryView()
            }
            .navigationDestination(for: SavedAnswerHistoryDestination.self) { _ in
                SavedAnswerHistoryView()
            }
            // spec 056: 新規 destinations
            .navigationDestination(for: UnderstandingCardListDestination.self) { _ in
                UnderstandingCardListView()
            }
            .navigationDestination(for: ActionItemsReviewDestination.self) { _ in
                ActionItemsReviewView()
            }
            // spec 044: 学習タブ root 削除後の DeepDiveChatView 動線継続 (UnderstandingCard 経由)
            .navigationDestination(for: UnderstandingCard.self) { card in
                DeepDiveChatView(card: card)
            }
            .refreshable {
                try? await services.digestService?.regenerateAllStale()
            }
            .overlay(alignment: .bottomTrailing) {
                FABButton(icon: "plus") {
                    showAddArticle = true
                }
                .accessibilityIdentifier("fab.addArticle")
            }
            .sheet(isPresented: $showAddArticle) {
                AddArticleSheet()
            }
            .accessibilityIdentifier("clip.scroll")
        }
        .accessibilityIdentifier("tab.knowledgeClip")
        .task {
            captureRecentSinceAndTouch()
        }
        // spec 052 + 056: Widget deep link 受信時の card push 遷移
        .onChange(of: services.pendingDeepLinkCardID) { _, newID in
            guard let newID else { return }
            Task {
                if let card = await loadCardFromDeepLink(cardID: newID) {
                    path.append(card)
                }
                services.pendingDeepLinkCardID = nil
            }
        }
    }

    /// spec 035 + 056: タブ初表示時に lastOpenedAt を取得 (差分起点)、その後現在時刻で touch。
    /// view ライフタイム中は sinceForRecent を固定し、表示中に差分が空にならないようにする。
    private func captureRecentSinceAndTouch() {
        guard let store = services.lastOpenedStore else { return }
        let since = store.lastOpenedAt ?? Date.distantPast
        if sinceForRecent == nil {
            sinceForRecent = since
        }
        store.touch()
    }

    /// Widget deep link 経由で card ID から UnderstandingCard を解決。
    /// 既存 ConceptPage を fetch → fromConceptPage で wrap。
    @MainActor
    private func loadCardFromDeepLink(cardID: UUID) async -> UnderstandingCard? {
        guard let context = services.understandingCardSurfaceService else { return nil }
        _ = context  // suppress unused warning - actual fetch is via @Environment
        // ID で ConceptPage fetch
        let cpDescriptor = FetchDescriptor<ConceptPage>(
            predicate: #Predicate { $0.id == cardID }
        )
        if let modelContext = try? ModelContext(.init(for: ConceptPage.self)) {
            _ = modelContext  // can't easily access global context here
        }
        // 実際には surface service 経由で全 card を取り出して該当 ID を探す
        let allCards = await services.understandingCardSurfaceService?.surfaceAllCards() ?? []
        return allCards.first { $0.id == cardID }
    }
}

// MARK: - Navigation Destinations (V2.5 から維持)

struct CategoryDigestDetailDestination: Hashable {
    let category: Category
}

// MARK: - spec 042: ConceptPage detail loader (reactive auto-pop)

/// ConceptPageDetailDestination の id から ConceptPage を fetch して DetailView を表示する loader。
/// **@Query で reactive 観測**: merge/delete で page が消えた瞬間に `page == nil` になり、
/// auto-dismiss で navigation stack を pop。これで DetailView の @Bindable conceptPage が
/// 削除済 @Model を参照し続けて crash する問題を防ぐ (2026-05-23 fix)。
struct ConceptPageDetailLoader: View {
    let destinationID: UUID
    @Environment(\.dismiss) private var dismiss
    @Query private var matchingPages: [ConceptPage]

    init(destinationID: UUID) {
        self.destinationID = destinationID
        let id = destinationID
        _matchingPages = Query(filter: #Predicate<ConceptPage> { $0.id == id })
    }

    var body: some View {
        Group {
            if let page = matchingPages.first {
                ConceptPageDetailView(conceptPage: page)
            } else {
                Color.clear
                    .onAppear { dismiss() }
            }
        }
    }
}

/// 「+N すべて見る」遷移先の全 ConceptPage 一覧画面 (LazyVStack)。
struct ConceptPageListView: View {
    @Query(
        sort: [SortDescriptor(\ConceptPage.updatedAt, order: .reverse)]
    )
    private var allPagesRaw: [ConceptPage]

    private var allPages: [ConceptPage] {
        allPagesRaw.filter { !(($0.relatedArticles) ?? []).isEmpty }.sorted { lhs, rhs in
            if lhs.isFollowing != rhs.isFollowing { return lhs.isFollowing }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    init() {}

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.xxl) {
                ForEach(allPages, id: \.id) { page in
                    NavigationLink(value: ConceptPageDetailDestination(id: page.id)) {
                        ConceptPageCard(conceptPage: page)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, DS.Spacing.xxl)
                }
            }
            .padding(.vertical, DS.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("ConceptPage.list.navigationTitle")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("conceptPageList_root")
    }
}

// MARK: - spec 043: SavedAnswerDetailLoader

/// SavedAnswerDetailDestination の id から SavedAnswer を fetch して DetailView を表示する loader。
/// @Query で reactive 観測: merge/delete で SavedAnswer が消えた瞬間に `matchingAnswers` が空に、
/// auto-dismiss で navigation stack を pop (spec 042 ConceptPageDetailLoader と同パターン)。
struct SavedAnswerDetailLoader: View {
    let destinationID: UUID
    @Environment(\.dismiss) private var dismiss
    @Query private var matchingAnswers: [SavedAnswer]

    init(destinationID: UUID) {
        self.destinationID = destinationID
        let id = destinationID
        _matchingAnswers = Query(filter: #Predicate<SavedAnswer> { $0.id == id })
    }

    var body: some View {
        Group {
            if let answer = matchingAnswers.first {
                SavedAnswerDetailView(answer: answer)
            } else {
                Color.clear
                    .onAppear { dismiss() }
            }
        }
    }
}

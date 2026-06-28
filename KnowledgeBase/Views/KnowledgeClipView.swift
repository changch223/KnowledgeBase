//
//  KnowledgeClipView.swift
//  KnowledgeTree
//
//  「iKnow」タブ — 概念(まとめ)中心のフィード (spec 075/080/087/088 で再設計)。
//  新着記事の横棚 + For You Wiki 棚 + 概念の超まとめ縦カード + カテゴリ/タグ ハイライト。
//  「気になったものが、勝手に整理される」体験の中核タブ。
//
//  ※ 旧 V3.0 の 3 section view (RecentArticlesSection / InterestingNextSection /
//    FollowingPeopleSection) は spec 075 以降で未使用になり、spec 102 で削除した。
//
//  右上 toolbar: AvatarMenu (Settings 遷移)
//

import SwiftUI
import SwiftData

struct KnowledgeClipView: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(ProcessingMonitor.self) private var monitor
    @Environment(\.modelContext) private var modelContext
    /// spec 080拡張: アプリ復帰で「重要×最新×既読」並びを更新する契機。
    @Environment(\.scenePhase) private var scenePhase
    @State private var path = NavigationPath()
    /// spec 080拡張: フィード表示順の session snapshot (スクロール/詳細往復で再並びしない)。
    /// .task / アプリ復帰 / 引っ張り更新で更新 → 既読が下がる「次回」並び替え。
    @State private var orderedConceptIDs: [UUID] = []
    /// spec 035 + 056: タブ表示時に lock した「前回開いた時刻」(view ライフタイム中は固定)
    @State private var sinceForRecent: Date?
    /// spec 056: FAB tap で URL 入力 sheet
    @State private var showAddArticle: Bool = false
    /// spec 056 polish: V2.5 → V3.0 初回起動 1 回限りの tooltip 表示
    @State private var showV3Tooltip: Bool = false

    // spec 066 (News+ フィード): 記事 + Wiki 更新を @Query で取り、FeedBuilder.assemble で
    // 時系列 mix。@Query ゆえ保存/更新で自動反映 (reactive)。AI 呼び出しゼロ。
    @Query(sort: \Article.savedAt, order: .reverse) private var feedArticles: [Article]
    @Query(
        filter: #Predicate<ConceptPage> { !$0.isHidden },
        sort: [SortDescriptor(\ConceptPage.updatedAt, order: .reverse)]
    )
    private var feedWikiPages: [ConceptPage]
    /// spec 075: 縦フィードの主役 = トップレベル概念 (広い概念 + 孤立 specific)。
    /// 子 specific を畳み込み、記事数を解決した ConceptFeedEntry を updatedAt 降順で返す。
    private var conceptEntries: [ConceptFeedEntry] {
        FeedBuilder.topLevelConcepts(pages: feedWikiPages, now: Date())
    }

    /// spec 080拡張: 表示順は session snapshot に固定 (既読化やスクロールで live 再並びしない)。
    /// snapshot に無い新概念は先頭 (新着=重要)。snapshot 未設定 (初回前) は fresh-first をそのまま。
    private var displayedConceptEntries: [ConceptFeedEntry] {
        let entries = conceptEntries
        guard !orderedConceptIDs.isEmpty else { return entries }
        let byID = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let known = Set(orderedConceptIDs)
        let newcomers = entries.filter { !known.contains($0.id) }
        let snapshotOrdered = orderedConceptIDs.compactMap { byID[$0] }
        return newcomers + snapshotOrdered
    }

    /// spec 080拡張: 並び順 snapshot を現在の fresh-first 順で取り直す (.task / 復帰 / 更新時)。
    private func refreshFeedOrder() {
        orderedConceptIDs = conceptEntries.map(\.id)
    }

    /// spec 080拡張: カードを見たら既読化 (未読のときだけ書込、live 再並びは snapshot で防ぐ)。
    private func markConceptSeen(_ page: ConceptPage) {
        guard FeedBuilder.isFresh(page) else { return }
        page.lastSeenAt = .now
        try? modelContext.save()
    }

    /// spec 075: 上部「新着」棚 = まだ概念に束ねられていない新着記事。概念化されると消える。
    private var newShelfArticles: [Article] {
        FeedBuilder.newArticleShelf(articles: feedArticles, now: Date())
    }

    /// spec 087: 「おすすめのまとめ」横列の表示フラグ (一旦非表示)。true で復活。
    private static let showRecommendCarousel = false

    /// spec 075: 「おすすめのまとめ」横棚 (一番上)。トップレベル概念を活動量+recency で上位 N。
    /// 既存 RecommendCarousel / WikiShelfCard を流用するため FeedItem.wikiUpdate に map。
    private var recommendItems: [FeedItem] {
        FeedBuilder.recommendConcepts(pages: feedWikiPages, now: Date()).map { .wikiUpdate($0) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: DS.Spacing.xxl) {
                    // spec 075: 上部「新着」棚 — まだ概念化されていない新着記事 (概念化で消える)。
                    if !newShelfArticles.isEmpty {
                        newArticleShelf
                    }

                    // spec 075: 「おすすめのまとめ」横棚 — トップレベル概念。候補不足なら非表示。
                    // spec 087: 一旦非表示 (コードは残置、復活は showRecommendCarousel = true)。
                    if Self.showRecommendCarousel, recommendItems.count >= FeedBuilder.carouselMinItems {
                        RecommendCarousel(items: recommendItems)
                    }

                    if displayedConceptEntries.isEmpty {
                        SeigaihaEmptyState(message: "clip.empty.concepts")
                    } else {
                        // 北斎スタイル見出し
                        SumiSectionHeader(title: "clip.section.concepts")

                        // spec 075: 縦フィードの主役 = 概念「超まとめ」カード。
                        // spec 080拡張: snapshot 順で表示 + 見たら既読化 (onSeen)。
                        ForEach(displayedConceptEntries) { entry in
                            ConceptSummaryCard(entry: entry, onSeen: { markConceptSeen(entry.page) })
                        }
                    }
                }
                .padding(.vertical, DS.Spacing.xxl)
            }
            .scrollIndicators(.hidden)
            .background(DS.Color.washiBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle("clip.nav.title")
            .navigationBarTitleDisplayMode(.large)
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
            // spec 058: ActionItemsReviewView 削除 (Confirm UX 廃止、AI 自動採用に移行)
            // spec 044: 学習タブ root 削除後の DeepDiveChatView 動線継続 (UnderstandingCard 経由)
            .navigationDestination(for: UnderstandingCard.self) { card in
                DeepDiveChatView(card: card)
            }
            // spec 058 polish: 「分野ごとの活動」section から Category 詳細遷移
            .navigationDestination(for: CategoryFilteredDestination.self) { dest in
                CategoryFilteredListView(category: dest.category)
            }
            // spec 068: タグハイライトカード → タグ別記事一覧
            .navigationDestination(for: TagFilteredDestination.self) { dest in
                TagFilteredListView(tagName: dest.tagName)
            }
            // V3.0 polish (2026-05-27): 「最近の Know」ヘッドライン tap → 詳細画面
            .navigationDestination(for: RecentLearningDetailDestination.self) { dest in
                RecentLearningDetailView(since: dest.since)
            }
            .refreshable {
                try? await services.digestService?.regenerateAllStale()
                refreshFeedOrder()  // spec 080拡張: 引っ張り更新で重要×最新×既読 並びを取り直す
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
            checkV3MigrationTooltip()
            refreshFeedOrder()  // spec 080拡張: 初回表示時に並び順 snapshot を確定
        }
        // spec 080拡張: アプリ復帰 (.active) で並び順を取り直す → 既読が下がる「次回」並び替え
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { refreshFeedOrder() }
        }
        // spec 056 polish: V3 migration tooltip (初回起動 1 回限り)
        .overlay(alignment: .top) {
            if showV3Tooltip {
                V3MigrationTooltip {
                    UserDefaults.standard.set(true, forKey: "spec056_v3_migrated")
                    withAnimation(.easeOut(duration: 0.3)) {
                        showV3Tooltip = false
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)
                .padding(.top, DS.Spacing.md)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
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

    /// spec 075: 上部「新着」棚 — まだ概念に束ねられていない新着記事を横スクロールで。
    /// 既存 ArticleShelfCard 流用。概念化されると newShelfArticles から外れて自動的に消える。
    private var newArticleShelf: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SumiSectionHeader(title: "feed.new.title")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DS.Spacing.md) {
                    ForEach(newShelfArticles, id: \.id) { article in
                        ArticleShelfCard(article: article)
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityIdentifier("clip.newShelf")
    }

    /// spec 066: フィードが空のときの穏やかな空状態。
    private var feedEmptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("clip.recent.empty")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.section)
        .padding(.horizontal, DS.Spacing.xxl)
    }

    /// spec 056 polish: V3 migration tooltip の表示判定 (初回起動 1 回限り)。
    private func checkV3MigrationTooltip() {
        let key = "spec056_v3_migrated"
        if !UserDefaults.standard.bool(forKey: key) {
            withAnimation(.easeIn(duration: 0.4).delay(0.5)) {
                showV3Tooltip = true
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
        guard services.understandingCardSurfaceService != nil else { return nil }
        // surface service 経由で全 card を取り出して該当 ID を探す
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
    // spec 063 (LLM Wiki): 非表示ページ (isHidden) は除外。
    @Query(
        filter: #Predicate<ConceptPage> { !$0.isHidden },
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

// MARK: - spec 056 polish: V3 migration tooltip

/// V2.5 → V3.0 アップデート時の初回起動で 1 回だけ表示する「タブが新しくなりました」 tooltip。
/// UserDefaults `spec056_v3_migrated` flag で永続的に dismiss を記録。
private struct V3MigrationTooltip: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("knowledgeClip.v3.tooltip.title")
                        .font(.headline)
                    Text("knowledgeClip.v3.tooltip.body")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
                .accessibilityIdentifier("v3Tooltip.dismiss")
                .accessibilityLabel(Text("knowledgeClip.v3.tooltip.ok"))
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(DS.Color.surfaceSecondary)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .accessibilityIdentifier("v3Tooltip")
    }
}

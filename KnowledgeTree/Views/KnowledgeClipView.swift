//
//  KnowledgeClipView.swift
//  KnowledgeTree
//
//  spec 018 — 「知識 Clip」タブ root。
//  Category 単位で AI 統合された Digest カードを縦スクロール表示。
//  期間フィルター (全部 / 7 日 / 30 日) + pull-to-refresh。
//
//  contracts/knowledge-clip-view.md 準拠。
//

import SwiftUI
import SwiftData

struct KnowledgeClipView: View {
    @Query(sort: \KnowledgeDigest.cardIndex) private var allDigests: [KnowledgeDigest]
    @Query private var allArticles: [Article]
    @Environment(ServiceContainer.self) private var services
    @Environment(ProcessingMonitor.self) private var monitor
    @State private var period: TimeFilter = .all
    @State private var path = NavigationPath()
    /// spec 018 fix: 初回 / 既存記事 → Digest 生成中フラグ
    @State private var isGenerating: Bool = false
    /// spec 035: タブ表示時に lock した「前回開いた時刻」(view ライフタイム中は固定で差分が消えない)
    @State private var sinceForRecent: Date?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: DS.Spacing.xxl) {
                    // spec 035: 最上部に「最近のあなた」セクション
                    if let since = sinceForRecent {
                        RecentDigestSection(since: since)
                    }
                    // spec 037: 事実更新の提案
                    FactConflictsSection()
                    // spec 041: AI が見つけた graph 仮説 (isUncertain edge レビュー)
                    GraphProposalsSection()
                    // spec 036: 動的トピック (候補 + 採用済)
                    DynamicTopicsSection()
                    timeFilterChips
                    digestsContent
                }
                .padding(.vertical, DS.Spacing.xxl)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("clip.tab.title")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: CategoryDigestDetailDestination.self) { dest in
                CategoryKnowledgeDetailView(category: dest.category)
            }
            .navigationDestination(for: UserTopicDestination.self) { dest in
                UserTopicDetailView(topicID: dest.topicID)
            }
            .navigationDestination(for: Article.self) { article in
                ArticleDetailView(article: article)
            }
            .refreshable {
                try? await services.digestService?.regenerateAllStale()
            }
            .accessibilityIdentifier("clip.scroll")
        }
        .accessibilityIdentifier("clip.root")
        .task {
            await tryInitialGeneration()
            captureRecentSinceAndTouch()
        }
    }

    /// spec 035: タブ初表示時に lastOpenedAt を取得 (差分起点)、その後現在時刻で touch。
    /// view ライフタイム中は sinceForRecent を固定し、表示中に差分が空にならないようにする。
    private func captureRecentSinceAndTouch() {
        guard let store = services.lastOpenedStore else { return }
        let since = store.lastOpenedAt ?? Date.distantPast
        if sinceForRecent == nil {
            sinceForRecent = since
        }
        store.touch()
    }

    /// 初回 (or 既存記事ありで Digest 0 件) の状態で自動生成を起動。
    /// 記事ゼロや essence ゼロ、すでに Digest 存在時は no-op。
    private func tryInitialGeneration() async {
        guard hasArticles, hasAnyEssence, allDigests.isEmpty, !isGenerating else { return }
        guard let digestService = services.digestService else { return }
        isGenerating = true
        defer { isGenerating = false }
        try? await digestService.regenerateAllStale()
    }

    // MARK: - Computed Properties

    private var filteredDigests: [KnowledgeDigest] {
        guard let cutoff = period.cutoffDate else { return allDigests }
        return allDigests.filter { digest in
            digest.sourceArticles.contains { $0.savedAt >= cutoff }
        }
    }

    private var digestsByCategory: [(Category, [KnowledgeDigest])] {
        let grouped = Dictionary(grouping: filteredDigests) { $0.categoryRaw }
        return grouped
            .compactMap { (rawName, digests) -> (Category, [KnowledgeDigest])? in
                let category = CategorySeed.allSeeds.first { $0.name == rawName }
                    ?? CategorySeed.otherCategory
                return (category, digests.sorted { $0.cardIndex < $1.cardIndex })
            }
            .sorted { lhs, rhs in
                let lhsLatest = lhs.1
                    .flatMap(\.sourceArticles)
                    .map(\.savedAt)
                    .max() ?? .distantPast
                let rhsLatest = rhs.1
                    .flatMap(\.sourceArticles)
                    .map(\.savedAt)
                    .max() ?? .distantPast
                return lhsLatest > rhsLatest
            }
    }

    private var hasArticles: Bool {
        !allArticles.isEmpty
    }

    private var hasAnyEssence: Bool {
        allArticles.contains { article in
            article.extractedKnowledge?.essence?.isEmpty == false
        }
    }

    // MARK: - Sections

    private var timeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(TimeFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation { period = filter }
                    } label: {
                        Text(filter.labelKey)
                            .font(DS.Typography.chipLabel)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(
                                period == filter ? DS.Color.actionBlue : DS.Color.tagFill,
                                in: Capsule()
                            )
                            .foregroundStyle(period == filter ? Color.white : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("clip.filter.\(filter.rawValue)")
                }
            }
        }
        .accessibilityIdentifier("clip.timeFilter")
    }

    @ViewBuilder
    private var digestsContent: some View {
        if !hasArticles {
            // 記事 0 件 — Empty state
            ContentUnavailableView(
                "clip.empty.title",
                systemImage: "lightbulb",
                description: Text("clip.empty.description")
            )
            .accessibilityIdentifier("clip.empty")
        } else if !hasAnyEssence {
            // 記事はあるが essence 未生成 — 抽出中プレースホルダ
            VStack(spacing: DS.Spacing.lg) {
                ProgressView()
                Text("clip.extracting.title")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xxxl)
            .accessibilityIdentifier("clip.extracting")
        } else if allDigests.isEmpty || isGenerating {
            // 記事 + essence あるが Digest 未生成 — 初回 AI 生成中
            VStack(spacing: DS.Spacing.lg) {
                ProgressView()
                Text("clip.generating.title")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text("clip.generating.subtitle")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xxxl)
            .accessibilityIdentifier("clip.generating")
        } else if digestsByCategory.isEmpty {
            // Digest はあるが期間フィルターで全部除外
            ContentUnavailableView(
                "clip.filteredEmpty.title",
                systemImage: "calendar.badge.clock",
                description: Text("clip.filteredEmpty.description")
            )
            .accessibilityIdentifier("clip.filteredEmpty")
        } else {
            ForEach(digestsByCategory, id: \.0) { category, digests in
                ForEach(digests, id: \.id) { digest in
                    NavigationLink(value: CategoryDigestDetailDestination(category: category)) {
                        KnowledgeClipCard(digest: digest)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - TimeFilter

enum TimeFilter: String, CaseIterable, Sendable {
    case all
    case days7
    case days30

    var labelKey: LocalizedStringKey {
        switch self {
        case .all: return "clip.filter.all"
        case .days7: return "clip.filter.days7"
        case .days30: return "clip.filter.days30"
        }
    }

    var cutoffDate: Date? {
        switch self {
        case .all: return nil
        case .days7: return Calendar.current.date(byAdding: .day, value: -7, to: .now)
        case .days30: return Calendar.current.date(byAdding: .day, value: -30, to: .now)
        }
    }
}

// MARK: - Navigation Destination

struct CategoryDigestDetailDestination: Hashable {
    let category: Category
}

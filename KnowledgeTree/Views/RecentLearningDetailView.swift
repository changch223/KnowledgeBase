//
//  RecentLearningDetailView.swift
//  KnowledgeTree
//
//  V3.0 polish (2026-05-27):
//  知識 Clip 「最近の Know」セクションのヘッドライン tap → 詳細画面。
//  フル headline + テーマ chips + 関連記事リスト (tap で個別記事詳細)。
//  NavigationStack を持たないシンプル view、親の NavigationStack に push される。
//

import SwiftUI
import SwiftData

struct RecentLearningDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(ServiceContainer.self) private var services

    /// 表示時に lock した「以降」基準時刻 (一覧と同じ)。
    let since: Date

    @State private var headline: String = ""
    @State private var themes: [String] = []
    @State private var articles: [Article] = []
    @State private var isLoading: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.section) {
                headlineSection
                if !themes.isEmpty {
                    themesSection
                }
                articlesSection
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.vertical, DS.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("knowledgeClip.section.recentArticles")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("recentLearningDetail.root")
        .task {
            await load()
        }
    }

    // MARK: - sections

    @ViewBuilder
    private var headlineSection: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(DS.Color.actionBlue)
            if isLoading && headline.isEmpty {
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView().scaleEffect(0.8)
                    Text("knowledgeClip.recent.headline.loading")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(headline.isEmpty ? String(localized: "knowledgeClip.recent.headline.empty") : headline)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineSpacing(DS.Typography.bodyLineSpacing)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(DS.Spacing.lg)
        .background(DS.Color.surfaceSecondary, in: .rect(cornerRadius: DS.Radius.card))
    }

    @ViewBuilder
    private var themesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("knowledgeClip.recent.themes.label")
                .font(.caption)
                .foregroundStyle(.secondary)
            FlowingTagsLayout(spacing: DS.Spacing.sm) {
                // spec 061: 同テーマ重複で id: \.self 衝突 → index 込み一意 ID。
                ForEach(Array(themes.enumerated()), id: \.offset) { _, theme in
                    Text(theme)
                        .font(.caption)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(DS.Color.tagFill, in: Capsule())
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    @ViewBuilder
    private var articlesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(String(format: String(localized: "knowledgeClip.recent.detail.articles.title") + " (%lld)", articles.count))
                .font(.title3.bold())
            if articles.isEmpty {
                Text("knowledgeClip.recent.detail.articles.empty")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(articles) { article in
                    NavigationLink(value: article) {
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(article.title)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            if let essence = article.extractedKnowledge?.essence,
                               !essence.isEmpty {
                                Text(essence)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Text(SavedAtFormatter.format(article.savedAt))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, DS.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }

    // MARK: - data

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        // 関連記事 (since 以降、なければ全件最新 N)
        if let service = services.recentArticlesService {
            var fetched = await service.fetchRecentArticles(since: since, limit: 30, in: context)
            if fetched.isEmpty {
                let descriptor = FetchDescriptor<Article>(
                    sortBy: [SortDescriptor(\Article.savedAt, order: .reverse)]
                )
                var bounded = descriptor
                bounded.fetchLimit = 30
                fetched = (try? context.fetch(bounded)) ?? []
            }
            articles = fetched
        }

        // headline + themes (RecentDigestService の 4 tier fallback)
        guard let digest = services.recentDigestService else { return }
        do {
            let result = try await digest.generate(since: since, in: context)
            if let first = result.paragraphs.first {
                headline = first
            }
            if result.paragraphs.count > 1 {
                themes = Array(result.paragraphs.dropFirst().prefix(3))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        } catch {
            // 維持
        }
    }
}

/// 「最近の Know」ヘッドライン tap での遷移先 (詳細画面)。
/// since を含めて Hashable にすることで、view ライフタイム中の差分起点と一致させる。
struct RecentLearningDetailDestination: Hashable {
    let since: Date
}

//
//  RecentArticlesSection.swift
//  KnowledgeTree
//
//  spec 056 V3.0 polish (2026-05-26):
//  「最近の記事をそのまま並べる」→「AI が要約した 1 文ヘッドライン + 主要テーマ chips + 元記事 chips」へ。
//
//  ユーザー指摘: 知識 Clip 最上部で記事 URL/title を 3 枚並べても価値が薄い。
//  AI が抽出した「最近何を学んだか」を簡単に伝える形に統合。
//
//  構成:
//   1. AI ヘッドライン (60-100 字、tap でライブラリ全体へ)
//   2. テーマ chips (AI 抽出のテーマ名詞句 最大 3 個)
//   3. 元記事 chips (最新 5 件の title、tap で個別記事詳細へ)
//
//  RecentDigestService (spec 035) を再利用、prompt を 1 文ヘッドライン形式に変更済。
//  AI 不可時は essence-based fallback で動作継続。
//

import SwiftUI
import SwiftData

struct RecentArticlesSection: View {
    @Environment(\.modelContext) private var context
    @Environment(ServiceContainer.self) private var services
    @Environment(RefreshTrigger.self) private var refreshTrigger

    /// view ライフタイム中で固定の「以降」基準時刻 (画面表示中に差分が消えないようにする)。
    let since: Date

    @State private var articles: [Article] = []
    @State private var headline: String = ""
    @State private var themes: [String] = []
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // ヘッダ
            HStack {
                Text("knowledgeClip.section.recentArticles")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.xxl)

            if articles.isEmpty && !isLoading {
                ContentUnavailableView(
                    "knowledgeClip.empty.recentArticles",
                    systemImage: "tray",
                    description: Text("knowledgeClip.empty.recentArticles.body")
                )
                .padding(.vertical, DS.Spacing.xxl)
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    // 1. AI ヘッドライン
                    headlineCard

                    // 2. テーマ chips (AI 抽出)
                    if !themes.isEmpty {
                        themeChips
                    }

                    // 3. 元記事 chips
                    if !articles.isEmpty {
                        articleChips
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)
            }
        }
        .accessibilityIdentifier("section.recentArticles")
        .task {
            await refresh()
        }
        .onChange(of: refreshTrigger.version) { _, _ in
            Task { await refresh() }
        }
    }

    // MARK: - subviews

    @ViewBuilder
    private var headlineCard: some View {
        // V3.0 polish (2026-05-27): 要点だけ短く表示 (2 行 + truncation)、tap で詳細画面へ。
        // RecentLearningDetailView は親 NavigationStack に push される (独自 NavigationStack なし、入れ子安全)。
        NavigationLink(value: RecentLearningDetailDestination(since: since)) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(DS.Color.actionBlue)
                if isLoading && headline.isEmpty {
                    HStack(spacing: DS.Spacing.sm) {
                        ProgressView().scaleEffect(0.8)
                        Text("knowledgeClip.recent.headline.loading")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // V3.0 polish (2026-05-28): カードは 1 行 40 字以内で要点だけ、tap で詳細画面 (全文)。
                    Text(headline.isEmpty ? String(localized: "knowledgeClip.recent.headline.empty") : Self.cardHeadline(headline))
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.Spacing.lg)
            .background(DS.Color.surfaceSecondary, in: .rect(cornerRadius: DS.Radius.card))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("recentArticles.headline")
    }

    @ViewBuilder
    private var themeChips: some View {
        FlowingTagsLayout(spacing: DS.Spacing.sm) {
            // spec 061: AI が同じテーマ文字列を複数返すと id: \.self が衝突し
            // ForEach undefined results 警告になるため、index 込みの一意 ID にする。
            ForEach(Array(themes.enumerated()), id: \.offset) { _, theme in
                Text(theme)
                    .font(.caption)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Color.tagFill, in: Capsule())
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("recentArticles.theme.\(theme)")
            }
        }
    }

    @ViewBuilder
    private var articleChips: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("knowledgeClip.recent.articles.label")
                .font(.caption)
                .foregroundStyle(.secondary)
            FlowingTagsLayout(spacing: DS.Spacing.sm) {
                ForEach(articles) { article in
                    NavigationLink(value: article) {
                        Text(articleChipLabel(article))
                            .font(.caption)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(DS.Color.surfaceSecondary, in: Capsule())
                            .overlay(
                                Capsule().stroke(DS.Color.aiBrandEdge.opacity(0.3), lineWidth: 0.5)
                            )
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recentArticles.chip.\(article.id.uuidString)")
                }
            }
        }
    }

    private func articleChipLabel(_ article: Article) -> String {
        let title = article.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.count > 18 ? String(title.prefix(18)) + "…" : title
    }

    /// V3.0 polish (2026-05-28): カード用 1 行 40 字以内 headline。詳細画面は全文表示なので
    /// 切り詰めても情報損失は最小限 (tap で全文確認可能)。
    static func cardHeadline(_ headline: String) -> String {
        let trimmed = headline.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 40 ? String(trimmed.prefix(40)) + "…" : trimmed
    }

    // MARK: - data

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }

        // 元記事 (最新 5 件、since 以降)。0 件なら全 Article から最新 5 件 fallback。
        if let service = services.recentArticlesService {
            var fetched = await service.fetchRecentArticles(since: since, limit: 5, in: context)
            if fetched.isEmpty {
                let descriptor = FetchDescriptor<Article>(
                    sortBy: [SortDescriptor(\Article.savedAt, order: .reverse)]
                )
                var bounded = descriptor
                bounded.fetchLimit = 5
                fetched = (try? context.fetch(bounded)) ?? []
            }
            articles = fetched
        }

        // AI ヘッドライン + テーマ (RecentDigestService 経由、0 件 fallback は service 内で対応済)
        guard let digest = services.recentDigestService else { return }
        do {
            let result = try await digest.generate(since: since, in: context)
            // V3.0 polish: paragraphs[0] = ヘッドライン、[1..3] = テーマ
            if let first = result.paragraphs.first {
                headline = first
            }
            if result.paragraphs.count > 1 {
                themes = Array(result.paragraphs.dropFirst().prefix(3))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            } else {
                themes = []
            }
        } catch {
            // headline / themes は前回値を維持 (calm UX)
        }
    }
}


//
//  RecentArticlesSection.swift
//  KnowledgeTree
//
//  spec 056 — 知識 Clip タブ最上部「最近の記事」セクション (差分キャッチアップ)。
//  LastOpenedStore.lastOpenedAt 以降の新規 Article 上位 3 件を横スクロール表示。
//  差分ゼロの場合は前回 cache から復元 (画面が空にならない)。
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
    @State private var totalNewCount: Int = 0
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("knowledgeClip.section.recentArticles")
                    .font(.headline)
                Spacer()
                if totalNewCount > articles.count {
                    // Layer 2: 「+N もっと見る」(将来 Phase B でライブラリへの誘導に拡張、当面は表示のみ)
                    Text("knowledgeClip.recentArticles.moreCount \(totalNewCount - articles.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DS.Spacing.xxl)

            if articles.isEmpty {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.xxxl)
                } else {
                    ContentUnavailableView(
                        "knowledgeClip.empty.recentArticles",
                        systemImage: "tray",
                        description: Text("knowledgeClip.empty.recentArticles.body")
                    )
                    .padding(.vertical, DS.Spacing.xxl)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.md) {
                        ForEach(articles) { article in
                            NavigationLink(value: article) {
                                RecentArticleCard(article: article)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("recentArticle.card.\(article.id.uuidString)")
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xxl)
                }
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

    private func refresh() async {
        guard let service = services.recentArticlesService else { return }
        isLoading = true
        defer { isLoading = false }
        articles = await service.fetchRecentArticles(since: since, limit: 3, in: context)
        // 「+N もっと見る」用に since 以降の総件数も求める
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.savedAt >= since }
        )
        totalNewCount = (try? context.fetchCount(descriptor)) ?? articles.count
    }
}

private struct RecentArticleCard: View {
    let article: Article

    private var essencePreview: String {
        let essence = article.extractedKnowledge?.essence ?? ""
        let trimmed = essence.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return article.title
        }
        return trimmed.count > 50 ? String(trimmed.prefix(50)) + "…" : trimmed
    }

    private var siteName: String {
        URL(string: article.url)?.host ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(essencePreview)
                .font(.body)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(article.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !siteName.isEmpty {
                    Text(siteName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(width: 240, height: 160, alignment: .topLeading)
        .background(DS.Color.surfaceSecondary, in: .rect(cornerRadius: DS.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(DS.Color.aiBrandEdge.opacity(0.3), lineWidth: 0.5)
        )
    }
}

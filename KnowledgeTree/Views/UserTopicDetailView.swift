//
//  UserTopicDetailView.swift
//  KnowledgeTree
//
//  spec 036 — 動的トピック詳細画面。
//  構成記事の一覧 + Top KeyFact / Entity (将来 spec で AI 統合要約追加)。
//

import SwiftUI
import SwiftData

struct UserTopicDetailView: View {
    let topicID: UUID

    @Query private var allTopics: [UserTopic]

    private var topic: UserTopic? {
        allTopics.first(where: { $0.id == topicID })
    }

    var body: some View {
        ScrollView {
            if let topic {
                VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                    headerSection(topic: topic)
                    keyFactsSection(topic: topic)
                    entitiesSection(topic: topic)
                    articlesSection(topic: topic)
                }
                .padding(DS.Spacing.xxl)
            } else {
                ContentUnavailableView("category.detail.empty.title", systemImage: "sparkles.slash")
            }
        }
        .navigationTitle(topic?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("topic.detail.root")
    }

    // MARK: - Sections

    private func headerSection(topic: UserTopic) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(topic.name)
                .font(DS.Typography.sectionTitle)
            Text("clip.topics.meta.articleCount \(topic.articles.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func keyFactsSection(topic: UserTopic) -> some View {
        let facts = Self.aggregatedKeyFacts(topic: topic)
        return Group {
            if !facts.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("clip.detail.keyFacts.title")
                        .font(DS.Typography.sectionTitle)
                    ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in
                        Text("・\(fact)")
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func entitiesSection(topic: UserTopic) -> some View {
        let entities = Self.aggregatedEntities(topic: topic)
        return Group {
            if !entities.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("clip.detail.entities.title")
                        .font(DS.Typography.sectionTitle)
                    FlowLayout(spacing: DS.Spacing.sm) {
                        ForEach(entities, id: \.self) { name in
                            Text(name)
                                .font(.caption)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.15))
                                )
                        }
                    }
                }
            }
        }
    }

    private func articlesSection(topic: UserTopic) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("clip.detail.articles.title")
                .font(DS.Typography.sectionTitle)
            // 最新順
            let sorted = topic.articles.sorted { $0.savedAt > $1.savedAt }
            ForEach(sorted) { article in
                NavigationLink(value: article) {
                    ArticleRow(article: article)
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
    }

    // MARK: - Aggregations

    static func aggregatedKeyFacts(topic: UserTopic) -> [String] {
        // 全 Article から KeyFact statement を集約、上位 5 件 (重複除去 + 出現数順)
        var counts: [String: Int] = [:]
        for article in topic.articles {
            for fact in article.extractedKnowledge?.keyFacts ?? [] {
                counts[fact.statement, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
    }

    static func aggregatedEntities(topic: UserTopic) -> [String] {
        var counts: [String: Int] = [:]
        for article in topic.articles {
            for entity in article.extractedKnowledge?.entities ?? [] {
                counts[entity.name, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(8).map { $0.key }
    }
}

/// 簡易 FlowLayout (chips を折り返し配置)
private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, x)
        }
        return CGSize(width: totalWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        let maxX = bounds.maxX
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

//
//  DynamicTopicsSection.swift
//  KnowledgeTree
//
//  spec 036 — 知識 Clip タブの「動的トピック」セクション。
//  AI 提案候補 (acceptedAt/dismissedAt 共に nil) と採用済 (acceptedAt != nil) を分離表示。
//

import SwiftUI
import SwiftData

struct DynamicTopicsSection: View {
    @Query(filter: #Predicate<UserTopic> {
        $0.acceptedAt == nil && $0.dismissedAt == nil
    }, sort: \UserTopic.createdAt, order: .reverse)
    private var candidates: [UserTopic]

    @Query(filter: #Predicate<UserTopic> {
        $0.acceptedAt != nil && $0.dismissedAt == nil
    })
    private var accepted: [UserTopic]

    /// spec 036 fix (2026-05-09): 動的トピック準備中も可視化
    @Query private var allArticles: [Article]
    private var articlesWithEmbedding: Int {
        allArticles.filter { $0.essenceEmbedding != nil }.count
    }
    private let minArticlesForClustering = 10

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if !candidates.isEmpty {
                candidatesSection
            }
            if !accepted.isEmpty {
                acceptedSection
            }
            if candidates.isEmpty && accepted.isEmpty {
                emptyHintCard
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .accessibilityIdentifier("clip.topics.section")
    }

    private var emptyHintCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "sparkles")
                    .foregroundStyle(DS.Color.actionBlue)
                Text("clip.topics.empty.title")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
            }
            if articlesWithEmbedding < minArticlesForClustering {
                let remaining = minArticlesForClustering - articlesWithEmbedding
                Text("clip.topics.empty.gathering \(remaining)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("clip.topics.empty.ready")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCardBackground()
    }

    private var candidatesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("clip.topics.candidates.title")
                    .font(DS.Typography.sectionTitle)
                    .foregroundStyle(.primary)
                Text("clip.topics.candidates.subtitle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(candidates.prefix(3)) { topic in
                UserTopicCandidateRow(topic: topic)
            }
        }
    }

    private var acceptedSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("clip.topics.accepted.title")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(.primary)

            // 重要度順 (importanceScore 降順、上位 N 件)
            let sorted = accepted.sorted { $0.importanceScore > $1.importanceScore }
            ForEach(sorted.prefix(5)) { topic in
                NavigationLink(value: UserTopicDestination(topicID: topic.id)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(topic.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text("clip.topics.meta.articleCount \(topic.articles.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding(DS.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .dsCardBackground()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// UserTopicDetailView への遷移用 Hashable destination。
struct UserTopicDestination: Hashable {
    let topicID: UUID
}

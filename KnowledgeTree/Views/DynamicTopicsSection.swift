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

    var body: some View {
        if candidates.isEmpty && accepted.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if !candidates.isEmpty {
                    candidatesSection
                }
                if !accepted.isEmpty {
                    acceptedSection
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .accessibilityIdentifier("clip.topics.section")
        }
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

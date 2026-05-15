//
//  UserTopicCandidateRow.swift
//  KnowledgeTree
//
//  spec 036 — 動的トピック候補 row (AI 提案、採用/却下ボタン)。
//

import SwiftUI
import SwiftData

struct UserTopicCandidateRow: View {
    let topic: UserTopic
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "sparkles")
                    .foregroundStyle(DS.Color.actionBlue)
                Text(topic.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("clip.topics.meta.articleCount \(topic.articles.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 代表記事 3 件 (savedAt 降順)
            let sortedArticles = topic.articles.sorted { $0.savedAt > $1.savedAt }.prefix(3)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(sortedArticles), id: \.id) { article in
                    Text("• \(article.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: DS.Spacing.md) {
                Button {
                    accept()
                } label: {
                    Text("clip.topics.action.accept")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Color.actionBlue)

                Button {
                    dismiss()
                } label: {
                    Text("clip.topics.action.dismiss")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCardBackground()
        .accessibilityIdentifier("clip.topics.candidateRow")
    }

    private func accept() {
        topic.acceptedAt = .now
        try? modelContext.save()
    }

    private func dismiss() {
        topic.dismissedAt = .now
        try? modelContext.save()
    }
}

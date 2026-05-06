//
//  ChatMessageRow.swift
//  KnowledgeTree
//
//  spec 021 — AI Chat (RAG) の 1 message 表示。
//  - user: 右寄せ actionBlue 背景 + white text
//  - assistant: 左寄せ dsCardBackground、引用記事 DisclosureGroup
//  - 引用 row タップで ArticleDetailView (NavigationLink、既存 spec 005)
//  - 引用 Article が削除済の場合は表示しない (spec 022 削除追従)
//

import SwiftUI
import SwiftData

struct ChatMessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == ChatMessageRole.user.rawValue {
                Spacer(minLength: 40)
                userBubble
            } else {
                assistantBubble
                Spacer(minLength: 40)
            }
        }
        .accessibilityIdentifier("chat.message.row.\(message.role)")
    }

    private var userBubble: some View {
        Text(message.text)
            .font(.body)
            .foregroundStyle(.white)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Color.actionBlue, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(message.text)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if !message.citedArticleIDs.isEmpty {
                CitedArticlesSection(articleIDs: message.citedArticleIDs)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCardBackground()
    }
}

private struct CitedArticlesSection: View {
    let articleIDs: [String]
    @Query private var allArticles: [Article]

    private var citedArticles: [Article] {
        let idSet = Set(articleIDs)
        // 順序を citedArticleIDs の順に保つ
        let mapped = allArticles.filter { idSet.contains($0.id.uuidString) }
        let dict = Dictionary(uniqueKeysWithValues: mapped.map { ($0.id.uuidString, $0) })
        return articleIDs.compactMap { dict[$0] }
    }

    var body: some View {
        if citedArticles.isEmpty {
            EmptyView()
        } else {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    ForEach(citedArticles) { article in
                        NavigationLink(value: article) {
                            HStack(spacing: DS.Spacing.sm) {
                                Text(article.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, DS.Spacing.xs)
                        }
                        .accessibilityIdentifier("chat.message.citedRow")
                    }
                }
                .padding(.top, DS.Spacing.sm)
            } label: {
                Text("chat.message.cited.count \(citedArticles.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("chat.message.citedSection")
        }
    }
}

//
//  ReaderView.swift
//  KnowledgeTree
//
//  spec 003 — アプリ内 Reader View
//  spec 004 — 本文の上に KnowledgeSummaryView を配置 (knowledge 存在時のみ)
//

import SwiftUI

struct ReaderView: View {
    let article: Article
    @Environment(\.dismiss) private var dismiss
    @State private var presentedSafariURL: ReaderSafariWrapper?

    private var paragraphs: [String] {
        guard let text = article.body?.extractedText else { return [] }
        return text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var knowledgeAvailable: Bool {
        guard let knowledge = article.extractedKnowledge else { return false }
        return knowledge.status == .succeeded || knowledge.status == .partiallySucceeded
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                    // spec 004: knowledge セクション (本文の上)
                    if knowledgeAvailable, let knowledge = article.extractedKnowledge {
                        KnowledgeSummaryView(knowledge: knowledge)
                    }

                    // spec 004: 「本文」見出し (knowledge があるときのみ表示、本文の前)
                    if knowledgeAvailable && !paragraphs.isEmpty {
                        Text("knowledge.bodyHeading")
                            .font(DS.Typography.sectionTitle)
                            .padding(.top, DS.Spacing.xs)
                    }

                    // spec 003: 本文段落
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.body)
                            .lineSpacing(DS.Typography.bodyLineSpacing)
                            .frame(maxWidth: 680, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, DS.Spacing.section)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .navigationTitle("reader.navigationTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ReaderToolbar(
                    onDone: { dismiss() },
                    onOpenOriginal: {
                        if let url = URL(string: article.url) {
                            presentedSafariURL = ReaderSafariWrapper(url: url)
                        }
                    }
                )
            }
            .sheet(item: $presentedSafariURL) { wrapper in
                SafariView(url: wrapper.url)
            }
        }
        .accessibilityIdentifier("readerView")
    }
}

private struct ReaderSafariWrapper: Identifiable {
    let id = UUID()
    let url: URL
}

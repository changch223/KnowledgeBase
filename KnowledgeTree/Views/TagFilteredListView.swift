//
//  TagFilteredListView.swift
//  KnowledgeTree
//
//  spec 008 — 特定 Tag を持つ記事のみ一覧表示する画面。
//

import SwiftUI
import SwiftData

struct TagFilteredListView: View {
    let tagName: String

    var body: some View {
        TagFilteredListContent(tagName: tagName)
            .navigationTitle(Text("tag.filtered.title \(tagName)"))
    }
}

private struct TagFilteredListContent: View {
    let tagName: String
    @Query private var articles: [Article]
    @State private var selectedArticle: Article?
    @Environment(\.modelContext) private var modelContext

    init(tagName: String) {
        self.tagName = tagName
        let normalized = tagName
        _articles = Query(
            filter: #Predicate<Article> { article in
                article.tags.contains(where: { $0.name == normalized })
            },
            sort: \Article.savedAt,
            order: .reverse
        )
    }

    var body: some View {
        Group {
            if articles.isEmpty {
                ContentUnavailableView(
                    "tag.filtered.empty.title",
                    systemImage: "tag.slash"
                )
            } else {
                List(articles) { article in
                    Button {
                        selectedArticle = article
                    } label: {
                        ArticleRow(article: article)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("articleListRow")
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            delete(article)
                        } label: {
                            Label("list.deleteAction", systemImage: "trash")
                        }
                        .accessibilityIdentifier("articleDeleteAction")
                    }
                    // spec 030: contextMenu (長押し) を併記、LazyVStack 系 view と UX 統一
                    .contextMenu {
                        Button(role: .destructive) {
                            delete(article)
                        } label: {
                            Label("list.deleteAction", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedArticle) { article in
            ArticleDetailView(article: article)
        }
    }

    private func delete(_ article: Article) {
        modelContext.delete(article)
        try? modelContext.save()
    }
}

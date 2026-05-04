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
                }
            }
        }
        .sheet(item: $selectedArticle) { article in
            ArticleDetailView(article: article)
        }
    }
}

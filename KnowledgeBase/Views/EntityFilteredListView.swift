//
//  EntityFilteredListView.swift
//  KnowledgeTree
//
//  spec 008 — 特定 KnowledgeEntity name を含む記事のみ一覧表示する画面。
//

import SwiftUI
import SwiftData

struct EntityFilteredListView: View {
    let entityName: String

    var body: some View {
        EntityFilteredListContent(entityName: entityName)
            .navigationTitle(Text("entity.filtered.title \(entityName)"))
    }
}

private struct EntityFilteredListContent: View {
    let entityName: String
    @Query private var articles: [Article]
    @State private var selectedArticle: Article?
    @Environment(\.modelContext) private var modelContext

    init(entityName: String) {
        self.entityName = entityName
        // SwiftData Predicate macro は optional chaining + nested contains が動かないので
        // 全件 fetch + View 側 post-filter で対応 (research.md R1 / SearchPredicate と同じ)
        _articles = Query(
            sort: \Article.savedAt,
            order: .reverse
        )
    }

    private var filtered: [Article] {
        let target = entityName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return articles.filter { article in
            guard let entities = article.extractedKnowledge?.entities else { return false }
            return entities.contains { entity in
                entity.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == target
            }
        }
    }

    var body: some View {
        let visible = filtered
        return Group {
            if visible.isEmpty {
                ContentUnavailableView(
                    "entity.filtered.empty.title",
                    systemImage: "tag.slash"
                )
            } else {
                List(visible) { article in
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

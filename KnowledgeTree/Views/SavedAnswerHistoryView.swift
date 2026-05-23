//
//  SavedAnswerHistoryView.swift
//  KnowledgeTree
//
//  spec 043 — SavedAnswer の全履歴画面。
//  Settings → 「保存された答えの履歴」NavigationLink で開く独立画面。
//  @Query で全 SavedAnswer fetch、isPinned 優先 + savedAt desc 表示、
//  100+ 件で LazyVStack による 60fps scroll、検索 (P3) は SearchService.searchSavedAnswers 経由。
//

import SwiftUI
import SwiftData

struct SavedAnswerHistoryView: View {
    @Query(sort: [SortDescriptor(\SavedAnswer.savedAt, order: .reverse)])
    private var allAnswers: [SavedAnswer]
    @State private var searchText: String = ""

    init() {}

    /// isPinned 優先 + savedAt desc (in-memory) → 検索時は SearchService.searchSavedAnswers (T020)
    private var displayedAnswers: [SavedAnswer] {
        let baseSort = allAnswers.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.savedAt > rhs.savedAt
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return baseSort }
        return SearchService.searchSavedAnswers(query: trimmed, in: baseSort).map(\.savedAnswer)
    }

    var body: some View {
        Group {
            if displayedAnswers.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty
                        ? LocalizedStringKey("SavedAnswer.empty.title")
                        : LocalizedStringKey("SavedAnswer.search.empty.title"),
                    systemImage: searchText.isEmpty ? "quote.bubble" : "magnifyingglass",
                    description: Text(searchText.isEmpty
                        ? LocalizedStringKey("SavedAnswer.empty.description")
                        : LocalizedStringKey("SavedAnswer.search.empty.description"))
                )
                .accessibilityIdentifier("savedAnswerHistory_empty")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayedAnswers, id: \.id) { answer in
                            NavigationLink(value: SavedAnswerDetailDestination(id: answer.id)) {
                                SavedAnswerRow(answer: answer)
                                    .padding(.horizontal, DS.Spacing.xxl)
                            }
                            .buttonStyle(.plain)
                            Divider()
                                .padding(.leading, DS.Spacing.xxl)
                        }
                    }
                    .padding(.vertical, DS.Spacing.md)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("SavedAnswer.history.title")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: Text("SavedAnswer.search.prompt"))
        .navigationDestination(for: SavedAnswerDetailDestination.self) { dest in
            SavedAnswerDetailLoader(destinationID: dest.id)
        }
        .navigationDestination(for: Article.self) { article in
            ArticleDetailView(article: article)
        }
        .navigationDestination(for: ConceptPageDetailDestination.self) { dest in
            ConceptPageDetailLoader(destinationID: dest.id)
        }
        .accessibilityIdentifier("savedAnswerHistory_root")
    }
}

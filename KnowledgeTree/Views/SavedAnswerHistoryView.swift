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
    /// spec 045: isStale 絞り込み state (chip タップで toggle)
    @State private var showStaleOnly: Bool = false

    init() {}

    /// spec 045: isStale な SavedAnswer の件数 (chip 表示判定)
    private var staleCount: Int {
        allAnswers.filter(\.isStale).count
    }

    /// isPinned 優先 + savedAt desc (in-memory) → 検索時は SearchService.searchSavedAnswers (T020)
    /// spec 045: showStaleOnly が true なら isStale=true のみフィルター
    private var displayedAnswers: [SavedAnswer] {
        let staleFiltered = showStaleOnly ? allAnswers.filter(\.isStale) : allAnswers
        let baseSort = staleFiltered.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.savedAt > rhs.savedAt
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return baseSort }
        return SearchService.searchSavedAnswers(query: trimmed, in: baseSort).map(\.savedAnswer)
    }

    /// spec 045: isStale 絞り込み chip (件数 0 で非表示、calm UX)
    @ViewBuilder
    private var staleFilterChip: some View {
        if staleCount > 0 {
            HStack {
                Button {
                    withAnimation { showStaleOnly.toggle() }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "clock.badge.exclamationmark")
                        Text(String(format: String(localized: "⚠️ 更新が必要 (%lld)"), staleCount))
                            .font(.caption)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(showStaleOnly ? Color.orange.opacity(0.25) : Color.orange.opacity(0.10))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(showStaleOnly ? Color.orange : .clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chip.stale.filter")
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.top, DS.Spacing.md)
        }
    }

    var body: some View {
        Group {
            if displayedAnswers.isEmpty && !showStaleOnly {
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
                    VStack(spacing: 0) {
                        staleFilterChip
                        LazyVStack(spacing: 0) {
                            if displayedAnswers.isEmpty && showStaleOnly {
                                Text("古い答えはアクションメニューから削除できます")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .padding(DS.Spacing.xxl)
                            }
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
            // spec 043 bug fix: 外側 NavigationStack 経由 → 内側 NavigationStack 作らない
            ArticleDetailView(article: article, embedNavigationStack: false)
        }
        .navigationDestination(for: ConceptPageDetailDestination.self) { dest in
            ConceptPageDetailLoader(destinationID: dest.id)
        }
        .accessibilityIdentifier("savedAnswerHistory_root")
    }
}

//
//  ActionItemsReviewView.swift
//  KnowledgeTree
//
//  spec 056 — ⚠️ 「更新が必要」 badge tap で push される、
//  ConflictProposal + isStale SavedAnswer を 1 画面に統合した review 画面。
//  旧 FactConflictsSection + StaleSavedAnswersSection の機能を統合。
//

import SwiftUI
import SwiftData

/// ⚠️ 更新が必要 badge から push される Hashable destination。
struct ActionItemsReviewDestination: Hashable {}

struct ActionItemsReviewView: View {
    @Query(
        filter: #Predicate<ConflictProposal> { $0.status == "pending" }
    )
    private var conflicts: [ConflictProposal]

    @Query(
        filter: #Predicate<SavedAnswer> { $0.isStale == true },
        sort: [SortDescriptor(\SavedAnswer.updatedAt, order: .reverse)]
    )
    private var staleAnswers: [SavedAnswer]

    var body: some View {
        List {
            if !conflicts.isEmpty {
                Section {
                    ForEach(conflicts) { conflict in
                        ConflictProposalRow(proposal: conflict)
                    }
                } header: {
                    Text("actionItems.section.factConflicts")
                }
            }

            if !staleAnswers.isEmpty {
                Section {
                    ForEach(staleAnswers) { answer in
                        NavigationLink(value: SavedAnswerDetailDestination(id: answer.id)) {
                            SavedAnswerRow(answer: answer)
                        }
                    }
                } header: {
                    Text("actionItems.section.staleSavedAnswers")
                }
            }

            if conflicts.isEmpty && staleAnswers.isEmpty {
                ContentUnavailableView(
                    "actionItems.empty.title",
                    systemImage: "checkmark.circle",
                    description: Text("actionItems.empty.body")
                )
            }
        }
        .navigationTitle("actionItems.title")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("view.actionItems")
    }
}

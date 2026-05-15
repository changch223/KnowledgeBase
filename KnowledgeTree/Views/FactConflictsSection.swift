//
//  FactConflictsSection.swift
//  KnowledgeTree
//
//  spec 037 — 知識 Clip タブの「事実更新の提案」セクション。
//  status == "pending" の ConflictProposal を一覧表示、
//  ユーザーが「上書き」「両方残す」「却下」を選択。
//

import SwiftUI
import SwiftData

struct FactConflictsSection: View {
    @Query(filter: #Predicate<ConflictProposal> { $0.status == "pending" })
    private var pendingProposals: [ConflictProposal]

    var body: some View {
        if pendingProposals.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                header
                ForEach(pendingProposals) { proposal in
                    ConflictProposalRow(proposal: proposal)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .accessibilityIdentifier("clip.conflicts.section")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("clip.conflicts.title")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(.primary)
            Text("clip.conflicts.subtitle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

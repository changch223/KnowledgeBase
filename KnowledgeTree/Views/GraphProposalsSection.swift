//
//  GraphProposalsSection.swift
//  KnowledgeTree
//
//  spec 041 (Phase B) — 知識 Clip タブの「AI が見つけた仮説」セクション。
//  GraphExtractionService が isUncertain=true で作成した edge を 1 件ずつ表示、
//  ユーザーが「採用」「却下」「ラベル変更」できる。
//

import SwiftUI
import SwiftData

struct GraphProposalsSection: View {
    @Query(filter: #Predicate<GraphEdge> { $0.isUncertain == true })
    private var proposals: [GraphEdge]

    @Environment(ServiceContainer.self) private var services
    @State private var presentedRelabel: GraphEdge?

    /// 最大表示件数 (UI が肥大化しないように)
    private let maxItems: Int = 5

    private var sortedProposals: [GraphEdge] {
        proposals
            .filter { $0.source?.isActive == true && $0.target?.isActive == true }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var visibleProposals: [GraphEdge] {
        Array(sortedProposals.prefix(maxItems))
    }

    var body: some View {
        if visibleProposals.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HStack {
                    Text("AI が見つけた仮説")
                        .font(DS.Typography.sectionTitle)
                    Spacer()
                    if sortedProposals.count > maxItems {
                        Text("+\(sortedProposals.count - maxItems)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(visibleProposals) { edge in
                    proposalRow(edge: edge)
                }
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .accessibilityIdentifier("graph.proposals.section")
            .sheet(item: $presentedRelabel) { edge in
                NavigationStack {
                    GraphEdgeEditSheet(edge: edge)
                }
            }
        }
    }

    @ViewBuilder
    private func proposalRow(edge: GraphEdge) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(DS.Color.actionBlue.opacity(0.7))
                Text(edge.source?.name ?? "?")
                    .font(.subheadline)
                    .bold()
                Text("—")
                    .foregroundStyle(.secondary)
                Text(edge.label ?? "共起")
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.actionBlue)
                Text("→")
                    .foregroundStyle(.secondary)
                Text(edge.target?.name ?? "?")
                    .font(.subheadline)
                    .bold()
            }
            Text("確信度 \(String(format: "%.0f", edge.confidence * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: DS.Spacing.sm) {
                Button {
                    accept(edge)
                } label: {
                    Text("採用")
                        .font(.caption)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(DS.Color.actionBlue, in: Capsule())
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("graph.proposal.accept")

                Button {
                    presentedRelabel = edge
                } label: {
                    Text("ラベル変更")
                        .font(.caption)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(DS.Color.tagFill, in: Capsule())
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("graph.proposal.relabel")

                Button {
                    reject(edge)
                } label: {
                    Text("却下")
                        .font(.caption)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(DS.Color.tagFill, in: Capsule())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("graph.proposal.reject")
            }
        }
        .padding(DS.Spacing.lg)
        .dsCardBackground()
    }

    private func accept(_ edge: GraphEdge) {
        try? services.graphProposalReviewService?.accept(edge: edge)
    }

    private func reject(_ edge: GraphEdge) {
        try? services.graphProposalReviewService?.reject(edge: edge)
    }
}

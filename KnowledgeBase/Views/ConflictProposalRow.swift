//
//  ConflictProposalRow.swift
//  KnowledgeTree
//
//  spec 037 — 1 件の ConflictProposal を表示する row。
//  上書き / 両方残す / 却下 ボタンで status を更新。
//

import SwiftUI
import SwiftData

struct ConflictProposalRow: View {
    let proposal: ConflictProposal
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // 矛盾説明
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(proposal.entityName)
                    .font(.headline)
                Spacer()
            }

            Text(proposal.conflictDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // 新記事
            factCard(
                labelKey: "clip.conflicts.label.new",
                title: proposal.newArticle?.title ?? "—",
                fact: proposal.newFact,
                emphasized: true
            )

            // 旧記事
            factCard(
                labelKey: "clip.conflicts.label.old",
                title: proposal.oldArticle?.title ?? "—",
                fact: proposal.oldFact,
                emphasized: false
            )

            // ボタン
            HStack(spacing: DS.Spacing.md) {
                Button {
                    resolve(.overwrite)
                } label: {
                    Text("clip.conflicts.action.overwrite")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Color.sumiInk)

                Button {
                    resolve(.keepBoth)
                } label: {
                    Text("clip.conflicts.action.keepBoth")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    resolve(.dismissed)
                } label: {
                    Text("clip.conflicts.action.dismiss")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCardBackground()
        .accessibilityIdentifier("clip.conflicts.row")
    }

    @ViewBuilder
    private func factCard(labelKey: LocalizedStringKey, title: String, fact: String, emphasized: Bool) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Text(labelKey)
                .font(.caption.bold())
                .foregroundStyle(emphasized ? .primary : .secondary)
                .frame(width: 24, alignment: .center)
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(emphasized ? DS.Color.sumiInk.opacity(0.15) : Color.gray.opacity(0.15))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(emphasized ? .primary : .secondary)
                    .lineLimit(1)
                if !fact.isEmpty {
                    Text(fact)
                        .font(.body)
                        .foregroundStyle(emphasized ? .primary : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func resolve(_ status: ConflictStatus) {
        proposal.status = status.rawValue
        proposal.resolvedAt = .now
        if status == .overwrite {
            proposal.oldArticle?.isObsolete = true
        }
        try? modelContext.save()
    }
}

//
//  SavedAnswerRow.swift
//  KnowledgeTree
//
//  spec 043 — 履歴画面 / ConceptPage 詳細セクション内で表示する SavedAnswer の 1 行 row。
//

import SwiftUI

struct SavedAnswerRow: View {
    let answer: SavedAnswer

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            if answer.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.sumiInk)
                    .accessibilityHidden(true)
            }
            // spec 045: isStale 視覚マーク (orange 🕒)
            if answer.isStale {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("savedAnswer.stale.icon")
                    .accessibilityLabel(Text("更新が必要"))
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(answer.questionPreview)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: DS.Spacing.sm) {
                    Text(String(format: String(localized: "SavedAnswer.row.citedCount"), (answer.citedArticles ?? []).count))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(SavedAtFormatter.format(answer.savedAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    // spec 045: isStale chip (text)
                    if answer.isStale {
                        Text("更新が必要")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                            .accessibilityIdentifier("savedAnswer.stale.chip")
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, DS.Spacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(answer.questionPreview), 引用 \((answer.citedArticles ?? []).count) 件, \(SavedAtFormatter.accessibilityText(answer.savedAt))")
        .accessibilityIdentifier("savedAnswerRow_\(answer.id.uuidString)")
    }
}

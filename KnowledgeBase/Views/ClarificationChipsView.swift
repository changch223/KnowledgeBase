//
//  ClarificationChipsView.swift
//  KnowledgeTree
//
//  spec 057 — assistant message が clarification (suggestions 非空) のとき、bubble の下に
//  3 つの chip を縦並びで表示。tap で auto-fill + 自動送信 callback。
//

import SwiftUI

struct ClarificationChipsView: View {
    let suggestions: [String]
    let onTap: (String) -> Void
    /// spec 083: 4 つ目「その他（自由に入力）」タップ時 (送信せず入力欄にフォーカス)。
    var onOther: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(suggestions.filter { !$0.isEmpty }, id: \.self) { suggestion in
                Button {
                    onTap(suggestion)
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Text(suggestion)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.left.circle")
                            .foregroundStyle(.tint)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .background(
                        Capsule()
                            .stroke(Color.accentColor, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("clarification.chip.\(suggestion.prefix(20))")
            }

            // spec 083: 4 つ目 — 自由入力 (Claude の AskUserQuestion の「その他」相当)
            if onOther != nil {
                Button {
                    onOther?()
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Text("chat.clarification.other")
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .background(
                        Capsule()
                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("clarification.chip.other")
            }
        }
    }
}

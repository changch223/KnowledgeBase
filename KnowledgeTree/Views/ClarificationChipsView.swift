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
        }
    }
}

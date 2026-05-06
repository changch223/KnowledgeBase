//
//  ChatInputField.swift
//  KnowledgeTree
//
//  spec 021 — AI Chat (RAG) の質問入力欄 + 送信ボタン。
//  - 1〜4 行 vertical 拡張
//  - isThinking 中は disabled (TextField + Button 両方)
//  - 送信不可 (空 / thinking) は actionBlue → tertiary fade
//

import SwiftUI

struct ChatInputField: View {
    @Binding var text: String
    @Binding var isThinking: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: DS.Spacing.md) {
            TextField("chat.input.placeholder", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .disabled(isThinking)
                .accessibilityIdentifier("chat.input.field")

            Button {
                onSend()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? DS.Color.actionBlue : .secondary.opacity(0.4))
            }
            .disabled(!canSend)
            .accessibilityIdentifier("chat.input.send")
            .accessibilityLabel(Text("chat.input.send"))
        }
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking
    }
}

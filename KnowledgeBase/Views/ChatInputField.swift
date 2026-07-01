//
//  ChatInputField.swift
//  KnowledgeTree
//
//  spec 021 — AI Chat (RAG) の質問入力欄 + 送信ボタン。
//  - 1〜4 行 vertical 拡張
//  - isThinking 中は disabled (TextField + Button 両方)
//  - 送信不可 (空 / thinking) は actionBlue → tertiary fade
//  - spec 099: chatMode toggle (⚡ Quick / 🧠 Think) を入力欄左に配置
//

import SwiftUI

struct ChatInputField: View {
    @Binding var text: String
    @Binding var isThinking: Bool
    @Binding var chatMode: ChatMode
    let onSend: () -> Void
    /// spec 083: clarification「その他」から入力欄にフォーカスするための binding (optional)。
    var focused: FocusState<Bool>.Binding? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: DS.Spacing.md) {
            // モード切り替えボタン (Fast / Think)
            Button {
                chatMode = chatMode == .quick ? .think : .quick
            } label: {
                Text(chatMode == .quick ? "Fast" : "Think")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.Color.sumiInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        DS.Color.sumiInk.opacity(chatMode == .quick ? 0.12 : 0.06),
                        in: Capsule()
                    )
            }
            .accessibilityIdentifier("chat.input.modeToggle")
            .accessibilityLabel(Text(chatMode == .quick ? "Fast" : "Think"))

            inputTextField
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .disabled(isThinking)
                .accessibilityIdentifier("chat.input.field")

            Button {
                onSend()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? DS.Color.sumiInk : .secondary.opacity(0.4))
            }
            .disabled(!canSend)
            .accessibilityIdentifier("chat.input.send")
            .accessibilityLabel(Text("chat.input.send"))
        }
        .padding(DS.Spacing.lg)
        .background(DS.Color.washiCard)
        .overlay(alignment: .top) {
            DS.Color.sumiRule.frame(height: 0.5)
        }
    }

    @ViewBuilder
    private var inputTextField: some View {
        if let focused {
            TextField("chat.input.placeholder", text: $text, axis: .vertical)
                .focused(focused)
        } else {
            TextField("chat.input.placeholder", text: $text, axis: .vertical)
        }
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking
    }
}

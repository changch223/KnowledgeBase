//
//  TagInputField.swift
//  KnowledgeTree
//
//  spec 008 — Detail 画面のタグセクション内に配置する追加入力欄。
//

import SwiftUI

struct TagInputField: View {
    let onAdd: (String) -> Void
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            TextField(
                "tag.input.placeholder",
                text: $text
            )
            .textFieldStyle(.roundedBorder)
            .submitLabel(.done)
            .focused($focused)
            .onSubmit { submit() }
            .accessibilityIdentifier("tagInputTextField")

            Button("tag.input.add") {
                submit()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("tagInputAddButton")
        }
    }

    private func submit() {
        let raw = text
        text = ""
        onAdd(raw)
        focused = true  // 連続入力可
    }
}

//
//  SuggestedPromptsSection.swift
//  KnowledgeTree
//
//  spec 056 — AI チャットタブの空状態 (ChatSession 履歴ゼロ) で表示する
//  suggested prompts 3 件 + tap で送信。
//

import SwiftUI

struct SuggestedPromptsSection: View {
    @Environment(\.modelContext) private var context
    @Environment(ServiceContainer.self) private var services

    @State private var prompts: [SuggestedPrompt] = []
    @State private var isLoading: Bool = false

    /// Suggested prompt tap → 上位 view (ChatTabView) に text を渡す。
    let onPromptTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            Text("chat.suggested.title")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(Array(prompts.enumerated()), id: \.element.id) { index, prompt in
                Button {
                    onPromptTap(prompt.text)
                } label: {
                    HStack {
                        Text(prompt.text)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.right.circle")
                            .foregroundStyle(.tint)
                    }
                    .padding(DS.Spacing.lg)
                    .background(DS.Color.surfaceSecondary, in: .rect(cornerRadius: DS.Radius.chip))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("prompt.suggested.\(index)")
            }
        }
        .task {
            await refresh()
        }
    }

    private func refresh() async {
        guard let generator = services.suggestedPromptGenerator else { return }
        isLoading = true
        defer { isLoading = false }
        prompts = await generator.generateSuggestedPrompts(in: context)
    }
}

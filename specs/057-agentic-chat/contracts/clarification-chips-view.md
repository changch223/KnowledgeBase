# Contract: ClarificationChipsView

## Purpose

assistant message bubble の下に表示する clarification suggested chips UI。tap で input field に auto-fill + 自動送信。

## View

```swift
struct ClarificationChipsView: View {
    let suggestions: [String]
    let onTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    onTap(suggestion)
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Text(suggestion)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)
                        Spacer()
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
```

## Integration in ChatTabView

```swift
// ChatMessageRow の assistant message に対して、clarification 種別なら chips を下に表示
if message.role == .assistant, !message.clarificationSuggestions.isEmpty {
    ClarificationChipsView(suggestions: message.clarificationSuggestions) { tappedChip in
        inputText = tappedChip
        Task { await sendQuestion() }
    }
}
```

注: `ChatMessage` に `clarificationSuggestions: [String]` を追加するか、message text を parse する判断は R5 / 実装時。本 contract では「ChatMessage に optional `clarificationSuggestions: [String]?` 追加 + 既存スキーマ無破壊」を想定。

## Test Cases

- 3 chips 表示 (各 30 字以内)
- tap で onTap callback 動作
- 空配列なら view 描画なし

## Accessibility

- `clarification.chip.{suggestion[0..20]}` identifier
- VoiceOver: "候補: {suggestion}"
- Dynamic Type 対応 (subheadline + multilineTextAlignment)

## xcstrings

- なし (suggestion text は LLM 生成、xcstrings 不要)

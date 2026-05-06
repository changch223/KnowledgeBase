# Contract — ChatInputField

**spec**: 021 / **file**: `KnowledgeTree/Views/ChatInputField.swift` (new)

## 役割

質問入力 TextEditor + 送信 Button。

## 構成

```swift
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
                    .foregroundStyle(canSend ? DS.Color.actionBlue : DS.Color.surfaceTertiary)
            }
            .disabled(!canSend)
            .accessibilityIdentifier("chat.input.send")
        }
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking
    }
}
```

## 動作

- 送信不可 (空 / thinking 中): button disabled + actionBlue → tertiary fade
- isThinking 中: TextField も disabled
- 1〜4 行 vertical 拡張 (`.lineLimit(1...4)`)

## Constitution

- V (calm UX): action ボタンは actionBlue 1 色、disable 時は visually muted
- VII (日本語): placeholder xcstrings

# Contract — ChatTabView

**spec**: 021 / **file**: `KnowledgeTree/Views/ChatTabView.swift` (new)

## 役割

4 タブ目「AI チャット」の root view。最新 ChatSession の messages を時系列表示 + 入力欄。

## 構成

```swift
struct ChatTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.chatService) private var chatService
    @State private var currentSession: ChatSession?
    @State private var inputText: String = ""
    @State private var isThinking: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: DS.Spacing.lg) {
                            ForEach(messages) { msg in
                                ChatMessageRow(message: msg)
                            }
                            if isThinking {
                                ProgressView("chat.message.assistant.thinking")
                            }
                        }
                    }
                }
                ChatInputField(text: $inputText, isThinking: $isThinking, onSend: sendQuestion)
            }
            .navigationTitle("chat.tab.title")
            .task { await ensureSession() }
            .alert(item: $errorAlertItem) { ... }
        }
    }
}
```

## 動作

1. `.task { ensureSession() }`: 起動時に最新 ChatSession を fetch、なければ create
2. `messages`: currentSession.messages の timestamp 昇順
3. `sendQuestion`: chatService.send → message 追加 → ScrollViewReader で auto scroll
4. message 追加後の auto scroll は `proxy.scrollTo(lastMessage.id, anchor: .bottom)`

## Empty state

```
ContentUnavailableView(
    "chat.empty.title",
    systemImage: "bubble.left.and.bubble.right",
    description: Text("chat.empty.subtitle")
)
```

## Constitution

- V (calm UX): エラー時のみ alert、通知ゼロ
- VII (日本語): 全文言 xcstrings 経由

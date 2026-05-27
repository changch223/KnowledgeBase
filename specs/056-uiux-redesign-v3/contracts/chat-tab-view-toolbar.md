# Contract: ChatTabView toolbar 📊 + Suggested prompts

## Purpose

AI チャットタブに toolbar 📊 アイコン + 空状態 suggested prompts を追加。既存 ChatTabView (spec 021/033) の改修。

## Toolbar 改修

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        NavigationLink(value: KnowledgeGraphFullScreenDestination()) {
            Image(systemName: "chart.dots.scatter")
                .accessibilityIdentifier("toolbar.knowledgeGraph")
        }
    }
}
.navigationDestination(for: KnowledgeGraphFullScreenDestination.self) { _ in
    KnowledgeGraphFullScreenView()
}
```

## 空状態 Suggested prompts 統合

ChatTabView body 内、ChatSession の messages が空の時:

```swift
if currentSession.messages?.isEmpty ?? true {
    VStack(alignment: .leading, spacing: 24) {
        Text("chat.empty.placeholder")  // "💬 何でも聞いて"
            .font(.title2)
            .foregroundStyle(.secondary)
        SuggestedPromptsSection { promptText in
            // tap 時、user message として送信
            Task {
                await chatService.sendMessage(promptText, in: currentSession)
            }
        }
    }
    .padding()
} else {
    // 既存 messages display
}
```

## Hashable destination 追加

```swift
struct KnowledgeGraphFullScreenDestination: Hashable {}
```

## アクセシビリティ

- `tab.chat`
- `toolbar.knowledgeGraph` (📊 アイコン)
- `prompt.suggested.{0,1,2}` (各 prompt button)

## 既存機能維持

- ChatHistorySidebar (spec 033) 動作維持
- multi-turn context (spec 033) 動作維持
- 引用 chip + ConceptPage chip (spec 047) 動作維持
- 擬似 streaming (spec 033) 動作維持

## xcstrings 追加

- `chat.empty.placeholder` = "💬 何でも聞いて"
- `chat.suggested.title` = "💡 候補"
- (suggested-prompt-generator.md にて prompt text strings 定義済)

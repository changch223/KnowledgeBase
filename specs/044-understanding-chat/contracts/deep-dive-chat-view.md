# Contract: DeepDiveChatView

**Feature**: spec 044 Understanding Chat
**Type**: SwiftUI View
**File**: `KnowledgeTree/Views/DeepDiveChatView.swift`

## Definition

```swift
struct DeepDiveChatView: View {
    let card: UnderstandingCard
    @EnvironmentObject private var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss
    @State private var session: ChatSession?
    @State private var isInitializing = true
    @State private var startError: Error?

    var body: some View
}
```

## Layout

```text
VStack(spacing: 0) {
    if isInitializing {
        ProgressView("家庭教師を起動中…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if let session {
        // 既存 ChatTabView から component 化した chat body
        ChatBodyView(session: session)
    } else if startError != nil {
        ContentUnavailableView(
            "家庭教師を起動できませんでした",
            systemImage: "exclamationmark.bubble",
            description: Text("もう一度開いてみてください。")
        )
    }
    UnderstandingActionBar(card: card, session: session)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
}
.navigationTitle(card.deepDiveTitle)
.navigationBarTitleDisplayMode(.inline)
.task {
    await startChat()
}
```

## UnderstandingActionBar Sub-View

```swift
struct UnderstandingActionBar: View {
    let card: UnderstandingCard
    let session: ChatSession?
    @EnvironmentObject private var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            ActionButton(title: "✓ わかった", color: .green) {
                await handleUnderstood()
            }
            .accessibilityIdentifier("button.understood")
            ActionButton(title: "🤔 もっと", color: .blue) {
                await handleNeedMore()
            }
            .accessibilityIdentifier("button.needMore")
            ActionButton(title: "✗ 違う", color: .orange) {
                await handleDismissed()
            }
            .accessibilityIdentifier("button.dismissed")
        }
    }
}
```

## startChat()

```swift
private func startChat() async {
    guard let starter = services.deepDiveChatStarter else { return }
    do {
        session = try await starter.startChat(for: card)
        isInitializing = false
    } catch {
        startError = error
        isInitializing = false
    }
}
```

## Action Handlers

```swift
private func handleUnderstood() async {
    guard let tracker = services.understandingTrackerService else { return }
    try? await tracker.recordUnderstood(card: card)
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    // chat 画面は閉じない (ユーザーが続けたい場合がある)
}

private func handleNeedMore() async {
    guard let tracker = services.understandingTrackerService,
          let session = session,
          let chatService = services.chatService else { return }
    try? await tracker.recordNeedMore(card: card)
    // 「もう少し別の角度から教えて」と AI に再質問
    _ = try? await chatService.ask(message: "もう少し別の角度から教えてください。", in: session)
}

private func handleDismissed() async {
    guard let tracker = services.understandingTrackerService else { return }
    try? await tracker.recordDismissed(card: card)
    dismiss()    // 違うカードに戻る、画面を閉じる
}
```

## Behavior

- カード表示から AI 初期発話まで 3 秒以内 (SC-002、Apple Intelligence 利用可時)
- 「✓ わかった」タップ → DB 反映 1 秒以内 (SC-003)、画面は閉じない
- 「🤔 もっと」タップ → AI に追加質問送信、対話継続
- 「✗ 違う」タップ → priority -10 設定後、`dismiss()` で前画面へ
- 3 ボタンは scroll しても sticky (bottom safe area 上に固定)

## Accessibility

- 全 button に `accessibilityLabel` 日本語明示 ("はい、わかりました" / "もっと教えてください" / "違う、戻る")
- VoiceOver readers が「✓」記号でなく日本語で読み上げる

## Performance

- 起動 3 秒以内 (SC-002)
- 各 button tap → DB 反映 1 秒以内 (SC-003)

## Test Coverage

- UI test (UnderstandingTabUITests): カードタップ → DeepDiveChatView 起動 + 「✓ わかった」tap → 前画面に戻った時 surface 入れ替わり
- Unit test: DeepDiveChatStarterTests + UnderstandingTrackerServiceTests で内部ロジック検証

## Constitution Compliance

- V (calm UX): haptic light のみ、効果音 / 通知 / バッジゼロ ✅
- VII (日本語ファースト): 全 UI 日本語、VoiceOver 日本語明示 ✅

# Contract: DeepDiveChatStarter

**Feature**: spec 044 Understanding Chat
**Type**: @MainActor Protocol + Default 実装
**File**: `KnowledgeTree/Services/DeepDiveChatStarter.swift`

## Protocol

```swift
@MainActor
protocol DeepDiveChatStarterProtocol: AnyObject {
    func startChat(for card: UnderstandingCard) async throws -> ChatSession
}
```

## Default 実装

```swift
@MainActor
final class DefaultDeepDiveChatStarter: DeepDiveChatStarterProtocol {
    private let chatService: ChatServiceProtocol      // spec 021、既存
    private let tracker: UnderstandingTrackerServiceProtocol
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "deepdive")

    init(chatService: ChatServiceProtocol, tracker: UnderstandingTrackerServiceProtocol)
}
```

## Algorithm: startChat

```text
1. ChatSession 作成: try chatService.createSession()
2. session.title = makeTitle(for: card)
   - ConceptPage: "「{page.name}」を深掘り"
   - SavedAnswer: "「{question.prefix(40)}」を深掘り"
3. context = buildTutorContext(for: card)
4. ChatService.ask(message: context, in: session) で初期発話を AI に自動生成させる
5. tracker.recordOpenedChat(card: card)
6. session 返却
```

## Tutor Prompt Template

```text
あなたは家庭教師として、ユーザーが「{conceptName}」を腹落ちするまで助けてください。
質問に答えるだけでなく、ユーザーの理解度を確認する逆質問や、関連する保存記事への参照を促してください。

【補助情報】
{kind == .conceptPage ? "概念の現在の理解:\n  - " + essence + "\n  - 主な事実: " + topKeyFacts : ""}
{kind == .savedAnswer ? "前回の質問: " + question + "\n  前回の答え抜粋: " + answer.prefix(100) : ""}

【最初の発話】
ユーザーがこの概念について現時点で気になっていることは何かを 1 つ問いかけてください。
答えではなく、質問を返してください。
```

## Error Handling

- `chatService.createSession()` 失敗 → throw、呼び出し側 (DeepDiveChatView) は `try?` で nil 受けて isInitializing=false + log error
- `chatService.ask()` 失敗 (Foundation Models 不可) → throw されず spec 021 既存 fallback (essence 並べ) が return される、ChatSession は作成済みなので session 返却継続
- `tracker.recordOpenedChat()` 失敗 → 重大度低、log warning のみで session 返却継続 (defer 化推奨)

## Performance

- chatService.createSession: < 100ms
- chatService.ask (Foundation Models): 1-3 秒
- tracker.recordOpenedChat: < 100ms
- 合計 3 秒以内 (SC-002、Apple Intelligence 利用可時)

## Test Coverage (5 ケース)

| # | ケース | 期待 |
|---|------|------|
| 1 | ConceptPage card で startChat | ChatSession 作成 + title 設定 + 初期発話 1 件 + openedChat 履歴 |
| 2 | tutor prompt の context に concept name が含まれる | MockChatService.lastAskMessage に concept name string substring |
| 3 | openedChat 履歴記録 | UnderstandingInteraction 1 件 (action=openedChat) |
| 4 | Foundation Models 不可 (Mock LM が throws) → ChatService fallback | ChatSession は返却される、isInitializing=false |
| 5 | SavedAnswer card で startChat | prompt に question + answer.prefix(100) 含む |

## Mock Strategy

```swift
final class MockChatService: ChatServiceProtocol {
    var lastAskMessage: String?
    var sessionsCreated: Int = 0
    func createSession() throws -> ChatSession
    func ask(message: String, in session: ChatSession) async throws -> ChatAnswerOutput
    // ...
}
```

既存 spec 021 ChatServiceTests の MockLanguageModelSession は内部実装テスト用、本 test では Service 層 Mock が必要。

## Constitution Compliance

- I (privacy): ChatService 経由 (on-device LM)、外部送信ゼロ ✅
- III (source 追跡): ChatService.ask の citedArticles は既存 spec 021 仕様で保持 ✅
- IV (iOS 実現可能性): 既存 ChatService 流用、新 API ゼロ ✅
- VI (architecture): Protocol + Default + Test Mock = 2 箇所抽象化 ✅

## DI

`ServiceContainer.deepDiveChatStarter: DeepDiveChatStarterProtocol?` + bootstrap で chatService + tracker inject。

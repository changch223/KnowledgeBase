# Contract: `ChatService.ask` Hook Extension

**File**: `KnowledgeTree/Services/ChatService.swift` (改修、~15 行追加)
**Type**: 既存 service の末尾 hook + DI 追加

## Purpose

ChatService.ask の assistantMessage 永続化直後に SavedAnswerService.captureIfWorthy を fire-and-forget Task で呼ぶ hook。spec 037 / 040 / 042 と同パターン。

## Modifications

### 1. Dependency 追加

```swift
@MainActor
final class ChatService: ChatServiceProtocol {
    // ... 既存 properties (context, embeddingService, session, availability, graphTraversal, ...)

    /// spec 043: chat 答え永続化時の SavedAnswer 自動保存用 (default nil で後方互換)
    private weak var savedAnswerService: SavedAnswerServiceProtocol?

    init(
        context: ModelContext,
        embeddingService: EmbeddingService,
        session: LanguageModelSessionProtocol,
        availability: AvailabilityChecker = SystemLanguageModelAvailabilityChecker(),
        graphTraversal: GraphTraversalServiceProtocol? = nil,
        savedAnswerService: SavedAnswerServiceProtocol? = nil   // ★ 追加
    ) {
        // ...
        self.savedAnswerService = savedAnswerService
    }
}
```

### 2. ask 末尾に hook 追加

```swift
func ask(question: String, in session: ChatSession) async throws -> ChatMessage {
    // ... 既存処理 (retrieval / 回答生成 / cited フィルター / cleanedAnswer / persist assistantMessage)

    // ★ 末尾 (return assistantMessage の直前)
    Task { [weak self] in
        await self?.savedAnswerService?.captureIfWorthy(
            question: trimmed,                // 既存変数 (trim 済 question)
            answer: cleanedAnswer,             // 既存変数 (UUID strip 済 answer 本文)
            citedArticleIDs: filteredCited,    // 既存変数 ([String]、availableIDs 通過済)
            sessionID: session.id              // ChatSession.id
        )
    }

    return assistantMessage
}
```

`persistAssistantUnknown` (「分かりません」path) や `persistAssistantFallback` (Foundation 失敗 path) からは **hook を呼ばない** (citedArticleIDs 空 + 50 字未満なので Service 側で reject されるが、無駄な呼び出しを避ける)。

### 3. ServiceContainer 更新

`ServiceContainer.swift` に property 追加:

```swift
@MainActor
@Observable
final class ServiceContainer {
    // ... 既存
    /// spec 043: SavedAnswer の auto-save / pin / delete service
    var savedAnswerService: SavedAnswerServiceProtocol?
}
```

### 4. KnowledgeTreeApp bootstrap

`KnowledgeTreeApp.bootstrap()` で SavedAnswerService 構築 + ChatService に inject + ServiceContainer に登録:

```swift
// spec 043: SavedAnswerService 構築 (純粋ロジック、AI 不要)
let savedAnswerService: SavedAnswerServiceProtocol = DefaultSavedAnswerService(
    context: context,
    refreshTrigger: refreshTrigger
)

// spec 021 ChatService 構築に inject 追加
let chatService: ChatServiceProtocol = ChatService(
    context: context,
    embeddingService: embeddingService,
    session: session,
    availability: availability,
    graphTraversal: graphTraversalService,
    savedAnswerService: savedAnswerService  // ★ 追加
)

// ServiceContainer 登録
serviceContainer.savedAnswerService = savedAnswerService  // ★ 追加
```

## Concurrency

- hook Task は fire-and-forget、`[weak self]` capture
- ChatService.ask 本体は SavedAnswer 処理の完了を待たない (latency 影響ゼロ)
- SavedAnswerService.captureIfWorthy は `@MainActor` 保証 (内部で context.save)

## Error Handling

- hook は throw しない (SavedAnswerService 内部で silent fail)
- ChatService.ask の戻り値 (assistantMessage) は影響なし

## Tests

`ChatServiceTests` に 1-2 ケース追加:
- `ask()` 完了後、`MockSavedAnswerService.captureIfWorthyCallCount == 1`
- SavedAnswerService 未注入 (nil) で `ask()` 正常完了 (後方互換)

## Acceptance Criteria

- [x] ChatService.ask 末尾で savedAnswerService.captureIfWorthy が呼ばれる
- [x] `persistAssistantUnknown` / `persistAssistantFallback` path では hook 呼ばない
- [x] hook が nil でも ask() 正常完了する (optional 注入)
- [x] hook 内エラーが ask() 本体に伝播しない
- [x] 既存 ChatServiceTests 全 PASS (regression なし)

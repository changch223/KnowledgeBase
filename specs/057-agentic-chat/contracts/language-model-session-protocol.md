# Contract: LanguageModelSessionProtocol Extension

## Purpose

既存 `LanguageModelSessionProtocol` に `generateAgentAction` メソッドを追加。AgentAction Generable enum を Foundation Models 経由で取得。

## Protocol Addition

```swift
@MainActor
protocol LanguageModelSessionProtocol: AnyObject {
    // 既存メソッド (省略、無改修)
    func generate<T: Generable>(prompt: String) async throws -> T
    func generateText(prompt: String) async throws -> String
    func generateTutorReply(prompt: String) async throws -> String  // spec 044

    // spec 057 新規
    func generateAgentAction(prompt: String, context: [ChatMessage]) async throws -> AgentAction
}
```

## Foundation Implementation (FoundationModelLanguageModelSession)

```swift
extension FoundationModelLanguageModelSession {
    func generateAgentAction(prompt: String, context: [ChatMessage]) async throws -> AgentAction {
        // context を multi-turn message として fold
        let contextLines = context.suffix(4).map { msg in
            let role = msg.role == "user" ? "ユーザー" : "アシスタント"
            return "\(role): \(msg.text)"
        }.joined(separator: "\n")

        let fullPrompt = """
        \(prompt)

        ## 直前の会話
        \(contextLines)
        """

        let response = try await session.respond(
            to: fullPrompt,
            generating: AgentAction.self,
            options: GenerationOptions(temperature: 0.7)
        )
        return response.content
    }
}
```

## Mock Implementation (MockLanguageModelSession)

```swift
extension MockLanguageModelSession {
    // FIFO で AgentAction sequence を制御
    var nextAgentActions: [AgentAction] {
        get { _nextAgentActions }
        set { _nextAgentActions = newValue }
    }
    private var _nextAgentActions: [AgentAction] = []
    private(set) var agentActionCallCount: Int = 0
    private(set) var lastAgentActionPrompt: String = ""

    func generateAgentAction(prompt: String, context: [ChatMessage]) async throws -> AgentAction {
        agentActionCallCount += 1
        lastAgentActionPrompt = prompt
        if let throwError = nextThrowError {
            nextThrowError = nil
            throw throwError
        }
        guard !_nextAgentActions.isEmpty else {
            // default fallback
            return .immediate(answer: "Mock default answer")
        }
        return _nextAgentActions.removeFirst()
    }
}
```

## Usage in ChatService

```swift
// ChatService.agentLoop 内
let action = try await session.generateAgentAction(
    prompt: buildAgentPrompt(question: question, state: state, forceFinalAnswer: state.isMaxRoundReached),
    context: state.conversationContext
)
switch action {
case .immediate(let answer): ...
case .askClarification(let q, let chips): ...
case .searchArticles(let query): ...
case .finalAnswer(let text, let ids): ...
}
```

## Test Cases

1. Mock で `.immediate` を返す → ChatService が即答動作
2. Mock で `.askClarification` × 3 + `.immediate` → 3 round 後 immediate
3. Mock で `.searchArticles` + `.finalAnswer` → search 実行 + final 答え
4. Mock で error throw → ChatService が fallback generate
5. context が 4 message 超過 → 直前 4 件に truncate
6. AgentAction の Generable schema 解析が token budget 内 (~800 token)

## Token Budget

- AgentAction Generable schema: ~800 token (推定)
- prompt template (system + rules): ~500 token
- context (4 message): ~1000 token
- response budget: ~1800 token (response 用に確保)
- 合計: ~4100 token (4096 上限ギリ、graceful degrade で 4 → 2 message reduce)

## Error Handling

- Foundation Models throw → ChatService がキャッチ → fallback `generate(prompt:)` で plain answer
- Codable decode error (AgentAction format 違反) → 同じく fallback
- Cancellation → silent propagate (既存 spec 044 同パターン)

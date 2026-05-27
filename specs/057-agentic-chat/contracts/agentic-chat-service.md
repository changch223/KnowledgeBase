# Contract: ChatService Internal Agent Loop

## Purpose

既存 `ChatServiceProtocol` の public API を維持しつつ、内部実装を agent loop に refactor。UI 改修ゼロを実現。

## Public API (改修なし、既存維持)

```swift
@MainActor
protocol ChatServiceProtocol: AnyObject {
    func createSession() throws -> ChatSession
    func send(question: String, in session: ChatSession, contextMessages: [ChatMessage]) async throws -> ChatMessage
    func ask(message: String, in session: ChatSession) async throws -> ChatMessage
    func backfillEmbeddings() async
    func deleteAllSessions() throws
    func deleteSession(_ session: ChatSession) throws
}
```

## Internal Implementation (全面 refactor)

```swift
@MainActor
final class ChatService: ChatServiceProtocol {
    // 既存 dependencies (変更なし)
    private let context: ModelContext
    private let embeddingService: EmbeddingService
    private let session: LanguageModelSessionProtocol
    private let availability: AvailabilityChecker
    private let graphTraversal: GraphTraversalServiceProtocol?
    private let savedAnswerService: SavedAnswerServiceProtocol

    // spec 057 新規 internal state (per send call)
    private let maxClarificationRounds = 3

    func send(
        question: String,
        in session: ChatSession,
        contextMessages: [ChatMessage]
    ) async throws -> ChatMessage {
        // 1. user message を永続化 (既存動作)
        let userMessage = ChatMessage(role: .user, text: question)
        session.messages?.append(userMessage)
        try context.save()

        // 2. agent loop 開始
        var state = AgentState(conversationContext: contextMessages + [userMessage])

        // 3. agent loop iterate (max 3 + 1 final)
        let result = try await agentLoop(question: question, state: &state, session: session)

        // 4. assistant message を永続化 + post-process filter 適用
        let filtered = HedgePhraseFilter.replace(result.finalText)
        let assistantMessage = ChatMessage(
            role: .assistant,
            text: filtered,
            citedArticleIDs: result.citedArticleIDs
        )
        session.messages?.append(assistantMessage)
        try context.save()

        // 5. spec 057: SavedAnswer auto-save 廃止 (captureIfWorthy は no-op)
        // 旧 hook 呼び出しは残すが、内部 no-op (regression risk なし)
        try? savedAnswerService.captureIfWorthy(
            question: question,
            answer: filtered,
            citedArticleIDs: result.citedArticleIDs,
            sessionID: session.id
        )

        // 6. debug log
        NSLog("agent loop done: rounds=\(state.clarificationRound) search=\(state.searchPerformed)")

        return assistantMessage
    }

    private func agentLoop(
        question: String,
        state: inout AgentState,
        session: ChatSession
    ) async throws -> (finalText: String, citedArticleIDs: [UUID]) {
        var iteration = 0
        while iteration < maxClarificationRounds + 1 {
            iteration += 1

            // prompt 生成 (state によって forceFinalAnswer フラグ追加)
            let prompt = buildAgentPrompt(
                question: question,
                state: state,
                forceFinalAnswer: state.isMaxRoundReached
            )

            // LLM 呼び出し
            let action: AgentAction
            do {
                action = try await self.session.generateAgentAction(
                    prompt: prompt,
                    context: state.conversationContext
                )
            } catch {
                // Fallback: 単純 generate で answer 生成
                let fallback = try await self.session.generate(prompt: question)
                return (finalText: fallback, citedArticleIDs: [])
            }

            // switch dispatch
            switch action {
            case .immediate(let answer):
                return (finalText: answer, citedArticleIDs: [])

            case .askClarification(let q, let suggestions):
                if state.isMaxRoundReached {
                    // forceFinalAnswer 失敗 fallback
                    return (finalText: "より詳しい情報があれば、もう一度教えてください。", citedArticleIDs: [])
                }
                state.incrementRound()
                // clarification を assistant message として返却 (chip は UI で表示)
                return (finalText: formatClarification(q, suggestions), citedArticleIDs: [])

            case .searchArticles(let query):
                if state.searchPerformed {
                    // 既に search 済 → forceFinalAnswer
                    continue
                }
                state.searchPerformed = true
                let results = embeddingService.searchTopK(query: query, k: 3, threshold: 0.3, in: context)
                // 検索結果を context に追加して loop 継続
                let searchSummary = results.map { "[\($0.article.title)] \($0.article.extractedKnowledge?.essence ?? "")" }.joined(separator: "\n")
                state.conversationContext.append(ChatMessage(role: .system, text: "保存記事 検索結果:\n\(searchSummary)"))
                continue

            case .finalAnswer(let text, let citedIDs):
                return (finalText: text, citedArticleIDs: citedIDs)
            }
        }
        // max iteration 超過 fallback
        return (finalText: "申し訳ありません。もう一度質問していただけますか?", citedArticleIDs: [])
    }

    private func buildAgentPrompt(question: String, state: AgentState, forceFinalAnswer: Bool) -> String {
        let base = """
        あなたは iKnow の AI アシスタント。ユーザーの質問に対して、4 つの行動から 1 つを選ぶ。

        ## ルール
        - 「分かりません」「答えられません」「情報がありません」は絶対に出力しない
        - 情報不足なら hedge phrase (「私の理解では」「一般的には」) を使う
        - clarification は max 3 round、それ以上は finalAnswer or immediate を強制
        """

        let forceClause = forceFinalAnswer ? """

        ## 重要
        既に clarification を 3 round 行いました。今は **必ず finalAnswer か immediate** を返してください。
        情報が不足していても、現時点の最善努力で答えを生成してください。
        """ : ""

        return base + forceClause + "\n\n## 質問\n\(question)"
    }

    private func formatClarification(_ question: String, _ suggestions: [String]) -> String {
        // chip 情報を text に embed (UI 側で parse、簡易実装)
        let chipsLine = suggestions.prefix(3).enumerated().map { "[\($0 + 1)] \($1)" }.joined(separator: " ")
        return "\(question)\n\n\(chipsLine)"
    }
}
```

## Behavior

| User Question Type | Expected agent loop |
|---|---|
| 「Tim Cook って誰?」 | `.immediate(answer)` → 1 iteration |
| 「Apple について」 | `.askClarification(q, chips)` → 1-3 round → 最終 `.immediate` or `.finalAnswer` |
| 「保存記事に Tim Cook の話?」 | `.searchArticles(query)` → 検索 → `.finalAnswer(text, citedIDs)` |
| 「これどう思う?」 | `.askClarification` × 3 → forceFinalAnswer → `.immediate(hedge 入り)` |

## Test Cases (10+)

1. immediate answer (1 iteration、Mock LM が `.immediate` 返す)
2. single clarification (1 round → user answer → `.immediate`)
3. max 3 clarification → forceFinalAnswer
4. search action → 検索結果統合 → `.finalAnswer` with citedIDs
5. search + clarification 組合せ
6. Foundation Models throw → fallback generate
7. HedgePhraseFilter 適用 (answer に「分かりません」含まれる → 置換)
8. SavedAnswer auto-save が no-op (新 SavedAnswer が増えない)
9. session.messages へ user/assistant message 永続化
10. multi-turn context が次 agent loop に渡る
11. AgentAction Codable round-trip (各 case)
12. unknown agent action → default fallback

## Performance Constraints

- 平均 agent loop iteration: 1.5 round (SC-004)
- 即答時 elapsed: 2.5 sec 以内 (SC-010)
- clarification 含む: 5 sec 以内
- RAG 検索含む: 8 sec 以内
- token usage: 1 iteration あたり <= 3000 token (4096 上限の 75%)

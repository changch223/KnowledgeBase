# Contract — ChatService

**spec**: 021 / **file**: `KnowledgeTree/Services/ChatService.swift` (new)

## 役割

ユーザー質問 → retrieval → Foundation Models 回答生成 → ハルシネーション post-process → ChatMessage 永続化を担当する Service。

## API

```swift
@MainActor
protocol ChatServiceProtocol {
    func send(question: String, in session: ChatSession) async throws -> ChatMessage
    func createSession() throws -> ChatSession
    func deleteAllSessions() throws
}

@MainActor
final class ChatService: ChatServiceProtocol {
    init(
        modelContext: ModelContext,
        embeddingService: EmbeddingService,
        sessionFactory: @escaping () -> any LanguageModelSessionProtocol,
        availability: AvailabilityChecker
    )

    func send(question: String, in session: ChatSession) async throws -> ChatMessage
    func createSession() throws -> ChatSession  // 50 件超過で FIFO 削除
    func deleteAllSessions() throws
}
```

## 動作フロー (`send`)

1. **user message 永続化**: `ChatMessage(role: "user", text: question)` を session に追加、save
2. **retrieval**:
   - Embedding 可: `EmbeddingService.embed(question)` → `topK(corpus: 全 article, k=5)`
   - Embedding 不可: title / essence の keyword マッチで top-k=3
3. **low-similarity 早期 return** (R7): top-k 全 < 0.3 → assistant message text = "分かりません…" / cited = []
4. **回答生成**:
   - Foundation Models 可: prompt 組立て → `LanguageModelSession.respond(generating: ChatAnswerOutput.self)`
   - Foundation Models 不可: top-k 記事の essence + KeyFact を整形 → "以下の記事が参考になります" の Fallback
5. **post-process** (R7):
   - `citedArticleIDs` 空 → text 上書き「分かりません…」、cited = []
   - 存在しない ID → filter
6. **assistant message 永続化** + session.lastMessageAt 更新

## エラー伝播

- LanguageModelSession 失敗 → ChatService 内で catch、Fallback 経路へ
- ModelContext.save 失敗 → throws (UI で alert 表示)

## 50 件 FIFO (`createSession`)

```
fetch ChatSession sorted by createdAt ASC
if count >= 50:
    delete first (cascade で messages も削除)
insert new session
```

## Test cases (T011)

| # | シナリオ | 期待 |
|---|---|---|
| 1 | 質問 → embedding retrieval → 引用付き回答 | citedArticleIDs.count >= 1 |
| 2 | low-similarity (空 corpus) | text = "分かりません…" |
| 3 | LM 出力 cited が空 | text を「分かりません」上書き |
| 4 | LM 出力 cited に存在しない ID | filter で消える |
| 5 | Embedding 不可 → keyword fallback | mode = .keyword で動作 |
| 6 | Foundation Models 不可 → KeyFact 並べ | text に "以下の記事..." 含む |
| 7 | createSession で 51 件目 | 古い 1 件削除、count = 50 維持 |
| 8 | deleteAllSessions | 全 session + message 消える |

## Constitution

- I (privacy): on-device only
- III (source 追跡): citedArticleIDs 必須、空時は「分かりません」
- IV (実現可能性): Foundation Models + NLEmbedding 確立 API
- V (calm UX): silent 保存、エラー時のみ UI alert
- VI (architecture): protocol + DI で test 可能

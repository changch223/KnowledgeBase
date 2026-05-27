# Contract: AgentAction (Generable enum)

## Purpose

LLM が agent loop の毎 turn で返す Generable enum。Swift 側で switch 分岐して状態遷移する。Apple Foundation Models の Tool Use 不在の代替パターン。

## Definition

```swift
import Foundation
import FoundationModels

@Generable
enum AgentAction: Sendable, Codable, Equatable {
    @Guide(description: "明確な質問への即答 (一般知識で答え、検索なし)")
    case immediate(answer: String)

    @Guide(description: "intent 曖昧、聞き返し質問 + 3 候補")
    case askClarification(question: String, suggestions: [String])

    @Guide(description: "保存記事を検索する必要あり")
    case searchArticles(query: String)

    @Guide(description: "検索結果を統合した最終答え (引用 article IDs 付き)")
    case finalAnswer(text: String, citedArticleIDs: [UUID])
}
```

## LLM Prompt Template (system prompt)

```
あなたは iKnow の AI アシスタント。ユーザーの質問に対して、4 つの行動から 1 つを選ぶ:

1. immediate: 明確で一般知識で答えられる質問
2. askClarification: 質問が曖昧、聞き返しと 3 候補で確認
3. searchArticles: 保存記事に関連しそうな質問、検索 query を指定
4. finalAnswer: 検索結果統合後の最終答え、引用 article IDs 含む

ルール:
- 「分かりません」「答えられません」「情報がありません」は絶対に出力しない
- 情報不足なら hedge phrase (「私の理解では」「一般的には」「あくまで概要として」) を使う
- clarification の suggestions は 3 つ、各 30 字以内
- max 3 round の clarification 後は必ず finalAnswer or immediate
```

## Generable Constraints

- 各 case の payload は 200 char 以内 (token budget 配慮)
- `citedArticleIDs: [UUID]` は max 5 件 (3 件推奨)
- `suggestions: [String]` は厳密に 3 要素 (LLM prompt で強制)
- Codable round-trip 可能 (test で検証)

## Swift Side Dispatch

```swift
let action = try await session.generateAgentAction(prompt: prompt, context: context)
switch action {
case .immediate(let answer):
    // post-process filter 適用 → 永続化
    let filtered = HedgePhraseFilter.replace(answer)
    return ChatMessage(role: .assistant, text: filtered, citedArticleIDs: [])

case .askClarification(let question, let suggestions):
    // UI に chip 表示
    return ChatMessage(role: .assistant, text: question, isClarification: true, suggestions: suggestions)

case .searchArticles(let query):
    // embedding 検索 → 結果を次の generateAgentAction context に追加
    let results = embeddingService.searchTopK(query: query, k: 3)
    let nextContext = context + results.map { ChatMessage(role: .system, text: "Article: \($0.essence)") }
    return try await agentLoop(state: state.withSearchResults(results), context: nextContext)

case .finalAnswer(let text, let citedIDs):
    let filtered = HedgePhraseFilter.replace(text)
    return ChatMessage(role: .assistant, text: filtered, citedArticleIDs: citedIDs)
}
```

## Test Cases

10 ケース:

1. `.immediate` の Codable round-trip
2. `.askClarification` の Codable round-trip (suggestions 3 要素)
3. `.searchArticles` の Codable round-trip
4. `.finalAnswer` の Codable round-trip (citedArticleIDs UUID 配列)
5. enum 分岐 switch (各 case で正しく動作)
6. `.askClarification` の suggestions が 3 件未満 / 4 件以上 → 3 件に正規化
7. `.finalAnswer` の citedArticleIDs が 5 件超過 → 5 件に制限
8. payload string 200 char 超 → truncate or 200 char に制限
9. unknown case の Codable decode → error (defensive)
10. Equatable 比較 (test fixture 用)

## Performance

- Generable schema size: ~800 token (4096 上限の 20% 使用)
- prompt + context (4 message): ~1500 token
- search results 3 件 × 100 char essence: ~300 token
- response budget: ~1500 token (余裕)

## Edge Cases

- `.searchArticles` で query が empty → fallback で `.immediate("検索 query が空です…")` 返却
- `.askClarification` で同 question を 3 回連続 → forceFinalAnswer prompt で `.immediate` or `.finalAnswer` 強制
- LLM が unknown case を生成 → Codable decode error → default `.immediate("申し訳ありません…")` fallback

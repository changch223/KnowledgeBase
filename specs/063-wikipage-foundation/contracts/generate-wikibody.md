# Contract: generateWikiBody plain string 生成 (R3)

## 対象
- `KnowledgeTree/Services/LanguageModelSessionProtocol.swift`

## protocol 追加
```swift
func generateWikiBody(prompt: String) async throws -> String
```

## FoundationModelLanguageModelSession 実装 (generateTutorReply 同型、:355)
```swift
func generateWikiBody(prompt: String) async throws -> String {
    let session = LanguageModelSession()
    let response = try await session.respond(to: prompt)   // @Generable 不使用 = token 節約
    return response.content
}
```

## Mock 追従
```swift
var nextWikiBodyResult: Result<String, Error>?
private(set) var wikiBodyCallCount = 0
func generateWikiBody(prompt: String) async throws -> String {
    wikiBodyCallCount += 1
    switch nextWikiBodyResult { ... }   // default は適当な非空 String
}
```

## 契約条件
| 条件 | 期待 |
|---|---|
| @Generable schema | 渡さない (plain string respond)、token ~1500 節約 (SC-002) |
| 長い入力 | 出力 schema コストゼロゆえ token 上限内 |
| Mock default | 既存テスト (generateWikiBody 未設定) が壊れない |

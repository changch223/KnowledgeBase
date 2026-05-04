# Contract: KnowledgeExtractor

**Layer**: Foundation Models 抽象境界 (Constitution Principle VI)
**Used by**: `KnowledgeExtractionService`

## Purpose

Apple Foundation Models の `LanguageModelSession` を thin にラップし、`extractedText` を入力に取り `ExtractedKnowledgeOutput` (Generable struct) を返す純粋なジェネレータ。テストでは `MockLanguageModelSession` で差し替え。

## Interface

```swift
protocol LanguageModelSessionProtocol: Sendable {
    func generateKnowledge(prompt: String) async throws -> ExtractedKnowledgeOutput
}

@MainActor
final class FoundationModelLanguageModelSession: LanguageModelSessionProtocol {
    func generateKnowledge(prompt: String) async throws -> ExtractedKnowledgeOutput {
        let session = LanguageModelSession()  // 都度作成 (research.md / R4)
        let response = try await session.respond(
            generating: ExtractedKnowledgeOutput.self,
            prompt: prompt
        )
        return response.content
    }
}

@MainActor
struct KnowledgeExtractor {
    let session: LanguageModelSessionProtocol

    /// extractedText から prompt を組み立てて Foundation Models で生成。
    /// availability チェックは呼び出し側 (Service) の責務。
    func extract(extractedText: String) async throws -> ExtractedKnowledgeOutput {
        let prompt = buildPrompt(text: extractedText)
        return try await session.generateKnowledge(prompt: prompt)
    }

    /// research.md / R3 の strict instructions を含む日本語 prompt を構築。
    private func buildPrompt(text: String) -> String {
        """
        以下の記事本文から構造化された知識を抽出してください。

        # 抽出ルール (厳守)
        - 元記事に明示されている内容のみを抽出してください
        - 推測・補完・常識による補強は行わないでください
        - 該当する事実が見つからない場合は空配列を返してください
        - essence と summary と key facts は互いに矛盾しないでください
        - すべて日本語で出力してください

        # 元記事本文
        \(text)
        """
    }
}
```

## Behavior

### `extract(extractedText:)`

1. `buildPrompt(text:)` で日本語 prompt 文字列を構築 (research.md / R3 の strict instructions を含む)。
2. `session.generateKnowledge(prompt:)` を呼び `ExtractedKnowledgeOutput` を取得。
3. throw されたエラーはそのまま上位 (Service) に伝播 (本 contract は判定しない)。

### `buildPrompt(text:)`

固定テンプレート (Plan 設計判断 #6)。MVP では Swift 文字列リテラルとして埋め込む。

## Error handling

本 contract はエラーを catch せず、`throws` で上位 (Service) に伝播する。Service 層で `ExtractionStatus` への分類を行う (research.md / R5):

- `LanguageModelSession.SafetyFilterError` → `.failed`
- `LanguageModelSession.ContextWindowExceededError` → `.failed` (extractedText 切り詰め retry も検討)
- `LanguageModelSession.GenerationError` (parse 失敗等) → `.failed` または `.partiallySucceeded` (部分要素が取れた場合)
- `URLError(.timedOut)` 等 → `.failed`
- `CancellationError` → 状態変更なし (`.pending` のまま)

## Threading

- `protocol` は `Sendable`、実装は `@MainActor`。
- 実 Foundation Models 呼び出しは `Task.detached(priority: .utility)` から行う想定 (Service 側で wrap)。

## Tests (KnowledgeTreeTests / `KnowledgeExtractorTests`)

| ケース | 入力 | Mock の動作 | 期待 |
|---|---|---|---|
| 通常成功 | "記事本文..." (200+ 字) | `nextResult = .success(fixture)` | fixture の ExtractedKnowledgeOutput が返る |
| safety filter blocked | 任意 | `nextResult = .failure(SafetyError)` | throw、上位で `.failed` 判定 |
| context 超過 | 巨大 text | `nextResult = .failure(ContextError)` | throw、上位で `.failed` 判定 |
| timeout | 任意 | `nextResult = .failure(URLError(.timedOut))` | throw |
| empty output | 任意 | `nextResult = .success(空 output)` | 空の output が返る (Service 層で `.failed` 判定) |
| partial output | 任意 | `nextResult = .success(essence のみ)` | partial output が返る (Service 層で `.partiallySucceeded` 判定) |

すべて `MockLanguageModelSession` で決定論的に走る。実 Foundation Models のテストは quickstart 手動検証。

## Mock implementation (test)

```swift
final class MockLanguageModelSession: LanguageModelSessionProtocol, @unchecked Sendable {
    var nextResult: Result<ExtractedKnowledgeOutput, Error> = .success(.fixture())
    var callCount = 0
    var lastPrompt: String?

    func generateKnowledge(prompt: String) async throws -> ExtractedKnowledgeOutput {
        callCount += 1
        lastPrompt = prompt
        switch nextResult {
        case .success(let v): return v
        case .failure(let e): throw e
        }
    }
}

extension ExtractedKnowledgeOutput {
    static func fixture(
        essence: String = "Apple は WWDC で iOS 26 を発表した。",
        summary: String = "Apple は 2025 年の WWDC で iOS 26 を発表し、Foundation Models を公開した。Tim Cook 氏は AI のオンデバイス実行を強調した。",
        keyFacts: [KeyFactOutput] = [
            KeyFactOutput(statement: "WWDC 2025 が開催された", type: .event),
            KeyFactOutput(statement: "iOS 26 が発表された", type: .event),
            KeyFactOutput(statement: "Foundation Models は on-device で動作する", type: .claim),
        ],
        entities: [KnowledgeEntityOutput] = [
            KnowledgeEntityOutput(name: "Apple", type: .organization, salience: 5),
            KnowledgeEntityOutput(name: "iOS 26", type: .product, salience: 5),
            KnowledgeEntityOutput(name: "WWDC", type: .event, salience: 4),
            KnowledgeEntityOutput(name: "Tim Cook", type: .person, salience: 4),
            KnowledgeEntityOutput(name: "Foundation Models", type: .product, salience: 5),
        ]
    ) -> Self {
        Self(essence: essence, summary: summary, keyFacts: keyFacts, entities: entities)
    }
}
```

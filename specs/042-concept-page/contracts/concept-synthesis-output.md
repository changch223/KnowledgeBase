# Contract: `ConceptSynthesisOutput` (@Generable)

**File**: `KnowledgeTree/Services/LanguageModelSessionProtocol.swift` (改修、~50 行追加)
**Type**: `@Generable Codable` struct + protocol method 追加 + Mock 拡張

## Purpose

Foundation Models から ConceptPage の AI 合成結果 (summary + crossSourceInsights) を
構造化出力として受け取るための schema 定義。spec 040 GraphTripleOutput / spec 018
DigestOutput と同パターン。

## Public API

### `ConceptSynthesisOutput`

```swift
import FoundationModels

@Generable
struct ConceptSynthesisOutput: Codable {
    @Guide(description: """
    概念について複数の保存記事から統合した「今わかっていること」を、
    200〜400 字の日本語で書きなさい。
    重要:
    - 推測や一般知識から補強した内容は含めない。原文に明示された内容のみ統合すること。
    - 主語は省略可、断定調 (「である / する / だ」)。です・ます調禁止。
    - 元記事の固有名詞 (英語 / カタカナ) は原文のまま維持。
    """)
    let summary: String

    @Guide(description: """
    複数記事を横断して見える知見の bullet 配列。最大 7 件、各 50〜150 字の日本語。
    「単一記事だけでは見えない発見」を含めること。例:
    - 「A 社と B 社が異なる時期に同じ戦略を取った」
    - 「2024 年から 2026 年にかけて方針が変化している」
    記事に書かれていない推測は含めない。
    1 つも見つからなければ空配列を返す。
    """)
    let crossSourceInsights: [String]
}
```

### `ConceptSummaryChunk` (補助型、hierarchical 用)

```swift
@Generable
struct ConceptSummaryChunk: Codable {
    @Guide(description: """
    この記事チャンクの要点を 100-200 字の日本語でまとめた要約。
    断定調、原文にない情報は含めない。
    """)
    let chunkSummary: String
}
```

### `LanguageModelSessionProtocol` 追加 method

```swift
protocol LanguageModelSessionProtocol: AnyObject {
    // ... 既存 method (generateTriple, generateDigest, generateChat, ...)

    func generateConceptSynthesis(prompt: String) async throws -> ConceptSynthesisOutput
    func generateConceptSummaryChunk(prompt: String) async throws -> ConceptSummaryChunk
}
```

### `FoundationModelLanguageModelSession` 実装

```swift
final class FoundationModelLanguageModelSession: LanguageModelSessionProtocol {
    // ... 既存実装

    func generateConceptSynthesis(prompt: String) async throws -> ConceptSynthesisOutput {
        let response = try await session.respond(
            to: prompt,
            generating: ConceptSynthesisOutput.self
        )
        return response.content
    }

    func generateConceptSummaryChunk(prompt: String) async throws -> ConceptSummaryChunk {
        let response = try await session.respond(
            to: prompt,
            generating: ConceptSummaryChunk.self
        )
        return response.content
    }
}
```

### `MockLanguageModelSession` 拡張

```swift
final class MockLanguageModelSession: LanguageModelSessionProtocol {
    // ... 既存 properties (mockDigest, mockTriples, ...)

    var mockConceptSynthesis: ConceptSynthesisOutput?
    var mockConceptSummaryChunk: ConceptSummaryChunk?
    var conceptSynthesisCallCount: Int = 0
    var conceptSummaryChunkCallCount: Int = 0
    var shouldFailConceptSynthesis: Bool = false

    func generateConceptSynthesis(prompt: String) async throws -> ConceptSynthesisOutput {
        conceptSynthesisCallCount += 1
        if shouldFailConceptSynthesis {
            throw NSError(domain: "MockError", code: -1)
        }
        return mockConceptSynthesis ?? ConceptSynthesisOutput(
            summary: "Mock summary content for testing purposes (200+ chars)...",
            crossSourceInsights: ["Mock insight 1", "Mock insight 2"]
        )
    }

    func generateConceptSummaryChunk(prompt: String) async throws -> ConceptSummaryChunk {
        conceptSummaryChunkCallCount += 1
        return mockConceptSummaryChunk ?? ConceptSummaryChunk(
            chunkSummary: "Mock chunk summary content"
        )
    }
}
```

## Prompt Templates

### 1-shot (4 件以下、ConceptSynthesisService 内)

```
あなたは複数の保存記事から「{name}」について「今わかっていること」を統合する役割です。

## 概念
名前: {name}
別名: {aliases}
カテゴリー: {categoryDisplay}

## 元記事 (essence + KeyFact)
{記事ごとに}
- [{index}] {title} ({savedAt 日本語})
  essence: {essence}
  KeyFact: {keyFacts joined "、"}

## 出力要件
- summary: 200-400 字、原文に明示された内容のみ統合、断定調
- crossSourceInsights: 最大 7 件、各 50-150 字、複数記事を並べて初めて見える発見
- 推測・一般知識からの補強禁止
```

### Hierarchical chunk prompt (5+ 件、ConceptSummaryChunk 用)

```
あなたは保存記事のチャンクを要約する役割です。

## 概念
名前: {name}
カテゴリー: {categoryDisplay}

## 記事チャンク ({chunkIndex+1}/{totalChunks})
{記事ごとに}
- [{index}] {title} ({savedAt})
  essence: {essence}
  KeyFact: {keyFacts joined "、"}

## 出力要件
- chunkSummary: 100-200 字、原文に明示された内容のみ、断定調
```

### Hierarchical meta prompt (5+ 件、最終 ConceptSynthesisOutput 用)

```
あなたは複数の記事チャンク要約を統合して「{name}」について「今わかっていること」を
書く役割です。

## 概念
名前: {name}
別名: {aliases}
カテゴリー: {categoryDisplay}

## 記事チャンク要約 (元 {N} 件記事)
{chunkSummaries 各 100-200 字}

## 出力要件
- summary: 200-400 字、チャンク要約のみから統合、推測禁止
- crossSourceInsights: 最大 7 件、各 50-150 字、チャンクを横断して見える知見
```

## Acceptance Criteria

- [x] `ConceptSynthesisOutput` が Foundation Models から直接返る (JSON parse 不要)
- [x] Mock で deterministic な fixture を返却できる
- [x] Mock の callCount で session 呼び出し回数を検証できる (hierarchical テスト用)
- [x] `shouldFailConceptSynthesis = true` で Foundation 経路エラーシミュレーション可能
- [x] @Guide description で推測禁止 + 断定調を強制 (Constitution III + FR-031)

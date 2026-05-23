# Contract: `KnowledgeExtractionService` Stale Hook Extension

**File**: `KnowledgeTree/Services/KnowledgeExtractionService.swift` (改修、~10 行追加)
**Type**: 既存 service 末尾 hook 追加 + DI 追加

## Purpose

新規記事 ingest で関連 ConceptPage が isStale 化される時、その ConceptPage に紐付く SavedAnswer も isStale=true でマーク。spec 042 ConceptPage 自動生成 hook と並列で動作。

## Modifications

### 1. Dependency 追加

```swift
@MainActor
final class DefaultKnowledgeExtractionService: KnowledgeExtractionServiceProtocol {
    // ... 既存 properties (tagStore, digestService, embeddingService, conflictDetectionService, graphExtractionService, conceptSynthesisService)

    /// spec 043: 引用記事 → 関連 ConceptPage → SavedAnswer の isStale 連鎖用 (default nil で後方互換)
    private weak var savedAnswerService: SavedAnswerServiceProtocol?

    init(
        // ... 既存 parameters
        conceptSynthesisService: ConceptSynthesisServiceProtocol? = nil,
        savedAnswerService: SavedAnswerServiceProtocol? = nil   // ★ 追加
    ) {
        // ...
        self.savedAnswerService = savedAnswerService
    }

    /// spec 043: knowledge 抽出 succeeded/partiallySucceeded 直後に呼ばれる SavedAnswer.isStale 化 hook。
    /// fire-and-forget、失敗 silent。本 spec では UI 影響なし (WikiLint で別 spec)。
    private func markSavedAnswersStaleIfPossible(article: Article) {
        guard let savedAnswerService else { return }
        Task { [weak self] in
            _ = self
            await savedAnswerService.markStaleForArticle(article)
        }
    }
}
```

### 2. extract 末尾 (single + chunked 両経路) に hook 追加

spec 042 ConceptPage の `synthesizeConceptIfPossible(article:)` hook の隣に並列追加:

```swift
// 単一 extract path (extractedKnowledge_succeed の case)
applyAutoTagsIfPossible(article: article)
markDigestStaleIfPossible(article: article)
generateEmbeddingIfPossible(article: article)
detectConflictsIfPossible(article: article)
extractGraphIfPossible(article: article)
synthesizeConceptIfPossible(article: article)         // spec 042
markSavedAnswersStaleIfPossible(article: article)     // ★ spec 043 追加

// chunked extract path 末尾 (同じ 7 hooks を append)
```

### 3. ServiceContainer / KnowledgeTreeApp bootstrap

KnowledgeTreeApp.bootstrap() で KnowledgeExtractionService 構築時に inject 追加:

```swift
let knowledgeService = DefaultKnowledgeExtractionService(
    extractor: knowledgeExtractor,
    store: knowledgeStore,
    processingMonitor: processingMonitor,
    chunkProgressStore: chunkProgressStore,
    tagStore: tagStore,
    digestService: digestService,
    embeddingService: embeddingService,
    conflictDetectionService: conflictDetectionService,
    graphExtractionService: graphExtractionService,
    conceptSynthesisService: conceptSynthesisService,
    savedAnswerService: savedAnswerService           // ★ 追加
)
```

## Concurrency

- hook Task は fire-and-forget、`[weak self]` capture
- extract 本体は SavedAnswer 処理の完了を待たない
- markStaleForArticle は `@MainActor` で context fetch + update

## Error Handling

- hook は throw しない
- markStaleForArticle 内 try? + silent

## Tests

KnowledgeExtractionServiceTests に既存 ConceptPage hook 検証 (`MockConceptSynthesisService`) と並列で `MockSavedAnswerService` 注入の検証 1 ケース追加:

```swift
@Test func extractInvokesSavedAnswerStaleHookOnSingleShot() async {
    let mockSavedAnswer = MockSavedAnswerService()
    let (service, _, _) = makeService(savedAnswerService: mockSavedAnswer)
    let article = makeArticleWithBody()
    await service.extract(article: article)
    try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
    #expect(mockSavedAnswer.markStaleCallCount == 1)
}
```

## Acceptance Criteria

- [x] extract 末尾で savedAnswerService.markStaleForArticle が呼ばれる (single + chunked 両経路)
- [x] hook が nil でも extract が正常完了する (optional 注入)
- [x] hook 内エラーが extract 本体に伝播しない
- [x] 既存 spec 037 / 040 / 042 の hook も並列で動作し続ける

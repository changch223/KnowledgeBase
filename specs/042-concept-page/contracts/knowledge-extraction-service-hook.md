# Contract: `KnowledgeExtractionService` Hook Extension

**File**: `KnowledgeTree/Services/KnowledgeExtractionService.swift` (改修、~10 行追加)
**Type**: 既存 service 末尾 hook 追加 + dependency injection 追加

## Purpose

新規記事 ingest 時の知識抽出パイプライン (entity / KeyFact / essence) の末尾に、
ConceptSynthesisService.processNewArticle を fire-and-forget で呼ぶ hook を追加。
spec 037 ConflictDetection / spec 040 GraphExtraction と完全同パターン。

## Modifications

### 1. Dependency 追加

```swift
@MainActor
final class KnowledgeExtractionService {
    // ... 既存 properties (session, availability, context, refreshTrigger, ...)
    private weak var conflictDetectionService: ConflictDetectionServiceProtocol?
    private weak var graphExtractionService: GraphExtractionServiceProtocol?
    // ★ 追加:
    private weak var conceptSynthesisService: ConceptSynthesisServiceProtocol?

    init(
        session: LanguageModelSessionProtocol,
        availability: AvailabilityChecker,
        context: ModelContext,
        refreshTrigger: RefreshTrigger,
        embeddingService: EmbeddingServiceProtocol? = nil,
        conflictDetectionService: ConflictDetectionServiceProtocol? = nil,
        graphExtractionService: GraphExtractionServiceProtocol? = nil,
        conceptSynthesisService: ConceptSynthesisServiceProtocol? = nil  // ★ 追加
    ) {
        // ...
        self.conceptSynthesisService = conceptSynthesisService
    }
}
```

### 2. extract 経路 末尾に hook 追加

extract には 2 経路あり (1-shot と chunked)、両方の末尾に同 hook を追加:

```swift
// 1-shot extract (短記事)
func extract(article: Article) async {
    // ... 既存処理 (essence + KeyFact + entity 抽出 + save)

    // ★ 末尾: 他 service の hook (spec 037 / 040 / 042)
    Task { [weak self] in
        await self?.conflictDetectionService?.processNewArticle(article: article)
    }
    Task { [weak self] in
        await self?.graphExtractionService?.extractGraphIfPossible(article: article)
    }
    // ★ 042 追加:
    Task { [weak self] in
        await self?.conceptSynthesisService?.processNewArticle(article: article)
    }
}

// chunked extract (長記事、spec 010)
func extractChunked(article: Article) async {
    // ... 既存 hierarchical 処理

    // ★ 同じ 3 hook を末尾に追加
    Task { [weak self] in
        await self?.conflictDetectionService?.processNewArticle(article: article)
    }
    Task { [weak self] in
        await self?.graphExtractionService?.extractGraphIfPossible(article: article)
    }
    Task { [weak self] in
        await self?.conceptSynthesisService?.processNewArticle(article: article)
    }
}
```

### 3. ServiceContainer 更新

`ServiceContainer.swift` で KnowledgeExtractionService 構築時に conceptSynthesisService を渡す:

```swift
@MainActor
final class ServiceContainer {
    // ... 既存
    let conceptSynthesisService: ConceptSynthesisServiceProtocol
    let conceptPageStore: ConceptPageStore

    init(context: ModelContext, refreshTrigger: RefreshTrigger) {
        // ... 既存 service 構築

        // ★ Fallback service 先に構築
        let fallbackConcept = FallbackConceptSynthesisService(
            context: context,
            refreshTrigger: refreshTrigger
        )

        // ★ Foundation service 構築 (Fallback 注入)
        self.conceptSynthesisService = FoundationModelsConceptSynthesisService(
            session: foundationSession,
            availability: availability,
            fallback: fallbackConcept,
            embeddingService: embeddingService,
            context: context,
            refreshTrigger: refreshTrigger
        )

        // ★ Store 構築
        self.conceptPageStore = ConceptPageStore(
            context: context,
            refreshTrigger: refreshTrigger
        )

        // ★ KnowledgeExtractionService に inject
        self.knowledgeExtractionService = KnowledgeExtractionService(
            session: foundationSession,
            availability: availability,
            context: context,
            refreshTrigger: refreshTrigger,
            embeddingService: embeddingService,
            conflictDetectionService: conflictDetectionService,
            graphExtractionService: graphExtractionService,
            conceptSynthesisService: conceptSynthesisService  // ★ 追加
        )
    }
}
```

### 4. KnowledgeTreeApp bootstrap

`KnowledgeTreeApp.swift` で BGTask register + backfill 起動:

```swift
@main
struct KnowledgeTreeApp: App {
    init() {
        // ... 既存

        // ★ Concept resynthesis BGTask register
        BackgroundExtractionScheduler.registerConceptResynthesisTask(
            synthesisService: serviceContainer.conceptSynthesisService
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(serviceContainer)
                .task {
                    // ★ 初回 backfill (UserDefaults flag で 2 回目以降 skip)
                    await serviceContainer.conceptSynthesisService.backfillFromExistingArticles()
                    // ★ Stale 再合成 1 回トリガー
                    await serviceContainer.conceptSynthesisService.resynthesizeAllStale()
                }
        }
    }
}
```

## Concurrency

- 3 つの hook Task は並列で fire-and-forget、相互独立 (異なる service / 異なる
  ModelContext 操作)
- KnowledgeExtractionService.extract 本体は 3 Task の完了を待たない (latency 影響ゼロ)
- ConceptSynthesisService.processNewArticle 内部で `@MainActor` 保証

## Error Handling

- 3 hook はいずれも throw しない (Service 内部で silent fail)
- extract 本体に影響を与えない (Constitution V calm UX)

## Tests

`KnowledgeExtractionServiceTests` に 1-2 ケース追加:
- `MockConceptSynthesisService` を inject、extract 後に `processNewArticleCallCount` が 1
- chunked extract でも同 callCount が 1 (重複呼び出しなし)

## Acceptance Criteria

- [x] extract 末尾で conceptSynthesisService.processNewArticle が呼ばれる
- [x] 1-shot / chunked 両経路で hook が動作する
- [x] hook が nil でも extract が正常完了する (optional 注入)
- [x] hook 内 throw が extract 本体に伝播しない
- [x] 既存 spec 037 / 040 の hook も並列で動作し続ける

# Contract: `ConceptSynthesisService`

**File**: `KnowledgeTree/Services/ConceptSynthesisService.swift` (新規、~250 行)
**Type**: Protocol + 2 実装 (Foundation 経路 + Fallback 経路)

## Purpose

ConceptPage の自動生成 / 再合成パイプラインを提供する。Foundation Models 利用可能なら
複数記事を統合した summary + crossSourceInsights を AI 合成、不可なら Fallback 経路で
essence 並べた簡易 summary を生成。

## Public API

```swift
@MainActor
protocol ConceptSynthesisServiceProtocol: AnyObject {
    /// 新規記事 ingest 時に呼ばれる。記事内 entity を見て、
    /// - 2+ Article に同名登場 & 未存在 → ConceptPage 新規生成 (isStale=true)
    /// - 既存 ConceptPage あり → isStale = true で再合成予約
    /// silent fire-and-forget、例外を throw しない (内部で握り潰し + ActivityLog 記録)
    func processNewArticle(article: Article) async

    /// 単一 ConceptPage を再合成 (Foundation 経路 or Fallback 経路)
    /// 4 件以下 → 1-shot prompt
    /// 5+ 件 → hierarchical (chunked) + meta-summary
    func resynthesize(_ conceptPage: ConceptPage) async

    /// 全 stale ConceptPage を順次再合成 (BGTask から呼ばれる)
    /// 1 回の呼び出しで fetchLimit=5 まで、時間制限超過で中断可
    func resynthesizeAllStale() async

    /// 既存全 Article から ConceptPage 群を初期 backfill
    /// V1 リリース後 1 回起動時に呼ぶ (UserDefaults flag で 2 回目以降は skip)
    func backfillFromExistingArticles() async
}

@MainActor
final class FoundationModelsConceptSynthesisService: ConceptSynthesisServiceProtocol {
    init(
        session: LanguageModelSessionProtocol,
        availability: AvailabilityChecker,
        fallback: ConceptSynthesisServiceProtocol,
        embeddingService: EmbeddingServiceProtocol,
        context: ModelContext,
        refreshTrigger: RefreshTrigger
    )
}

@MainActor
final class FallbackConceptSynthesisService: ConceptSynthesisServiceProtocol {
    init(
        context: ModelContext,
        refreshTrigger: RefreshTrigger
    )
}
```

## Behavior

### `processNewArticle(article:)`

1. article.extractedKnowledge.entities から (name, categoryRaw) 一覧取得
2. 各 entity について:
   - lowercased(name) で他 Article 内出現件数を fetch (count)
   - `ConceptPage` 検索: `searchableNames.contains(lowercased(name))` && `categoryRaw == raw`
   - 既存あり: `isStale = true; updatedAt = .now`
   - 既存なし & 他出現件数 >= 1 (= 今回で 2 件目): 新規 ConceptPage 生成 (isStale=true)、
     relatedArticles に過去 1 件 + 今回記事 = 計 2 件追加
   - 既存なし & 他出現件数 == 0: 何もしない
3. `context.save()`、`refreshTrigger.bump()`

### `resynthesize(_:)`

```
availability.isAvailable == false → fallback.resynthesize(_:) に委譲
relatedArticles.count <= 4 → 1-shot prompt (R4)
relatedArticles.count >= 5 → hierarchical:
  chunks = relatedArticles.chunked(into: 4)
  chunkSummaries = chunks.map { session.generateChunkSummary(...) }
  metaPrompt = R4 prompt 形式 (元記事 = chunkSummaries text)
  output = session.generateConceptSynthesis(prompt: metaPrompt)
最終:
  conceptPage.summary = output.summary.trimmedToMax(500)
  conceptPage.crossSourceInsights = output.crossSourceInsights.prefix(7)
  conceptPage.embedding = await embeddingService.embed(text: output.summary)
  conceptPage.isStale = false
  conceptPage.updatedAt = .now
  context.save(); refreshTrigger.bump()
例外発生 → silent fail、isStale 維持、ActivityLog 記録 (将来 spec)
```

### `resynthesizeAllStale()`

```
descriptor = FetchDescriptor<ConceptPage>(predicate: #Predicate { $0.isStale })
descriptor.fetchLimit = 5
descriptor.sortBy = [SortDescriptor(\.updatedAt)]
for page in fetched: await resynthesize(page)
```

### `backfillFromExistingArticles()`

```
UserDefaults flag "ConceptPage.backfillCompleted" == true → 即 return
全 Article fetch → ConceptSynthesisService.processNewArticle を順次適用 (重複 entity は
ConceptPage 既存判定で skip される)
完了で flag = true 設定
```

## Fallback Service Behavior

Foundation Models 不可時の degraded mode。AI 呼び出しゼロ、ConceptPage を低品質だが
表示可能な状態にする。

```swift
extension FallbackConceptSynthesisService {
    func resynthesize(_ conceptPage: ConceptPage) async {
        let articles = conceptPage.relatedArticles.sorted { $0.savedAt > $1.savedAt }
        let essences = articles.compactMap { $0.extractedKnowledge?.essence }
        conceptPage.summary = essences.prefix(3).joined(separator: "\n\n")
        conceptPage.crossSourceInsights = essences.prefix(3).compactMap {
            $0.split(separator: "。").first.map(String.init)
        }
        conceptPage.isStale = false  // ★ Fallback でも一旦完了扱い
        conceptPage.updatedAt = .now
        try? context.save()
    }
}
```

Foundation 経路が後で利用可能になっても、Fallback で生成された summary は次回 isStale
trigger (新記事 ingest) で上書きされる。

## Concurrency

- `@MainActor` で SwiftData ModelContext と協調
- `processNewArticle` は呼び出し元 (KnowledgeExtractionService) の Task 内で実行、
  silent fire-and-forget
- `resynthesizeAllStale` は BGTask scope 内で実行、timeout 30 秒を超えないよう
  fetchLimit=5 で制御

## Error Handling

- すべての public method は throw しない (silent fail + 内部 log)
- Foundation Models 例外 → fallback に委譲
- SwiftData save 例外 → ActivityLog 記録 (将来 spec)、UI には伝播しない (calm UX)

## Acceptance Criteria

- [x] 2+ 同 entity 登場で ConceptPage 自動生成
- [x] 1 件のみ → 生成しない
- [x] 既存 ConceptPage + 新記事 → isStale = true
- [x] 4 件以下は 1-shot、5+ 件は hierarchical
- [x] availability=false → Fallback 経路で essence 並べた summary
- [x] Foundation 経路エラー時 silent fail
- [x] backfill が UserDefaults flag で 1 回限り
- [x] 全テスト 8-10 ケースで網羅 (research.md R10)

# Contract: KnowledgeExtractionService

**Layer**: Orchestration boundary (Constitution Principle VI)
**Used by**: `BodyExtractionService` (spec 003 — ArticleBody .succeeded 時に呼ぶ)、`KnowledgeTreeApp` (起動時 backfill)

## Purpose

Apple Intelligence の availability チェック → `KnowledgeExtractor` 呼び出し → `ArticleKnowledgeStore` 経由保存 までの全ライフサイクルを管理。エラー / 部分成功 / skip の状態判定を担う。

## Protocol

```swift
protocol KnowledgeExtractionServiceProtocol: Sendable {
    /// 指定 Article の知識を抽出 → 保存。
    /// availability チェック / 既に成功 / extractedText 短すぎ / rawHTML 不在 等は no-op。
    func extract(article: Article) async

    /// 起動時 backfill 用: ExtractedKnowledge 不在で ArticleBody .succeeded の Article を全件処理。
    func backfillAll() async

    /// 進行中の全ジョブをキャンセル。
    func cancelAll()
}
```

## Behavior

### `extract(article:)`

1. **冪等性チェック**: `article.extractedKnowledge?.status` が `.succeeded` または `.partiallySucceeded` なら no-op。
2. **入力チェック**: `article.body?.extractedText` が nil または 200 字未満なら no-op (ExtractedKnowledge 作成しない、FR-013)。
3. **availability チェック**: `SystemLanguageModel.availability != .available` なら `store.upsert(.skipped)` で保存して return (FR-003)。
4. `store.upsert(.extracting)` でステータス更新。
5. `Task.detached(priority: .utility)` 内で:
   - `KnowledgeExtractor.extract(extractedText:)` 呼び出し (research.md / R5 — エラーハンドリング)。
   - 成功時: `output.essence` 等を partial / full 判定し、`store.upsert(...)` でマッピング & 保存。
   - 失敗時: `store.upsert(.failed)` で状態更新。
6. メインスレッドでの結果を `@MainActor` で `store.upsert` に渡す。

### partial vs full success 判定

```swift
let hasEssence = !output.essence.isEmpty
let hasSummary = !output.summary.isEmpty
let hasKeyFacts = !output.keyFacts.isEmpty
let hasEntities = !output.entities.isEmpty
let count = [hasEssence, hasSummary, hasKeyFacts, hasEntities].filter { $0 }.count

let status: ExtractionStatus = switch count {
    case 4: .succeeded
    case 1...3: .partiallySucceeded
    default: .failed
}
```

### `backfillAll()`

1. `store.fetchPendingArticles()` で対象 Article を列挙 (ArticleBody .succeeded だが ExtractedKnowledge 不在 / 状態 .pending / .skipped / .failed)。
2. 各 Article に対して `await extract(article:)` を順次実行 (並列度 1)。
3. 全件処理完了で return。

### `cancelAll()`

1. `Task` ハンドルを cancel。
2. 進行中の Foundation Models 生成は cancellation respect。

## Dependency injection

- `BodyExtractionService` の init に optional `knowledgeExtractionService: KnowledgeExtractionServiceProtocol?` を追加 (spec 003 既存 service の拡張)。
- ArticleBody .succeeded 時に `Task { await knowledgeExtractionService?.extract(article:) }` を fire-and-forget で起動。
- spec 003 の既存テストを破壊しないよう default は nil (spec 003 単独テストではこの依存なし)。

## Error model

`KnowledgeExtractionError`:
- `.persistenceFailure(underlying: Error)` — Store 書き込み失敗。
- `.cancelled` — Task cancellation。

エラーは UI に伝播せず、`ExtractionStatus.failed` として吸収される (Principle V — UI 安定)。

## Threading

- protocol は `Sendable`、実装は `@MainActor`。
- 実 Foundation Models 生成は `Task.detached(priority: .utility)` で main thread 占有ゼロ (FR-015)。
- `ArticleKnowledgeStore` 書き込みは `@MainActor`。

## Tests (KnowledgeTreeTests / `KnowledgeExtractionServiceTests`)

`MockLanguageModelSession` + `MockArticleKnowledgeStore` で実行 (実 Foundation Models / 実 SwiftData なし、決定論的)。

| ケース | Mock 設定 | 期待 |
|---|---|---|
| 通常成功 | extractedText 500 字、Mock が full output 返す | `store.upsert(.succeeded, essence:, summary:, [KeyFact], [KnowledgeEntity])` |
| extractedText 短すぎ | 100 字 | no-op、store 呼ばれない |
| Apple Intelligence 不可能 | availability mock を `.unavailable(...)` | `store.upsert(.skipped)`、generator 呼ばれない |
| 既に成功 | article.extractedKnowledge?.status == .succeeded | no-op |
| safety filter blocked | Mock generator が `SafetyError` throw | `store.upsert(.failed)` |
| 部分成功 | Mock が essence + summary のみ返す | `store.upsert(.partiallySucceeded, essence:, summary:, [], [])` |
| 完全空出力 | Mock が空 output 返す | `store.upsert(.failed)` |
| backfill 複数件 | pendingArticles に 3 件 | 順次 `extract` が 3 回呼ばれる |
| cancel | extract 中に cancelAll | Task が cancel、Store の `.failed` 書き込みもしない |

すべて Mock 経由で決定論的。実 Foundation Models / Apple Intelligence 統合テストは quickstart 手動検証で担保 (Constitution テストゲート / Principle II 解釈の範囲内)。

## Wiring (in `KnowledgeTreeApp.bootstrap()`)

```swift
let knowledgeStore = SwiftDataArticleKnowledgeStore(context: context)
let extractor = KnowledgeExtractor(session: FoundationModelLanguageModelSession())
let knowledgeService = DefaultKnowledgeExtractionService(
    extractor: extractor,
    store: knowledgeStore
)

// spec 003 の BodyExtractionService に inject:
let bodyService = DefaultBodyExtractionService(
    store: bodyStore,
    knowledgeExtractionService: knowledgeService
)

// 起動時 backfill (spec 003 と直列):
await enrichmentService.backfillAll()
await bodyService.backfillAll()
await knowledgeService.backfillAll()
```

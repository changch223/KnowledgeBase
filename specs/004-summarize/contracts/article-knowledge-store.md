# Contract: ArticleKnowledgeStore

**Layer**: Persistence boundary (Constitution Principle VI)
**Used by**: `KnowledgeExtractionService`、`ArticleListView` / `ReaderView` (relationship 経由の自動 reload)

## Purpose

`ExtractedKnowledge` + 配下の `[KeyFact]` / `[KnowledgeEntity]` を SwiftData に upsert する。**Generable 出力 (`ExtractedKnowledgeOutput`) → @Model (`ExtractedKnowledge` etc.) のマッピング** を集中管理 (Principle VI)。

## Protocol

```swift
protocol ArticleKnowledgeStoreProtocol {
    /// status のみ更新する軽量版 (`.extracting` / `.skipped` / `.failed` 用)。
    func upsertStatus(
        article: Article,
        status: ExtractionStatus
    ) throws

    /// 完全 / 部分成功時の保存。Generable 出力を @Model にマッピング、配下の旧 KeyFact / KnowledgeEntity を削除して新規挿入。
    func upsertSucceeded(
        article: Article,
        status: ExtractionStatus,            // .succeeded または .partiallySucceeded
        output: ExtractedKnowledgeOutput,
        modelVersion: String?,
        durationMs: Int?
    ) throws

    /// ExtractedKnowledge 不在 & ArticleBody .succeeded の Article を全件取得 (起動時 backfill 用)。
    func fetchPendingArticles() throws -> [Article]

    /// テスト / デバッグ用: 全 ExtractedKnowledge 削除 (子もカスケード削除される)。
    func deleteAll() throws
}
```

## Implementations

### `SwiftDataArticleKnowledgeStore` (production)

- 内部に `ModelContext` を保持。
- `upsertStatus`: `article.extractedKnowledge` が nil なら create、あれば status のみ更新。`context.save()` 呼ぶ。
- `upsertSucceeded`:
  1. `article.extractedKnowledge` が nil なら新規 ExtractedKnowledge を作成 + Article に紐付け。
  2. 既存 `[KeyFact]` / `[KnowledgeEntity]` をすべて削除 (`context.delete(fact)` ループ、cascade で済むが明示的に。重複防止)。
  3. `output.keyFacts` を順に enumerate して KeyFact を挿入、`knowledge` 関係を設定、order を 0,1,2... で付与。
  4. `output.entities` を同様に挿入、salience でソートしないが order で生成順を保持 (一覧表示は salience desc で再ソート可能)。
  5. ExtractedKnowledge.essence / summary / generatedAt / modelVersion / generationDurationMs / status を更新。
  6. `context.save()`。
- `fetchPendingArticles`: predicate で `body != nil AND body.statusRaw == "succeeded" AND extractedKnowledge == nil` の Article を最大 1000 件取得。
- 全 SwiftData 操作は `@MainActor`。

```swift
@MainActor
final class SwiftDataArticleKnowledgeStore: ArticleKnowledgeStoreProtocol {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func upsertStatus(article: Article, status: ExtractionStatus) throws {
        if let existing = article.extractedKnowledge {
            existing.status = status
        } else {
            let new = ExtractedKnowledge(article: article, status: status)
            context.insert(new)
            article.extractedKnowledge = new
        }
        try saveContext()
    }

    func upsertSucceeded(
        article: Article,
        status: ExtractionStatus,
        output: ExtractedKnowledgeOutput,
        modelVersion: String?,
        durationMs: Int?
    ) throws {
        let knowledge: ExtractedKnowledge
        if let existing = article.extractedKnowledge {
            knowledge = existing
            // 旧 children を削除
            for fact in knowledge.keyFacts { context.delete(fact) }
            for entity in knowledge.entities { context.delete(entity) }
            knowledge.keyFacts = []
            knowledge.entities = []
        } else {
            knowledge = ExtractedKnowledge(article: article, status: status)
            context.insert(knowledge)
            article.extractedKnowledge = knowledge
        }

        knowledge.status = status
        knowledge.essence = output.essence.isEmpty ? nil : String(output.essence.prefix(150))
        knowledge.summary = output.summary.isEmpty ? nil : String(output.summary.prefix(300))
        knowledge.generatedAt = Date()
        knowledge.modelVersion = modelVersion
        knowledge.generationDurationMs = durationMs

        // KeyFacts
        for (idx, factOutput) in output.keyFacts.enumerated() {
            let fact = KeyFact(
                knowledge: knowledge,
                statement: factOutput.statement,
                type: factOutput.type,
                order: idx
            )
            context.insert(fact)
            knowledge.keyFacts.append(fact)
        }

        // Entities
        for (idx, entityOutput) in output.entities.enumerated() {
            let entity = KnowledgeEntity(
                knowledge: knowledge,
                name: entityOutput.name,
                type: entityOutput.type,
                salience: entityOutput.salience,
                order: idx
            )
            context.insert(entity)
            knowledge.entities.append(entity)
        }

        try saveContext()
    }

    func fetchPendingArticles() throws -> [Article] {
        var descriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { article in
                article.body != nil &&
                article.body?.statusRaw == "succeeded" &&
                article.extractedKnowledge == nil
            }
        )
        descriptor.fetchLimit = 1000
        do {
            return try context.fetch(descriptor)
        } catch {
            throw ArticleKnowledgeStoreError.persistenceFailure(underlying: error)
        }
    }

    func deleteAll() throws {
        do {
            try context.delete(model: ExtractedKnowledge.self)
            try context.save()
        } catch {
            throw ArticleKnowledgeStoreError.persistenceFailure(underlying: error)
        }
    }

    private func saveContext() throws {
        do { try context.save() }
        catch { throw ArticleKnowledgeStoreError.persistenceFailure(underlying: error) }
    }
}

enum ArticleKnowledgeStoreError: Error {
    case persistenceFailure(underlying: Error)
}
```

### `MockArticleKnowledgeStore` (testing)

```swift
@MainActor
final class MockArticleKnowledgeStore: ArticleKnowledgeStoreProtocol {
    struct UpsertCall: Equatable {
        let articleID: UUID
        let status: ExtractionStatus
        let essence: String?
        let summary: String?
        let factCount: Int
        let entityCount: Int
    }

    var calls: [UpsertCall] = []
    var pendingArticles: [Article] = []
    var shouldThrowOnUpsert = false

    enum MockError: Error { case forced }

    func upsertStatus(article: Article, status: ExtractionStatus) throws {
        if shouldThrowOnUpsert { throw MockError.forced }
        calls.append(UpsertCall(
            articleID: article.id, status: status,
            essence: nil, summary: nil, factCount: 0, entityCount: 0
        ))
    }

    func upsertSucceeded(
        article: Article,
        status: ExtractionStatus,
        output: ExtractedKnowledgeOutput,
        modelVersion: String?,
        durationMs: Int?
    ) throws {
        if shouldThrowOnUpsert { throw MockError.forced }
        calls.append(UpsertCall(
            articleID: article.id,
            status: status,
            essence: output.essence,
            summary: output.summary,
            factCount: output.keyFacts.count,
            entityCount: output.entities.count
        ))
    }

    func fetchPendingArticles() throws -> [Article] { pendingArticles }
    func deleteAll() throws { calls.removeAll() }
}
```

## Tests (KnowledgeTreeTests / `SwiftDataArticleKnowledgeStoreTests`)

| ケース | 期待 |
|---|---|
| upsertStatus 新規 | Article.extractedKnowledge が nil から ExtractedKnowledge が紐づき指定 status |
| upsertStatus 更新 | 既存 ExtractedKnowledge の status のみ更新、id 不変 |
| upsertSucceeded 新規 | KeyFact / KnowledgeEntity が output 通り作成、relationship 正常 |
| upsertSucceeded 更新 (既存 children 削除) | 旧 KeyFact / KnowledgeEntity が削除、新 children に置換 |
| fetchPendingArticles 空 | body .succeeded だが既に knowledge 持ち → 空配列 |
| fetchPendingArticles 混在 | body .succeeded & knowledge nil の Article のみ返却 |
| Article 削除 → cascade | Article 削除後 ExtractedKnowledge + KeyFact + KnowledgeEntity すべて削除 |
| deleteAll | 全 ExtractedKnowledge 削除、Article は残る (extractedKnowledge は nil に) |

すべて `ModelConfiguration(isStoredInMemoryOnly: true)` の `ModelContainer` で実行。

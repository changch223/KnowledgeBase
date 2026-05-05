# Contract: KnowledgeDigestService

新規 protocol + 2 実装 (`KnowledgeTree/Services/KnowledgeDigestService.swift`)。Foundation Models 経由で Category 内記事を統合した KnowledgeDigest を生成・管理する。

## protocol 定義

```swift
@MainActor
protocol KnowledgeDigestService {
    /// 該当 Category の Article 群から AI 統合 Digest を生成。
    /// マルチカード分割は AI 判断 (`@Generable DigestOutput { cards: [Card] }`)。
    /// Foundation Models 利用不可時は fallback (essence 並べ簡易) で生成。
    /// 既存の同 Category Digest を delete + 新 Digest を insert のアトミック操作。
    func regenerate(for category: Category) async throws -> [KnowledgeDigest]

    /// 全 Category の stale な Digest を一括再生成。
    /// pull-to-refresh で起動される。
    func regenerateAllStale() async throws

    /// 記事追加時に該当 Category の Digest を stale 化。
    /// 既に stale な Digest への呼び出しは no-op (冪等)。
    func markStale(for category: Category)
}
```

## FoundationModelsKnowledgeDigestService 実装

```swift
@MainActor
final class FoundationModelsKnowledgeDigestService: KnowledgeDigestService {
    private let session: LanguageModelSessionProtocol
    private let context: ModelContext
    private let availability: AvailabilityChecker
    private let fallback: KnowledgeDigestService

    init(session:, context:, availability:, fallback:)

    func regenerate(for category: Category) async throws -> [KnowledgeDigest] {
        guard availability.isAvailable else {
            return try await fallback.regenerate(for: category)
        }
        let articles = fetchArticles(for: category, limit: 50)
        guard !articles.isEmpty else { return [] }
        let prompt = buildPrompt(articles: articles, categoryName: category.name)
        do {
            let output = try await session.respond(to: prompt, generating: DigestOutput.self)
            return try persistDigests(from: output, for: category, articles: articles)
        } catch {
            return try await fallback.regenerate(for: category)
        }
    }

    func regenerateAllStale() async throws {
        let staleCategories = fetchStaleCategoryNames()
        for categoryName in staleCategories {
            guard let category = CategorySeed.allSeeds.first(where: { $0.name == categoryName })
                ?? CategorySeed.otherCategory else { continue }
            _ = try? await regenerate(for: category)
        }
    }

    func markStale(for category: Category) {
        let categoryName = category.name
        let descriptor = FetchDescriptor<KnowledgeDigest>(
            predicate: #Predicate { $0.categoryRaw == categoryName }
        )
        let digests = (try? context.fetch(descriptor)) ?? []
        for digest in digests {
            digest.isStale = true
        }
        try? context.save()
    }

    // 内部 helper
    private func fetchArticles(for category: Category, limit: Int) -> [Article]
    private func buildPrompt(articles: [Article], categoryName: String) -> String
    private func persistDigests(from: DigestOutput, for: Category, articles: [Article]) throws -> [KnowledgeDigest]
    private func fetchStaleCategoryNames() -> [String]
}
```

## FallbackKnowledgeDigestService 実装

```swift
@MainActor
final class FallbackKnowledgeDigestService: KnowledgeDigestService {
    private let context: ModelContext

    init(context:)

    func regenerate(for category: Category) async throws -> [KnowledgeDigest] {
        let articles = fetchArticles(for: category, limit: 10)
        guard !articles.isEmpty else { return [] }

        // 既存 Digest 削除
        deleteExistingDigests(for: category)

        // essence + KeyFact + Entity から簡易 Digest を 1 個生成
        let summary = "最近の \(articles.count) 記事から: " +
                      articles.prefix(3).compactMap(\.extractedKnowledge?.essence).joined(separator: " / ")
        let topKeyFacts = articles
            .flatMap { $0.extractedKnowledge?.keyFacts ?? [] }
            .sorted { $0.salience > $1.salience }
            .prefix(3)
            .map(\.text)
        let topEntityNames = articles
            .flatMap { $0.extractedKnowledge?.entities ?? [] }
            .sorted { $0.salience > $1.salience }
            .prefix(3)
            .map(\.name)

        let digest = KnowledgeDigest(
            categoryRaw: category.name,
            cardIndex: 0,
            summary: summary,
            topKeyFacts: Array(topKeyFacts),
            topEntityNames: Array(topEntityNames),
            sourceArticles: articles
        )
        context.insert(digest)
        try context.save()
        return [digest]
    }

    func regenerateAllStale() async throws { /* same pattern */ }
    func markStale(for category: Category) { /* same pattern */ }
}
```

## 入出力契約

### regenerate(for:)

- **入力**: `category: Category`
- **出力**: `[KnowledgeDigest]` (1〜3 個、AI 判断によるマルチカード)
- **副作用**: 古い同 Category Digest を delete、新 Digest を insert + save
- **failure**: throws (但し Foundation 失敗時は内部で Fallback に delegate、外部には rare)

### regenerateAllStale()

- **入力**: なし
- **出力**: void
- **副作用**: 全 stale Digest を順次 regenerate
- **failure**: 個別 Category 失敗は無視、全体 throw なし

### markStale(for:)

- **入力**: `category: Category`
- **出力**: void
- **副作用**: 該当 Category 全 Digest の `isStale = true`
- **failure**: silent (try? context.save())

## 不変条件

- `regenerate` は同 Category の古い Digest を必ず delete してから新 Digest を insert (重複防止)
- `markStale` は冪等 (既 stale への再呼び出しは no-op、`isStale = true` の代入のみ)
- Foundation 失敗時は必ず Fallback に delegate (UX 維持)
- `sourceArticles` は non-empty (Constitution III)、empty なら Digest 作らず空配列返す
- すべて `@MainActor` で SwiftData ModelContext 安全アクセス

## アクセシビリティ

Service 自体は表示要素ではないため、accessibility 要件なし。view 側で対応。

## テストケース (KnowledgeDigestServiceTests)

| # | ケース | 検証内容 |
|---|---|---|
| 1 | `testRegenerateProducesDigestWithSourceArticles` | regenerate 後、Digest.sourceArticles が記事を保持 |
| 2 | `testRegenerateAllStaleSkipsNonStale` | isStale = false の Digest は再生成されない (タイムスタンプ不変) |
| 3 | `testMarkStaleSetsFlag` | markStale 後、該当 Digest の isStale = true |
| 4 | `testFallbackWhenAvailabilityUnavailable` | availability.isAvailable = false で Fallback 実装が呼ばれる |
| 5 | `testMultiCardSplitWhenAIReturnsMultipleCards` | mock AI が 2 cards 返すと Digest 2 個生成 (cardIndex 0, 1) |
| 6 | `testIdempotentMultipleRegenerate` | 同 Category を 2 回 regenerate しても結果同じ (古い delete + 新 insert) |
| 7 | `testEmptyCategoryReturnsEmpty` | 記事 0 件 Category で空配列を返す、Digest 作らず |

## 互換性

- 既存 `LanguageModelSessionProtocol` / `AvailabilityChecker` を再利用 (spec 004 / 015)
- `ModelContext` 経由で SwiftData 標準パターン
- `SharedSchema.all` に KnowledgeDigest 追加で SwiftData lightweight migration

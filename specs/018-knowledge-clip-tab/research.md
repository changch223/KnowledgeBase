# Research: 知識 Clip タブ (spec 018)

## R1 — KnowledgeDigest @Model schema 設計

**Decision**:
```swift
@Model final class KnowledgeDigest {
    @Attribute(.unique) var id: UUID
    var categoryRaw: String
    var cardIndex: Int
    var summary: String
    var topKeyFacts: [String]      // SwiftData は [String] を Codable 経由で標準サポート
    var topEntityNames: [String]
    var generatedAt: Date
    var isStale: Bool
    @Relationship(deleteRule: .nullify, inverse: \Article.digests) var sourceArticles: [Article] = []

    init(...) { ... }
}
```

`SharedSchema.all` に `KnowledgeDigest.self` を append。Article 側に inverse relationship `var digests: [KnowledgeDigest] = []` を追加。

**Rationale**:
- `[String]` は SwiftData iOS 17+ で Codable 経由標準サポート、@Attribute(.transformable) 不要
- `@Relationship(deleteRule: .nullify)` で Article 削除時に sourceArticles から null 化 (Digest 自体は残す → 履歴保全 + Constitution III 整合)
- `inverse: \Article.digests` で双方向、Article から Digest 群を逆引き可能 (Detail 画面で活用)
- `isStale: Bool` 単一フラグで Category 単位の更新管理、cardIndex 関係なく全 Digest 一括 stale 化

**Alternatives considered**:
- topKeyFacts を別 @Model にする → 過剰、3 個固定で String 配列で十分
- sourceArticles を non-optional 関係 `Article` 単独 → マルチ記事を扱えない、却下
- isStale を Date? 型 (lastStaleAt) → 複雑化、Bool で十分

## R2 — Foundation Models @Generable DigestOutput 設計

**Decision**:
```swift
@Generable
struct DigestOutput {
    @Guide(description: "Category 内の記事を統合した 1〜3 個のカード。1 つにまとまるなら 1 個、トピックが散らばるなら最大 3 個に分割。")
    let cards: [DigestCardOutput]
}

@Generable
struct DigestCardOutput {
    @Guide(description: "このカードの要点を 150 字以内で日本語で要約")
    let summary: String

    @Guide(description: "重要なキーファクト 3 個 (各 30 字程度)")
    let topKeyFacts: [String]

    @Guide(description: "関連する重要エンティティ名 3 個 (人物 / 概念 / 製品名)")
    let topEntityNames: [String]

    @Guide(description: "このカードに対応する元記事の ID list (UUID 文字列)")
    let sourceArticleIDs: [String]
}
```

`LanguageModelSession.respond(to: prompt, generating: DigestOutput.self)` で構造化生成。

**Rationale**:
- `@Generable` macro で Foundation Models が JSON schema 自動生成、構造化出力保証
- `@Guide` description で AI に意図を明示、品質確保
- マルチカード分割は AI 自由判断 (Q13=A)、cards.count = 1〜3 を許容、`@Guide` で意図伝達
- `sourceArticleIDs: [String]` で Article への参照を明示、Constitution III 整合

**Alternatives considered**:
- `@Generable struct CardOutput` 単独 (常に 1 カード) → マルチカード分割不可、要件満たさない
- AI の自然言語出力 + 自前 JSON parse → 信頼性低、@Generable のメリット捨てる

## R3 — KnowledgeDigestService protocol + Foundation/Fallback 実装

**Decision**:
```swift
@MainActor
protocol KnowledgeDigestService {
    func regenerate(for category: Category) async throws -> [KnowledgeDigest]
    func regenerateAllStale() async throws
    func markStale(for category: Category)
}

@MainActor
final class FoundationModelsKnowledgeDigestService: KnowledgeDigestService {
    private let session: LanguageModelSessionProtocol
    private let context: ModelContext
    private let availability: AvailabilityChecker
    private let fallback: KnowledgeDigestService  // FallbackKnowledgeDigestService を delegate

    func regenerate(for category: Category) async throws -> [KnowledgeDigest] {
        guard availability.isAvailable else {
            return try await fallback.regenerate(for: category)
        }
        do {
            let articles = fetchArticles(for: category, limit: 50)
            guard !articles.isEmpty else { return [] }
            let prompt = buildPrompt(articles: articles, categoryName: category.name)
            let output: DigestOutput = try await session.respond(to: prompt, as: DigestOutput.self)
            return persist(output, for: category)
        } catch {
            return try await fallback.regenerate(for: category)
        }
    }

    func regenerateAllStale() async throws {
        let staleCategories = fetchStaleCategories()
        for category in staleCategories {
            _ = try await regenerate(for: category)
        }
    }

    func markStale(for category: Category) {
        let descriptor = FetchDescriptor<KnowledgeDigest>(
            predicate: #Predicate { $0.categoryRaw == category.name }
        )
        let digests = (try? context.fetch(descriptor)) ?? []
        for digest in digests { digest.isStale = true }
        try? context.save()
    }
}

@MainActor
final class FallbackKnowledgeDigestService: KnowledgeDigestService {
    // essence 上位 3 + KeyFact list を結合した簡易 Digest を 1 個生成
    func regenerate(for category: Category) async throws -> [KnowledgeDigest] {
        let articles = fetchArticles(for: category, limit: 10)
        guard !articles.isEmpty else { return [] }
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
            categoryRaw: category.name, cardIndex: 0,
            summary: summary, topKeyFacts: topKeyFacts,
            topEntityNames: topEntityNames,
            sourceArticles: articles
        )
        context.insert(digest)
        try? context.save()
        return [digest]
    }
    // regenerateAllStale / markStale は同パターン
}
```

Bootstrap で FoundationModels 実装に Fallback を inject (composite pattern)。

**Rationale**:
- Constitution VI 整合: protocol で差し替え可能、test mock 容易
- Foundation 失敗時の auto fallback で UX 維持 (Apple Intelligence 不可端末でも体験提供、Constitution IV)
- regenerate は古い Digest を delete + 新 Digest を insert のアトミック操作
- markStale は冪等 (既 stale な Digest への再 markStale は no-op、`isStale = true` の代入のみ)

**Alternatives considered**:
- Fallback を独立 service として bootstrap で switch → composite pattern の方が呼び出し側シンプル
- regenerate を sync → async が SwiftData / Foundation Models と整合
- markStale を async → 同期 set + save で十分、async 不要

## R4 — markStale hook 位置

**Decision**: `KnowledgeExtractionService.extract(article:)` の最後 (要約 + KeyFact + Entity + Tag 全部抽出完了後) で:

```swift
// spec 018: 該当 Category の Digest を stale 化
let categoryName = article.tags.first?.categoryRaw
if let categoryName,
   let category = CategorySeed.allSeeds.first(where: { $0.name == categoryName }) {
    digestService?.markStale(for: category)
}
```

`KnowledgeExtractionService` に `digestService: KnowledgeDigestService?` を inject (DI、test mock 可能、optional で test 時に nil 可)。

**Rationale**:
- spec 012 (AutoTagApplier) / spec 015 (AutoCategoryClassifier) と同パターン (knowledgeService への hook injection)
- 知識抽出完了後 = Tag categoryRaw が確定後、Category 引き正確
- optional `?` で既存テストが service nil でも動作

**Alternatives considered**:
- Article 保存直後に hook → categoryRaw 未確定、却下
- AutoCategoryClassifier 完了後に hook → Tag-Category 関係はもう既に解決済 (spec 015 で記事保存時に自動分類)、Knowledge 抽出完了後の方が安全
- NotificationCenter 経由 → 直接 inject のほうが追跡可能、spec 012 パターン踏襲

## R5 — pull-to-refresh 実装

**Decision**: SwiftUI 標準 `.refreshable { ... }` を ScrollView に適用。

```swift
ScrollView {
    LazyVStack(spacing: DS.Spacing.xxl) { /* cards */ }
}
.refreshable {
    do {
        try await digestService.regenerateAllStale()
    } catch {
        // ログ記録、UI には fallback 表示
    }
}
```

**Rationale**:
- SwiftUI 標準、ProgressView 表示・Task 管理を SwiftUI が auto-handle
- Reduce Motion 自動短縮対応
- async closure で `await regenerateAllStale()` を直接呼び出し

**Alternatives considered**:
- 自前 ProgressView + ボタン → UX 標準から逸脱
- BGTask で自動更新 → 将来 spec、本 spec MVP では手動 refresh

## R6 — KnowledgeClipCard layout

**Decision**: ~120 行の SwiftUI struct、レイアウト:
- Header HStack: Category 名 (sectionTitle) + 元記事数 caption + savedAt + Spacer + (stale なら「更新あり」caption) + 小 OG (48x48)
- summary Text (body font、lineSpacing で読みやすさ)
- KeyFact ForEach (3 個、HStack「・」+ Text)
- EntityChip 横並び LazyHStack (3 個、Capsule + tagFill 背景)
- 全体 padding(DS.Spacing.xxl) + dsCardBackground()

**Rationale**:
- spec 016 ArticleRow / spec 015 KnowledgeCategoryRow と同レベルの layout 詳細度
- DS.* token 経由で Dark Mode (spec 017) 自動対応
- Apple-quiet 路線維持 (gradient/shadow なし)

**Alternatives considered**:
- 縦 ScrollView でカード全体 scrollable → 1 カード 1 画面、TikTok 風になる、却下 (Q1=A)
- KeyFact / Entity を tap 可能 → 本 spec では view-only、tap で個別 filter は将来 spec

## R7 — CategoryKnowledgeDetailView 包括サマリ実装

**Decision**: **MVP は案 A (結合)**。Category 内全 Digest の summary を `\n\n` で結合表示。AI 再要約は将来 spec で改良 (案 B/C)。

```swift
private var aggregatedSummary: String {
    digestsForCategory
        .sorted { $0.cardIndex < $1.cardIndex }
        .map(\.summary)
        .joined(separator: "\n\n")
}
```

**Rationale**:
- AI 追加コストゼロ (Foundation Models 呼び出し回数 +0)
- 既存 Digest summary を再利用、Constitution III 整合維持
- 詳細画面の「総まとめ」は KeyFact + Entity + 元記事一覧で深掘り提供、サマリは概要のみで OK

**Alternatives considered**:
- 案 B (AI 再要約 1 回): 高品質だが追加 AI コスト、本 spec MVP では不要
- 案 C (元 essence 全部 AI で 500 字長文): 最高品質、コスト最大、将来 spec で改良
- これらを将来 spec 035 候補として明記

## R8 — 期間フィルター computed property

**Decision**:
```swift
@State private var period: TimeFilter = .all
enum TimeFilter: String, CaseIterable {
    case all, days7, days30
    var labelKey: LocalizedStringKey {
        switch self {
        case .all: return "clip.filter.all"
        case .days7: return "clip.filter.days7"
        case .days30: return "clip.filter.days30"
        }
    }
}

private var filteredDigests: [KnowledgeDigest] {
    let cutoff: Date? = {
        switch period {
        case .all: return nil
        case .days7: return Calendar.current.date(byAdding: .day, value: -7, to: .now)
        case .days30: return Calendar.current.date(byAdding: .day, value: -30, to: .now)
        }
    }()
    guard let cutoff else { return allDigests }
    return allDigests.filter { digest in
        digest.sourceArticles.contains { $0.savedAt >= cutoff }
    }
}
```

**Rationale**:
- spec 016 CategoryFilter 純関数パターン同様
- TimeFilter enum で type-safe、Localizable.xcstrings との連携明確
- 「7 日 / 30 日 内に元記事 1 件以上ある Digest」を filter
- `@State` で view local、画面遷移でリセット (spec 016 selectedTagNames と同パターン)

**Alternatives considered**:
- @AppStorage で永続化 → constitution V「シンプルな UX」、ユーザー任意、永続化不要
- API 別の `[TimeFilter]` 多選択 → constitution II「MVP 最小」、単選択で十分

## R9 — SwiftData lightweight migration

**Decision**: `SharedSchema.swift` の `static var all: [any PersistentModel.Type]` に `KnowledgeDigest.self` を append。SwiftData は新 @Model 追加を auto-detect、既存テーブル無傷で新テーブル作成。

```swift
// SharedSchema.swift
enum SharedSchema {
    static var all: [any PersistentModel.Type] {
        [
            Article.self,
            ArticleEnrichment.self,
            ArticleBody.self,
            ExtractedKnowledge.self,
            KeyFact.self,
            KnowledgeEntity.self,
            Tag.self,
            KnowledgeChunkProgress.self,
            BackgroundExtractionQueueEntry.self,
            KnowledgeDigest.self,  // spec 018
        ]
    }
}
```

**Rationale**:
- spec 015 Tag.categoryRaw lightweight migration と同パターン
- SwiftData は新 @Model 追加に対して migration plan 不要、auto-handle
- 既存データ無傷で起動 → 初回起動時に空 KnowledgeDigest テーブル → bootstrap で stale 全再集約 (中身 0 件なので no-op)

**Alternatives considered**:
- 明示的 VersionedSchema + MigrationPlan → 過剰、本 spec は新 @Model 追加のみ
- 別 ModelContainer → bundle 共有複雑化、SharedSchema 一元維持

## R10 — テスト戦略

**Decision**: 2 ファイル、合計 10 ケース:

### KnowledgeDigestServiceTests (7 ケース)

```swift
private typealias Tag = KnowledgeTree.Tag

@MainActor struct KnowledgeDigestServiceTests {
    @Test func testRegenerateProducesDigestWithSourceArticles() async throws { ... }
    @Test func testRegenerateAllStaleSkipsNonStale() async throws { ... }
    @Test func testMarkStaleSetsFlag() async throws { ... }
    @Test func testFallbackWhenAvailabilityUnavailable() async throws { ... }
    @Test func testMultiCardSplitWhenAIReturnsMultipleCards() async throws { ... }
    @Test func testIdempotentMultipleRegenerate() async throws { ... }
    @Test func testEmptyCategoryReturnsEmpty() async throws { ... }
}
```

### KnowledgeDigestModelTests (3 ケース)

```swift
@MainActor struct KnowledgeDigestModelTests {
    @Test func testRelationshipNullifyOnArticleDelete() throws { ... }
    @Test func testIsStaleDefaultsFalse() throws { ... }
    @Test func testCardIndexOrdering() throws { ... }
}
```

**Rationale**:
- in-memory `ModelContainer` で隔離、spec 011-017 同パターン
- Foundation Models mock (`MockLanguageModelSession`) で AI 出力を制御、構造化出力テスト容易
- Fallback の純関数性 (essence 並べ) は外部依存ゼロでテストしやすい
- UI test は本 spec で追加せず、quickstart 12 シナリオで実機検証代替

**Alternatives considered**:
- snapshot test → 未導入、別 spec で
- AI 統合の E2E test → mock で代替、実機検証で実 Foundation Models 確認

## R11 — Foundation Models 利用不可時の fallback トリガー

**Decision**: `FoundationModelsKnowledgeDigestService.regenerate(for:)` 内で:
1. `availability.isAvailable == false` → 即 Fallback service へ delegate
2. `try await session.respond(...)` 失敗 (token 超過 / 生成失敗) → catch して Fallback service へ delegate
3. Fallback service は essence 並べ簡易 Digest を 1 個生成

```swift
func regenerate(for category: Category) async throws -> [KnowledgeDigest] {
    guard availability.isAvailable else {
        return try await fallback.regenerate(for: category)
    }
    do {
        let response = try await session.respond(to: prompt, as: DigestOutput.self)
        return persist(response, for: category)
    } catch {
        // Foundation Models 失敗時 (token 超過 / 生成失敗 / 構造化出力エラー)
        return try await fallback.regenerate(for: category)
    }
}
```

**Rationale**:
- spec 004 KnowledgeExtractor の availability check 同パターン
- 2 段階防御 (availability + try catch) で堅牢性確保
- Constitution IV 整合 (Apple Intelligence 不可端末での fallback UX 提供)

**Alternatives considered**:
- 失敗を throw する → ユーザーに「集約失敗」エラー表示、UX 悪化、却下
- 部分失敗時のリトライロジック → 過剰、Fallback で十分

## R12 — 大量記事時のトークン上限対策

**Decision**: Category 内最大 50 記事 cap、それ以上は最新 50 件で集約。

```swift
private func fetchArticles(for category: Category, limit: Int = 50) -> [Article] {
    let categoryName = category.name
    let descriptor = FetchDescriptor<Article>(
        predicate: #Predicate { article in
            article.tags.contains { $0.categoryRaw == categoryName }
        },
        sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
    )
    descriptor.fetchLimit = limit
    return (try? context.fetch(descriptor)) ?? []
}

private func buildPrompt(articles: [Article], categoryName: String) -> String {
    let essences = articles
        .compactMap(\.extractedKnowledge?.essence)
        .filter { !$0.isEmpty }
    return """
    あなたはユーザーが保存した「\(categoryName)」カテゴリの記事 \(essences.count) 件を統合する AI です。

    各記事の要点:
    \(essences.enumerated().map { "[\($0.offset + 1)] \($0.element)" }.joined(separator: "\n"))

    上記を統合し、1〜3 個の知識カードを生成してください。
    各カードは summary (150 字)、topKeyFacts (3 個)、topEntityNames (3 個)、
    sourceArticleIDs (該当記事の UUID) を含みます。

    1 つのトピックで完結するなら 1 カード、トピックが分散しているなら 2-3 カードに分割してください。
    """
}
```

**Rationale**:
- 50 件 × 200 字 = 10,000 字、Foundation Models on-device の典型 context window (~8K-16K) に収まる
- 最新優先 (savedAt desc + fetchLimit) で「最近の知識」を優先
- spec 010 階層 chunked summarization と同じトークン管理思想
- 50 件超え時は将来 spec で「階層化集約」(複数バッチ → 中間サマリ → 最終 Digest)

**Alternatives considered**:
- 階層化集約を本 spec で → 過剰、50 件を超える Category は実際に多くないと推定
- 全件含める → トークン超過リスク高

## DESIGN.md 整合確認

- 全 view が DS.Color.* token 経由で Dark Mode (spec 017) 自動対応
- 単一 accent rule: actionBlue 1 色 (stale マーク含む)
- gradient / shadow / 多色 phase tint 全廃継続
- 既読管理 / バッジ / トースト / ストリーク 全廃継続 (constitution V)

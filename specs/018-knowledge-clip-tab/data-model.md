# Data Model: spec 018

## 新規 @Model

### KnowledgeDigest

`KnowledgeTree/Models/KnowledgeDigest.swift` (新規ファイル)。

```swift
import Foundation
import SwiftData

@Model
final class KnowledgeDigest {
    @Attribute(.unique) var id: UUID
    var categoryRaw: String              // CategorySeed.allSeeds.name
    var cardIndex: Int                   // マルチカード分割時の順序 (0/1/2...)
    var summary: String                  // 統合 essence (~150 字)
    var topKeyFacts: [String]            // 統合 KeyFact list (3 個)
    var topEntityNames: [String]         // 関連エンティティ名 (3 個)
    var generatedAt: Date                // 生成日時
    var isStale: Bool                    // 新記事追加で true、再集約で false

    @Relationship(deleteRule: .nullify, inverse: \Article.digests)
    var sourceArticles: [Article] = []   // Constitution III 必須 (元記事への参照)

    init(
        id: UUID = UUID(),
        categoryRaw: String,
        cardIndex: Int = 0,
        summary: String,
        topKeyFacts: [String] = [],
        topEntityNames: [String] = [],
        generatedAt: Date = .now,
        isStale: Bool = false,
        sourceArticles: [Article] = []
    ) {
        self.id = id
        self.categoryRaw = categoryRaw
        self.cardIndex = cardIndex
        self.summary = summary
        self.topKeyFacts = topKeyFacts
        self.topEntityNames = topEntityNames
        self.generatedAt = generatedAt
        self.isStale = isStale
        self.sourceArticles = sourceArticles
    }
}
```

| フィールド | 型 | 用途 |
|---|---|---|
| `id` | `UUID` (`@Attribute(.unique)`) | 一意キー |
| `categoryRaw` | `String` | CategorySeed.allSeeds.name の値 |
| `cardIndex` | `Int` | マルチカード分割時の順序 (0/1/2...)、単独なら 0 |
| `summary` | `String` | 統合 essence (~150 字、Foundation Models 出力) |
| `topKeyFacts` | `[String]` | 統合 KeyFact (3 個) |
| `topEntityNames` | `[String]` | 関連エンティティ名 (3 個) |
| `generatedAt` | `Date` | 生成日時 |
| `isStale` | `Bool` | 新記事追加で true、再集約で false |
| `sourceArticles` | `[Article]` | `@Relationship(deleteRule: .nullify)` で元記事 |

## 既存 @Model 改修

### Article (改修)

`KnowledgeTree/Models/Article.swift` に inverse relationship 追加:

```swift
@Model
final class Article {
    // ... 既存フィールド ...

    // spec 018: KnowledgeDigest への inverse relationship
    @Relationship var digests: [KnowledgeDigest] = []

    // ... 既存 init ...
}
```

`@Relationship` は inverse を `KnowledgeDigest.sourceArticles` に対して自動推測 (KnowledgeDigest 側で `inverse: \Article.digests` 指定済)。

## 永続化スキーマへの影響

### SharedSchema.swift 改修

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
            KnowledgeDigest.self,  // spec 018 追加
        ]
    }
}
```

SwiftData lightweight migration: 新 @Model 追加 → auto-detect、既存テーブル無傷、新テーブル作成のみ。

## 新規 transient 型 (永続化なし)

### CategoryDigestDetailDestination

`KnowledgeTree/Views/CategoryKnowledgeDetailView.swift` 末尾 or 別ファイル:

```swift
struct CategoryDigestDetailDestination: Hashable {
    let category: Category
}
```

NavigationStack の `.navigationDestination(for: CategoryDigestDetailDestination.self)` 用。

### DigestOutput / DigestCardOutput (Foundation Models)

`KnowledgeTree/Services/KnowledgeDigestService.swift` 内 (新規):

```swift
import FoundationModels

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

Foundation Models 構造化出力用 transient 型、永続化されない。

### TimeFilter

`KnowledgeTree/Views/KnowledgeClipView.swift` 内:

```swift
private enum TimeFilter: String, CaseIterable {
    case all, days7, days30

    var labelKey: LocalizedStringKey {
        switch self {
        case .all: return "clip.filter.all"
        case .days7: return "clip.filter.days7"
        case .days30: return "clip.filter.days30"
        }
    }
}
```

@State `period: TimeFilter` で view local 状態保持。

## State 遷移

### KnowledgeDigest.isStale ライフサイクル

```
作成時: isStale = false (regenerate 完了直後)
   ↓
新記事保存 → KnowledgeExtractionService 完了 → markStale(category) → isStale = true
   ↓
ユーザー pull-to-refresh → regenerate(category) → 古い Digest delete + 新 Digest insert (isStale = false)
   ↓
   (繰り返し)
```

### KnowledgeClipView 状態

- `@Query private var allDigests: [KnowledgeDigest]` (SwiftData 監視)
- `@State period: TimeFilter = .all`
- `@State isRefreshing: Bool` (`.refreshable` SwiftUI 内部で管理、明示的不要)

## 検証ルール

| ルール | 検証 |
|---|---|
| `KnowledgeDigest.sourceArticles` は non-empty (Constitution III) | 必須、regenerate 時に sourceArticles.isEmpty チェック |
| `KnowledgeDigest.cardIndex` は 0 以上の整数 | 必須、AI 出力後に validate |
| `KnowledgeDigest.topKeyFacts.count == 3` | 推奨、AI 出力時 padding/truncate |
| `KnowledgeDigest.topEntityNames.count == 3` | 推奨、AI 出力時 padding/truncate |
| `KnowledgeDigest.summary.count <= 200` | 推奨 (150 字目標、AI バリエーションで多少超え許容) |

## エラーケース

| ケース | 挙動 |
|---|---|
| `regenerate(for:)` で sourceArticles.isEmpty | Empty 配列を返す (Digest 作らない、UI 側で非表示) |
| Foundation Models 利用不可 | Fallback service に delegate (R11) |
| Foundation Models 失敗 (token 超過 / generation エラー) | Fallback service に delegate |
| Article 削除中に regenerate 走行 | `@Relationship(deleteRule: .nullify)` で参照 null 化、Digest 自体は残る |
| markStale で該当 Category の Digest 0 件 | no-op (loop で空配列を回す) |
| 同時に複数 markStale (race condition) | MainActor 制約で逐次処理、安全 |

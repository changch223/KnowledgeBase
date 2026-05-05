# Contract: KnowledgeDigest @Model

新規 SwiftData @Model (`KnowledgeTree/Models/KnowledgeDigest.swift`)。Category 単位の AI 統合ダイジェストを永続化する。

## 定義

```swift
import Foundation
import SwiftData

@Model
final class KnowledgeDigest {
    @Attribute(.unique) var id: UUID
    var categoryRaw: String
    var cardIndex: Int
    var summary: String
    var topKeyFacts: [String]
    var topEntityNames: [String]
    var generatedAt: Date
    var isStale: Bool

    @Relationship(deleteRule: .nullify, inverse: \Article.digests)
    var sourceArticles: [Article] = []

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
    )
}
```

## フィールド契約

| フィールド | 型 | 制約 |
|---|---|---|
| `id` | `UUID` | 一意、auto-generated |
| `categoryRaw` | `String` | non-empty、`CategorySeed.allSeeds.name` のいずれか |
| `cardIndex` | `Int` | 0 以上 (単独カードなら 0、マルチカードで 0/1/2...) |
| `summary` | `String` | non-empty、150 字目標 (200 字以下推奨) |
| `topKeyFacts` | `[String]` | 0〜3 個 (理想 3 個) |
| `topEntityNames` | `[String]` | 0〜3 個 (理想 3 個) |
| `generatedAt` | `Date` | 生成日時 |
| `isStale` | `Bool` | デフォルト false、新記事保存で true |
| `sourceArticles` | `[Article]` | non-empty (Constitution III 必須)、deleteRule .nullify |

## Article inverse relationship

`Article.swift` に追加:
```swift
@Relationship var digests: [KnowledgeDigest] = []
```

`KnowledgeDigest.sourceArticles` の inverse として双方向リンク。

## SharedSchema 登録

```swift
// SharedSchema.swift
static var all: [any PersistentModel.Type] {
    [
        // ... 既存 9 model ...
        KnowledgeDigest.self,  // spec 018
    ]
}
```

## State 遷移

```
created (regenerate 完了) → isStale = false
       ↓
新記事保存 → markStale → isStale = true
       ↓
pull-to-refresh → regenerate → 古い Digest delete + 新 Digest create (isStale = false)
```

## アクセシビリティ

@Model 自体は表示要素ではないため、accessibility 要件なし。view 側で対応。

## テストケース (KnowledgeDigestModelTests)

| # | ケース | 検証 |
|---|---|---|
| 1 | `testRelationshipNullifyOnArticleDelete` | Article 削除後、Digest.sourceArticles から該当記事が外れる、Digest 自体は残る |
| 2 | `testIsStaleDefaultsFalse` | init() default で isStale = false |
| 3 | `testCardIndexOrdering` | 同 categoryRaw で複数 Digest を cardIndex 順に sort 可能 |

## エラーケース

| ケース | 挙動 |
|---|---|
| sourceArticles 空で init | 許容するが、view 側でフィルター or service 側で生成しない |
| categoryRaw が CategorySeed にない値 | 許容、CategorySeed.category(for:) で「その他」にフォールバック |
| cardIndex 負数 | SwiftData は許容、view 側で sort 時に意図しない結果あり、要 validate |

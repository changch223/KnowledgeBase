# Data Model: 知識抽出 + 要約 — Phase 1

**Feature**: spec 004 — 知識抽出 + 要約
**Date**: 2026-05-04

本 spec は **2 種類の型** を扱う:

1. **生成型 (Generable)**: Apple Foundation Models に渡す構造化出力スキーマ。transient (永続化しない)。
2. **永続型 (@Model)**: SwiftData に永続化される DB エンティティ。

Store 層で Generable→@Model のマッピングを行う (Principle VI、関心分離)。

---

## Generable Types (Foundation Models 出力スキーマ、transient)

すべて `import FoundationModels` 経由の `@Generable` マクロを使用。Swift コード内に定義し、SwiftData には保存しない。

### `ExtractedKnowledgeOutput`

```swift
@Generable
struct ExtractedKnowledgeOutput {
    @Guide(description: "1 文 / 150 字以内 / 元記事の主題と核心 / 元記事に明示されている内容のみ")
    let essence: String

    @Guide(description: "2-3 文 / 300 字以内 / 元記事の構造を維持した説明的要約 / 推測禁止")
    let summary: String

    @Guide(description: "3-5 件、元記事に明示されている事実のみ")
    let keyFacts: [KeyFactOutput]

    @Guide(description: "5-10 件、重要な固有名詞")
    let entities: [KnowledgeEntityOutput]
}
```

### `KeyFactOutput`

```swift
@Generable
struct KeyFactOutput {
    @Guide(description: "事実の 1 文 (200 字以内)、元記事に明示されている内容のみ")
    let statement: String

    @Guide(description: "事実の種別")
    let type: FactType
}

@Generable
enum FactType {
    case event       // 出来事
    case claim       // 主張・意見
    case statistic   // 数値・統計
    case definition  // 定義・説明
    case quote       // 引用
}
```

### `KnowledgeEntityOutput`

```swift
@Generable
struct KnowledgeEntityOutput {
    @Guide(description: "固有名詞 (30 字以内)")
    let name: String

    @Guide(description: "種別")
    let type: EntityType

    @Guide(description: "重要度 1〜5 (5 が最重要)")
    let salience: Int
}

@Generable
enum EntityType {
    case person        // 人物
    case organization  // 組織・企業
    case location      // 場所
    case concept       // 概念・用語
    case product       // 製品・サービス
    case work          // 作品 (本・記事・動画等)
}
```

---

## Persistent Types (SwiftData @Model、永続化)

### Existing Entity (spec 001-003) — 要更新

#### `Article` (要追加: extractedKnowledge への optional relationship)

```swift
@Model
final class Article {
    @Attribute(.unique) var id: UUID
    var url: String
    var title: String
    var savedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ArticleEnrichment.article)
    var enrichment: ArticleEnrichment?

    @Relationship(deleteRule: .cascade, inverse: \ArticleBody.article)
    var body: ArticleBody?

    // 新規 (spec 004):
    @Relationship(deleteRule: .cascade, inverse: \ExtractedKnowledge.article)
    var extractedKnowledge: ExtractedKnowledge?

    init(/* unchanged */) { /* unchanged */ }
}
```

### New Entity 1: `ExtractedKnowledge`

1 件の `Article` に紐づく抽出セッションのメタ + essence + summary。

#### Attributes

| Field | Type | Optional | Default | Description |
|---|---|---|---|---|
| `id` | `UUID` | No | `UUID()` | 一意識別子 (主キー)。 |
| `article` | `Article` | **No** | — | 親 Article への non-optional 参照 (Principle III)。 |
| `statusRaw` | `String` | No | `"pending"` | `ExtractionStatus` enum 変換用。 |
| `essence` | `String?` | Yes | nil | 一文要旨 (150 字以内、リスト用)。 |
| `summary` | `String?` | Yes | nil | 説明的要約 (300 字以内、Reader 用)。 |
| `generatedAt` | `Date?` | Yes | nil | 生成完了日時。 |
| `modelVersion` | `String?` | Yes | nil | Apple Foundation Models のバージョン (将来再生成判定用)。 |
| `extractionVersion` | `Int` | No | 1 | 本アプリ側の prompt/Guide バージョン。 |
| `generationDurationMs` | `Int?` | Yes | nil | 計測値 (Performance 計測用)。 |

#### `ExtractionStatus` enum

```swift
enum ExtractionStatus: String, Codable, Sendable {
    case pending             // 未着手
    case extracting          // Foundation Models 生成中
    case succeeded           // 4 出力すべて取得
    case partiallySucceeded  // 一部出力取得 (essence のみ等)
    case failed              // 生成失敗 (safety filter / context / parse 等)
    case skipped             // Apple Intelligence 不可能でスキップ
}

extension ExtractedKnowledge {
    var status: ExtractionStatus {
        get { ExtractionStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}
```

#### SwiftData 構成

```swift
@Model
final class ExtractedKnowledge {
    @Attribute(.unique) var id: UUID
    var article: Article
    var statusRaw: String
    var essence: String?
    var summary: String?
    var generatedAt: Date?
    var modelVersion: String?
    var extractionVersion: Int
    var generationDurationMs: Int?

    @Relationship(deleteRule: .cascade, inverse: \KeyFact.knowledge)
    var keyFacts: [KeyFact] = []

    @Relationship(deleteRule: .cascade, inverse: \KnowledgeEntity.knowledge)
    var entities: [KnowledgeEntity] = []

    init(
        id: UUID = UUID(),
        article: Article,
        status: ExtractionStatus = .pending,
        essence: String? = nil,
        summary: String? = nil,
        generatedAt: Date? = nil,
        modelVersion: String? = nil,
        extractionVersion: Int = 1,
        generationDurationMs: Int? = nil
    ) {
        self.id = id
        self.article = article
        self.statusRaw = status.rawValue
        self.essence = essence
        self.summary = summary
        self.generatedAt = generatedAt
        self.modelVersion = modelVersion
        self.extractionVersion = extractionVersion
        self.generationDurationMs = generationDurationMs
    }
}
```

### New Entity 2: `KeyFact`

元記事に明示されている事実の 1 文。

#### Attributes

| Field | Type | Optional | Default | Description |
|---|---|---|---|---|
| `id` | `UUID` | No | `UUID()` | 主キー。 |
| `knowledge` | `ExtractedKnowledge` | **No** | — | 親への non-optional 参照。 |
| `statement` | `String` | No | — | 事実の 1 文 (200 字以内)。 |
| `typeRaw` | `String` | No | — | `event/claim/statistic/definition/quote`。 |
| `order` | `Int` | No | 0 | 表示順 (生成順を保持)。 |

#### SwiftData 構成

```swift
@Model
final class KeyFact {
    @Attribute(.unique) var id: UUID
    var knowledge: ExtractedKnowledge
    var statement: String
    var typeRaw: String
    var order: Int

    init(
        id: UUID = UUID(),
        knowledge: ExtractedKnowledge,
        statement: String,
        type: FactType,
        order: Int
    ) {
        self.id = id
        self.knowledge = knowledge
        self.statement = String(statement.prefix(200))
        self.typeRaw = String(describing: type)
        self.order = order
    }
}

extension KeyFact {
    var type: FactType {
        FactType(rawValue: typeRaw) ?? .claim
    }
}

extension FactType {
    init?(rawValue: String) {
        switch rawValue {
        case "event": self = .event
        case "claim": self = .claim
        case "statistic": self = .statistic
        case "definition": self = .definition
        case "quote": self = .quote
        default: return nil
        }
    }
}
```

注: `FactType` は `@Generable enum` であり、SwiftData では String として保存。getter で enum 復元。

### New Entity 3: `KnowledgeEntity`

重要な固有名詞 1 件。

#### Attributes

| Field | Type | Optional | Default | Description |
|---|---|---|---|---|
| `id` | `UUID` | No | `UUID()` | 主キー。 |
| `knowledge` | `ExtractedKnowledge` | **No** | — | 親への non-optional 参照。 |
| `name` | `String` | No | — | 固有名詞 (30 字以内)。 |
| `typeRaw` | `String` | No | — | `person/organization/location/concept/product/work`。 |
| `salience` | `Int` | No | 3 | 重要度 1〜5。 |
| `order` | `Int` | No | 0 | 生成順 (表示用)。 |

#### SwiftData 構成

```swift
@Model
final class KnowledgeEntity {
    @Attribute(.unique) var id: UUID
    var knowledge: ExtractedKnowledge
    var name: String
    var typeRaw: String
    var salience: Int
    var order: Int

    init(
        id: UUID = UUID(),
        knowledge: ExtractedKnowledge,
        name: String,
        type: EntityType,
        salience: Int,
        order: Int
    ) {
        self.id = id
        self.knowledge = knowledge
        self.name = String(name.prefix(30))
        self.typeRaw = String(describing: type)
        self.salience = max(1, min(5, salience))
        self.order = order
    }
}

extension KnowledgeEntity {
    var type: EntityType {
        EntityType(rawValue: typeRaw) ?? .concept
    }
}

extension EntityType {
    init?(rawValue: String) {
        switch rawValue {
        case "person": self = .person
        case "organization": self = .organization
        case "location": self = .location
        case "concept": self = .concept
        case "product": self = .product
        case "work": self = .work
        default: return nil
        }
    }
}
```

---

## Validation rules (Service 層)

`KnowledgeExtractionService.extract(article:)` 内で:

1. **Apple Intelligence チェック**: `SystemLanguageModel.availability == .available` でなければ `.skipped` で保存。
2. **入力長さ**: `article.body?.extractedText` が 200 字未満なら ジョブを skip (ExtractedKnowledge 作成しない、FR-013)。
3. **生成失敗**: `LanguageModelSession.respond` が throw → `.failed` で保存。
4. **完全空出力**: essence == "" && summary == "" && keyFacts.isEmpty && entities.isEmpty → `.failed`。
5. **部分成功**: 4 出力のうち 1 つ以上取れた → `.partiallySucceeded`、得られた要素のみ保存 (FR-014)。
6. **長さ切り詰め**: クライアント側で essence > 150、summary > 300、fact > 200、entity name > 30 を truncate (Guide が守られなかった場合の安全網)。
7. **salience 範囲制限**: 1〜5 の範囲外は max/min で clamp。

---

## State transitions

```
ExtractedKnowledge.status:
pending → extracting → succeeded
                    → partiallySucceeded
                    → failed
                    → skipped (Apple Intelligence 不可能)
```

- `pending`: ジョブキューイング直後 (初期状態)。
- `extracting`: Foundation Models 生成中 (UI 表示なし、Principle V — UI ノイズ回避、FR-016)。
- `succeeded`: 4 出力すべて取得。
- `partiallySucceeded`: 1 つ以上の出力取得。UI 上は `.succeeded` と同じ扱い (得られた要素のみ表示)。
- `failed`: 生成失敗。UI 表示なし。再試行は MVP では発生しない (将来 spec)。
- `skipped`: Apple Intelligence 不可能で skip。UI 表示なし。状態が変化したら起動時 backfill で再キューイング。

---

## Relationships (整合性)

```
Article (root)
└── ExtractedKnowledge (1:0..1, cascade delete)
    ├── KeyFact (1:many, cascade delete)
    └── KnowledgeEntity (1:many, cascade delete)
```

Article 削除 → ExtractedKnowledge 削除 → 配下の全 KeyFact + KnowledgeEntity 削除。Principle III の「ソースに基づいた知識生成」を構造レベルで保証。

---

## Storage location

- **本番**: spec 001-003 と同じ App Group container 配下の SwiftData ストア。
- **schema 拡張**: `Schema([Article.self, ArticleEnrichment.self, ArticleBody.self, ExtractedKnowledge.self, KeyFact.self, KnowledgeEntity.self])`。
- **migration**: SwiftData 自動 lightweight migration で吸収 (新エンティティ追加 + 既存 Article への optional relationship 追加は backward-compatible)。
- **テスト**: `ModelConfiguration(isStoredInMemoryOnly: true)`。

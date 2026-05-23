# Data Model: ConceptPage

**Feature**: spec 042 ConceptPage
**Phase**: 1 (Design & Contracts)
**Date**: 2026-05-23

本ドキュメントは spec 042 で追加 / 改修するデータモデルを SwiftData @Model 中心に
記述する。新規 @Model は 1 つのみ、Article への影響はゼロ (片方向参照)。

---

## 1. ConceptPage (新規 @Model)

複数の保存記事に登場する entity (人物 / モノ / 概念) を統合した「概念ページ」。
spec.md "Key Entities" の主役。

### Fields

| Name | Type | Constraint | Initial | 説明 |
|------|------|-----------|---------|------|
| `id` | `UUID` | `@Attribute(.unique)`, non-nil | `UUID()` | 主キー、不変 |
| `name` | `String` | non-nil, 1-30 chars, 同 category 内 unique (大文字小文字無視) | — | 表示用「主名」(例: "Apple") |
| `nameAliases` | `[String]` | 各要素 1-30 chars | `[]` | 同義語 (例: `["アップル"]`)、merge 時 source.name と aliases を吸収 |
| `categoryRaw` | `String` | non-nil, spec 015 と同 10 種固定値 | — | 所属カテゴリーの raw |
| `summary` | `String` | 0-500 chars (200-400 が目標、500 でハード上限) | `""` | AI 合成「今わかっていること」、初期空 |
| `crossSourceInsights` | `[String]` | 各要素 50-150 chars、配列 0-7 件 | `[]` | 横断的知見の bullet 配列 |
| `relatedArticles` | `[Article]` | `@Relationship(deleteRule: .nullify)` | `[]` | 原典 Article への参照、Article 側は片方向 (inverse 自動推論なし) |
| `relatedConceptIDs` | `[UUID]` | 他 ConceptPage の id 配列 | `[]` | graph 経由の関連概念、`@Relationship` ではなく ID 配列で柔軟性確保 |
| `userUnderstanding` | `Int` | 0-5 | `0` | ユーザー理解度 (本 spec では永続化のみ、surface は spec 049) |
| `isFollowing` | `Bool` | — | `false` | ピン (フォロー)、上位表示の優先キー |
| `isStale` | `Bool` | — | `true` | BGTask 再合成フラグ、新規作成時は未合成なので true |
| `embedding` | `Data?` | `@Attribute(.externalStorage)` | `nil` | summary の L2 正規化済 `[Float]` を Data 化 |
| `createdAt` | `Date` | — | `.now` | 作成日時 |
| `updatedAt` | `Date` | — | `.now` | 更新日時、編集 / 再合成で更新 |

### Computed properties

```swift
extension ConceptPage {
    /// 検索 / 表示用の大文字小文字無視マッチ済 name (lowercased) と aliases lowercased
    var searchableNames: [String] {
        ([name] + nameAliases).map { $0.lowercased() }
    }

    /// summary 表示用 1 行 preview (knowledge clip card で使う)
    var summaryPreview: String {
        summary.replacingOccurrences(of: "\n", with: " ")
    }

    /// セクション表示判定: 「整理中…」を出すか
    var isSynthesisInProgress: Bool {
        summary.isEmpty || isStale
    }
}
```

### Validation rules

- `name`: 1-30 chars、空白 trim 後評価、ConceptPageStore.rename で強制
- `nameAliases`: 各要素も 1-30 chars (ただし重複は merge 時自動 dedup)
- `categoryRaw`: spec 015 で確立済の 10 種固定 (`AutoCategoryClassifier.categories` と同集合)
- `summary`: 500 chars 超は post-process で trim (`String.prefix(497) + "…"`)
- `crossSourceInsights`: 7 件超は先頭 7 件のみ保持
- `relatedArticles`: 0 件 → ConceptPage 削除候補 (Wikilint で別 spec)、本 spec では 0 件
  ConceptPage はそのまま残す (孤立状態)
- `embedding`: `[Float]` length は EmbeddingService に依存 (NLEmbedding 日本語 = 768 dim)

### State transitions

```
[初期生成] (entity 2 件目登場)
    ↓ ConceptSynthesisService.processNewArticle
[isStale=true, summary=""]
    ↓ BGTask resynthesizeAllStale → resynthesize
[Foundation 経路 success]
[isStale=false, summary="...", crossSourceInsights=[...], embedding=Data]
    ↓ 新記事 ingest (同 entity)
[isStale=true]  (summary 残る、再合成待ち)
    ↓ 再 BGTask
[isStale=false, summary 更新]

[Fallback 経路 (availability=false)]
[isStale=false, summary="essence 並べた簡易版", crossSourceInsights=最初3件]

[ConceptPageStore.rename]
[name 更新, isStale=true]  → 再合成

[ConceptPageStore.merge source→target]
[source 削除, target.relatedArticles ∪ source.relatedArticles,
 target.nameAliases += source.name + source.aliases,
 target.isStale=true, target.userUnderstanding=max, target.isFollowing=OR]

[ConceptPageStore.delete]
[ConceptPage 削除, 他 ConceptPage.relatedConceptIDs から id 除去,
 Article は @Relationship.nullify で残る]
```

### Indices (SwiftData 自動 + 明示)

- `id` (unique attribute)
- 大文字小文字無視マッチ用 lookup は in-memory (fetch 全件 → `searchableNames.contains`)
  で実装、SwiftData は case-insensitive 検索を直接サポートしないため。50-200 件規模で
  問題なし。

---

## 2. SharedSchema (改修)

`SharedSchema.swift` の `static let all: [any PersistentModel.Type]` に
`ConceptPage.self` を追加。SwiftData lightweight migration が自動適用、既存 store
からのデータ移行不要 (新規 entity 追加のみ)。

```swift
enum SharedSchema {
    static let all: [any PersistentModel.Type] = [
        Article.self,
        KnowledgeEntity.self,
        // ... (既存)
        ConceptPage.self,  // ★ 追加
    ]
}
```

---

## 3. Article (既存、変更なし)

ConceptPage.relatedArticles の参照先として利用。**Article 側に inverse property を
追加しない** (片方向参照、Article の既存 schema 影響ゼロ)。

理由:
- 既存 spec 全 (001-041) への regression リスク回避
- Article から派生 ConceptPage 取得は `FetchDescriptor<ConceptPage>(predicate: #Predicate { $0.relatedArticles.contains(where: { $0.id == articleID }) })` で十分 (ArticleDetailView の P3 派生概念ページセクションで使用)

---

## 4. KnowledgeEntity (既存、変更なし)

ConceptPage 生成のトリガー source として利用 (各 Article の `extractedKnowledge.entities`)。
@Model 側変更ゼロ。

ConceptSynthesisService が KnowledgeEntity.name + KnowledgeEntity.categoryRaw を見て
同名 ConceptPage を検索 / 生成判定する。

---

## 5. GraphNode (既存、spec 040、参照のみ)

本 spec 範囲外。将来 spec 045 (Community) で GraphNode と ConceptPage の関係を
整理する想定。本 spec ではゼロ依存。

---

## 6. Transient (non-persisted) 型

ConceptSynthesisService や View で使う構造体。@Model ではない。

### `ConceptSynthesisOutput` (`@Generable`)

```swift
@Generable
struct ConceptSynthesisOutput: Codable {
    @Guide(description: "200〜400 字の日本語、原文に明示された内容のみ。推測禁止")
    let summary: String

    @Guide(description: "最大 7 件、各 50〜150 字、複数記事を横断して見える知見")
    let crossSourceInsights: [String]
}
```

Foundation Models からの構造化出力 schema。`LanguageModelSessionProtocol.generateConceptSynthesis(prompt:)` の戻り値。

### `ConceptSummaryChunk` (`@Generable`、private 補助型)

```swift
@Generable
struct ConceptSummaryChunk: Codable {
    @Guide(description: "この記事チャンクの要点を 100-200 字でまとめた日本語")
    let chunkSummary: String
}
```

R5 hierarchical パターンの中間 chunk 用、最終 prompt 前段で使う。

### `ConceptPageDetailDestination` (Hashable, transient)

```swift
struct ConceptPageDetailDestination: Hashable {
    let id: UUID  // ConceptPage.id
}
```

NavigationStack の navigationDestination 用、SwiftData @Model を直接 navigation value
にせず ID 経由で安全に遷移 (spec 016 同パターン)。

### `ConceptPageListDestination` (Hashable, transient)

```swift
struct ConceptPageListDestination: Hashable {}  // 全 ConceptPage 一覧画面
```

「+N すべて見る」link 用。

### `ConceptPageStoreError` (Error enum)

```swift
enum ConceptPageStoreError: LocalizedError {
    case emptyName
    case nameTooLong
    case duplicateInCategory
    case sameSourceTarget
    var errorDescription: String? { ... }  // 日本語 LocalizedStringKey 経由
}
```

ConceptPageStore のバリデーション error 表現。EditSheet で alert に表示。

---

## 7. Relationship 図

```
Article (既存)  ←─ @Relationship(.nullify) ─  ConceptPage.relatedArticles
                                                  │
                                                  ├─ name, nameAliases, categoryRaw
                                                  ├─ summary, crossSourceInsights, embedding
                                                  ├─ isFollowing, isStale, userUnderstanding
                                                  ├─ createdAt, updatedAt
                                                  └─ relatedConceptIDs: [UUID]
                                                              │
                                                              └─→ 他 ConceptPage (ID lookup)

KnowledgeEntity (既存) → (Service 経由 fetch trigger) → ConceptPage 生成
GraphNode (既存、spec 040) → (本 spec では参照なし、spec 045 で統合検討)
```

- Article ↔ ConceptPage: N:N (1 Article は複数 ConceptPage に登場 (= 複数 entity を含む)、
  1 ConceptPage は複数 Article を関連)。SwiftData @Relationship は to-many 単方向で実現。
- ConceptPage ↔ ConceptPage: N:N (relatedConceptIDs)、ID 配列で疎結合

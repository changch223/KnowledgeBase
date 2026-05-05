# Phase 1 Data Model: spec 015 (AI ブレイン v2 + DesignSystem migration + Category)

**Created**: 2026-05-05

## 概要

本 spec は 1 つの **lightweight migration** (Tag.categoryRaw 追加) と新規 transient struct (Category) を導入。新規 SwiftData @Model はゼロ。

---

## Section A: 既存 @Model 改修

### A-1. `Tag` (spec 008 既存、spec 015 で 1 attribute 追加)

```swift
@Model
final class Tag {
    @Attribute(.unique) var name: String
    @Relationship(inverse: \Article.tags) var articles: [Article] = []
    var categoryRaw: String?  // spec 015 追加 (default nil)

    init(name: String, categoryRaw: String? = nil) {
        self.name = name
        self.categoryRaw = categoryRaw
    }
}
```

| Field | 説明 | 制約 |
|---|---|---|
| `name` | spec 008 既存 | unique、TagNormalizer 済 |
| `articles` | spec 008 既存 | many-to-many with Article |
| `categoryRaw` | **spec 015 新規** | nil = 未分類、または `CategorySeed.allSeeds.map(\.name)` のいずれか |

### A-2. SwiftData lightweight migration

SwiftData は属性追加のみの変更を **自動で migration**。`SharedSchema.all` の Schema バージョンは bump しない。

```swift
// SharedSchema.swift (改修なし)
enum SharedSchema {
    static var all: Schema {
        Schema([
            Article.self, ArticleEnrichment.self, ArticleBody.self,
            ExtractedKnowledge.self, KeyFact.self, KnowledgeEntity.self,
            Tag.self,                                  // ← categoryRaw 追加でも自動対応
            KnowledgeChunkProgress.self,
            BackgroundExtractionQueueEntry.self,
        ])
    }
    // ...
}
```

既存 Tag インスタンスは migration 後 `categoryRaw == nil` で初期化される。`AutoCategoryBackfillRunner` がそれらを後追い classify。

---

## Section B: 新規 transient struct (Category 階層)

### B-1. `Category`

```swift
struct Category: Hashable, Sendable {
    let name: String          // 日本語、Tag.categoryRaw に保存
    let englishName: String   // 将来 i18n 用
    let order: Int            // 表示順 (0 = 最上位)
    let symbolName: String    // SF Symbol 名 (将来 UI 表示用)
}
```

| Field | 説明 | 制約 |
|---|---|---|
| `name` | 日本語表示名 | "テクノロジー" / "経済" / "健康" / etc. |
| `englishName` | 英語名 | 将来 i18n 用、現状未使用 |
| `order` | 表示順 | 0-9 (10 個固定)、order 同点は name で sub-sort |
| `symbolName` | SF Symbol 名 | 将来 UI でアイコン表示する時用 |

### B-2. `CategorySeed`

```swift
enum CategorySeed {
    static let allSeeds: [Category] = [
        Category(name: "テクノロジー", englishName: "Technology",    order: 0, symbolName: "cpu"),
        Category(name: "経済",         englishName: "Economy",       order: 1, symbolName: "chart.line.uptrend.xyaxis"),
        Category(name: "健康",         englishName: "Health",        order: 2, symbolName: "heart"),
        Category(name: "デザイン",     englishName: "Design",        order: 3, symbolName: "paintbrush"),
        Category(name: "学術",         englishName: "Academic",      order: 4, symbolName: "book"),
        Category(name: "アート",       englishName: "Art",           order: 5, symbolName: "paintpalette"),
        Category(name: "ニュース",     englishName: "News",          order: 6, symbolName: "newspaper"),
        Category(name: "スポーツ",     englishName: "Sports",        order: 7, symbolName: "figure.run"),
        Category(name: "エンタメ",     englishName: "Entertainment", order: 8, symbolName: "tv"),
        Category(name: "その他",       englishName: "Other",         order: 9, symbolName: "ellipsis.circle"),
    ]

    /// nil / unknown を「その他」に正規化
    static func category(for name: String?) -> Category {
        guard let name else { return otherCategory }
        return allSeeds.first { $0.name == name } ?? otherCategory
    }

    static var otherCategory: Category {
        allSeeds.last!  // 最後の "その他"
    }
}
```

### B-3. `CategoryListEntry` (transient view-model)

```swift
struct CategoryListEntry: Hashable, Sendable {
    let category: Category
    let articleCount: Int
    let topTagName: String  // Category 内最も記事多い Tag (タップ遷移先)
}
```

`KnowledgeCategoryRow` の入力に使う。`AIBrainView` の computed property で集計。

---

## Section C: ProcessingMonitor.Phase 拡張

### C-1. 新 case `.categoryClassifying = 4`

```swift
@MainActor @Observable
final class ProcessingMonitor {
    enum Phase: Int, Comparable, Sendable {
        case enrichment        = 0
        case body              = 1
        case knowledge         = 2
        case tagBackfilling    = 3
        case categoryClassifying = 4  // spec 015 追加
    }
}
```

BottomStatusBar の `phaseLabel(_)` switch で `case .categoryClassifying: return "status.phase.categoryClassifying"` を追加。

### C-2. UserDefaults キー (BackfillFlagStore 経由)

| Key | Type | 用途 |
|---|---|---|
| `auto_tag_backfill_v1_done` | Bool | spec 013 既存 |
| `auto_category_backfill_v1_done` | Bool | **spec 015 新規** |

両者は別キーで独立、後方互換。

---

## State Transitions

### Tag.categoryRaw の状態遷移

| From | Event | To |
|---|---|---|
| `nil` (新規 Tag) | `TagStore.addTag` 経由で AutoCategoryClassifier 呼び出し | `categoryRaw = "テクノロジー"` 等 |
| `nil` (spec 014 までの既存 Tag) | bootstrap で `AutoCategoryBackfillRunner.run()` | 同上 |
| `nil` (Foundation Models 利用不可) | `classifier.classify()` が失敗 | `categoryRaw = "その他"` |
| `"テクノロジー"` 等 (既に分類済) | 再 backfill 実行 | **変化なし** (predicate `categoryRaw == nil` で skip) |
| 任意 | アプリ強制終了 → 次回起動 | フラグが false なら再 backfill 実行 |

### AutoCategoryBackfillRunner の状態遷移

| From | Event | To |
|---|---|---|
| `flagStore.isCompleted() == false` | `bootstrap()` で `run()` 呼び出し | candidates 取得 → 順次 classify |
| 全 candidates 完了 | last classify | `flagStore.markCompleted()`、次回 skip |
| classify 中アプリ終了 | next launch | flagStore false → 再 run、`categoryRaw == nil` predicate で残り Tag のみ処理 |

---

## Validation Rules

| Rule | 適用先 | 違反時の挙動 |
|---|---|---|
| `Tag.categoryRaw` は nil または `CategorySeed.allSeeds.map(\.name)` のいずれか | TagStore 経由でのみ書き込み | 不正値が入った場合、UI 側 `CategorySeed.category(for:)` で「その他」として表示 |
| `AutoCategoryClassifier.classify(tagName:)` 戻り値は `CategorySeed` 内の名前 | classifier 実装 | 不正値 → "その他" にフォールバック |
| `Tag.name` は spec 008 既存制約のまま | TagStore.addTag | TagNormalizer で正規化、unique |
| `Category.order` は 0-9 (10 個固定) | CategorySeed | hardcoded、変更時はファイル直接編集 |

---

## 永続化なし宣言 (新 SwiftData @Model)

本 spec で **新規 SwiftData @Model はゼロ**。`Category` は struct で transient、`CategorySeed` は enum + static let。

`Tag.categoryRaw` 1 attribute 追加のみが永続化変更。

---

## 関係性ダイアグラム

```
Article ─── tags (M:N) ──── Tag
                            ├── name (既存)
                            ├── articles (既存)
                            └── categoryRaw: String? (spec 015 新規)
                                    │
                                    ↓ category(for:) で正規化
                            CategorySeed.allSeeds [Category]
                                    │
                                    ↓ inferred by
                            AutoCategoryClassifier (protocol)
                                    │
                                    ├── FoundationModelsAutoCategoryClassifier (production)
                                    └── InMemoryAutoCategoryClassifier (test)
                                    │
                                    ↑ called by
                            TagStore.addTag (spec 008 改修) — fire-and-forget
                            AutoCategoryBackfillRunner (spec 015 新規) — bootstrap で 1 回

AI ブレインタブ:
AIBrainView (改修) ── ScrollView ──┬─ AIBrainStatsRow (新規)
                                   ├─ AIInsightCard (新規)
                                   └─ CategoryListSection ──→ KnowledgeCategoryRow (新規) × N
                                                              ↓ tap
                                                              TagFilteredListView (既存)
```

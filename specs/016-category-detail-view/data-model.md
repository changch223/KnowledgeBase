# Data Model: spec 016

## 既存エンティティ (再利用、変更なし)

### Article (`KnowledgeTree/Models/Article.swift`)

- `id: UUID`
- `url: String`
- `title: String`
- `savedAt: Date` ← **本 spec で表示に使用 (新規操作なし)**
- `enrichment: ArticleEnrichment?`
- `body: ArticleBody?`
- `extractedKnowledge: ExtractedKnowledge?`
- `tags: [Tag]` (inverse: `Tag.articles`)

変更なし。

### Tag (`KnowledgeTree/Models/Tag.swift`)

- `name: String` (`@Attribute(.unique)`)
- `articles: [Article]` (`@Relationship(inverse: \Article.tags)`)
- `categoryRaw: String?` ← **spec 015 で導入済、本 spec で照会のみ**

変更なし。

### Category (`KnowledgeTree/Services/CategorySeed.swift`)

```swift
struct Category: Hashable, Sendable {
    let name: String          // "テクノロジー" 等、Tag.categoryRaw に保存される値
    let englishName: String
    let order: Int
    let symbolName: String
}
```

変更なし。`CategorySeed.allSeeds` (10 個) と `CategorySeed.category(for:)` を再利用。

## 新規 transient 型 (永続化なし)

### CategoryFilteredDestination

`KnowledgeTree/Views/ArticleListView.swift` 末尾に追加。

```swift
struct CategoryFilteredDestination: Hashable {
    let category: Category
}
```

**用途**: NavigationStack の `.navigationDestination(for: CategoryFilteredDestination.self)` によるタイプベース遷移。

**フィールド**:
- `category: Category` — 遷移先 CategoryFilteredListView に渡す Category

**Hashable 要件**:
- `Category` が既に Hashable なので auto-synthesized で OK

## 新規 view コンポーネント (永続化なし)

### CategoryFilteredListView

`KnowledgeTree/Views/CategoryFilteredListView.swift` (新規)。

```swift
struct CategoryFilteredListView: View {
    let category: Category

    @Query private var allTags: [Tag]
    @State private var selectedTagNames: Set<String> = []
    @State private var showsAllTags: Bool = false

    // computed: categoryTags / filteredArticles (R5 参照)
    // body: NavigationTitle + タグフィルター行 + Article リスト
}
```

**State**:
- `selectedTagNames: Set<String>` — 選択中のタグ名 (OR フィルター)
- `showsAllTags: Bool` — 「+N ▼」展開状態

**永続化なし**: 戻る / タブ切替で破棄。

### ArticleDetailView の追加 state

`@State private var isBodyExpanded: Bool = false` を追加。

**永続化なし**: ArticleDetailView 起動毎にリセット (= spec 通り、毎回 collapsed)。

## 永続化スキーマへの影響

**ゼロ**。`Tag.categoryRaw` (spec 015) を読むだけ、新 attribute / 新 @Model / migration なし。

## State 遷移

### CategoryFilteredListView の state machine

```
初期: selectedTagNames = []          → Category 内全記事表示 (savedAt desc)
タグA タップ: selectedTagNames = {A}  → Tag A の記事のみ
タグB タップ: selectedTagNames = {A,B} → Tag A or Tag B の記事 (OR)
タグA 再タップ: selectedTagNames = {B} → Tag B のみ
全解除: selectedTagNames = []          → 全記事 (初期に戻る)

「+N ▼」: showsAllTags = true        → 全タグ表示
「閉じる ▲」: showsAllTags = false   → 上位 5 個 + 「+N ▼」
```

### ArticleDetailView 本文 disclosure state

```
初期: isBodyExpanded = false → DisclosureGroup collapsed (本文非表示)
「本文を読む」タップ: isBodyExpanded = true → 標準アニメで展開
chevron 再タップ: isBodyExpanded = false → 折りたたみ
sheet dismiss → 次回開く時に新 instance で false に戻る
```

## 検証ルール

### CategoryFilteredListView

- `category` は `CategorySeed.allSeeds` のいずれかであること (型レベル保証)
- `selectedTagNames` の各文字列は `categoryTags` 内に存在する Tag 名 (UI で操作するため自然に保証、検証コード不要)
- `filteredArticles` は重複排除済み (R5 の Set<PersistentIdentifier> 実装で保証)

### ArticleRow.savedAt 表示

- `savedAt` は SwiftData @Model 由来で常に non-nil
- 未来時刻 (時計ずれ) も RelativeDateTimeFormatter が「N 秒後」等を返すため許容 (R3 参照)

### ArticleDetailView 本文 disclosure

- `paragraphs.isEmpty` 時は DisclosureGroup 自体を非表示 (FR-028)
- `isBodyExpanded` の初期値は常に `false` (FR-024)

## エラーケース

本 spec はネットワーク呼び出しゼロ、永続化変更ゼロのため、エラーケースは UI 表示の想定外パスのみ:

| ケース | 挙動 |
|---|---|
| Category 内 Tag 0 件 | filteredArticles = []、ContentUnavailableView 表示 |
| 全タグ選択 = 全タグ OR | filteredArticles = Category 全記事 (= 未選択と同じ結果)、機能としては動作 |
| Article 本文未取得 (paragraphs.isEmpty) | DisclosureGroup 非表示、要約のみ表示 |
| savedAt が未来 (時計ずれ) | RelativeDateTimeFormatter が「N 秒後」等を返す、許容 |

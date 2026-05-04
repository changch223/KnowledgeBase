# Data Model: 振り返り支援 (Phase 1)

**Feature**: spec 008
**Date**: 2026-05-05

## 1. 永続化エンティティ (@Model)

### 1.1 Tag (新規 @Model)

```swift
@Model
final class Tag {
    @Attribute(.unique) var name: String
    @Relationship(inverse: \Article.tags) var articles: [Article] = []

    init(name: String) {
        self.name = name  // 必ず TagNormalizer.normalize 経由 (空文字列禁止)
    }
}
```

**バリデーション**:
- `name` は空でない (TagNormalizer.normalize の戻り値が non-nil)
- `name` は lowercased + trimmed (TagNormalizer 経由で生成)
- `name` は最大 50 文字 (TagNormalizer で truncate)
- DB レベル: `@Attribute(.unique)` で重複排除

**delete rule**: Article 削除時に Tag は残る (relationship のみ解除、tag の `articles` から削除)。tag の articles が空になったら手動 (TagStore で context.delete) で消す (FR-013)。

### 1.2 Article (既存 + relationship 追加)

```swift
@Model
final class Article {
    // ... 既存フィールド
    @Relationship var tags: [Tag] = []
}
```

**migration**: SwiftData lightweight migration で `tags` relationship 追加 (既存 article の tags は空配列で初期化)。

---

## 2. Transient エンティティ

### 2.1 SearchPredicate (struct factory)

```swift
struct SearchPredicate {
    /// 検索クエリから動的 Predicate<Article> を生成。
    /// 空クエリは nil を返し、@Query が全件 fetch する。
    static func make(query: String) -> Predicate<Article>?
}
```

**用途**: ArticleListView 内で `@Query(filter: SearchPredicate.make(query: searchQuery))` の形で利用。

### 2.2 SearchHighlight

```swift
struct SearchHighlight: Sendable {
    let fieldName: LocalizedStringKey  // 例: "essence" -> "knowledge.essenceLabel"
    let excerpt: AttributedString      // bold ハイライト済
}
```

**生成元**: `SearchHighlighter.highlight(article:query:) -> SearchHighlight?`
**用途**: ArticleRow が検索結果モードで excerpt 表示するときに使用。

### 2.3 RelatedArticle

```swift
struct RelatedArticle: Identifiable, Sendable {
    let id: UUID                  // article.id
    let article: Article
    let commonEntityCount: Int
    let commonEntities: [String]   // 上位 3 件まで表示用
}
```

**生成元**: `RelatedArticleFinder.find(for:in:limit:) -> [RelatedArticle]`
**用途**: Detail 画面の関連記事セクションで表示。

### 2.4 SuggestedTag

```swift
struct SuggestedTag: Identifiable, Sendable {
    var id: String { normalizedName }
    let normalizedName: String      // 既に TagNormalizer.normalize 済
    let displayName: String         // 元 entity.name (UI 表示用)
    let salience: Int
}
```

**生成元**: `SuggestedTagFinder.find(article:) -> [SuggestedTag]`
**用途**: Detail 画面のタグセクションで「+ X」候補チップ。

---

## 3. State Transition

### Tag 状態

```text
(存在しない)
   │
   ▼ TagStore.addTag(name, to: article)
[存在 + articles に 1 件以上]
   │
   ▼ TagStore.removeTag(name, from: article)
   │
   ├──── articles.isEmpty != true ──▶ [存在 + articles に他記事]
   └──── articles.isEmpty == true ──▶ context.delete(tag) ──▶ (存在しない)
```

### 検索クエリ状態

```text
[空文字列] ── searchable で入力 ──▶ [non-empty]
[non-empty] ── 入力消去 ──▶ [空文字列]
```

`@Query` は state 変化のたびに再 fetch される。

---

## 4. 既存型との互換性

| 型 | 変更 | 理由 |
|---|---|---|
| `Tag` | 新規追加 | 多対多 relationship のための entity |
| `Article` | tags relationship 追加 | 多対多のための inverse |
| `Article (他既存フィールド)` | 変更なし | 検索対象として title / url を使うが既存スキーマで OK |
| `ArticleEnrichment` | 変更なし | 検索対象として canonicalTitle / summary を読むだけ |
| `ExtractedKnowledge / KeyFact / KnowledgeEntity` | 変更なし | 検索対象 + 関連記事 + 自動提案で読み取り使用 |

---

## 5. データフロー

### 検索

```text
1. ユーザーが ArticleListView の検索バーに入力
2. searchQuery @State 更新
3. View body 再評価 → ArticleListContent(searchQuery: ...) 生成
4. ArticleListContent.init で @Query(filter: SearchPredicate.make(query:)) 構築
5. SwiftData が Predicate に基づき Article 配列を fetch
6. ForEach で ArticleRow 表示。search query 非空なら ArticleRow に query を渡してハイライト
7. ArticleRow が SearchHighlighter.highlight(article:query:) を内部で呼んで excerpt 表示
```

### タグ追加

```text
1. ユーザーが ArticleDetailView のタグセクション + 入力
2. raw text 取得 → TagNormalizer.normalize
3. 正規化結果が nil → no-op
4. TagStore.addTag(name: normalized, to: article)
5. TagStore 内: existing = #Predicate<Tag> { $0.name == normalized } で fetch、なければ新規 insert
6. article.tags.append(existing) (重複チェック必要)
7. context.save() → RefreshTrigger.bump() (spec 005)
8. SwiftUI が再 render、Detail 画面のタグセクションに新チップ表示
```

### タグ削除

```text
1. ユーザーがタグチップの × ボタンタップ
2. TagStore.removeTag(name: normalized, from: article)
3. article.tags から該当 Tag を除去
4. tag.articles から article を除去 (双方向 relationship 同期)
5. tag.articles.isEmpty なら context.delete(tag)
6. context.save() → RefreshTrigger.bump()
```

### 関連記事計算

```text
1. ArticleDetailView が表示される
2. 親 view から渡された全 articles 配列 (or @Query で別途 fetch) を保持
3. RelatedArticlesSection が computed property で
   RelatedArticleFinder.find(for: article, in: allArticles, limit: 5) を呼ぶ
4. 結果を縦リスト表示 (各行: タイトル + commonEntityCount チップ)
5. 行タップ → 該当 Article の Detail を sheet で開く (既存 selectedArticle 経由)
```

### 自動タグ提案

```text
1. ArticleDetailView の タグセクション render 時
2. SuggestedTagFinder.find(article: article) を呼ぶ
3. 既存 article.tags の name set と比較して未登録の候補のみ抽出
4. 上位 5 件を Group で表示
5. 候補チップタップ → TagStore.addTag(name: normalizedName, to: article)
6. RefreshTrigger.bump で UI 更新、候補リストから消える
```

---

## 6. 性能特性

| 操作 | 計算量 | 期待時間 |
|---|---|---|
| 検索 (1000 記事) | O(N) Predicate scan | < 200 ms |
| タグ追加 | O(1) (UUID lookup + insert) | < 50 ms |
| タグ削除 + 孤児 cleanup | O(1) | < 50 ms |
| 関連記事計算 (1000 記事) | O(N × E) where E = 各記事の平均 entity 数 (5-10) | < 200 ms |
| 自動提案計算 (1 記事) | O(E + T) where T = 既存タグ数 | < 50 ms |

すべて Constitution パフォーマンスゲート (100 ms 入力フィードバック / 200 ms 検索) を満たす。

---

## 7. テスト用 fixture

`KnowledgeTreeTests/Fixtures/SearchFixtures.swift` (新規):

| Fixture | 内容 |
|---|---|
| `tenArticlesWithVariedFields` | 10 件、各記事は title / canonicalTitle / essence / keyFact / entity に異なる固有名詞 |
| `articleWithFiveEntities` | entities = [Apple (s5), OpenAI (s4), ChatGPT (s3), GPT-4 (s5), Anthropic (s4)] |
| `articleWithSharedEntities` | 別記事、上記と Apple / OpenAI 共通 (commonCount = 2 想定) |
| `tagsCollection` | "swift", "ios", "swiftui", "swift-data" の 4 タグを持つ記事複数 |

各 fixture は `BodyFixtures.swift` (spec 006) と統合可能。

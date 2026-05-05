# Contract: SearchPredicate + SearchHighlighter

**Files**:
- `KnowledgeTree/Services/SearchPredicate.swift` (新規)
- `KnowledgeTree/Services/SearchHighlighter.swift` (新規)

## SearchPredicate

### 責務
検索クエリから動的 `Predicate<Article>` を生成する純粋関数。空クエリは nil 返却 (= 全件取得を SwiftUI に任せる)。

### API

```swift
struct SearchPredicate {
    /// 検索クエリから Predicate<Article> を生成。
    /// - Parameter query: ユーザー入力 (trim 前)
    /// - Returns: 空クエリは nil、それ以外は SwiftData 動的 Predicate
    static func make(query: String) -> Predicate<Article>?
}
```

### 動作詳細

```swift
static func make(query: String) -> Predicate<Article>? {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return nil }

    return #Predicate<Article> { article in
        article.title.localizedStandardContains(q) ||
        (article.enrichment?.canonicalTitle?.localizedStandardContains(q) ?? false) ||
        (article.enrichment?.summary?.localizedStandardContains(q) ?? false) ||
        (article.extractedKnowledge?.essence?.localizedStandardContains(q) ?? false) ||
        (article.extractedKnowledge?.summary?.localizedStandardContains(q) ?? false) ||
        (article.extractedKnowledge?.keyFacts.contains { $0.statement.localizedStandardContains(q) } ?? false) ||
        (article.extractedKnowledge?.entities.contains { $0.name.localizedStandardContains(q) } ?? false) ||
        article.tags.contains { $0.name.localizedStandardContains(q) }
    }
}
```

### Fallback (Predicate サポート不足時)

iOS 26 SDK で上記 nested optional + collection contains が動かない場合の fallback:
- `make(query:)` は Article 直接フィールド (title, url) のみで Predicate を返す
- ArticleListContent 側で post-filter:
  ```swift
  let candidates = articles  // @Query で title/url のみ predicate
  let filtered = q.isEmpty ? candidates : candidates.filter { article in
      // relationship target を view 側で再評価
  }
  ```

実装フェーズで動作確認、両 path に対応した実装を用意。

### 不変条件

1. 空クエリ (空文字 or whitespace) → nil 返却
2. 空でないクエリ → 必ず Predicate<Article> 返却
3. Predicate は 8 フィールド (title / canonicalTitle / summary / essence / extractedKnowledge.summary / keyFact.statement / entity.name / tag.name) を OR 結合
4. case-insensitive (`localizedStandardContains` は default で case-insensitive)

### テストケース

```swift
@Test("空クエリは nil")
func emptyReturnsNil()

@Test("空白のみは nil")
func whitespaceOnlyReturnsNil()

@Test("title マッチで Predicate hit")
func matchesTitle()

@Test("canonicalTitle マッチ")
func matchesCanonicalTitle()

@Test("essence マッチ")
func matchesEssence()

@Test("keyFact statement マッチ")
func matchesKeyFact()

@Test("entity name マッチ")
func matchesEntity()

@Test("tag name マッチ")
func matchesTag()

@Test("case-insensitive (oauth と OAuth が同じ結果)")
func caseInsensitive()

@Test("どこにも該当しないクエリで結果 0 件")
func noMatchEmptyResult()
```

SwiftData in-memory ModelContainer で Article fixtures を投入してテスト。

---

## SearchHighlighter

### 責務
検索結果でマッチしたフィールドの excerpt を AttributedString として返す純粋関数。

### API

```swift
struct SearchHighlighter {
    /// article から query にマッチするフィールドを 1 つ選び、ハイライト済 excerpt を返す。
    /// 優先順位: title > canonicalTitle > essence > summary > keyFact > entity
    /// - Returns: マッチ無しなら nil
    static func highlight(article: Article, query: String) -> SearchHighlight?

    /// 純粋なテキストハイライト関数 (テスト用)
    static func highlightText(
        _ text: String,
        query: String,
        excerptRadius: Int = 30
    ) -> AttributedString?
}

struct SearchHighlight: Sendable {
    let fieldName: LocalizedStringKey
    let excerpt: AttributedString
}
```

### 動作詳細

```swift
static func highlight(article: Article, query: String) -> SearchHighlight? {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return nil }

    // 優先順位順にマッチ確認
    if let excerpt = highlightText(article.title, query: q) {
        return SearchHighlight(fieldName: "search.field.title", excerpt: excerpt)
    }
    if let canonical = article.enrichment?.canonicalTitle,
       let excerpt = highlightText(canonical, query: q) {
        return SearchHighlight(fieldName: "search.field.canonicalTitle", excerpt: excerpt)
    }
    if let essence = article.extractedKnowledge?.essence,
       let excerpt = highlightText(essence, query: q) {
        return SearchHighlight(fieldName: "search.field.essence", excerpt: excerpt)
    }
    if let summary = article.extractedKnowledge?.summary,
       let excerpt = highlightText(summary, query: q) {
        return SearchHighlight(fieldName: "search.field.summary", excerpt: excerpt)
    }
    if let keyFact = article.extractedKnowledge?.keyFacts.first(where: {
        $0.statement.localizedStandardContains(q)
    }) {
        if let excerpt = highlightText(keyFact.statement, query: q) {
            return SearchHighlight(fieldName: "search.field.keyFact", excerpt: excerpt)
        }
    }
    if let entity = article.extractedKnowledge?.entities.first(where: {
        $0.name.localizedStandardContains(q)
    }) {
        if let excerpt = highlightText(entity.name, query: q) {
            return SearchHighlight(fieldName: "search.field.entity", excerpt: excerpt)
        }
    }
    if let tag = article.tags.first(where: { $0.name.localizedStandardContains(q) }) {
        if let excerpt = highlightText(tag.name, query: q) {
            return SearchHighlight(fieldName: "search.field.tag", excerpt: excerpt)
        }
    }
    return nil
}

static func highlightText(_ text: String, query: String, excerptRadius: Int = 30) -> AttributedString? {
    guard let range = text.range(of: query, options: .caseInsensitive) else { return nil }
    let start = text.index(range.lowerBound, offsetBy: -excerptRadius, limitedBy: text.startIndex) ?? text.startIndex
    let end = text.index(range.upperBound, offsetBy: excerptRadius, limitedBy: text.endIndex) ?? text.endIndex
    let excerpt = String(text[start..<end])

    var attrs = AttributedString(excerpt)
    var searchRange = attrs.startIndex..<attrs.endIndex
    while let r = attrs.range(of: query, options: .caseInsensitive, locale: nil, in: searchRange) {
        attrs[r].font = .body.bold()
        searchRange = r.upperBound..<attrs.endIndex
    }
    return attrs
}
```

### 不変条件

1. 空クエリ → nil 返却
2. マッチ無し → nil 返却
3. マッチあり → fieldName と excerpt 両方 non-nil
4. excerpt は AttributedString で、マッチ箇所が `.font = .body.bold()` 適用済
5. excerpt は元 text のサブ文字列 (前後 ±30 文字)

### テストケース

```swift
@Test("title マッチで fieldName=title, excerpt がマッチ周辺")
func highlightTitle()

@Test("title マッチが優先、他フィールドは見ない")
func priorityTitleOverOthers()

@Test("title マッチ無いが essence マッチ")
func fallthroughToEssence()

@Test("マッチ無しなら nil")
func noMatchReturnsNil()

@Test("excerpt は ±30 文字")
func excerptRadius()

@Test("複数マッチでも全部 bold")
func multipleMatchesAllBolded()

@Test("case-insensitive ハイライト")
func caseInsensitiveHighlight()

@Test("空クエリは nil")
func emptyQueryReturnsNil()
```

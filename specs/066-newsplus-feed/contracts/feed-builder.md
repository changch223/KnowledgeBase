# Contract: FeedBuilder

## 対象
- `KnowledgeTree/Services/FeedBuilder.swift` (Protocol + Default, @MainActor)
- `KnowledgeTree/Models/FeedItem.swift` (transient enum)

## API
```swift
protocol FeedBuilding {
    func build() -> [FeedItem]
}

@MainActor final class FeedBuilder: FeedBuilding {
    init(context: ModelContext, now: @escaping () -> Date = { .now })
    func build() -> [FeedItem]
}
```

## build() 仕様
1. Article fetch (savedAt 降順, limit maxArticles=60) → `.article`
2. ConceptPage fetch (isHidden==false, updatedAt 降順) → 更新カード候補
3. Wiki 更新ガード: `updatedAt >= now() - 14d` && `!bodyMarkdown.isEmpty` (空なら summary 非空) → `.wikiUpdate` (limit maxWikiUpdates=20)
4. 2 系列を `sortDate` 降順 merge
5. (P2) periodicDigest を一定間隔で挿入
6. 返り値 `[FeedItem]`、AI 呼び出しゼロ

## 契約条件
| 条件 | 期待 |
|---|---|
| 空 DB | `[]` |
| 記事+Wiki | sortDate 降順 mix (SC-001) |
| 古い Wiki (>14d) | 更新カード除外 (SC-005) |
| 本文なし Wiki | 更新カード除外 |
| isHidden Wiki | 除外 |
| AI 呼び出し | ゼロ (SC-007) |

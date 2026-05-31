# Contract: iKnow フィードレイアウト (KnowledgeClipView + Shelf カード)

## KnowledgeClipView 改修 (FR-001/002/004/009)
縦 LazyVStack (spec 066、見出し無し時系列 mix) に carousel を挿入:
```swift
ForEach(Array(feedItems.enumerated()), id: \.element.id) { idx, item in
    cardView(item)
    if idx == carouselInsertIndex - 1, !recommendItems.isEmpty {
        RecommendCarousel(items: recommendItems)
    }
}
```
- `recommendItems = FeedBuilder.recommend(articles:wikiPages:now:)`
- 候補 < carouselMinItems なら carousel 非表示
- 重複除外なし (FR-009)

## RecommendCarousel (新規)
```swift
struct RecommendCarousel: View { let items: [FeedItem] }
```
控えめ見出し (「おすすめ」) + `ScrollView(.horizontal) { LazyHStack { ShelfCard } }`。

## ArticleShelfCard / WikiShelfCard (新規、横用コンパクト)
- 幅 ~150、写真上 (~100h) + 名前/タイトル下 2 行
- ArticleShelfCard: NavigationLink(value: article)
- WikiShelfCard: 借用写真 or kind アイコン + 種別バッジ、NavigationLink(value: ConceptPageDetailDestination(id:))

## 契約条件
| 条件 | 期待 |
|---|---|
| フィード途中 | carousel 1 本挿入 (SC-003) |
| 候補不足 | carousel 非表示 |
| tap | 各詳細遷移 (SC-006) |
| LazyHStack | 60fps 横スクロール |
| 写真なし | kind アイコン fallback |

# Contract: FeedBuilder.recommend + AI 処理中除外

## 対象
- `KnowledgeTree/Services/FeedBuilder.swift`

## assemble 改修 (FR-003)
article filter に AI 処理完了条件を追加:
```swift
.filter { a in
    let s = a.extractedKnowledge?.status
    return s == .succeeded || s == .partiallySucceeded
}
```
pending / processing / failed / nil (knowledge 未生成) は除外。

## recommend (FR-005/006、static 純関数)
```swift
static func recommend(
    articles: [Article],
    wikiPages: [ConceptPage],
    now: Date,
    limit: Int = recommendLimit
) -> [FeedItem]
```
- Wiki: `score = Double(relatedArticles.count) * wikiArticleWeight + recencyBonus(updatedAt, now)`、isHidden 除外、本文/要約あり
- 記事: succeeded/partiallySucceeded のみ、`score = recencyBonus(savedAt, now)` ベース
- `recencyBonus(date, now)`: `max(0, 1 - 経過日/recommendRecencyWindowDays)` 線形減衰 (14日で0)
- 全候補を score desc sort、上位 limit を `.article` / `.wikiUpdate` の FeedItem 化

## 契約条件
| 条件 | 期待 |
|---|---|
| 関連記事多+最近更新 Wiki | 上位 (SC-004) |
| AI 処理中記事 | recommend/assemble 両方から除外 (SC-002) |
| 候補 > 5 | top 5 のみ (FR-005) |
| AI 呼び出し | ゼロ (SC-005) |
| isHidden Wiki | 除外 |

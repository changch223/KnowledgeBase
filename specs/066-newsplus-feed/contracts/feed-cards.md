# Contract: ArticleFeedCard / WikiFeedCard

## ArticleFeedCard
```swift
struct ArticleFeedCard: View { let article: Article }
```
- 写真: `article.enrichment?.ogImageURL` を大判 (full-width, ~16:9) AsyncImage、なければ色ブロック + favicon/アイコン
- タイトル + savedAt (SavedAtFormatter) + essence/summary preview
- 関連 Wiki チップ: `article.relatedConcepts?.prefix(3)` capsule、tap → `ConceptPageDetailDestination`
- カード全体 tap (NavigationLink value: article) → 記事詳細

## WikiFeedCard
```swift
struct WikiFeedCard: View { let page: ConceptPage }
```
- 写真借用: `page.relatedArticles?.compactMap { $0.enrichment?.ogImageURL }.first`、なければ `page.kind.symbolName` + カテゴリ色
- 種別バッジ (kind) + name + bodyMarkdown/summary preview + 「更新」ラベル + updatedAt
- カード tap (NavigationLink value: ConceptPageDetailDestination(id: page.id)) → 概念詳細

## 契約条件
| 条件 | 期待 |
|---|---|
| 画像あり | 写真表示 (SC-003) |
| 画像なし | fallback 崩れず (SC-004) |
| 記事 tap | 記事詳細 (SC-002) |
| Wiki tap | 概念詳細 (SC-002) |
| チップ tap | 関連概念へ (SC-006) |
| LazyVStack 内 | AsyncImage 遅延ロード、60fps (SC-008) |

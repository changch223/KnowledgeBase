# Data Model: News+ 風フィード

## SwiftData @Model 変更
**ゼロ。** Article / ConceptPage / ArticleEnrichment は既存。CloudKit migration 不要。

## 新規 transient

### FeedItem (enum, Identifiable + Hashable)
| case | 中身 | sortDate |
|---|---|---|
| `article(Article)` | 記事カード | `article.savedAt` |
| `wikiUpdate(ConceptPage)` | Wiki 更新カード | `page.updatedAt` |
| `periodicDigest([ConceptPage])` | 周期まとめ (P2) | 束ねた最大 updatedAt |

`id`: `"a-\(article.id)"` / `"w-\(page.id)"` / `"d-\(最古 page.id)"`。

## 既存フィールド利用
| フィールド | 役割 |
|---|---|
| `Article.savedAt` | 時系列 |
| `Article.enrichment?.ogImageURL` | 記事写真 |
| `Article.relatedConcepts` (inverse) | 関連 Wiki チップ |
| `ConceptPage.updatedAt` | 時系列 + 更新判定 |
| `ConceptPage.bodyMarkdown` / `summary` | 更新カード本文あり判定 |
| `ConceptPage.isHidden` | 除外 |
| `ConceptPage.relatedArticles[].enrichment?.ogImageURL` | Wiki 写真借用 |
| `ConceptPage.kind.symbolName` / `categoryRaw` | fallback アイコン+色 |

## 新規定数 (FeedBuilder)
| 名前 | 値 | 役割 |
|---|---|---|
| `wikiUpdateWindowDays` | 14 | Wiki 更新カードを出す直近日数 |
| `maxArticles` | 60 | fetch 上限 |
| `maxWikiUpdates` | 20 | Wiki 更新カード上限 |
| `periodicDigestEvery` | (P2) | 周期ダイジェスト挿入間隔 |

## 状態遷移
なし。

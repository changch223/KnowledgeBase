# Data Model: iKnow タブ 自然 mix フィード

## SwiftData @Model 変更
**ゼロ。** Article / ConceptPage / ArticleEnrichment / ExtractedKnowledge 既存。CloudKit migration 不要。

## 既存利用
| フィールド | 役割 |
|---|---|
| `Article.savedAt` | 時系列 + 記事 recommend スコア |
| `Article.extractedKnowledge?.status` | AI 処理完了判定 (.succeeded/.partiallySucceeded のみ表示) |
| `Article.enrichment?.ogImageURL` | 記事写真 |
| `Article.relatedConcepts` | 関連 Wiki チップ |
| `ConceptPage.relatedArticles.count` | Wiki recommend スコア (記事数) |
| `ConceptPage.updatedAt` | 時系列 + Wiki recommend 更新ボーナス |
| `ConceptPage.isHidden` | 除外 |
| `ConceptPage.relatedArticles[].enrichment?.ogImageURL` | Wiki 写真借用 |
| `ConceptPage.kind` | 種別バッジ / fallback アイコン |

## 新規定数 (FeedBuilder)
| 名前 | 値 | 役割 |
|---|---|---|
| `recommendLimit` | 5 | carousel 件数 |
| `wikiArticleWeight` | 2.0 | Wiki recommend の記事数重み |
| `recommendRecencyWindowDays` | 14 | 更新ボーナス減衰窓 |
| `carouselMinItems` | 3 | これ未満なら carousel 非表示 |
| `carouselInsertIndex` | 3 | 縦フィードの何件目の後に挿入するか |

## 新規純関数
| 関数 | 配置 | 役割 |
|---|---|---|
| `recommend(articles:wikiPages:now:limit:)` | FeedBuilder (static) | おすすめ 5 件算出 |
| `assemble` 改修 | FeedBuilder | AI 処理中記事の除外を追加 |

## 状態遷移
なし (AI 完了で @Query 再評価され記事が現れるのは SwiftData reactive の自然挙動)。

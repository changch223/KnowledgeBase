# Data Model: RecentDigest token 超過修正 + SchemaLoader bundle 同梱

## SwiftData @Model 変更

**ゼロ。** 本 spec は永続化スキーマを一切変更しない (FR-008)。

## 既存 @Model (参照のみ、無改修)

| Model | 関与 |
|---|---|
| `Article` | RecentDigest.buildPrompt の入力 (title / essence / keyFacts)。参照のみ。 |

## 新規定数 (RecentDigestService 内)

| 名前 | 値 | 役割 |
|---|---|---|
| `promptArticleLimit` | 8 | buildPrompt に列挙する記事の上限 (maxArticles=30 とは別) |
| `promptCharBudget` | 3000 | buildPrompt の累積文字数の安全上限 (~token 概算、4096 未満を保証) |

## 新規リソース

| パス | 内容 |
|---|---|
| `KnowledgeTree/Resources/iknow-schema.md` | `docs/iknow-schema.md` のコピー (6121 chars)。bundle 同梱用、SchemaLoader が読む。 |

## 状態遷移

なし。

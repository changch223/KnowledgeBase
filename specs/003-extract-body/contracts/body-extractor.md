# Contract: BodyExtractor (Pure Function)

**Layer**: Pure function boundary (Constitution Principle VI)
**Used by**: `BodyExtractionService`

## Purpose

HTML 文字列を入力に取り、本文 plain text + メタ情報を抽出する純関数。副作用なし、テスト容易。

## Interface

```swift
struct BodyExtractor {
    struct ParsedBody: Equatable, Sendable {
        /// 抽出された本文 plain text (段落区切り = "\n\n")。100 文字未満の場合は nil。
        let extractedText: String?
        /// 採用された抽出戦略 (debug / 将来の品質指標用)。
        let strategy: ExtractionStrategy
    }

    enum ExtractionStrategy: String, Sendable {
        case semanticTagArticle      // <article> タグから採用
        case semanticTagMain         // <main> または role="main"
        case textDensityScoring      // text-density スコアリング fallback
        case noBodyFound             // 何も見つからなかった (extractedText は nil)
        case parseFailed             // HTML パース完全失敗
    }

    /// HTML から本文を抽出する。100 文字未満は nil 返却 (上位 Service が `failed` で永続化)。
    static func extract(html: String) -> ParsedBody
}
```

## Behavior

### 抽出戦略 (順番に試行)

1. **semantic タグ優先**: `<article>...</article>`、`<main>...</main>`、`<div role="main">...</div>` を case-insensitive 正規表現 + 単純なタグ stack で取得。最初に見つかったブロックを本文候補。
2. **text-density スコアリング fallback**: 上記が見つからない or 結果が < 100 文字なら、HTML 全体から `<div>` / `<section>` / `<p>` を走査し、各ブロックを以下でスコアリング:
   - `score = textLength - (linkTextLength * 2.0) - (tagCount * 5)`
   - 最高スコアのブロックを本文採用。閾値 (例 score > 200) を満たさなければ `noBodyFound`。
3. 採用ブロックから boilerplate (`<script>`、`<style>`、`<nav>`、`<aside>`、`<footer>`、`<header>`、`<form>`、`<noscript>`) を除去。
4. メディア (`<img>`、`<video>`、`<iframe>`、`<picture>`、`<canvas>`) を完全除去 (FR-009)。
5. リンク `<a href="...">text</a>` は text のみ抽出 (URL 捨てる、研究 R2)。
6. 残りのテキストノードを段落単位で連結 (research.md / R2 の規則表に従う)。
7. HTML エンティティ decode + 連続空行を 1 つに圧縮 + 前後 trim。
8. 最終長さが < 100 文字なら `extractedText = nil`、それ以外は値を設定。

### 例外時

すべての抽出戦略が失敗 / HTML が完全に壊れて parse 不可 → `ParsedBody(extractedText: nil, strategy: .parseFailed)`。例外を throw しない (Service 側を簡潔に保つ)。

## Why a pure function?

- `URLSession` / SwiftData / Logger 等の副作用なし → 単体テストが固定 HTML フィクスチャで完結 (高速・決定論的)。
- `BodyExtractionService` の差し替え自由度 (将来 WebKit ベースに切り替えるとき contract は不変)。
- detached `Task` で main thread を一切ブロックしない (research.md / R5)。

## Tests (KnowledgeTreeTests / `BodyExtractorTests`)

最低限のテストケース:

| ケース | 入力 fixture | 期待 strategy | 期待 extractedText |
|---|---|---|---|
| `<article>` あり典型 | body-article-tag.html | `.semanticTagArticle` | ≥ 100 文字、本文を含む |
| `<main>` あり典型 | body-main-tag.html | `.semanticTagMain` | ≥ 100 文字 |
| semantic なし、text density 救済 | body-no-semantic.html | `.textDensityScoring` | ≥ 100 文字 |
| boilerplate 多 | body-boilerplate-heavy.html | (任意) | 本文だけが含まれる、nav / footer は除去 |
| 短すぎる結果 | body-too-short.html | (任意) | nil (extractedText) |
| 画像含む HTML | body-with-images.html | (任意) | extractedText に `<img>` 由来文字列含まない |
| リンク含む HTML | body-with-links.html | (任意) | リンクの URL 部分が含まれない |
| 箇条書き含む | body-with-lists.html | (任意) | 行頭 "・" で箇条書き化 |
| 日本語記事 | body-japanese.html | (任意) | 日本語段落が正しく抽出 |
| 完全に壊れた HTML | body-broken.html | `.parseFailed` または `.noBodyFound` | nil |
| 空文字列 | "" | `.parseFailed` | nil |

すべて固定 HTML 文字列 / フィクスチャで実行 (test bundle に含める)。

# Contract: MetadataParser

**Layer**: Pure function boundary (Constitution Principle VI)
**Used by**: `ArticleEnrichmentService`

## Purpose

HTML 文字列を入力に取り、canonical title / description / og:image URL を抽出する純関数。副作用なし、テスト容易。

## Interface

```swift
struct MetadataParser {
    struct ParsedMetadata: Equatable, Sendable {
        let canonicalTitle: String?
        let summary: String?
        let ogImageURL: URL?
    }

    /// Parse 結果は best-effort。1 フィールドも抽出できなくても throw せず空の ParsedMetadata を返す。
    static func parse(html: String, baseURL: URL?) -> ParsedMetadata
}
```

## Behavior

### canonical title

1. `<title>...</title>` を正規表現で抽出 (大文字小文字無視、属性は許容)。
2. HTML エンティティ (`&amp;` `&lt;` `&#39;` 等) を decode。
3. 前後空白 / 改行を trim。
4. 1000 文字超は 200 文字で切り詰め (Edge Case)。
5. 空文字列なら nil 返却。

### summary (meta description)

1. `<meta name="description" content="...">` を抽出 (name は大文字小文字無視、シングル/ダブルクオート対応)。
2. 見つからなければ `<meta property="og:description" content="...">` を fallback。
3. HTML エンティティ decode + trim。
4. 500 文字超は 300 文字で切り詰め (一覧 2 行表示で十分)。
5. 空文字列なら nil。

### og:image URL

1. `<meta property="og:image" content="...">` を抽出。
2. `<meta property="og:image:secure_url" content="...">` を優先 fallback。
3. 相対 URL は `URL(string: relative, relativeTo: baseURL)?.absoluteURL` で解決。
4. http スキームは https に置換 (R5)。
5. 解決後の URL が `URL?.scheme == "https"` でなければ nil。

## Why a pure function?

- `URLSession` / SwiftData / `Logger` 等の副作用なし → 単体テストが固定 HTML フィクスチャで完結 (高速・決定論的)。
- `ArticleEnrichmentService` の差し替え自由度を確保 (将来 WKWebView ベースに切り替えても本 contract は不変)。

## Tests (KnowledgeTreeTests / `MetadataParserTests`)

最低限のテストケース:

| ケース | 入力 | 期待 |
|---|---|---|
| 完全な HTML | title / description / og:image 全て有 | 全 3 フィールド抽出成功 |
| title のみ | description / og:image 不在 | canonicalTitle のみ、他 nil |
| 空 HTML | "" | 全 nil |
| HTML エンティティ含む title | `<title>Foo &amp; Bar</title>` | "Foo & Bar" |
| 1500 文字の title | 巨大 title | 200 文字に切り詰められる |
| 相対 og:image | `<meta property="og:image" content="/og.jpg">` + baseURL `https://example.com/post` | `https://example.com/og.jpg` |
| 不在 og:image_secure_url | `og:image` http のみ | https に置換、解決成功 |
| http only og:image (置換も失敗) | `og:image` `http://example.com/og.jpg` で https 経路無 | 取得側 (Service) で fetch 失敗 → nil 確定 (本 parser では https 化のみ実施) |
| 壊れた HTML | 末尾切れ | best-effort 抽出 |
| og:description fallback | name="description" 不在、og:description 有 | summary に og:description 値 |
| 大文字 META タグ | `<META NAME="DESCRIPTION" CONTENT="...">` | 抽出成功 (case-insensitive) |
| シングルクォート | `<meta name='description' content='...'>` | 抽出成功 |
| 多重 meta | 複数 description | 最初を採用 |

すべて固定 HTML 文字列で実行 (フィクスチャは tests target に bundle、または string literal でも可)。

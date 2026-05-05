# Contract: PaginationDetector

**File**: `KnowledgeTree/Services/PaginationDetector.swift` (新規)

## 責務

HTML 文字列と現在ページ URL から「次のページ」候補を 1 つ検出する純粋関数。クロスドメイン拒否 / 自己ループ拒否は呼び出し側 (Crawler) で行うが、relative URL の絶対化は本関数で実施。

## API

```swift
struct PaginationDetector {
    /// HTML 内の pagination 候補を検出して 1 件返す。
    /// 検出ルール優先順位:
    ///   1. <link rel="next" href="...">
    ///   2. <a rel="next" href="...">
    ///   3. <a class="...next..." href="..."> (大文字小文字無視)
    ///   4. URL パターン推測 (?page=N+1, /page/N+1, &page=N+1, /?p=N+1)
    /// 各ルールで複数候補があれば最初の出現を採用。
    /// 相対 URL は currentURL を base に absolute 化。
    /// scheme が https 以外なら nil 返却。
    /// クロスドメイン (host が異なる) なら nil 返却。
    static func detect(html: String, currentURL: URL) -> PaginationLink?
}

struct PaginationLink: Equatable, Sendable {
    let url: URL
    let detectedBy: DetectionRule
}

enum DetectionRule: String, Sendable {
    case linkRelNext
    case anchorRelNext
    case anchorClassNext
    case urlPattern
}
```

## 不変条件 (Invariants)

1. 戻り値の `url.scheme == "https"` (https 強制)
2. 戻り値の `url.host?.lowercased().replacingOccurrences(of: "^www\\.", ...) == currentURL.host?...` (host が同一、`www.` 違いは同一視)
3. 戻り値の URL は相対参照を含まない (absolute 解決済)
4. 戻り値の URL == currentURL (normalized 比較) なら nil 返却 (自己ループ防止)

## 検出アルゴリズム詳細

### Rule 1: `<link rel="next">`

```text
正規表現: <link\s+[^>]*rel\s*=\s*["']next["'][^>]*href\s*=\s*["']([^"']+)["']
       OR: <link\s+[^>]*href\s*=\s*["']([^"']+)["'][^>]*rel\s*=\s*["']next["']
```

`<head>` 内 `<link>` タグだが、HTML パーサ無しなので head/body 区別は行わない (実運用上 `<link rel="next">` が body に出現する誤動作リスクは低い)。

### Rule 2: `<a rel="next">`

```text
正規表現: <a\s+[^>]*rel\s*=\s*["']next["'][^>]*href\s*=\s*["']([^"']+)["']
       OR: <a\s+[^>]*href\s*=\s*["']([^"']+)["'][^>]*rel\s*=\s*["']next["']
```

### Rule 3: `<a class="...next...">`

```text
正規表現: <a\s+[^>]*class\s*=\s*["'][^"']*\bnext\b[^"']*["'][^>]*href\s*=\s*["']([^"']+)["']
       OR: <a\s+[^>]*href\s*=\s*["']([^"']+)["'][^>]*class\s*=\s*["'][^"']*\bnext\b[^"']*["']
```

`\bnext\b` で word boundary 一致 (例: `class="next-button"` も `class="pagination-next"` も hit、`class="nextstep"` は不一致)。大文字小文字無視。

### Rule 4: URL パターン推測

現在 URL から次ページ URL の候補リストを生成:

| パターン | currentURL 例 | 候補生成 |
|---|---|---|
| `?page=N` | `https://x.com/a?page=1` | `https://x.com/a?page=2` |
| `&page=N` | `https://x.com/a?id=10&page=1` | `https://x.com/a?id=10&page=2` |
| `/page/N` | `https://x.com/a/page/1` | `https://x.com/a/page/2` |
| `/?p=N` | `https://x.com/a?p=1` | `https://x.com/a?p=2` |
| 末尾 `/N` | `https://x.com/a/1` | `https://x.com/a/2` (false positive リスク高、優先度低) |

各候補について HTML 内に `<a href="...">` があるか正規表現で検索 (相対 URL も考慮)。最初にヒットした候補を返す。

注意: rule 4 は誤検出リスク高。1, 2, 3 で検出できなかった場合の最終手段。

## ボーダーケース

| HTML / currentURL | 期待結果 |
|---|---|
| `<link rel="next" href="page2.html">`, current=`https://x.com/a` | url=`https://x.com/page2.html`, rule=linkRelNext |
| `<link rel="next" href="https://x.com/a">`, current=`https://x.com/a` | nil (自己ループ) |
| `<link rel="next" href="https://other.com/p">`, current=`https://x.com/a` | nil (クロスドメイン) |
| `<link rel="next" href="http://x.com/p2">`, current=`https://x.com/a` | nil (http 拒否) |
| 通常記事 (rel=next なし、class=next なし、URL パターンも該当 a 無し) | nil |
| `<link rel="next">` と `<a rel="next">` 両方ある | rule 1 (`<link>`) 優先 |
| `<link rel="next" href="">` (空 href) | nil |
| `<link rel="next" href="javascript:void(0)">` | nil (URL parse 失敗 or scheme 違い) |
| `<a class="next prev" href="/p2">` | rule 3 hit (next が含まれる) |
| `<a class="nextpage" href="/p2">` | nil (`\bnext\b` で word boundary 一致しない) |

## テストケース (`PaginationDetectorTests.swift`)

```swift
@Test("rule 1: link rel=next 検出")
func detectsLinkRelNext()

@Test("rule 2: a rel=next 検出")
func detectsAnchorRelNext()

@Test("rule 3: a class=next 検出 (word boundary)")
func detectsAnchorClassNext()

@Test("rule 3: class=nextstep は word boundary 不一致")
func ignoresClassNextstep()

@Test("rule 4: ?page=N URL パターン検出")
func detectsURLPatternQueryParam()

@Test("rule 4: /page/N URL パターン検出")
func detectsURLPatternPathSegment()

@Test("優先順位: rule 1 が rule 2 より先")
func priorityRule1OverRule2()

@Test("優先順位: rule 2 が rule 3 より先")
func priorityRule2OverRule3()

@Test("クロスドメイン拒否")
func rejectsCrossDomain()

@Test("http 拒否 (https 強制)")
func rejectsHTTP()

@Test("自己ループ拒否")
func rejectsSelfLoop()

@Test("空 href 拒否")
func rejectsEmptyHref()

@Test("javascript: scheme 拒否")
func rejectsJavascriptScheme()

@Test("相対 URL の絶対化")
func resolvesRelativeURL()

@Test("www 違いは同一ホスト扱い")
func wwwSameHost()

@Test("通常記事 (pagination 無し) は nil")
func returnsNilWhenNoPagination()
```

## エラーケース

純粋関数なので throw しない。検出失敗 / 拒否 はすべて nil 返却。

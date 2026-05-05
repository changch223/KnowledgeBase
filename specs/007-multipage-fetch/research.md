# Research: マルチページ記事の自動追跡 (Phase 0)

**Feature**: spec 007
**Date**: 2026-05-05

## R1: pagination 検出ルールの優先順位

**Decision**: rel=next > class=next > URL パターン推測 の 3 段階優先順位

**Rationale**:
- `<link rel="next">` は HTML5 標準 / WHATWG / Google が推奨する正規仕様。ニュースサイト・ブログ・Wikipedia でも採用
- `<a rel="next">` も同等に強い (HTML5 仕様で a タグでも有効)
- `class="next"` / `class="pagination-next"` は CSS 慣例で多用される (WordPress / Bootstrap pagination 等)
- URL パターン推測 (?page=N, /page/N) は誤検出リスクあるが、上記が無くても WordPress / Drupal 系で頻出

**Alternatives considered**:
- A: rel=next のみ → 実用的サイトの 30-40% で検出失敗
- B: 上記 3 ルール統合 (採用)
- C: HTML5 microdata / schema.org の `nextItem` プロパティも検出 → ニッチ、MVP 不要

**Implementation note**: `PaginationDetector.detect(html:currentURL:)` は順序通り 3 ルールを試し、最初にヒットしたものを返す。各ルールの候補が複数あれば最初の `<link>` / `<a>` を採用。

---

## R2: URL 正規化と重複検出

**Decision**: スキーマ小文字 / ホスト小文字 / `www.` prefix 削除 / fragment 削除 / tracking params (`utm_*`, `fbclid`, `gclid`) 削除 / trailing slash 統一

**Rationale**:
- 同一ページが微妙に違う URL で表現される (例: `https://example.com/article` と `https://www.example.com/article#top`、`https://example.com/article?utm_source=foo`)
- 正規化なしだと URL set の重複検出が機能せず、無限ループに陥るリスク
- tracking params の削除は副作用があるが (例えばサーバーが utm を見て別ページを返す可能性) 一般的にコンテンツは同一なので safe

**Alternatives considered**:
- A: 正規化しない (URL string そのまま) → 上記理由で重複検出が脆弱
- B: 完全な RFC 3986 normalization (path encoding 等まで) → MVP に過剰
- C: 採用案 (実用的に適切な範囲のみ)

**Implementation note**: `URL.normalized() -> String` 拡張を `Services/URLNormalization.swift` に新設。`URLComponents` を使って path / query / host を別々に処理。

```swift
extension URL {
    func normalized() -> String {
        var c = URLComponents(url: self, resolvingAgainstBaseURL: false) ?? URLComponents()
        c.scheme = c.scheme?.lowercased()
        c.host = c.host?.lowercased().replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression)
        c.fragment = nil
        c.queryItems = c.queryItems?.filter { !$0.name.hasPrefix("utm_") && $0.name != "fbclid" && $0.name != "gclid" }
        var path = c.path
        if path.count > 1, path.hasSuffix("/") { path.removeLast() }
        c.path = path
        return c.string ?? self.absoluteString
    }
}
```

---

## R3: actor vs class for MultiPageCrawler

**Decision**: `actor MultiPageCrawler` を採用

**Rationale**:
- 5 ページの逐次 fetch を 1 つのジョブとして管理する concurrency context が必要
- URL set と取得済 HTML 配列を保持する mutable state がある → thread safety が必要
- Swift Concurrency の actor がこの用途の自然な選択 (isolation 保証 + Sendable)
- 既存 `ArticleEnrichmentService` も `@MainActor` だが、Crawler は detached でも良い (ネットワーク I/O が中心)

**Alternatives considered**:
- A: class + Lock (NSLock 等) → 古いパターン、Swift 6 で discouraged
- B: @MainActor class → メインスレッドを長時間ブロック (1 秒遅延 × 4)、UI 凍結リスク
- C: actor (採用) → main から切り離して fetch + delay。完了結果のみ MainActor に return

**Implementation note**: actor で 1 秒遅延中も他処理を妨げない。Crawler の API は `func crawl(initialURL:URL, session:URLSessionProtocol) async throws -> CrawlResult`。Service 側で await して結果を受け取る。

---

## R4: 連結 HTML の境界マーカーとパース耐性

**Decision**: HTML コメント `<!-- KnowledgeTree.PageBoundary index="N" url="..." -->` を区切りとして使用、各ページの decode 済 HTML を `\n\n<comment>\n\n` で連結

**Rationale**:
- HTML コメントは spec 003 の `BodyExtractor` regex (article / main / div etc.) で `<!-- ... -->` がマッチ対象外なので影響しない
- BodyExtractor の boilerplate 除去で `<!-- ... -->` を意図せず捕捉しない (現在の正規表現を確認: `<script>` 等のタグのみ対象、コメントは別扱い)
- 将来 spec で「page X 由来の本文だ」と追跡したい場合、コメントを parse できる
- HTML comment は HTML5 仕様で `<!-- ... -->` で確実に終端、攻撃対象になりにくい

**Alternatives considered**:
- A: 単純 `\n\n\n` で区切り → ページ境界が不明瞭、将来追跡不可
- B: HTML 内に `<div class="kt-page-boundary">` を挿入 → BodyExtractor が article 抽出時に誤捕捉する可能性
- C: 採用案 (HTML コメント)
- D: 各ページを別々に保存して別 column → スキーマ変更大、MVP 不要

**Implementation note**: 連結文字列の生成:
```swift
let combined = pages.enumerated().map { (i, html) in
    "\(html)\n\n<!-- KnowledgeTree.PageBoundary index=\"\(i+1)\" url=\"\(urls[i].absoluteString)\" -->"
}.joined(separator: "\n\n")
```

---

## R5: rawHTML 2MB 上限超過時の挙動

**Decision**: 連結後の総文字数が `rawHTMLCacheLimit` を超えたら `enrichment.rawHTML = nil` で保存。後続 body 抽出は skip。

**Rationale**:
- spec 002 既存の 2MB 上限は SwiftData の永続化負荷 (BLOB 保存) を抑える目的
- 連結 HTML が肥大化すると DB 全体のパフォーマンスに影響
- rawHTML を nil にしても Article + canonical title + summary + thumbnail は保存される (ユーザーは元記事 URL を SVC で開ける)
- 失敗ではなく degradation として扱う

**Alternatives considered**:
- A: 全ページ取得済でも 2MB 超えたら 1 ページ目だけ保存 → 中途半端、ユーザーから見て期待挙動と違う
- B: 上限を 5MB に引き上げ → DB 肥大化リスク、Constitution Principle IV (パフォーマンス) と整合しない
- C: 採用案 (nil 保存 + body 抽出 skip)

**Implementation note**: Service の保存ロジックで `combined.count > rawHTMLCacheLimit` チェックを追加。

---

## R6: 既存 retry/backoff ポリシーとの関係

**Decision**: 1 ページ目のみ retry (spec 002 の 3 回バックオフ継承)。2 ページ目以降の失敗はリトライせず early return。

**Rationale**:
- 多重リトライで遅延が膨らむ (4 ページ × 3 retry × 30s backoff = 6 分以上)
- ユーザーは Detail 画面の再試行ボタンで enrichment 全体を再実行可能 (spec 005)
- 2-N ページの失敗は often サイト側の構造変更 / pagination 切れ → リトライしても無意味

**Alternatives considered**:
- A: 全ページ retry → 遅延膨大
- B: 1 ページ目のみ retry (採用) → 妥協点、UX 許容
- C: 1 ページ目すら retry なし → 一時的ネットワーク不安定で全体失敗、悪化

**Implementation note**: `MultiPageCrawler.crawl` 内で 1 ページ目のみ既存の retry ロジックを呼ぶ。2 ページ目以降は `URLSession.data(for:)` を 1 回だけ。

---

## R7: BottomStatusBar の N/M 表示の M 不確定性

**Decision**: M = 最大可能数 (5) で固定表示 (例: 「メタデータ取得中 (1/5)」)。実際の停止が N=3 だったら最終的に「メタデータ取得中 (3/5)」風になる前にフェーズ遷移するため違和感は少ない。

**Rationale**:
- M (total) は途中で確定しない (検出が再帰的に進む)
- spec 006 の chunked では M が事前確定するため「(3/5)」と読むと「あと 2 ページある」と誤解される可能性
- ただし 1 秒のフェーズ表示を見るのが UX 的に短時間なので妥協可能
- 代替の「(1/?)」表示は spec 006 の N/M 表記と整合性が崩れる

**Alternatives considered**:
- A: 「メタデータ取得中 (1/?)」 → spec 006 と表記不整合
- B: 「メタデータ取得中 (1)」(N のみ) → spec 006 と表記不整合
- C: 「メタデータ取得中 (1/5)」(M=5 固定、採用)
- D: M 確定後に切り替え → 1 ページ目が完了するまで表示できない

**Implementation note**: `monitor.updateProgress(articleID, index: i+1)` を呼ぶときに `progressTotal` を再 set する API を追加検討。MVP は固定 5 で OK。

---

## R8: テスト戦略

**Decision**: `PaginationDetector` 単体テスト (純粋関数、HTML 文字列ハードコード)、`MultiPageCrawler` integration テスト (Mock URLSessionProtocol で 5 シナリオ網羅)、`ArticleEnrichmentService` の既存テストは無修正で pass する後方互換を担保。

**Rationale**:
- `PaginationDetector` は純粋関数なので網羅テスト容易
- `MultiPageCrawler` は actor + I/O なので Mock 必須。既存 `URLSessionProtocol` (spec 002) を Mock 化
- 既存 `ArticleEnrichmentService` は単一ページ動作を検証する 4 ケース有。これらは pagination 検出失敗 → 単一ページ動作のシナリオで pass する設計

**Alternatives considered**:
- A: `MultiPageCrawler` を実 URL でテスト → ネットワーク依存、Constitution テストゲート違反
- B: 採用案 (Mock + 既存 protocol 流用)

**Implementation note**: `MockURLSessionProtocol` を URL ごとに異なるレスポンスを返せるよう拡張 (現状は固定レスポンスかも、要確認)。

---

## サマリ

| Topic | Decision |
|---|---|
| R1 検出ルール優先順位 | rel=next > class=next > URL パターン |
| R2 URL 正規化 | スキーマ/ホスト lowercase + www 削除 + fragment 削除 + tracking params 削除 + trailing slash 統一 |
| R3 actor vs class | `actor MultiPageCrawler` |
| R4 連結 HTML 区切り | HTML コメント `<!-- KnowledgeTree.PageBoundary -->` |
| R5 rawHTML 上限超過 | nil 保存 + body 抽出 skip |
| R6 retry ポリシー | 1 ページ目のみ retry、2 ページ目以降は失敗で打ち切り |
| R7 BottomStatusBar M | 固定 5 (N/5 表示) |
| R8 テスト戦略 | Pure 関数 + Mock + 既存後方互換 |

NEEDS CLARIFICATION 残数: 0。Phase 1 へ進める。

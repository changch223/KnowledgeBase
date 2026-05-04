# Research: 本文抽出 (Reader View) — Phase 0

**Feature**: spec 003 — 本文抽出 (Reader View)
**Date**: 2026-05-04
**Status**: Complete (全 NEEDS CLARIFICATION 解決)

---

## R1. 本文抽出アルゴリズム選定 (Foundation 標準のみ)

**Decision**: **2 段階ヒューリスティック**:

1. **Semantic タグ優先**: `<article>`、`<main>`、`<div role="main">`、`<div id="content">` 等を最初に探し、見つかったらその中身を本文候補とする。
2. **Text-density スコアリング fallback**: 上記が無い / 短すぎる場合、HTML 内の `<div>` / `<section>` / `<p>` を走査し、各ブロックを (text 長さ) - (タグ数 × 重み) - (link 内テキスト割合) でスコアリング。最高スコアのブロックを本文採用。
3. 採用ブロックから `<script>` / `<style>` / `<nav>` / `<aside>` / `<footer>` / `<header>` / `<form>` を除去し、残りのテキストノードを段落単位で連結。

実装は `BodyExtractor.extract(html:) -> ParsedBody` の 1 純関数に集約。サードパーティ依存なし。

**Rationale**:
- Mozilla Readability の中核アイデア (text density scoring) を最小限実装することで、Foundation 標準 API のみで 70% 程度 (SC-003) の成功率を狙う。
- semantic タグ優先で、最近の HTML5 サイトはほぼ拾える。レガシーサイトは text density で救う。
- 純関数のためテスト容易 (固定 HTML フィクスチャでカバレッジ確保)。
- detached `Task` で実行すれば main thread を 1 ms もブロックしない (SC-004)。

**Alternatives considered**:
- **Mozilla Readability の Swift port**: 実装コストが高く、サードパーティライブラリ採用と実質的に同じリスク。MVP には過剰。
- **`NSAttributedString(data: htmlData, options: [.documentType: NSAttributedString.DocumentType.html])`**: rendering を伴うため重い + main thread 制約あり。本文以外も含まれる (構造抽出に不向き)。
- **`WKWebView.evaluateJavaScript("document.body.innerText")`**: フルブラウザ engine 経由で本文取得可能だが、メモリ ~50 MB+、main thread 制約。enrichment 件数あたりのコスト過剰。
- **`NSXMLParser` で strict XML パース**: 実 HTML はほぼ malformed XML なのでパース失敗が大半。

---

## R2. HTML → plain text 変換ルール

**Decision**: 採用ブロックの DOM walk で以下の規則:

| HTML 要素 | 出力 |
|---|---|
| `<p>`、`<div>` | テキスト + 段落区切り (空行) |
| `<br>` | 改行 |
| `<h1>` 〜 `<h6>` | テキスト + 段落区切り (見出しスタイルは Reader View 側で太字化を検討、MVP は plain) |
| `<a href="...">text</a>` | text のみ抽出 (URL は捨てる、MVP) |
| `<strong>`、`<em>`、`<b>`、`<i>` | テキストのみ (装飾は捨てる、MVP) |
| `<ul>`、`<ol>` の `<li>` | 行頭 "・" + テキスト + 改行 (順序付きでも箇条書き表示で統一) |
| `<blockquote>` | 行頭 "> " + テキスト + 段落区切り |
| `<code>`、`<pre>` | テキストのみ (等幅表示は将来 spec) |
| `<script>`、`<style>`、`<noscript>` | 完全除去 |
| `<img>`、`<video>`、`<iframe>`、`<picture>`、`<canvas>` | **完全除去** (MVP は plain text のみ、FR-009) |
| `<table>` | 行ごとに改行、cell は `\t` で区切り (MVP は粗い表示) |
| HTML エンティティ (`&amp;` `&lt;` 等) | decode |

連続する空行は 1 つに圧縮。前後 trim。

**Rationale**:
- plain text only の制約 (FR-009) を厳守しつつ、構造情報 (段落、箇条書き、引用) はテキストレベルで保持。
- リンク URL を捨てるのは Principle V (落ち着いた UX) — `[https://...]` がベタ書きされるのはノイズ。タップで元記事に飛ぶ (`<a>` レンダリング) は将来 spec で扱う。
- 画像 / 動画 / iframe 完全除去で MVP の plain-text-only 約束を守る。

**Alternatives considered**:
- **Markdown 形式で出力**: 表現力が増すが、Reader View 側で markdown レンダリングが必要となり複雑性増。MVP は plain text 一本化。
- **`AttributedString` で太字 / 斜体保持**: 抽出時はリッチに、表示時は plain にも切替可能。MVP では複雑性回避で plain string 保存。

---

## R3. Reader View typography (Dynamic Type 対応)

**Decision**: SwiftUI 標準の `Text` + `.font(.body)` で表示。`.lineSpacing(8)` で段落内行間を広げ、`.padding(.horizontal, 24)` で左右余白。最大幅 680 pt (iPad で長すぎないよう ScrollView 内に `.frame(maxWidth: 680)`)。Dark Mode は `Color(.label)` / `Color(.systemBackground)` で自動対応。

**Rationale**:
- Dynamic Type に完全対応 (`.body` は OS 設定に追従)。Constitution アクセシビリティゲート / Principle V 充足。
- Reader Mode 的な視覚 (Safari Reader、Pocket、Instapaper) を最小工数で実現。
- 680 pt は web の typography ベストプラクティス (1 行 60-75 文字) に近い。iPad で本文が画面いっぱいに広がるのを防ぐ。
- Dark Mode は SwiftUI default の semantic color で自動対応。明示的な color 指定不要。

**Alternatives considered**:
- **`SwiftUI` の `MarkdownText` 風カスタム renderer**: 装飾 (太字 / リンク等) を再現できるが、MVP は plain text 約束のため過剰。
- **typography 設定 UI** (フォントサイズ / 行間 / テーマ): MVP Out of Scope。OS 設定で十分。

---

## R4. Enrichment 完了 → Body 抽出 trigger

**Decision**: `ArticleEnrichmentService` に optional `bodyExtractionService: BodyExtractionServiceProtocol?` を inject。enrichment 成功時 (`status` を `.succeeded` に更新する直後) に `bodyExtractionService?.extract(article:)` を呼ぶ。enrichment service は body service の存在を知るが、抽出結果には関与しない (片方向の依存)。

**Rationale**:
- Service → Service の直接 call は test 容易 (Mock を inject すれば呼ばれたか検証できる)。
- Combine / NotificationCenter は依存が見えにくく、debugging / test がややこしい。MVP には過剰。
- enrichment service が body service を **optional** で受けることで、spec 002 単独テストが壊れない (body service nil で動作)。

**Alternatives considered**:
- **NotificationCenter で broadcast**: subscriber 側で listen、疎結合。だがテスト時に notification の verify が煩雑。
- **Combine `Publisher`**: enrichment service が `enrichmentCompleted: AnyPublisher<Article, Never>` を expose。subscriber で listen。柔軟だが overkill。
- **SwiftData の `ModelContext.didSave` notification**: 全変更を listen して enrichment .succeeded を抽出。広く取りすぎる、効率悪。

---

## R5. パフォーマンス: 抽出ジョブを main thread から外す

**Decision**: `BodyExtractor.extract(html:)` を `nonisolated` 純関数として定義し、`BodyExtractionService` 内で `Task.detached(priority: .utility)` で実行。結果を `@MainActor` で `ArticleBodyStore.upsert` に渡す。

```swift
func extract(article: Article) async {
    guard let html = article.enrichment?.rawHTML else { return }
    let parsed = await Task.detached(priority: .utility) {
        BodyExtractor.extract(html: html)
    }.value
    await store.upsert(article: article, status: ..., extractedText: parsed.text, ...)
}
```

**Rationale**:
- HTML パースは CPU-bound で 100-500 ms かかりうる。main thread で実行すると UI が drop frame する。
- `Task.detached` で別スレッド実行、結果のみ main に戻す。
- `priority: .utility` で UI 操作 (user-initiated) より低い優先度に設定し、enrichment ジョブで一覧スクロールが詰まらないようにする (SC-004)。

**Alternatives considered**:
- **メイン thread で実行**: ≤ 1s 程度なら許容、と判断するシナリオもあるが SC-004 (≤ 100 ms) を割る。NG。
- **OperationQueue / GCD background**: Swift Concurrency の方が型安全。

---

## R6. SwiftUI `@Query` の relationship 自動更新挙動

**Decision**: 一覧 View では `@Query<Article>` のみ使用。Reader / SVC 切替判定は `article.body?.status` の direct access。SwiftData は `@Query` 結果の relationship 変更を自動 observe するため、ArticleBody が新規作成 / status 更新されたら一覧の再描画が走る (要検証、Apple ドキュメント未明示)。

万一 reactive 更新されない場合は `ArticleListView` の各行を `@Bindable Article` でラップし、`article.body` を観察する fallback あり。

**Rationale**:
- spec 001 / 002 と一貫した SwiftData reactive パターン (`@Query` 中心)。
- 行タップ判定は同期、`article.body?.status` の参照のみで OK (FR-013 — 判定 ≤ 50 ms)。
- 反応性が不足したらすぐ `@Bindable` で fallback できる退避策あり。

**Alternatives considered**:
- **`@Query<ArticleBody>` で別途 observe**: 二重 query になり整合性管理が複雑。

---

## R7. テストフィクスチャ HTML の収集

**Decision**: `KnowledgeTreeTests/Fixtures/` 配下に複数の本文抽出用 HTML を配置:

- `body-article-tag.html` (`<article>` タグありの典型)
- `body-main-tag.html` (`<main>` タグありの典型)
- `body-no-semantic.html` (semantic タグなし、text density で抽出するケース)
- `body-boilerplate-heavy.html` (広告 / nav / footer が多く本文が比較的少ないケース)
- `body-too-short.html` (本文 100 文字未満で `failed` になるケース)
- `body-with-images.html` (`<img>` 含む、plain text 化で除去されることの確認)
- `body-with-links.html` (`<a>` 含む、URL 部分が捨てられることの確認)
- `body-with-lists.html` (`<ul>` / `<ol>` 含む、箇条書き化の確認)
- `body-japanese.html` (日本語記事サンプル)
- `body-broken.html` (HTML 壊れ、best-effort で抽出)

spec 002 の `MetadataParser` 用フィクスチャと共有可能なものは流用。

**Rationale**:
- フィクスチャベースで決定論的テスト (Constitution テストゲート)。
- 実 web からスナップショットして anonymize して bundle に含める方針。著作権等で問題があれば手書きの架空 HTML を作る。

---

## 追加メモ (NEEDS CLARIFICATION なし)

- **既存 Article への backfill**: 起動時に `ArticleBody` を持たない & rawHTML 有り の Article を全件スキャンしてキューイング。spec 002 の backfill と同じ実装パターン。
- **再抽出**: 本 spec MVP では rawHTML 更新経路がないため発生しない。`extractionVersion` フィールドを持つことで将来のヒューリスティック改善時に再抽出判定に使える。
- **Reader View のスクロール位置記憶**: 持たない (Out of Scope)。再オープンは先頭から。
- **多言語**: 日本語 + 英語のみ動作確認。RTL は将来 spec で対応。
- **既存 spec 001 の SVC タップ動線**: spec 003 で **置き換える** (Reader 優先、SVC は失敗フォールバック + US3 の「元記事を開く」用途)。spec 001 / spec 002 の SafariView 自体は残す (SVC を呼ぶコードパスが 2 箇所になる)。

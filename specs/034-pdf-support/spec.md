# Feature Specification: PDF サポート (内部 metadata + 本文抽出)

**Feature Branch**: `019-chrome-app-intent` (継続実装、別 spec docs)
**Created**: 2026-05-06
**Status**: ✅ 実装完了

## なぜ (Why)

実機検証 (2026-05-06) で報告: **PDF サイトを保存するとメタデータが取得できない** = ライブラリに URL のみで title 不明、AI 抽出も動かない。

### 原因

`MultiPageCrawler.fetch()` は `Accept: text/html` ヘッダで HTML 期待、`MetadataParser.decodeHTML(data:contentType:)` で string 化。PDF binary は HTML として decode できず `decodingFailed` throw → `firstPageFailed` 状態で permanently failed。

→ Article は保存されるが title = URL のまま、enrichment / body / knowledge / auto-tag / auto-category / AI Chat retrieval すべて動かない。

## ゴール

PDF URL を保存した時に:
- ライブラリに **title 付き** で表示
- **summary / author** 等のメタデータも表示 (PDF 内部にある場合)
- 本文テキストが AI 抽出フローに乗る → KeyFact / entities / Auto-Tag / Auto-Category 動作
- AI Chat retrieval にもヒット (essence embedding 生成される)

## 非ゴール

- PDF サムネイル化 (page 1 を画像化して og:image 相当に) → 将来 spec
- スキャン PDF (画像のみ) の OCR → 将来 spec、Vision framework 必要
- パスワード付き PDF → 将来 spec
- 巨大 PDF (5 MB 超) → maxDownloadBytes 既存制限のまま

## 採用案: PDFKit + 擬似 HTML 化

PDFKit (iOS 11+) で:
- `PDFDocument(data: Data)` でロード
- `documentAttributes[.titleAttribute]` で内部 Title metadata
- `documentAttributes[.subjectAttribute]` で Subject (summary 候補)
- `documentAttributes[.authorAttribute]` で Author
- 全 page を `PDFPage.string` でテキスト化 → 連結

抽出した metadata + 本文を **`<article>` 構造の擬似 HTML に整形** → 既存 `MetadataParser` / `BodyExtractor` / `KnowledgeExtractor` のフローに乗せる。新たな経路を増やさず、PDF 入力点だけ仮想 HTML にラップする設計。

## ユーザストーリー

### US1 (P1) — PDF 保存 → ライブラリに title 付き表示

1. Safari / Share Extension で PDF URL を保存
2. enrichment 完了 → ライブラリに **PDF の Title metadata** (なければ filename から推測) で表示
3. summary に Subject metadata or 本文冒頭 200 字

### US2 (P1) — PDF 本文の知識抽出

1. PDF の本文テキストが BodyExtractor → KnowledgeExtractor フローに乗る
2. essence / KeyFact 3-5 件 / entities 5-10 件が生成される
3. AI Auto-Tag (5 件) + Auto-Category 自動分類

### US3 (P1) — PDF が AI Chat retrieval にヒット

1. PDF の essence embedding が生成される (spec 021 hook 経由)
2. AI Chat で関連質問 → top-k=5 retrieval にヒット
3. 引用記事として PDF Article が cited される

## 機能要件

- **FR-001**: `PDFFetcher.isPDF(contentType:url:)` で PDF 判定 (Content-Type `application/pdf` or URL 末尾 `.pdf`)
- **FR-002**: `PDFFetcher.parse(data:sourceURL:)` で PDFDocument → `ParsedPDF { title, summary, author, pseudoHTML, pageCount }`
- **FR-003**: title: PDF 内部 `.titleAttribute` 優先、なければ `titleFromFilename` で URL filename から humanize
- **FR-004**: summary: PDF 内部 `.subjectAttribute` 優先、なければ本文冒頭 200 字
- **FR-005**: author: PDF 内部 `.authorAttribute` (任意)
- **FR-006**: pseudoHTML: `<article>` + `<h1>title</h1>` + 段落毎の `<p>` 列、`<head>` に `<title>` `<meta name="description">` `<meta name="author">`
- **FR-007**: `MultiPageCrawler.fetch` で Content-Type 判定 → PDF なら PDFFetcher へ分岐、HTML 経路は変更なし
- **FR-008**: Accept ヘッダに `application/pdf` 追加
- **FR-009**: PDF decode 失敗 (壊れた data 等) → `decodingFailed` throw、既存挙動同等

## 成功基準

- SC-001: PDF URL を保存 → title が PDF 内部 metadata or filename ベースで表示
- SC-002: summary が表示 (Subject or 本文冒頭)
- SC-003: 数分以内に knowledge / KeyFact / entities が生成
- SC-004: Auto-Tag / Auto-Category 動作
- SC-005: AI Chat で PDF 内容について質問 → 引用にヒット
- SC-006: 不正 / 壊れた PDF → 既存 HTML フローと同様 silent fail
- SC-007: 既存 HTML サイト保存に regression なし

## 想定実装規模

- 新規 1 ファイル: `KnowledgeTree/Services/PDFFetcher.swift` (~120 行、PDFKit + 擬似 HTML 整形 + helper)
- 改修 1 ファイル: `KnowledgeTree/Services/MultiPageCrawler.swift` (~10 行、PDF 分岐追加)
- 新規 1 テスト: `KnowledgeTreeTests/PDFFetcherTests.swift` (10 ケース、UIGraphicsPDFRenderer で in-memory PDF 生成)
- 合計 ~150 行、~5 タスク

## Constitution

- I (privacy): PDFKit on-device、外部送信ゼロ
- II (MVP): 内部 metadata + 本文テキストのみ、サムネイル / OCR は将来 spec
- III (source 追跡): pseudoHTML は元 PDF URL を保持、引用追跡可能
- IV (実現可能性): PDFKit iOS 11+ 確立 API
- V (calm UX): 失敗時 silent skip、追加 UI なし
- VI (architecture): 既存フロー (MetadataParser / BodyExtractor) を再利用、変更最小
- VII (日本語): エラー文言ゼロ追加

## 状態

✅ 実装 + テスト (10/10 PASS) 完了 (2026-05-06)。実機検証はユーザー実施。

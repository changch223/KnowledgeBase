# Implementation Plan: マルチページ記事の自動追跡 + 本文統合

**Branch**: `007-multipage-fetch` | **Date**: 2026-05-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/007-multipage-fetch/spec.md`

## Summary

`ArticleEnrichmentService` の HTTP fetch ロジックを拡張し、HTML 内の `<link rel="next">` / `<a rel="next">` / pagination URL パターンを検出して最大 5 ページまで自動追跡する。各ページの HTML を decode してから連結し、`enrichment.rawHTML` に 1 つの結合済み HTML として保存する (page 区切り HTML コメント付き)。1 ページ目の canonical title / og:image を採用し、後続 spec (003 body 抽出 / 004+006 knowledge 抽出) は連結済み HTML/本文を元に既存通り動作する。

技術アプローチ: 純粋関数 `PaginationDetector` (HTML から次ページ URL 候補を返す) と `MultiPageCrawler` (URLSession + 1 秒遅延 + URL set + 上限 5 で逐次 fetch する actor) を新規導入。`ArticleEnrichmentService.fetchAndParse` を `MultiPageCrawler.crawl` 経由で呼ぶように修正、結合 HTML を返す。`ProcessingMonitor.ActiveTask` に既存 `progressIndex/progressTotal` を活用 (spec 006 の拡張を継承)。

## Technical Context

**Language/Version**: Swift 6.x (Xcode 16+, iOS 26+)
**Primary Dependencies**: SwiftUI, SwiftData, Foundation (URLSession, Network)
**Storage**: SwiftData (App Group group container、既存 ArticleEnrichment 列追加)
**Testing**: Swift Testing + XCTest UI testing
**Target Platform**: iOS 26+ / iPadOS 26+
**Project Type**: mobile-app
**Performance Goals**: 5 ページ記事の総 enrichment 時間 ≤ 15 秒 (1 ページあたり 1.5-2 秒 fetch + 1 秒遅延 × 4 = 約 12-14 秒)。単一ページのオーバーヘッド ≤ 0.5 秒
**Constraints**:
- 同一ホスト (host) のみ追跡 (FR-005)
- HTTPS のみ (spec 002 既存)
- 最大 5 ページ (FR-006)
- ページ間 1 秒遅延 (FR-008、`Task.sleep`)
- rawHTML 連結後 2MB 上限 (FR-017)
- 各ページ 5MB 上限 (spec 002 既存)
**Scale/Scope**: 1 記事あたり最大 5 ページ × 5MB = 25MB のメモリピーク (decode 時)。1 ユーザーあたり数百記事想定、enrichment は 1 記事ずつ逐次処理 (spec 002 既存の重複抑止)

## Constitution Check

Reference: `.specify/memory/constitution.md` (v1.0.0)

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — 全ページ取得は外部 HTTP fetch (Web 記事自体の取得なので元々外部送信)。新たに送信するデータは追加 URL のみ (User-Agent / Referer は既存)。永続化先は SwiftData ローカル
- [x] **II. MVP ファースト開発** — 上限 5 ページ / 同一ホスト限定 / 1 秒固定遅延 等を MVP 範囲として明確化、動的 rate-limit 調整 / クロスドメイン許可 / ページ番号永続表示 等は将来 spec として spec.md Assumptions に分離
- [x] **III. ソースに基づいた知識生成** — 全ページ HTML が `enrichment.rawHTML` に保存され、元の記事 URL は `Article.url` で 1 ページ目を保持 (Article 1 件あたり 1 URL を維持、cascade 関係不変)
- [x] **IV. iOS の実現可能性を重視する** — URLSession / Network framework / Swift Concurrency の標準 API のみ使用。Apple Intelligence は無関係 (knowledge 抽出は spec 004 / 006)
- [x] **V. シンプルで落ち着いた UX** — BottomStatusBar に N/M 表示を追加するだけ (spec 005 / 006 既存 API 拡張)。Detail 画面の追加 UI は注記 (skipped pages の表示) のみ。プッシュ通知無し
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — 新規 `PaginationDetector` (純粋関数) / `MultiPageCrawler` (actor) を Service 層から分離。既存 `ArticleEnrichmentService.fetchAndParse` のみ修正、`URLSessionProtocol` 境界は変更しない
- [x] **VII. 日本語ファースト** — spec / plan / 文言 すべて日本語。英語サイト (rel=next の英語ページ) も検出ルール上同等扱い

### Quality Gates (二次ゲート)

- [x] **コード品質** — `PaginationDetector` は純粋関数。`MultiPageCrawler` は actor で thread safety 担保。`fatalError` 不使用。新規抽象化は spec 007 + 将来 spec 010 (動的 rate limit) で再利用見込み
- [x] **テスト** — `PaginationDetector` の検出ルール 3 段階テスト (rel=next / class=next / URL パターン)、`MultiPageCrawler` の Mock URLSessionProtocol を使った 5 シナリオテスト (3 ページ正常 / 上限 5 / 循環ループ / クロスドメイン拒否 / HTTP error 中断)、`ArticleEnrichmentService` integration test に multi-page case 追加。SwiftData は in-memory ModelContainer
- [x] **アクセシビリティ・UX 一貫性** — BottomStatusBar の N/M 表示は既存 `Localizable.xcstrings` の `status.phase.enrichment` をベースに progress suffix を追加。新規キー: `status.phase.enrichmentWithProgress`
- [x] **パフォーマンス** — 各 fetch 後の 1 秒遅延は ProgressView 更新に十分。メインスレッドブロック無し (Crawler は actor 内 async)。100 件超リスト無し

**結論**: Constitution Check 全項目 ✓ パス。Complexity Tracking 記載不要

## Project Structure

### Documentation (this feature)

```text
specs/007-multipage-fetch/
├── plan.md
├── research.md
├── data-model.md
├── contracts/
│   ├── pagination-detector.md
│   ├── multipage-crawler.md
│   └── enrichment-service.md
├── quickstart.md
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks で生成、本コマンドでは作成しない
```

### Source Code (repository root)

```text
KnowledgeTree/
├── Models/
│   └── ArticleEnrichment.swift                # 既存 + 列追加 (pageCountFetched, pageCountSkipped)
├── Services/
│   ├── ArticleEnrichmentService.swift         # 既存 + Crawler 経由に変更
│   ├── ArticleEnrichmentStore.swift           # 既存 + 新列の永続化
│   ├── PaginationDetector.swift               # 新規 (純粋関数: HTML + currentURL → [PaginationLink])
│   ├── MultiPageCrawler.swift                 # 新規 (actor: 逐次 fetch + URL set + 遅延)
│   ├── ProcessingMonitor.swift                # 既存 (spec 006 の progress API を流用)
│   └── URLSessionProtocol.swift               # 既存 (Mock 用)
├── Views/
│   ├── BottomStatusBar.swift                  # 既存 + enrichment フェーズの N/M 表示分岐
│   └── ArticleDetailView.swift                # 既存 + skippedPages 注記
└── Localization/
    └── Localizable.xcstrings                  # 新規キー (status.phase.enrichmentWithProgress / detail.pages.skippedNotice)

KnowledgeTreeTests/
├── PaginationDetectorTests.swift              # 新規
├── MultiPageCrawlerTests.swift                # 新規
└── ArticleEnrichmentServiceTests.swift        # 既存 + multi-page case
```

**Structure Decision**: spec 005/006 と同じ Models/Services/Views 配置。`PaginationDetector` は純粋関数なので Services 配下のシンプルファイル、`MultiPageCrawler` は actor として独立ファイル化 (Constitution Principle VI: 層分離)。HTTP fetch は既存 `URLSessionProtocol` を流用、Crawler が複数 fetch を統括する。

## 設計判断 (Phase 0 → Phase 1 への橋渡し)

### #1 検出ルール優先順位

`PaginationDetector` は以下順で確定したら return:
1. `<link rel="next" href="...">` (HTML 標準仕様、最高信頼度)
2. `<a rel="next" href="...">` (実用的に多い)
3. `<a class="next" ...>` または `<a class="...next..." ...>` (大文字小文字無視)
4. URL パターン推測: 現在 URL に対して `?page=N+1` / `&page=N+1` / `/page/N+1` / `/?p=N+1` を生成し、href として一致する `<a>` タグを検出

複数候補がヒットした場合は **rule 1 を最優先**、なければ rule 2、... の順で選ぶ。同 rule 内で複数 link がある場合は最初に出現したものを採用。

### #2 同一ホスト判定

`URL.host()` (iOS 16+) を使用。`www.` の有無は normalize して同一視 (例: `example.com` と `www.example.com` は同一ホスト)。スキーマは https のみ受理 (http の次ページは検出時に拒否)。

### #3 URL 正規化と重複検出

訪問済 URL set のキーは「normalized URL string」:
- スキーマ小文字化
- ホスト小文字化、`www.` prefix 削除
- query string 中の tracking params (`utm_*`, `fbclid`, `gclid` 等) を削除
- fragment (`#...`) 削除
- path の trailing `/` 統一 (削除)

`URL.normalized() -> String` 拡張を `Services/URLNormalization.swift` に新設。

### #4 1 秒遅延の実装

`Task.sleep(for: .seconds(1))` をページ間で 1 回ずつ。1 ページ目 fetch → 検出 → (next が存在) → sleep 1s → 2 ページ目 fetch → ...

総待機時間: (N-1) 秒 (5 ページなら 4 秒の遅延)。HTTP fetch 自体の 1.5-2 秒と合わせて 5 ページで ~12-14 秒。

### #5 ProcessingMonitor の N/M 表示

spec 006 で `progressIndex` / `progressTotal` を `ActiveTask` に追加済。spec 007 では:
- 1 ページ目 fetch 開始時: `monitor.start(.enrichment, articleID, title)` (progressIndex/Total なし、従来挙動)
- pagination 検出 + 2 ページ目以降が確定したら: `monitor.updateProgress(articleID, index: 1)` (1/N の N は detector の rough estimate or 5 上限)
- 各ページ完了で incremenet

注意: M (total) は 1 ページ目時点では確定しない (途中で 2 ページ目の中の `<link rel="next">` がさらに 3 ページ目を指す等、再帰的に決まる)。MVP では **fixed M = 5** で「N/5」表示し、実際に検出が止まったら N で固定。これは UX 的にやや違和感があるが、シンプルさ優先。

代替案: 「メタデータ取得中 N (1/?)」のように M を表示しない。これも採用候補だが、spec 006 の chunked と表記が乱れる。

採用: **N/M で M は最大可能数 (5)**。実際にページ N で停止したら最終的に「メタデータ取得中 (N/N)」風に出ても良い (UX は実装時に微調整)。

### #6 連結 HTML フォーマット

各ページの decode 済 HTML を以下区切りで連結:

```text
<page1 HTML>

<!-- KnowledgeTree.PageBoundary index="1" url="https://example.com/page1" -->

<page2 HTML>

<!-- KnowledgeTree.PageBoundary index="2" url="https://example.com/page2" -->

...
```

理由:
- HTML コメントは body 抽出 (spec 003) で無視される (regex が `<!-- ... -->` をマッチしない)
- 将来 spec で「どのページから来た本文か」を辿る必要が出たらコメントを parse できる
- `\n\n` で `BodyExtractor` の段落区切りロジック (`\n\n` 連結) と整合

### #7 rawHTML 2MB 上限の挙動

連結後の HTML 総文字数が `rawHTMLCacheLimit` (spec 002 既存 = 2,000,000) を超えたら:
- `enrichment.rawHTML = nil`
- `body 抽出 (spec 003)` は `enrichment.rawHTML == nil` で skip
- ユーザーは Detail 画面で「本文を抽出できませんでした」表示 (spec 005 既存)

連結 HTML を保存しないだけで Article は保存される。`pageCountFetched / pageCountSkipped` は記録される。

### #8 既存 enrichment retry / backoff との関係

spec 002 のリトライポリシー (3 回バックオフ) は **1 ページ目** に対してのみ適用。2 ページ目以降が失敗したら、それまでの結果で打ち切り (リトライしない)。理由:
- 多重リトライで遅延が膨らむ (4 ページ × 3 リトライ × 30s = 6 分)
- ユーザーは Detail 画面の再試行ボタンで全体を再実行できる (spec 005)

実装: `MultiPageCrawler.crawl` は 2 ページ目以降 1 回試行のみ、失敗したら early return。

## Complexity Tracking

> Constitution Check 全項目 ✓ のため記載不要

## 次フェーズ

1. **Phase 0** (research.md): 検出ルール優先順位のベストプラクティス / URL 正規化のセキュリティ考慮 / actor モデルの適用範囲
2. **Phase 1** (data-model + contracts + quickstart): ArticleEnrichment 列追加 / PaginationDetector / MultiPageCrawler / Service 拡張の interface contract / 5 ページ記事 + 単一ページ + 循環 + クロスドメイン + 巨大 HTML の検証手順
3. **Phase 2** (`/speckit-tasks`): 実装タスク分解

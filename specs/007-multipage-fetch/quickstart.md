# Quickstart: マルチページ記事の自動追跡 (Phase 1)

**Feature**: spec 007
**Date**: 2026-05-05

実機 (iPhone 15 Pro 以降 / M1 以降の iPad) での手動検証手順。

## 前提

- spec 001-006 が main app に取り込まれビルド成功
- App Group entitlement 有効、provisioning profile 更新済
- Wi-Fi 接続環境
- `xcodebuild test` で `KnowledgeTreeTests` 全 pass

## 検証シナリオ

### S1: 単一ページ記事の互換性 (現状動作維持)

**目的**: pagination が無い記事は spec 002 の単一ページ動作を維持する。

1. zenn.dev / qiita.com の単一ページ記事を共有保存
2. BottomStatusBar 表示:
   - 「メタデータ取得中: <タイトル>」 → 「本文抽出中」 → 「知識抽出中」
   - 進捗 N/M 表示は出ない or 「メタデータ取得中 (1/5)」 → 即「本文抽出中」遷移
3. enrichment 完了時間: spec 002 比 +0.5 秒以内
4. ExtractedKnowledge データ確認:
   - `enrichment.pageCountFetched == 1`
   - `enrichment.pageCountSkipped == 0`

**期待結果**: 既存挙動維持。pagination 検出失敗時のオーバーヘッドが最小。

---

### S2: 3 ページ連載記事のフルキャプチャ

**目的**: 既知の rel=next 持ちサイト (例: 大手 news / 技術ブログの分割記事) の全ページ取得。

1. 3 ページに分割された連載記事 (例: ZDNet Japan / マイナビニュース / Engadget) を共有保存
2. BottomStatusBar 表示遷移:
   - 「メタデータ取得中 (1/5)」 (1 ページ目完了)
   - 「メタデータ取得中 (2/5)」 (2 ページ目完了)
   - 「メタデータ取得中 (3/5)」 (3 ページ目完了)
   - 検出停止 → 「本文抽出中」遷移
3. ExtractedKnowledge データ確認:
   - `enrichment.pageCountFetched == 3`
   - `enrichment.pageCountSkipped == 0`
   - `enrichment.rawHTML` に 3 ページ分の HTML が含まれる (各ページ固有文字列で grep 確認)
   - `<!-- KnowledgeTree.PageBoundary index="2" -->` のような区切りコメントが存在
4. body 抽出 / knowledge 抽出は連結 HTML を元に動作 → 後半ページ固有の essence / keyFacts が含まれる

**期待結果**: spec 006 の chunked summarization と組み合わせて、3 ページ × 2000 文字 = 6000 文字を 6 chunk + meta-summary でフル要約。

---

### S3: 上限ぎりぎり (5 ページ記事)

**目的**: 上限到達時の挙動。

1. 5 ページ以上に分割された長い記事 (Wikipedia の長い記事 / 学術論文の解説 / IT メディアの大型特集) を共有保存
2. BottomStatusBar 進捗:
   - (1/5), (2/5), (3/5), (4/5), (5/5) と進む
3. ExtractedKnowledge データ確認:
   - `enrichment.pageCountFetched == 5`
   - `enrichment.pageCountSkipped >= 1` (実際に 6 ページ以上ある場合)

**期待結果**: 上限で打ち切られても得られた情報で完了。

---

### S4: 循環 pagination の防御

**目的**: 無限ループ防止が機能する。

実機で自然再現は難しいので、ユニットテストで担保:
```bash
xcodebuild test -only-testing:KnowledgeTreeTests/MultiPageCrawlerTests/loopDetected
```

実装の正しさを Mock URLSessionProtocol で検証:
- ページ 1 → rel=next page 2
- ページ 2 → rel=next page 1 (循環)
- 期待: pageCountFetched=2, stopReason=.loopDetected

**期待結果**: アプリが 1 記事の取得で hang しない。

---

### S5: クロスドメイン rel=next の拒否

**目的**: セキュリティ的に意図しないドメインへの自動 fetch を防ぐ。

実機で自然再現は難しいので、ユニットテストで担保:
```bash
xcodebuild test -only-testing:KnowledgeTreeTests/MultiPageCrawlerTests/crossDomainBlocked
```

ページ 1 (`example.com`) → rel=next が `attacker.com/page2` を指す → 検出時に拒否、pageCountFetched=1。

**期待結果**: ユーザーの意図しない外部ドメインへの自動 fetch が発生しない。

---

### S6: 連結 HTML 2MB 超過時の挙動

**目的**: rawHTML 上限超過で nil 保存、body 抽出 skip、Article は保存される。

1. 1 ページ 1MB クラスの巨大 HTML を持つサイト (画像インライン埋め込みされた長文記事) で 3 ページ程度のものを共有保存
2. enrichment 完了時:
   - `enrichment.rawHTML == nil`
   - `enrichment.canonicalTitle / summary / ogImageURL` は 1 ページ目から取得済
   - `enrichment.pageCountFetched >= 2`
3. body 抽出は skip (rawHTML nil なので)
4. Detail 画面で「本文を抽出できませんでした」表示
5. 「元記事を開く」ボタンは機能する

**期待結果**: ユーザー視点ではタイトル + サムネは表示できる degradation。

---

### S7: マルチページ + chunked summarization の統合

**目的**: spec 006 + spec 007 の連携。

1. 5 ページ × 2000 文字 = 10000 文字の連載記事を共有保存
2. enrichment phase: 5 ページ取得 (5/5)
3. body extraction phase: 10000 文字の連結本文抽出
4. knowledge extraction phase: 10 chunk + meta-summary を逐次処理 (chunk 進捗 1/11 〜 11/11)
5. ExtractedKnowledge データ:
   - `chunkProcessedCount == 11`
   - `chunkTotalCount == 11`
   - `skippedTailChars == 0`
6. essence / summary / keyFacts / entities が記事全体 (5 ページ分) を反映

**期待結果**: 知識管理アプリの中核体験。連載記事 1 件を 1 つの整理された知識として保存。

---

## 自動テスト

```bash
# PaginationDetector 単体
xcodebuild test -only-testing:KnowledgeTreeTests/PaginationDetectorTests

# MultiPageCrawler 単体 (Mock URLSession)
xcodebuild test -only-testing:KnowledgeTreeTests/MultiPageCrawlerTests

# Service の multi-page integration
xcodebuild test -only-testing:KnowledgeTreeTests/ArticleEnrichmentServiceTests

# 既存 spec 002/005/006 互換性 (回帰なし)
xcodebuild test -only-testing:KnowledgeTreeTests/MetadataParserTests
xcodebuild test -only-testing:KnowledgeTreeTests/SwiftDataArticleEnrichmentStoreTests
```

すべて pass で PR merge 条件。

---

## 受け入れ基準サマリ

| Spec ID | シナリオ | 期待 |
|---|---|---|
| SC-001 | S2 | 3 ページの全 HTML が rawHTML に含まれる |
| SC-002 | S3 | 5 ページ全取得、pageCountSkipped == 0 |
| SC-003 | S3 | 7 ページ記事で pageCountFetched=5, skipped >=1 |
| SC-004 | S1 | 単一ページ +0.5 秒以内 |
| SC-005 | S4 (テスト) | 循環で 2 ページ停止 |
| SC-006 | S5 (テスト) | クロスドメインで 1 ページ停止 |
| SC-007 | S2 | 5 ページ ≤ 15 秒 |
| SC-008 | S2 | 後半ページ固有 entity が含まれる |

すべて pass で spec 007 完了。

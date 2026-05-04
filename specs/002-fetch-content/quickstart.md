# Quickstart: 本文取得・メタデータエンリッチメント — 手動検証ガイド

**Feature**: spec 002 — 本文取得・メタデータエンリッチメント
**Date**: 2026-05-04

実装完了後、本ドキュメントの手順に従って **すべての user story と edge case** を端末上で検証する。検証結果を PR description に貼付し、Constitution Per-PR ゲートの一部とする。

## 前提

- spec 001 が merge 済み (Share Extension + Article 保存が動作する状態)
- iOS 26+ / iPadOS 26+ シミュレータまたは実機 (Wi-Fi / セルラー疎通あり)
- Xcode 17+
- `001-save-article` ブランチ → spec 002 用ブランチに切り替え済 (実装フェーズで作成)

## ビルド & 実行

```bash
xcodebuild -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' build
```

または Xcode で ⌘R。

## 自動テスト

```bash
xcodebuild test \
  -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0'
```

期待: `MetadataParserTests`、`ArticleEnrichmentServiceTests`、`SwiftDataArticleEnrichmentStoreTests`、既存 `SaveArticleUITests` (enrichment 表示行 assertion 含む) が全 pass。

## User Story 1: 自動 enrichment と enriched 一覧表示 (P1)

### 手順

1. シミュレータで Safari を開き、任意の記事ページ (例 `https://www.apple.com/jp/newsroom/`) を開く。
2. 共有ボタン → KnowledgeTree → 「保存しました」。
3. KnowledgeTree アプリを開き、保存直後は行に「取得中」インジケータ (微小スピナー) が表示される。**Pass: FR-007**
4. 5 秒程度待つ → 行が enriched カードに変わる: 左にサムネイル、右に canonical タイトル + description (2 行)。**Pass: SC-001 / Acceptance Scenario 1**
5. 元の Article.title (フォールバック値、URL ホスト名) ではなく、HTML の `<title>` 値が表示されていることを確認。**Pass: Acceptance Scenario 2**
6. OG image があるサイト (NewsPicks, note 等) を保存 → サムネイルが表示される。**Pass: Acceptance Scenario 3**
7. OG image がないサイト (個人ブログ等) を保存 → サムネイルなし、行高がコンパクト。**Pass: Edge Case (OG image 不在)**

### 既存記事の backfill (前提: spec 001 で保存済の Article が複数ある状態で spec 002 起動)

8. アプリを完全終了 → 再起動 → 既存 Article がバックグラウンドで順次 enrichment され、リストが順次 enriched に変わる。**Pass: Plan 設計上の決定 #1 (backfill)**

## User Story 2: 取得失敗時のフォールバック (P2)

### 機内モードでの動作

1. シミュレータの設定 → 機内モード ON。
2. Safari で記事ページを開いて → KnowledgeTree に共有 (オフラインでも保存自体は spec 001 機能で動作)。
3. KnowledgeTree を開く → 行は spec 001 最低表示 (Article.title + URL) で表示され、「未取得」アイコン (例: 雲に斜線) が付く。**Pass: FR-008 / Acceptance Scenario 1 / SC-002**
4. 機内モード OFF → 1 〜 2 分待つ → 自動 backoff 再試行で enriched 表示に変わる。**Pass: SC-005 / Acceptance Scenario 2**

### 永続失敗 (404 等)

5. ブラウザで存在しない URL (例 `https://example.com/this-does-not-exist-404`) を共有保存。
6. 数分待つ → backoff で 3 回 retry → 最終的に「取得失敗」アイコン表示。**Pass: Acceptance Scenario 3**
7. アプリ再起動後も「取得失敗」のままで、自動再試行は止まっている。**Pass: FR-009 上限**

## Edge Cases 検証

| ケース | 手順 | 期待 |
|---|---|---|
| HTTPS 証明書エラー | 自己署名 HTTPS のサイトを共有 | enrichment 失敗 (ATS で fetch ブロック)、フォールバック表示 |
| HTML 以外 (PDF/JSON) | PDF 直リンクを共有 | enrichment 失敗、フォールバック |
| 巨大 HTML (5 MB 超) | 該当サイト (まれ) | enrichment 失敗、フォールバック |
| 相対 og:image | 該当サイト | サムネイル表示成功 (絶対化される) |
| 重複保存 | spec 001 で重複拒否される URL | enrichment ジョブはキューイングされない (新規 Article がないため) |
| Share 直後にアプリ終了 | 共有 → アプリ強制終了 → 後でアプリ起動 | 起動時 backfill で enrichment が実行される |

## パフォーマンス検証

- **SC-004**: enrichment 中も一覧スクロール 60 fps を維持 (Instruments + 100 件状態で計測 → PR に添付)
- **SC-006**: 1 enrichment あたり HTTP リクエスト = 1 (Charles Proxy 等で計測、または Console.app の URLSession ログ確認)
- **SC-007**: 100 件 enriched 一覧の 60 fps スクロール

## ネットワーク監視 (privacy 確認)

Charles Proxy / Wireshark で観察し、以下を確認:

- 送信先: 保存した記事 URL のオリジンのみ (第三者ホスト = 0)
- 送信ヘッダ: `User-Agent: KnowledgeTree/1.0 (iOS)`、標準 `Accept` のみ
- 送信されないこと: Cookie / Authorization / IDFA / 他記事 URL リスト
- 第三者解析サーバー (Firebase / Mixpanel 等) への接続: 0

**Pass: Network Access Justification セクション (spec.md) と FR-003 を実装が遵守している**

## アクセシビリティ検証

- **VoiceOver**: 「取得中」「未取得」「取得失敗」アイコンが日本語で読み上げられる。
- **Dynamic Type**: enriched カードが文字サイズ最大でも layout 崩れせず (サムネイル横、テキスト下に折り返し等)。
- **Dark Mode**: enriched カード / 状態インジケータが暗背景でも視認可能。

## 検証完了の判定

すべての user story が "Pass" で、edge case が期待通り、network 監視で privacy violation が無いこと → PR を merge 可能と判定。

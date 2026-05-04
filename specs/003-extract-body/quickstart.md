# Quickstart: 本文抽出 (Reader View) — 手動検証ガイド

**Feature**: spec 003 — 本文抽出 (Reader View)
**Date**: 2026-05-04

実装完了後、本ドキュメントの手順に従って **すべての user story と edge case** を端末上で検証する。検証結果を PR description に貼付し、Constitution Per-PR ゲートの一部とする。

## 前提

- spec 001 / spec 002 が merge 済み (Share Sheet 保存 + enrichment fetch + raw HTML キャッシュが動作する状態)
- iOS 26+ / iPadOS 26+ シミュレータまたは実機
- Xcode 17+
- spec 003 用ブランチに切り替え済 (実装フェーズで作成)

## ビルド & 実行

```bash
xcodebuild -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' build
```

## 自動テスト

```bash
xcodebuild test \
  -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0'
```

期待: 既存テスト + `BodyExtractorTests` (フィクスチャ 11 ケース)、`BodyExtractionServiceTests` (8 ケース)、`SwiftDataArticleBodyStoreTests` (7 ケース) が全 pass。

## User Story 1: アプリ内 Reader View で本文を読める (P1)

### 手順

1. Safari で記事ページ (例 `https://www.apple.com/jp/newsroom/`) を共有 → KnowledgeTree。
2. アプリを開いて enrichment 完了を待つ (5 秒程度、サムネイル + canonical title 表示)。
3. その行をタップ → **アプリ内 Reader View が画面を覆う**。Safari View Controller ではないことを確認。**Pass: FR-006 / Acceptance Scenario 1**
4. 本文が読みやすい typography (大きめのフォント、広い行送り、左右に余白) で表示される。広告・nav・サイドバーは表示されない。**Pass: FR-007**
5. スクロールして最後まで読む。途中に画像領域 / 動画 / iframe が無いことを確認 (plain text only)。**Pass: FR-009**
6. toolbar の「完了」をタップ → Reader View が閉じ、一覧に戻る。**Pass: Acceptance Scenario 2**
7. OS 設定で Dynamic Type を最大に → 同記事を Reader で開く → 文字サイズが追従、layout 崩れなし。**Pass: Acceptance Scenario 3 / SC-007**
8. OS 設定を Dark Mode に → 同記事を Reader で開く → 暗背景 + 明色テキスト で読みやすい。**Pass: Acceptance Scenario 3**

## User Story 2: 抽出失敗 / 未抽出時は SVC にフォールバック (P2)

### 手順

1. JavaScript 必須サイト (例 `https://x.com/...` の個別ツイート) を共有 → KnowledgeTree。
2. enrichment 完了を待つ (rawHTML はキャッシュされるが本文は js render なので抽出失敗する可能性大)。
3. その行をタップ → **Safari View Controller が立ち上がる** (Reader View には遷移しない)。**Pass: FR-006 / Acceptance Scenario 1**
4. 短い記事 (本文 100 文字未満のページ) を保存 → 抽出は `failed` 扱い → タップ時 SVC 直行。**Pass: FR-005 / Acceptance Scenario 2**

### rawHTML が無いケース

5. 5MB 超のページ (まれ) を共有 → spec 002 が rawHTML 破棄 → spec 003 は ArticleBody を作らない → タップ時 SVC 直行。**Pass: Edge Case (rawHTML nil)**

## User Story 3: Reader View 表示中に元記事を開く (P3)

### 手順

1. Reader View で記事を表示中。
2. toolbar の「元記事を開く」(SF Symbol `safari` 想定) をタップ → SVC が Reader View の上に modal 重ねで表示される。**Pass: FR-008 / Acceptance Scenario 1**
3. SVC で元記事 (画像・動画・コメント等含む) を確認。
4. SVC の「完了」を押す → SVC が閉じ、Reader View が再び見える。**Pass: Acceptance Scenario 2**
5. Reader View の「完了」を押す → 一覧に戻る。

## Edge Cases 検証

| ケース | 手順 | 期待 |
|---|---|---|
| 抽出 pending 状態のタップ | enrichment 直後すぐタップ | SVC 直行 (Reader 表示は試みない) |
| extracting 状態のタップ | 抽出ジョブ実行中にタップ | SVC 直行 (Reader 表示は試みない) |
| 100 文字未満の結果 | 短い記事ページ | `failed` 永続化、タップ時 SVC 直行 |
| 画像中心ページ | フォトギャラリー的なページ | 抽出は失敗 (テキスト 100 文字未満)、SVC フォールバック |
| 日本語記事 | 日本語ニュースサイト | 日本語本文が抽出されて Reader 表示される |
| 既存記事 backfill | spec 002 の状態でアップグレード | 起動時に既存 Article が順次 ArticleBody を獲得 → 一覧タップ挙動が Reader に切り替わる |

## パフォーマンス検証

- **SC-001**: 1 件の enrichment 完了から ArticleBody が `succeeded` になるまで median 1 秒以内 (ストップウォッチ + 10 件サンプル測定 → PR に貼付)
- **SC-002**: 一覧タップから Reader View 表示まで 300 ms 以内 (Instruments の Time Profiler で測定)
- **SC-004**: 抽出ジョブ実行中の一覧スクロール main thread 占有 ≤ 100 ms (Instruments)
- **SC-006**: 100 件 ArticleBody 持ちの一覧 60fps スクロール (Instruments)

## ネットワーク監視 (Principle I 遵守確認)

Charles Proxy / Console.app で本 spec の動作中に観察:

- 本 spec が **新規ネットワークリクエストを発生させていないこと** を確認
- spec 002 のリクエストはあって良い (enrichment fetch)
- spec 003 単独動作 (起動時 backfill 等) では HTTPS ハンドシェイクすら発生しないこと

**Pass: Principle I を完全維持、Network Access Justification の追加は不要**

## アクセシビリティ検証

- **VoiceOver**: Reader View 内の本文段落が日本語で正しく読み上げられる、toolbar ボタン (`完了` / `元記事を開く`) が日本語で読み上げられる
- **Dynamic Type**: 文字サイズ最大でも Reader View が崩れない (左右余白で 1 行幅は適切に維持)
- **Dark Mode**: Reader View が暗背景で読みやすい

## 検証完了の判定

すべての user story が "Pass"、edge case が期待通り、network 監視で **本 spec 起因のネットワーク = 0** を確認したら、PR を merge 可能と判定。

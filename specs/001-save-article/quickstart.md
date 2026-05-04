# Quickstart: 記事保存 (Share Sheet 経由) — 手動検証ガイド

**Feature**: spec 001 — 記事保存 (Share Sheet 経由)
**Date**: 2026-05-04

実装完了後、本ドキュメントの手順に従って **すべての user story と edge case** を端末上で検証する。検証結果を PR description に貼付し、Constitution Per-PR ゲートの一部とする。

## 前提

- iOS 26+ / iPadOS 26+ シミュレータまたは実機
- Xcode 17+ (iOS 26 SDK)
- リポジトリの `001-save-article` ブランチをチェックアウト済
- 必要なら `xcodebuild -scheme KnowledgeTree clean build` でクリーンビルド

## ビルド & インストール

```bash
# シミュレータで実行
xcodebuild -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' build
# または Xcode で Run (⌘R)
```

Share Extension は app target ビルド時に自動的に bundled される。

## 自動テスト (CI で実行可能)

```bash
xcodebuild test \
  -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0'
```

期待: `ArticleSavingServiceTests`、`SwiftDataArticleStoreTests`、`SaveArticleUITests` が全 pass。

## User Story 1: 共有から保存して一覧で確認できる (P1)

### 手順

1. シミュレータで KnowledgeTree を起動 → 一覧画面が空状態 (「共有メニューから記事を追加してみよう」が表示される)。**Pass: FR-013**
2. シミュレータで Safari を開き、任意の記事ページ (例 `https://www.apple.com/jp/newsroom/`) に遷移。
3. アドレスバー右の共有ボタン → 共有シート → 「KnowledgeTree」 を選択。
4. Share Extension の表示 → 「保存しました」のような短い表示 → 自動 dismiss。**Pass: FR-001 / FR-003 / Acceptance Scenario 1**
5. KnowledgeTree アプリに切り替え → 一覧の最上段に保存した記事のタイトルと URL が表示される。**Pass: FR-004 / Acceptance Scenario 2**
6. Safari に戻り別記事を共有 → KnowledgeTree を開く → 新しい方が上にくる。**Pass: 並べ替え順 / Acceptance Scenario 3**
7. (シミュレータに Chrome をインストールして) Chrome で記事を開き → 共有 → KnowledgeTree → 保存される。**Pass: Acceptance Scenario 4**

### 重複検出 (Acceptance Scenario 5 / FR-014 / FR-015 / SC-009)

8. 既に保存済みの記事の URL を Safari からもう一度共有。
9. Share Extension が「既に保存済みです」を 1 秒以内に表示 → 自動 dismiss。**Pass: SC-009**
10. KnowledgeTree を開く → 一覧に重複行が **追加されていない** こと、既存行の savedAt が変わっていないこと (順序変化なし)。**Pass: FR-015**

## User Story 2: 元記事をブラウザで再閲覧する (P2)

### 手順

1. 一覧の任意の行をタップ → 内蔵ブラウザビュー (Safari View Controller) が画面を覆う。**Pass: FR-006 / Acceptance Scenario 1**
2. ロード時間を計測 (Stopwatch アプリ等)。タップから SVC 表示まで 300 ms 以内であることを確認。**Pass: SC-004**
3. SVC 上部の「完了」ボタンをタップ → SVC が閉じ、一覧に戻る。**Pass: Acceptance Scenario 2**

## User Story 3: 不要な記事を削除する (P3)

### 手順

1. 一覧の任意の行を左にスワイプ → 「削除」ボタンが現れる。
2. 「削除」をタップ → その行が即座に消える (確認ダイアログなし)。**Pass: FR-007 / Acceptance Scenario 1**
3. 削除アクションから視覚的に行が消えるまでが 100 ms 以内であることを確認。**Pass: SC-007**
4. アプリを完全終了 (App Switcher で上スワイプ) → 再起動 → 削除した記事が復活していないことを確認。**Pass: Acceptance Scenario 2**

## Edge Cases 検証

| ケース | 手順 | 期待 |
|---|---|---|
| URL なし共有 | メモアプリでテキストを選択 → 共有 → KnowledgeTree | 「URL が見つかりません」表示 → 自動 dismiss、一覧に追加なし |
| 非対応スキーム | `file://` や `mailto:` の URL を共有 | 「対応していない URL です」表示 → dismiss、追加なし |
| 0 件状態 | 全削除後にアプリを開く | 「共有メニューから記事を追加してみよう」と落ち着いたメッセージ |
| 長いタイトル | 100 文字超のタイトルを持つページを共有 | 一覧で 2 行打ち切り表示 |
| Title なし | OG title が無いページを共有 | 一覧の title 欄に URL ホスト名 (例 `example.com`) が表示される |

## パフォーマンス検証 (Constitution パフォーマンスゲート)

100 件超のリスト性能を測るには、Debug ビルド時に一時的に seed コードを差し込むか、`SwiftDataArticleStoreTests` に「100 件挿入後 (a) 重複チェック < 1s、(b) ソート fetch < 100ms」のテストを足す。`SC-003` (60 fps スクロール) は Instruments の SwiftUI Time Profiler で計測し、ScreenRecording を PR に添付する。

## アクセシビリティ検証 (Quality Gate)

- **VoiceOver**: 設定 → アクセシビリティ → VoiceOver を ON。一覧行を読み上げると「タイトル + URL」が日本語で正しく読まれる。
- **Dynamic Type**: 設定 → アクセシビリティ → 文字サイズを最大に → 一覧が崩れない (打ち切りで対応)。
- **Dark Mode**: 設定 → 画面表示と明るさ → ダーク。一覧行が読みやすい。

## 検証完了の判定

すべての user story の "Pass" がチェックされ、すべての edge case が期待通りの挙動をしたら、PR を merge 可能と判定する。

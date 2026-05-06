# Feature Specification: Safari Web Extension (閲覧ページ自動検知 + 取り込み)

**Feature Branch**: `019-chrome-app-intent` (spec 019 と同ブランチで実装)
**Created**: 2026-05-06
**Status**: 🔧 実装完了 (Build SUCCEEDED、ユーザー実機検証待ち)

## なぜ (Why)

Safari でページ閲覧中、Share Sheet (3 タップ) より高速な「ツールバー 1 タップで保存」を実現したい。Constitution Principle IV では「Safari Extension は将来 / オプション」、本 spec で MVP 入り。

ユーザー体験変化:
- **Before**: Safari → 共有 → 知積アプリ → 保存 (3 タップ + アプリ切替)
- **After**: Safari ツールバーの知積アイコン → タップ → silent 保存 (1 タップ)

加えて、ホワイトリスト設定で「特定ドメイン (zenn.dev / qiita.com 等) 訪問時に自動取り込み」も可能に。

## ゴール

- Safari Web Extension target 新設、ツールバーに知積アイコン
- アイコンタップ → 現在ページの URL + title + og:image を抽出 → ArticleSavingActor 経由で保存
- spec 019 SettingsView の「外部連携」セクションに「Safari 拡張」エントリ追加
- ON/OFF + ホワイトリストドメイン設定 (App Group UserDefaults 共有)
- Apple-quiet 路線継続 (silent 保存、通知ゼロ)

## 非ゴール

- macOS Safari 対応 → 将来 spec (Constitution IV macOS は対象外)
- Edge / Chrome / Firefox の Safari Web Extensions 互換ブラウザ → 将来 spec
- ページ全文の自動 fetch (Safari Extension はページ DOM にアクセス可能だが、本 spec MVP では title + url + og:image のみ)
- 自動取り込み (ホワイトリスト) 詳細実装 → 将来 spec、本 spec は手動タップ + 設定枠のみ
- iCloud 同期で全デバイス共有 → 別 spec

## ユーザストーリー (P1: US1-US3 / P2: US4-US5)

### US1 (P1) — Safari ツールバーに知積アイコン表示

ユーザーが Safari Extension を有効化 → ツールバーに知積アイコンが表示される。

### US2 (P1) — 1 タップで現在ページを保存

知積アイコンタップ → 現在の URL + title + og:image を抽出 → ArticleSavingActor 経由で SwiftData 保存。silent 完了 (Safari の「拡張機能が実行されました」通知のみ、独自 UI なし)。

### US3 (P1) — SettingsView に「Safari 拡張」エントリ

spec 019 で追加した SettingsView の「外部連携」セクションに「Safari 拡張」エントリ追加。タップで Safari Extension Setup Guide (Setup の手順 + iOS 設定 → Safari → 拡張機能 への deeplink)。

### US4 (P2) — 重複 URL の silent skip

既存 URL 渡された場合、ArticleSavingActor 経由で silent skip (spec 019 と同パターン)。

### US5 (P2) — Extension 設定 UI

設定画面で Safari Extension の ON/OFF (情報表示のみ、実際の有効化は iOS 設定アプリ) + ホワイトリストドメイン管理 (将来 spec で自動取り込み実装時に活用)。

## 機能要件 (抜粋)

- **FR-001**: 新 target `KnowledgeTreeSafariExtension` を Xcode に追加 (Safari Web Extension テンプレート)
- **FR-002**: ツールバーボタンの SF Symbol `square.and.arrow.down`、actionBlue
- **FR-003**: ボタンタップで content script 経由でページ情報抽出 (`document.title` / `document.querySelector('meta[property="og:image"]')` / `window.location.href`)
- **FR-004**: native message 経由で App Group UserDefaults に「保存リクエスト」を書き込む or 直接 ArticleSavingActor.shared.save(url:title:) を呼ぶ
- **FR-005**: spec 019 SettingsView を改修、「Safari 拡張」NavigationLink を「外部連携」セクションに追加
- **FR-006**: SafariSetupView (新規) で 3 ステップガイド + 「iOS 設定アプリを開く」deeplink (`prefs:root=SAFARI&path=WEB_EXTENSIONS`)
- **FR-007**: silent 完了、独自 UI 通知なし (Safari の標準「拡張機能が実行されました」のみ)
- **FR-008**: 重複 URL は silent skip (spec 019 ArticleSavingActor 経由)

## 成功基準

- SC-001: iOS 設定 → Safari → 拡張機能で「知積」を ON → Safari ツールバーに知積アイコン表示
- SC-002: アイコンタップ → 1 秒以内に保存完了、ライブラリタブで 60 秒以内に表示
- SC-003: 既存 URL → silent skip、Article 数増えず
- SC-004: SettingsView「Safari 拡張」エントリタップ → SafariSetupView 表示
- SC-005: 「iOS 設定アプリを開く」ボタン → Settings.app の Safari 拡張機能画面が起動

## 依存・前提

- spec 019 (App Intents + SettingsView + ArticleSavingActor) merged 済 (本 spec で SettingsView 拡張、Actor 再利用)
- iOS 16+ Safari Web Extension framework
- App Group ModelContainer 共有 (Share Extension / spec 019 と同パターン)

## アサンプション

- Safari Web Extension JS → Swift 経由の保存は `browser.runtime.sendNativeMessage` で実現
- og:image / title 取得は content script で `document` API 経由 (DOM パース)
- Apple Intelligence 不要 (URL + メタ取得のみ)
- spec 002/003 backfill が後追いで本文 / 詳細 fetch

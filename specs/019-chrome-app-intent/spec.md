# Feature Specification: Chrome 連携 (App Intents + iOS Shortcut + 設定画面 Setup Guide)

**Feature Branch**: `019-chrome-app-intent`
**Created**: 2026-05-06
**Status**: Draft

## なぜ (Why)

ユーザー要望:
> Chrome から記事を保存するのに毎回 Share Sheet タップが面倒。Chrome のタブを開くと自動送信したい。

現状の問題:
- iPhone の Chrome で記事を読む → 知積に保存するには Share Sheet (3 タップ: 共有 → 知積アプリ → 保存)
- 毎日複数記事を保存するユーザーには摩擦が大きい
- iOS の制約上、Chrome 自身に「常に知積に送る」設定は追加不可 (Apple は third-party ブラウザに Default Share の上書きを許可しない)

解決アプローチ:
- iOS 16+ App Intents (`AppIntent`) で「URL を 知積に保存」アクションを定義
- AppShortcutsProvider で Shortcuts.app に **自動登録** (ユーザーが手動アクション追加不要)
- アプリ内 SettingsView (新規) で「Chrome から自動保存」セットアップガイドを提供
- Personal Automation 「Chrome を開く時 → 知積に保存」をユーザーが 1 度だけ設定 → 自動化

ユーザー体験の変化:
- **Before**: Chrome → 共有 → 知積アプリ → 保存 (3 タップ + アプリ切替)
- **After**: Chrome を開く → 自動で知積に保存 (0 タップ、Personal Automation 経由)

Constitution Principle IV では Shortcuts は「将来 / オプション」と位置づけられていたが、本 spec で MVP 入り。

## ゴール

- App Intent「知積に保存」(URL + optional title) を定義、Shortcuts.app に自動登録
- Personal Automation で「Chrome 起動時に自動保存」を実現
- 既存記事との重複は silently skip (Apple-quiet)
- Apple Intelligence 不可端末でも動作 (App Intent 経路は AI 不要)
- アプリ内 SettingsView (AI ブレインタブ右上の歯車) に Setup Guide 配置
- Setup Guide で Shortcuts.app deeplink + ステップ説明
- 通知 / バッジ / トースト 全廃継続 (constitution V)

## 非ゴール

- Safari Web Extension → spec 020 / Sprint 2 後半
- Edge / Brave / Arc 対応 → 将来 spec
- App Intent 「最近の記事を取得」「タグで検索」 → 将来 spec
- Setup Guide のステップ動画 / GIF → 将来 spec
- Siri 音声起動「Hey Siri、知積に保存」→ AppShortcutsProvider phrases で副次的に有効化、本 spec の主目的ではない
- Lock Screen Widget / Home Screen Widget → 将来 spec
- Settings の他項目 (テーマ / 通知 / バックアップ / エクスポート) → 将来 spec、本 spec は「Chrome 連携」セクションのみ
- App Intent 完了後の通知 / dialog → constitution V「不安喚起 UI 禁止」遵守、silent return

## ユーザストーリー

### US1 (P1) — Shortcuts.app に「知積に保存」が自動登録

**As a** アプリインストール直後のユーザー
**I want** iOS Shortcuts アプリを開けば「知積に保存」アクションが既に使える
**So that** 手動で「アクションを検索」する手間なく、即座に Shortcut を作成できる

#### 受け入れ基準

- アプリインストール後、Shortcuts アプリを起動 → アクション一覧 (or 検索) で「知積に保存」を確認
- アクションには icon (`square.and.arrow.down`) + 簡潔説明
- 検索キーワード: 「知積」「KnowledgeTree」「Save」のいずれかでヒット
- パラメータ: URL (必須) + タイトル (任意)

### US2 (P1) — Shortcut から URL を保存

**As a** Shortcut で「知積に保存」を実行したユーザー
**I want** URL を渡すと数秒以内に知積アプリに記事として保存される
**So that** Chrome / Safari / 他アプリ問わず URL を素早く保存できる

#### 受け入れ基準

- Shortcuts.app から手動実行 (テスト用): URL 入力 → 「実行」 → 数秒以内に保存完了
- Shortcut 完了時に dialog やバナー表示なし (silent)
- 保存後、ライブラリタブを開くと新記事が savedAt desc top に表示される (60 秒以内、AI 抽出は背景で進行)
- 既存 URL と同じ URL を渡した場合、silently skip (重複検出、既存記事 が touched されない)

### US3 (P1) — Personal Automation で Chrome 起動時に自動保存

**As a** Chrome で記事を読むユーザー
**I want** Chrome を開いた時点で現在のタブの URL が自動で知積に保存される
**So that** Share Sheet タップを省略でき、保存忘れも防げる

#### 受け入れ基準

- 初回セットアップ (1 度だけ):
  - Shortcuts アプリ → 自動化 → 個人用オートメーション → アプリ → Chrome を選択 → 開く
  - アクション追加 → 「知積に保存」
  - 「Chrome の現在の URL」(Shortcuts 標準アクション or Chrome x-callback-url) → 「知積に保存」のチェーン
- 設定後: Chrome を開く → URL が知積に自動保存される (silent)
- iOS の自動化動作の確認: 「実行前に通知」をオフにしておくと完全 silent

### US4 (P1) — アプリ内 SettingsView で Setup Guide

**As a** Chrome 自動化を設定したいが iOS Shortcuts に詳しくないユーザー
**I want** アプリ内に分かりやすい設定ガイドがある
**So that** ステップを見ながら数分で Personal Automation を作成できる

#### 受け入れ基準

- AI ブレインタブの右上 NavigationBar に歯車アイコン (`gearshape`)
- タップ → SettingsView (NavigationStack push)
- SettingsView は Form 形式、「外部連携」セクション内に「Chrome から自動保存」エントリ
- セットアップ完了済の場合は entry に checkmark (`checkmark.circle.fill`、actionBlue)
- エントリタップ → ChromeShortcutSetupView (詳細画面)
- ChromeShortcutSetupView の構成:
  - 説明文「以下の手順で Chrome を開いた時に自動保存できます」
  - Step 1 カード: 「Shortcuts アプリを開く」+ 「Shortcuts アプリを開く」ボタン (deeplink `shortcuts://`)
  - Step 2 カード: 「自動化を作成」(静的テキスト)
  - Step 3 カード: 「アクションを追加」(静的テキスト)
  - 「セットアップ完了」ボタン → UserDefaults flag を立てる
  - 「もう一度見る」リンク (flag が true の時、再表示用)

### US5 (P2) — Apple Intelligence 不可端末での動作

**As a** Apple Intelligence 非対応端末 (Simulator / 古い iPhone) のユーザー
**I want** App Intent 経路は Apple Intelligence に依存せず動作する
**So that** どの端末でも Shortcut で記事保存できる

#### 受け入れ基準

- App Intent の実装は Foundation Models を使わない (URL 受信 → SwiftData 保存のみ)
- Apple Intelligence 不可端末でも保存自体は完了
- 本文 / OG メタ取得は既存 spec 002/003 backfill が後追い (ネットワーク経由)
- 保存後の AI 抽出は spec 015 fallback で対応

### Edge Cases

- **App Intent 実行時にアプリが完全終了している**: iOS が App Intent target を起動して perform() を実行、終了後 background で残る (constitution IV iOS 制約準拠)
- **同 URL を異なるタイトルで複数 Shortcut 実行**: 重複検出で silently skip、最初のタイトルが保持される
- **無効な URL (例: `javascript:`)**: ArticleSavingService の既存 URL バリデーションで弾く、silently skip
- **Chrome がインストールされていない端末で Personal Automation 設定**: Shortcuts アプリの自動化作成画面で Chrome が表示されない (iOS の制約)、ユーザーは Chrome をインストールする必要あり
- **Personal Automation の「実行前に通知」が ON**: ユーザーが毎回承認タップする必要、Apple-quiet には反する → Setup Guide で「OFF にする」を案内
- **Shortcuts.app deeplink 失敗 (古い iOS)**: iOS 16+ では確実に動作、それ以下は Constitution IV で minimum バージョン 26.0+ なので問題なし
- **App Intent 実行中にデバイスがオフライン**: URL のみ保存、本文 fetch は次回起動時 backfill で補完
- **既存 SwiftData container と App Intent の競合**: App Group 共有で両者が同 container を使う、SwiftData の concurrent write は actor 経由で安全
- **AppShortcutsProvider が phrases を Siri 統合**: 「Hey Siri、知積に保存」が動作する場合あり (副次効果)、ただし URL 受け渡しが Siri 経由で困難なので主用途ではない
- **Setup Guide で「セットアップ完了」を押した後に再度設定し直したい**: 「もう一度見る」リンクで再表示、flag を false に戻す

## 機能要件

### 1. App Intent: SaveURLToKnowledgeTreeIntent

- **FR-001**: AppIntent struct を `KnowledgeTree/AppIntents/SaveURLToKnowledgeTreeIntent.swift` に定義
- **FR-002**: title `LocalizedStringResource = "知積に保存"`、description `"URL を 知積に保存します"`
- **FR-003**: `openAppWhenRun: Bool = false` でバックグラウンド完了 (アプリ起動しない)
- **FR-004**: パラメータ:
  - `url: URL` (必須、`@Parameter(title: "URL")`)
  - `title: String?` (任意、`@Parameter(title: "タイトル", default: nil)`)
- **FR-005**: `perform() async throws -> some IntentResult` 内で URL を SwiftData に保存
- **FR-006**: 保存は ArticleSavingActor 経由 (App Intent target / main app 双方からアクセス可能)
- **FR-007**: 重複 URL は silently skip (`silently return .result()`)
- **FR-008**: 無効 URL (空 / scheme なし / javascript:) は silently skip
- **FR-009**: 保存後の dialog 表示なし、`return .result()` のみ

### 2. AppShortcutsProvider: KnowledgeTreeShortcuts

- **FR-010**: `AppShortcutsProvider` を実装、`appShortcuts` static プロパティを定義
- **FR-011**: `AppShortcut(intent: SaveURLToKnowledgeTreeIntent(), phrases: ["知積に保存", "Save to ..."], shortTitle: "保存", systemImageName: "square.and.arrow.down")`
- **FR-012**: phrases は最低 2 つ (日本語 + 英語)、`\(.applicationName)` placeholder で「KnowledgeTree」を埋め込み
- **FR-013**: AppShortcutsProvider のインストール時自動登録を確認 (iOS 16+)

### 3. ArticleSavingActor (App Intent 用)

- **FR-014**: `KnowledgeTree/Services/ArticleSavingActor.swift` を新規作成、`actor ArticleSavingActor`
- **FR-015**: `ArticleSavingActor.shared` で singleton
- **FR-016**: `save(url: String, title: String) async throws` メソッド
- **FR-017**: 内部で `ModelContainer(for: SharedSchema.all, configurations: [SharedSchema.sharedConfiguration()])` を作成、App Group 共有 SwiftData にアクセス
- **FR-018**: 重複検出ロジックは spec 001 ArticleSavingService と同じ (`url` 完全一致)
- **FR-019**: 新規記事は `Article(url:, title:, savedAt:)` で insert + `try context.save()`

### 4. SettingsView (新規)

- **FR-020**: `KnowledgeTree/Views/SettingsView.swift` を新規作成
- **FR-021**: Form 形式、「外部連携」セクションに「Chrome から自動保存」エントリ
- **FR-022**: NavigationLink で `ChromeShortcutSetupView` へ遷移
- **FR-023**: `@AppStorage("settings.shortcutSetupCompleted") setupCompleted: Bool` を読み取り
- **FR-024**: `setupCompleted == true` で エントリの右側に checkmark icon (actionBlue)
- **FR-025**: navigationTitle は "settings.title" (= 「設定」)

### 5. ChromeShortcutSetupView (新規)

- **FR-026**: `KnowledgeTree/Views/ChromeShortcutSetupView.swift` を新規作成
- **FR-027**: 3 つの Step Card (番号 + タイトル + 説明) を縦並び
- **FR-028**: Step 1 カード内に「Shortcuts アプリを開く」ボタン
- **FR-029**: ボタンタップで `UIApplication.shared.open(URL(string: "shortcuts://")!)` を実行
- **FR-030**: 「セットアップ完了」ボタン → `setupCompleted = true`
- **FR-031**: setupCompleted == true で「もう一度見る」リンク表示、タップで `setupCompleted = false`
- **FR-032**: navigationTitle は "settings.chromeSetup.title" (= 「Chrome 連携」)
- **FR-033**: 全文言は Localizable.xcstrings 経由

### 6. AI ブレインタブ右上の歯車

- **FR-034**: `AIBrainView.swift` の NavigationStack に `.toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink(value: SettingsDestination()) { Image(systemName: "gearshape") } } }` を追加
- **FR-035**: SettingsDestination Hashable struct を定義 (空 struct でも可)
- **FR-036**: `.navigationDestination(for: SettingsDestination.self) { _ in SettingsView() }` を追加
- **FR-037**: 歯車 button に accessibilityIdentifier "settings.button"

### 7. Localizable.xcstrings

- **FR-038**: 新規 12 文言追加 (settings.title / settings.chromeSetup.entry / settings.chromeSetup.title / settings.chromeSetup.description / settings.chromeSetup.step1.title / settings.chromeSetup.step1.description / settings.chromeSetup.openShortcutsButton / settings.chromeSetup.step2.title / settings.chromeSetup.step2.description / settings.chromeSetup.step3.title / settings.chromeSetup.step3.description / settings.chromeSetup.completeButton / settings.chromeSetup.resetLink)、日本語 only

### 8. ストレスゼロ + Apple-quiet (DESIGN.md 準拠継続)

- **FR-039**: 単一 accent rule: actionBlue 1 色 (Setup ボタン / checkmark icon 含む)
- **FR-040**: gradient / shadow / 多色 phase tint 全廃継続
- **FR-041**: App Intent 完了は silent (dialog なし)
- **FR-042**: 通知 / バッジ / トースト 全廃 (constitution V)

### 9. 既存挙動の保持

- **FR-043**: ライブラリタブ / 知識 Clip タブ / AI ブレインタブのコア機能は完全保持
- **FR-044**: spec 005 RefreshTrigger / NotificationCenter / scenePhase live update メカニズム維持
- **FR-045**: 既存 Share Sheet (KnowledgeTreeShareExtension) は完全保持

### 10. テスト

- **FR-046**: SaveURLToKnowledgeTreeIntentTests (3-5 ケース)
  - 正常: URL 受信 → 保存される
  - 重複: 既存 URL → silently skip
  - 無効 URL: javascript: → silently skip
  - title 渡し: title が article.title に反映
- **FR-047**: ArticleSavingActor の actor isolation テスト
- **FR-048**: 既存 unit test 全回帰 PASS (110+ ケース)

## 主要エンティティ

### 既存 @Model 再利用

- `Article` (spec 001 等で定義済) を再利用、改修なし

### 新規 transient struct

- `SettingsDestination`: NavigationStack の `.navigationDestination(for:)` 用 (空 Hashable struct)
- `SaveURLToKnowledgeTreeIntent`: AppIntent struct (永続化なし、iOS Shortcuts 経由で受信)

### 新規 service / actor

- `ArticleSavingActor`: App Intent → SwiftData 保存仲介

### 新規 view

- `SettingsView`: 設定画面 root
- `ChromeShortcutSetupView`: Chrome 連携 Setup Guide

### 改修

| File | 改修内容 |
|---|---|
| `AIBrainView.swift` | 右上 toolbar に歯車 + .navigationDestination(SettingsDestination) 追加 |
| `Localization/Localizable.xcstrings` | 12 文言追加 |
| `KnowledgeTree.entitlements` | App Group 既存設定確認、変更なし |
| `KnowledgeTree.xcodeproj/project.pbxproj` | AppIntents/ ディレクトリ追加 (PBXFileSystemSynchronizedRootGroup で自動取り込み想定) |

## 成功基準 (Success Criteria)

- **SC-001**: アプリインストール後、Shortcuts.app に「知積に保存」アクションが自動登録される (検索キーワード「知積」「Save」でヒット)
- **SC-002**: Shortcuts.app から「知積に保存」を手動実行 → 5 秒以内に保存完了、ライブラリタブで 60 秒以内に表示
- **SC-003**: 既存記事と同 URL を渡す → silently skip、article は increment されない
- **SC-004**: Personal Automation 「Chrome 起動時 → 知積に保存」を設定 → Chrome 起動で自動保存トリガー
- **SC-005**: 既存 spec 002/003 backfill により OG メタ + 本文取得完了 (60 秒以内、Apple Intelligence あれば AI 抽出も)
- **SC-006**: AI ブレインタブ右上の歯車タップ → SettingsView 遷移 (≤300ms)
- **SC-007**: SettingsView の「Chrome から自動保存」エントリ → ChromeShortcutSetupView 遷移
- **SC-008**: ChromeShortcutSetupView の「Shortcuts アプリを開く」ボタン → Shortcuts.app deeplink 起動成功
- **SC-009**: 「セットアップ完了」ボタン → flag set、戻ると entry に checkmark 表示
- **SC-010**: 「もう一度見る」リンクで flag リセット可能
- **SC-011**: Apple Intelligence 不可端末でも App Intent 保存自体は完了 (AI 抽出は fallback で対応)
- **SC-012**: 既存ライブラリタブ / 知識 Clip タブ / AI ブレインタブが完全保持 (回帰なし)、既存 unit test 110+ ケース全 PASS

## 依存・前提

- spec 001-018 までの全機能稼働済 (現在 main = `9c41d60`)
- iOS 26+ / iPadOS 26+ (App Intents iOS 16+ で動作可能、Personal Automation iOS 17+)
- 既存 SwiftData schema 完全保持 (新 @Model なし)
- App Group 設定既存 (Share Extension で利用済)
- Chrome iOS の x-callback-url 仕様調査 (research.md で詳細)
- AppShortcutsProvider 自動登録動作確認 (research.md で詳細)

## アサンプション

- **App Intent の SwiftData アクセス**: App Group ModelContainer 経由で main app と App Intent の双方が同 store にアクセス可能 (spec 001 Share Extension パターン同様)
- **AppShortcutsProvider 自動登録**: iOS 16+ の確立 API、コード追加だけで Shortcuts.app に自動登録される
- **Personal Automation の Chrome 選択**: iOS Shortcuts.app の「アプリを開く」トリガーで Google Chrome (`com.google.chrome.ios`) が選択肢に表示される (要検証、研究結果次第で UX が変わる可能性あり)
- **Chrome x-callback-url の「現在のタブ」取得**: 実装難易度高、MVP では「Shortcut で URL 入力」or 「クリップボードから取得」で代替可能性あり
- **「知積に保存」の Spotlight 統合**: AppShortcutsProvider が自動で Spotlight 検索結果にも露出 (副次効果)
- **silent 完了**: App Intent の `return .result()` だけでは iOS が dialog を出す可能性あり、`opensIntent: false` 等のフラグで抑制 (要検証)
- **App Intent target の必要性**: 通常は main app に同梱で OK、`@AppIntent` macro が自動 expose

## ロールアウト

- ユーザーへの破壊的変更:
  - AI ブレインタブ右上に歯車追加 (UX 変更、機能損失なし)
  - Shortcuts.app に新アクション登録 (副次効果、ユーザーが意識しなくても安全)
- 既存データ完全保持
- スキーマ migration なし

## 非機能

- **パフォーマンス**:
  - App Intent 実行 ≤5 秒 (URL 受信 → SwiftData 保存)
  - Setup Guide 遷移 ≤300ms
  - Shortcuts.app deeplink 起動 ≤1 秒
- **メモリ**: ArticleSavingActor は singleton、ModelContainer は lazy 生成
- **アクセシビリティ**: 全 interactive 要素に accessibilityLabel / Hint、Dynamic Type 互換、VoiceOver 対応
- **Dark Mode**: spec 017 の DS.Color adaptive 経由で自動対応
- **ローカライゼーション**: 全 UI 文言 Localizable.xcstrings 経由、AppShortcutsProvider phrases も日本語 + 英語

## オープン質問

なし (確定済 Q&A 10 問 + Q10-D 改善案で全方針確定)。

将来 spec 候補:
- App Intent 「最近の記事を取得」「タグで検索」 → spec 020+ 候補
- Setup Guide のステップ動画 / GIF / スクリーンショット → 別 spec
- Lock Screen Widget / Home Screen Widget → 別 spec
- Settings の他項目 (テーマ / 通知 / バックアップ / エクスポート) → spec 034 候補
- 「Hey Siri、知積に保存」音声起動の本格対応 → 別 spec
- Edge / Brave / Arc 等他ブラウザ対応 → 別 spec
- Safari Web Extension → spec 020 / Sprint 2 後半

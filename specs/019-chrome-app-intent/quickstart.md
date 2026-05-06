# Quickstart: spec 019 実機検証シナリオ

実機 (iPhone 15 Pro 以降 / iPad mini A17 Pro 以降) で実施。spec 019 実装完了後に以下 10 シナリオで検証。

## 前提

- spec 014-018 main マージ済 (`9c41d60`)、spec 019 実装完了
- 実機に最新ビルドをインストール済
- iOS 17+ (Personal Automation 対応)
- Chrome iOS アプリインストール済 (テスト用)

## SC-001: AppShortcutsProvider 自動登録

**手順**:
1. アプリインストール (or 起動)
2. ホーム → Shortcuts.app (純正) を開く
3. 「Apps」セクション or 検索バーで「知積」を入力

**期待結果**:
- ✅ Shortcuts.app の Apps 一覧に「知積」(or KnowledgeTree) が表示される
- ✅ アプリをタップ → 「知積に保存」アクションが表示される
- ✅ アクションには SF Symbol `square.and.arrow.down` アイコン
- ✅ Spotlight 検索 (ホーム画面下スワイプ) で「知積」入力 → 「知積に保存」候補表示

## SC-002: Shortcuts.app からの手動実行

**手順**:
1. Shortcuts.app で新規 Shortcut 作成
2. 「アクション追加」→ 検索で「知積」→「知積に保存」を追加
3. URL に「https://example.com」を入力
4. 「実行」ボタンタップ
5. 知積アプリのライブラリタブを開く

**期待結果**:
- ✅ Shortcut 実行が 5 秒以内に完了
- ✅ Shortcuts.app に dialog やバナー表示なし (silent)
- ✅ 60 秒以内にライブラリタブで新記事「example.com」表示
- ✅ savedAt は現在時刻 + 「今日 HH:mm」形式 (spec 016 SavedAtFormatter)
- ✅ 既存 spec 002/003 backfill により OG メタ + 本文取得が背景で進行

## SC-003: 重複 URL の silent skip

**手順**:
1. SC-002 で保存した URL「https://example.com」を再度 Shortcut で渡す
2. 知積アプリのライブラリタブを確認

**期待結果**:
- ✅ Shortcut 実行は成功 (エラー表示なし)
- ✅ ライブラリタブに記事が増えない (重複検出で silent skip)
- ✅ 既存記事の savedAt が変わらない (touch されない)

## SC-004: 無効 URL の silent skip

**手順**:
1. Shortcuts.app で「知積に保存」アクション
2. URL に「javascript:alert(1)」を入力 (実際は URL バインドで弾かれるかも、必要なら "abc:def" 等)
3. 実行

**期待結果**:
- ✅ Shortcut 実行成功 (silent)
- ✅ ライブラリタブに記事が増えない (scheme チェックで silent skip)

## SC-005: Personal Automation で Chrome 起動時自動保存

**手順** (spec の核心、技術的に動くか実機検証):
1. Shortcuts.app → 自動化タブ → 「+」→「個人用オートメーション」
2. 「アプリ」→ Chrome を選択 → 「開く」を選択
3. アクション追加 → 「知積に保存」を選択
4. URL を「Chrome の現在の URL」に設定 (or テスト用に固定 URL「https://wikipedia.org」)
5. 「実行前に通知」を OFF にする
6. 自動化を保存
7. ホーム → Chrome を起動

**期待結果**:
- ✅ Chrome 起動時に自動化が発火、知積に保存が silent 実行される
- ✅ 知積アプリのライブラリタブで新記事が 60 秒以内に表示
- ⚠️ Chrome の現在の URL 取得が iOS Shortcuts で動くか実機確認 (動かなければ固定 URL でテスト、将来 spec で改善)

## SC-006: AI ブレインタブ右上の歯車

**手順**:
1. AI ブレインタブを開く
2. NavigationBar の右上を確認

**期待結果**:
- ✅ 歯車アイコン (`gearshape`) が右上に表示される (actionBlue 色)
- ✅ accessibilityIdentifier "settings.button" で UI test 可能
- ✅ タップで SettingsView へ push 遷移 (≤300ms)

## SC-007: SettingsView の「Chrome から自動保存」エントリ

**手順**:
1. SettingsView を開く
2. 「外部連携」セクションを確認
3. 「Chrome から自動保存」エントリをタップ

**期待結果**:
- ✅ Form 形式で iOS 設定アプリ風 UX
- ✅ Section ヘッダ「外部連携」表示
- ✅ NavigationLink エントリに safari icon + 「Chrome から自動保存」テキスト
- ✅ 初回は右側に checkmark なし (setupCompleted = false)
- ✅ タップで ChromeShortcutSetupView へ push 遷移

## SC-008: ChromeShortcutSetupView の Step Card

**手順**:
1. ChromeShortcutSetupView を開く
2. 各 Step Card の内容を確認

**期待結果**:
- ✅ 説明文「以下の手順で Chrome を開いた時に自動保存できます」
- ✅ Step 1 カード: 「Shortcuts アプリを開く」ボタン付き (actionBlue)
- ✅ Step 2 カード: 「自動化を作成」(静的テキスト + 「実行前に通知 OFF」案内)
- ✅ Step 3 カード: 「アクションを追加」(静的テキスト)
- ✅ Step Number Circle は actionBlue + white text
- ✅ Card 全体は dsCardBackground、Dark Mode 自動対応

## SC-009: 「Shortcuts アプリを開く」ボタン deeplink

**手順**:
1. ChromeShortcutSetupView で「Shortcuts アプリを開く」ボタンをタップ
2. 結果を確認

**期待結果**:
- ✅ 1 秒以内に Shortcuts.app が起動
- ✅ Shortcuts.app の root view (Shortcuts 一覧) が表示される
- ✅ 知積アプリには戻らず、Shortcuts.app で操作継続可能

## SC-010: 「セットアップ完了」ボタン + リセット

**手順**:
1. ChromeShortcutSetupView で「セットアップ完了」ボタンをタップ
2. 戻る → SettingsView に戻る
3. 「Chrome から自動保存」エントリの右側を確認
4. もう一度 ChromeShortcutSetupView を開く
5. 「もう一度見る」リンクをタップ
6. 戻る → SettingsView の checkmark を確認

**期待結果**:
- ✅ ボタンタップで setupCompleted = true、UserDefaults に永続化
- ✅ SettingsView に戻ると entry 右側に checkmark (actionBlue)
- ✅ 再度 ChromeShortcutSetupView を開くと「もう一度見る」リンク表示 (Complete ボタン非表示)
- ✅ 「もう一度見る」タップで setupCompleted = false、Complete ボタンに戻る
- ✅ SettingsView に戻ると checkmark 消える

## SC-011 (補): Apple Intelligence 不可端末での動作 (US5)

**手順**:
1. Simulator または Apple Intelligence 不可設定で起動
2. SC-002 と同じ手順で Shortcut 実行

**期待結果**:
- ✅ App Intent 経由の保存自体は完了 (AI 不要)
- ✅ ライブラリタブに記事表示
- ⚠️ AI 抽出は Fallback (spec 015) 経由で簡易処理 → 知識 Clip タブに反映確認

## SC-012 (補): 既存タブ完全保持 (回帰確認)

**手順**:
1. ライブラリタブ: 検索 / Tag 一覧 / ArticleRow タップ → Detail / 関連記事
2. 知識 Clip タブ: Category 別カード / 詳細画面 / pull-to-refresh
3. AI ブレインタブ: Stats Row / Insight Card / Category List → CategoryFilteredListView (spec 016 B1 修正)
4. ArticleDetailView: 本文 DisclosureGroup 折りたたみ

**期待結果**:
- ✅ spec 018 までと完全一致 (回帰なし)
- ✅ 既存 unit test 110+ ケース全 PASS

## トラブルシュート

| 症状 | 対処 |
|---|---|
| Shortcuts.app に「知積に保存」が表示されない | アプリを再インストール、iOS を再起動。AppShortcutsProvider 自動登録は数分かかる場合あり |
| Personal Automation で Chrome が選べない | iOS バージョン確認 (iOS 17+ 必須)、Chrome iOS の最新版インストール |
| Chrome の現在の URL が取得できない | iOS Shortcuts の制約、固定 URL or 「最後にコピーされた URL」アクション fallback |
| 「実行前に通知」が出続ける | Shortcuts.app の自動化 → 編集 → 「実行前に通知」を OFF |
| App Intent 実行で「失敗」表示 | ModelContainer 作成失敗 (ストレージ満杯等)、稀ケース |
| ChromeShortcutSetupView の Shortcuts.app deeplink 動かない | iOS バージョン確認、`shortcuts://` URL scheme は iOS 13+ 標準 |

## 検証完了チェック

```
□ SC-001: AppShortcutsProvider 自動登録
□ SC-002: 手動実行 → 保存
□ SC-003: 重複 silent skip
□ SC-004: 無効 URL silent skip
□ SC-005: Personal Automation 自動保存 (技術検証)
□ SC-006: 歯車 → SettingsView 遷移
□ SC-007: 「Chrome から自動保存」エントリ
□ SC-008: ChromeShortcutSetupView Step Card
□ SC-009: 「Shortcuts アプリを開く」deeplink
□ SC-010: 「セットアップ完了」+ リセット
□ SC-011: Apple Intelligence 不可端末動作
□ SC-012: 既存タブ完全保持
```

全 ✅ で spec 019 実機検証完了。⚠️ 部分は技術的不安要素 (Chrome 連携の自動 URL 取得) で、動かない場合は将来 spec で改善。

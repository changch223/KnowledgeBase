# 08 — Non-Goals (やらないこと)

## このファイルの目的

「機能を増やせば良い」ではなく、**「これは作らない」と明示することで vision の純度を保つ** ためのリスト。

各 non-goal には理由を必ず添える。将来検討余地があるものは「V?」で示す。

---

## 1. 機能・データの non-goals

### 1.1 マルチユーザー / 共有 / コラボレーション

**やらない**:
- 複数アカウントログイン (1 端末 = 1 ユーザー固定)
- チーム / 家族で wiki 共有
- 他人と概念ページの編集を共同で
- コメント / リアクション機能

**理由**:
- vision は「**あなた専用に進化する** AI」、共有すると個人化が薄まる
- on-device 原則と矛盾 (共有は cloud sync 必須)
- iPhone share sheet 経由の **export** があれば「他人に伝えたい時」は user 主体で OK

**将来**: V3+ で「家族で同じ wiki 参照モード」は検討余地、ただし vision 拡張で慎重に

---

### 1.2 課金 / サブスク / 広告 / 計測

**やらない**:
- アプリ内課金 (subscription / one-time purchase)
- pro 機能 / free 制限
- 広告表示 (banner / interstitial / native ad)
- アナリティクス SDK (Firebase / Mixpanel / Amplitude 等)
- A/B テスト framework

**理由**:
- 「優しい第二の脳」と矛盾 (課金は不安喚起、広告は集中阻害、計測はプライバシー違反)
- Foundation Models = 無料、運用コストほぼゼロ、課金理由がない
- アナリティクスは vision の「ローカルファースト」と直接対立

**V?**: 将来、開発コスト回収のため tip jar (寄付) は検討可、ただし機能制限は伴わない

---

### 1.3 マルチデバイス同期 (V1)

**やらない (V1)**:
- iCloud sync で iPhone / iPad / Mac 間データ同期

**理由**:
- V1 は iPhone 専用、Mac / iPad アプリが存在しないので同期する先がない
- 同期実装は重く、V1 スコープを膨らます

**V3+**: iPad / Mac アプリ展開と同時に iCloud sync 採用予定

---

### 1.4 自動 ingest

**やらない**:
- RSS feed 自動取り込み
- arXiv 新着自動 ingest
- Twitter / X タイムライン自動取り込み
- メール自動 forward 経由 ingest
- Web crawler 自動巡回

**理由**:
- 「眠っている知識の活性化」は **ユーザーが意図的に共有したもの** を対象とする
- 自動 ingest = ノイズ大量、Karpathy / Tsurubee の「理解ボトルネック」を悪化
- ユーザーが「読みたい」と判断した moment を尊重 (キュレーション主体)

**V?**: 限定的に「Pocket / Reading List 一括 import (1 回きり)」は V2 で検討

---

### 1.5 Web Search を自動で発火

**やらない (V1)**:
- アプリ内で「答えに必要なら web 検索」を自動実行
- Brave / Tavily / Exa / DuckDuckGo API への自動呼び出し

**理由**:
- on-device 原則と矛盾 (検索クエリが外部に出る)
- 「保存した知識から答える」原則を守るため
- 答えが不足な場合は「分かりません」と明示する設計

**V2**: BYOK で user opt-in、ユーザーが API key を入れる + 「Web 検索を許可する」を明示有効化した場合のみ発火

---

### 1.6 自動 PDF / Slides / レポート生成

**やらない**:
- 概念から PDF レポート生成
- 概念から Marp スライド生成
- 概念から チャート / グラフ画像生成

**理由**:
- 「秘書 + 家庭教師」の vision からズレ (output generator は別 product)
- LLM コスト (Foundation Models だが、時間とトークン消費)
- 「読む / 理解する」と「他人に見せる成果物を作る」は別シナリオ

**V?**: 「export → ChatGPT に渡して資料生成」を user が行う前提

---

### 1.7 動画 / 画像 生成

**やらない**:
- AI で画像生成 (Genmoji / Image Playground 連携も含む)
- AI で動画生成
- 写真の修正 / 加工

**理由**:
- vision (情報整理 + 理解伴走) と無関係
- マルチモーダル LLM が前提となる V3+ で再検討

---

### 1.8 自動エージェント / 自動 workflow

**やらない**:
- 「保存したら slack に通知」自動化
- 「概念ページ更新時に Twitter にツイート」自動化
- iOS Shortcuts との深い統合 (自動 workflow 構築 UI)

**理由**:
- 「秘書 + 家庭教師」の純度を保つ、「自動化プラットフォーム」化を避ける
- Calm UX (通知 / 外部送信ゼロ) 原則違反

**V?**: V3+ で「ユーザー定義 trigger」は限定検討、ただし vision からの逸脱注意

---

## 2. UX の non-goals

### 2.1 ゲーミフィケーション / streak / レベル

**やらない**:
- 「3 日連続学習中!」streak 表示
- 「Level Up!」「バッジ獲得!」通知
- ポイント / コイン / 経験値
- ランキング / リーダーボード
- 達成バッジコレクション

**理由**:
- Calm UX (不安喚起ゼロ) 原則違反
- 「サボると怒られる」感を作る = vision と矛盾
- 学習は「義務」ではなく「興味の赴くまま」

**V?**: 永久になし

---

### 2.2 push 通知の積極利用

**やらない (default)**:
- 「カードが届きました!」 push 通知 (default ON)
- 「今日のあなた」毎朝通知 (default ON)
- 「新概念ページが作成されました」通知

**理由**:
- 「通知ゼロ」が calm UX の柱
- 開きたい時に開く、押し付けない

**V?**: 「学習通知 (週 1 程度)」は Settings で **opt-in default OFF**、ユーザーが明示有効化したら週 1 程度の soft reminder を許容

---

### 2.3 強制テスト / 正解 / 不正解

**やらない**:
- カードに「○ / ×」表示
- クイズで「正答率 80%!」表示
- 「不正解、もう一度!」リトライ強制

**理由**:
- 「家庭教師ループ」は **自己申告ベース** ("✓ わかった" / "🤔 もっと")
- 不正解概念 = 不安喚起 = 学習意欲削ぐ
- Karpathy「understanding は人間に残す」原則: テストは学校的で重い

**V?**: spaced repetition は実装可能だが「テスト感」を出さない (「久しぶりに surface」だけ)

---

### 2.4 整理を user に要求

**やらない**:
- 「カテゴリーを作ってください」UI
- 「タグを 整理してください」notification
- 「孤立記事を整理しましょう」reminder
- 「重複ファイルを 整理して」催促

**理由**:
- 「**bookkeeping は LLM がやる**」原則の核
- ユーザーは「読む / 問う / 考える」だけ、整理は AI が

**V?**: 「WikiLint 提案」で **soft proposal** として通すのは OK (タップして accept / reject、無視も OK)

---

### 2.5 強制 onboarding tour (機能ガイド画面)

**やらない**:
- 矢印で「ここをタップしてください」連続ガイド
- 機能ごとの tooltip overlay
- 「使い方を全部覚えるまで進めない」強制

**理由**:
- Apple HIG 準拠、自然に発見できる UI に
- 重いガイドはアプリの calm 感を壊す

**初回 onboarding** (Flow 1) は **3-5 step、価値伝達のみ**、機能説明なし

---

### 2.6 「未読」バッジ / 数字表示

**やらない**:
- アプリアイコンに数字バッジ
- タブに 赤丸 / 未読数表示
- セクションに「あと 3 件」「+12」未読カウント

**理由**:
- 「未読」「未消化」がストレス源 (タブ太郎ペルソナの最大 pain)
- 「読まなければ」プレッシャーを生む = vision 違反

---

## 3. 入出力の non-goals

### 3.1 物理ハードウェア統合

**やらない**:
- Apple Watch アプリ (V1、ただし V3+ で voice capture 用に検討余地)
- AirPods 統合 (音声で query 等)
- Vision Pro / AR 統合

**理由**:
- vision の core (iPhone でスキマ時間に貯める / 学ぶ) を最初に固める
- ハードウェア多様化は V3+

---

### 3.2 ブラウザ拡張 (Chrome / Edge / Firefox)

**やらない**:
- Chrome / Edge / Firefox 用拡張

**理由**:
- iPhone 専用、デスクトップブラウザ拡張は別 platform
- Safari iOS の Web Extension は V1 で対応可 (iPhone Safari 経由保存)

**V?**: Mac native アプリ展開時に Safari Mac 拡張は検討

---

### 3.3 Smart Home / 家電 / IoT 統合

**やらない**:
- 「Hey Siri、〇〇について調べて」(基本)
- HomeKit / Matter 統合

**理由**:
- vision からズレ
- ただし AppShortcutsProvider 経由の **「知積に保存」(Siri 経由)** は副次効果として動く想定

---

## 4. AI / 機械学習 の non-goals

### 4.1 クラウド LLM API 連携 (V1)

**やらない**:
- OpenAI / Anthropic / Google API へのアプリ内自動呼び出し
- 「答えの質が低かったら自動で外部 LLM に escalate」
- ChatGPT 拡張 (iOS 18 標準) との深い統合

**理由**:
- on-device プライバシー絶対原則
- 「Apple Intelligence をあなた専用に進化」差別化軸を維持

**V2**: Web Search BYOK opt-in 経由で間接的に外部依存は可、ただし「自動で勝手に呼ぶ」は永久になし

---

### 4.2 個人特化 fine-tune (V1)

**やらない (V1)**:
- ユーザー固有データで Foundation Models / 別 LLM を fine-tune
- Synthetic data 生成

**理由**:
- 技術的に on-device fine-tune が成熟していない
- スコープが膨大

**V3+**: Karpathy "Further explorations" 路線、Apple が device-side fine-tune API を出した時に検討

---

### 4.3 画像 / 動画内容理解 (V1)

**やらない (V1)**:
- 写真の「これは何の写真か」自動分類 (vision LLM)
- 動画から内容抽出
- スクショの「これは何のアプリ画面か」自動判定

**理由**:
- Foundation Models が vision input に対応していない (2026-05 時点)
- OCR テキストのみで V1 は十分

**V3+**: Apple が vision LLM を出した瞬間に採用候補

---

### 4.4 リアルタイム streaming (LLM 答えを文字ごとに)

**やらない (V1)**:
- Foundation Models からの真の streaming API 利用

**理由**:
- Foundation Models の streaming API が安定していない (2026-05 時点)
- 擬似 streaming (15ms/文字) で UX 上は同等

**V?**: Apple が安定 API を出したら採用

---

## 5. 開発 / 運用の non-goals

### 5.1 Open source (V1)

**やらない**:
- コードを GitHub public 公開
- pull request 受け入れ
- contribution guide

**理由**:
- V1 は個人プロジェクト or 小チームで素早く回す
- OSS にすると貢献者対応 + 品質 review に時間取られる

**V?**: V3+ で安定後に判断、可能性は残す

---

### 5.2 商用テンプレ販売 / B2B 展開

**やらない**:
- 「企業向けカスタマイズ版」販売
- White label
- SDK 提供

**理由**:
- 一般 iPhone ユーザー向け B2C プロダクト、focus を保つ
- B2B 展開は別 product

---

### 5.3 多 OS 同時開発

**やらない**:
- React Native / Flutter での Android 対応
- Web app 並行開発

**理由**:
- Apple Intelligence 前提なので iOS 専用
- multi-OS = vision 中核機能の妥協を強いる

---

## 6. データ / プライバシー の non-goals

### 6.1 アナリティクス (再掲、強調)

**やらない**:
- アプリ内行動の計測
- カードタップ率 / chat 質問内容のログ収集
- アプリ起動回数のレポート

**理由**:
- 完全 on-device 原則
- vision の信頼性の核

---

### 6.2 クラッシュレポートを 3rd party SDK で

**やらない**:
- Sentry / Bugsnag / Crashlytics SDK 導入

**理由**:
- 3rd party SDK = 外部送信
- Apple 標準の TestFlight / App Store Connect のクラッシュレポートのみ使用 (Apple 経由は OK)

---

### 6.3 user データの machine learning training への利用

**やらない**:
- ユーザーの保存記事 / 質問内容を「次バージョン改善」のための学習データに

**理由**:
- 完全 on-device、データは端末を出ない
- フィードバック改善は user 端末内の concept page lifecycle で

---

## 7. ビジネス・マーケティング の non-goals

### 7.1 「無料」を売りにしすぎる

**やらない**:
- 「永遠に無料!」「Pro 版なし!」を全面に
- 「ChatGPT より安い!」「他社より安い!」訴求

**理由**:
- 「優しい第二の脳」「あなた専用 AI 進化」が核
- 無料は手段、目的ではない (目的は user の理解の増幅)

---

### 7.2 過剰なグローバル展開 (V1)

**やらない (V1)**:
- 全世界対応 UI / 多言語 / 多通貨
- ローカライズ 10 言語

**理由**:
- 日本 + 英語ユーザー (一般 iPhone) で十分始められる
- 多言語展開は V2+ で順次

---

## まとめ表

| カテゴリ | やらない | V? で再検討余地 |
|---|---|---|
| 機能 | マルチユーザー / 課金 / 広告 / アナリティクス | tip jar (V?) |
| 入力 | 自動 ingest / RSS / web crawler | 1 回限り import (V2) |
| 出力 | PDF / スライド / 動画生成 | export 経由で user が外でやる |
| UX | streak / 通知 default ON / テスト / 強制整理 | 通知 opt-in (V2) |
| AI | 自動クラウド LLM / vision LLM / fine-tune | Web Search BYOK (V2) / fine-tune (V3+) |
| プラットフォーム | Android / Web / Mac / iPad (V1) | iPad / Mac (V3+) |
| ビジネス | 課金前面押し / グローバル展開 | 安定後の段階展開 |

---

## 次に読むファイル

- `09-naming-candidates.md` — 名前候補
- `10-open-questions.md` — 未確定論点

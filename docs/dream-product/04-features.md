# 04 — Features

## 機能一覧 (網羅 + 帰属 + Priority)

本ファイルは「dream product として必要な機能」を網羅的に列挙し、各機能がどのループ (秘書 / 家庭教師 / 共通) に属するかと priority (V1 / V2 / V3+) を明示する。

実装の詳細は別ファイル (05-information-architecture, 06-ux-flows, 07-tech-constraints) で議論する。

---

## 機能カテゴリ全体図

```
┌─────────────────────────────────────────────────────────────┐
│ A. 情報投入 (Ingest)                                          │
│   ・Share Sheet / Photo Picker / 一括 import                  │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ B. 抽出パイプライン (Extract)                                 │
│   ・本文抽出 / 翻訳 / 要約 / 概念抽出 / 関係性抽出           │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ C. 蓄積層 (Wiki)                                             │
│   ・記事 / 概念ページ / グラフ / コミュニティ / 質問結果      │
└─────────────────────────────────────────────────────────────┘
            ↓                          ↓
┌─────────────────────┐    ┌─────────────────────────────────┐
│ D. 秘書 UI           │    │ E. 家庭教師 UI                   │
│ ・News Clip カード   │    │ ・学習カード surface             │
│ ・秘書 chat (RAG)    │    │ ・深堀り chat                    │
│ ・Widget (ambient)   │    │ ・「わかった/もっと」スコア      │
└─────────────────────┘    └─────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ F. 共通基盤                                                  │
│   ・検索 / Catalog / Lint / Export / Settings                │
└─────────────────────────────────────────────────────────────┘
```

---

## A. 情報投入 (Ingest)

| 機能 | ループ | priority | 中身 |
|---|---|---|---|
| Share Sheet 投入 (Web 記事) | 秘書 | **V1** | iPhone Share Sheet から URL を 1 タップ保存 |
| Share Sheet 投入 (PDF) | 秘書 | **V1** | PDF を Share → 自動でテキスト抽出 → 既存パイプラインへ |
| Share Sheet 投入 (画像 / スクショ) | 秘書 | **V1** | 写真 / スクショを Share → Vision OCR でテキスト化 → 既存パイプラインへ |
| AI 会話スクショの構造判定 (ChatGPT / Gemini / Claude) | 秘書 | **V1** | OCR 後に発話者構造を判定、Q&A pair として保存 |
| Photo Picker (アプリ内から選択) | 秘書 | V1 | アプリ起動 → 写真選択経路 |
| プレーンテキスト投入 | 秘書 | V1 | コピペした文章を直接保存 |
| Safari Web Extension で 1 タップ | 秘書 | V1 | Safari から直接 保存 (Share Sheet より速い) |
| Reading List / Pocket / Instapaper 一括 import | 秘書 | V2 | 既存サービスから過去 saved を 一括 import |
| YouTube transcript 取り込み | 秘書 | V2 | URL Share で transcript 自動取得 |
| ポッドキャスト音声 → 文字起こし | 秘書 | V3+ | Speech framework 経由、長時間処理 |
| メール / メッセージ転送 | 秘書 | V3+ | 受信箱からの forward 経路 |

---

## B. 抽出パイプライン (Extract)

| 機能 | ループ | priority | 中身 |
|---|---|---|---|
| 本文抽出 (HTML → 本文テキスト) | 共通 | **V1** | OG meta + body extractor、ノイズ除去 |
| 翻訳前処理 (英語 / 中国語 → 日本語) | 共通 | **V1** | Apple Translation framework、固有名詞は維持 |
| 要約生成 (essence + summary) | 共通 | **V1** | Foundation Models、決定論的 prompt |
| KeyFact 抽出 | 共通 | **V1** | 3-5 件の事実、引用元付き |
| Entity 抽出 (人物 / モノ / テーマ) | 共通 | **V1** | 5-10 件、salience 付き |
| 概念ページ自動生成 | 共通 | **V1** | 2+ 記事に登場する entity → 自動 ConceptPage 化 |
| 概念ページの増分更新 | 共通 | **V1** | 新記事 ingest → 関連概念を markStale → 再合成 |
| グラフ triple 抽出 | 共通 | **V1** | (主語, 関係, 目的語) で抽出、Graph に蓄積 |
| コミュニティ検出 (concept clustering) | 共通 | **V1** | K-means or Louvain、AI で命名 |
| Auto-Tag (記事へのタグ自動付与) | 共通 | V1 | 既存パターン、シンプル |
| Auto-Category (10 種固定カテゴリー分類) | 共通 | V1 | 既存パターン |
| 矛盾検出 (新記事 vs 既存事実) | 共通 | V1 | 「Apple が CEO 交代した?」等の時系列上書き |
| 画像内容理解 (vision LLM) | 共通 | V3+ | Foundation Models が vision 対応してから |

---

## C. 蓄積層 (Wiki)

| 機能 | ループ | priority | 中身 |
|---|---|---|---|
| 保存記事 (raw 不変) | 共通 | **V1** | Article + ArticleBody @Model、ソース真実 |
| 概念ページ | 共通 | **V1** | 人物 / モノ / テーマ単位、AI 合成 summary + 横断的知見 |
| Knowledge Graph (ノード + エッジ) | 共通 | **V1** | entity 関係性 |
| Entity Community | 共通 | **V1** | 概念のグループ、AI 命名 |
| 質問結果ファイリング (SavedAnswer) | 共通 | **V1** | chat 答えを wiki に file |
| カテゴリー Digest | 共通 | V1 | 10 種固定カテゴリーごとのまとめ |
| 動的トピック (User Topic) | 共通 | V2 | clustering で自動発見 |
| 「最近のあなた」差分ダイジェスト | 共通 | V2 | 期間別の差分 |
| ActivityLog (時系列、内部) | 共通 | V1 | log.md 相当、内部のみ |

---

## D. 秘書 UI (Outsource Thinking)

| 機能 | ループ | priority | 中身 |
|---|---|---|---|
| News Clip 風カード (要点提示) | 秘書 | **V1** | 受動的に「最近のあなた」「今のあなた」カードで surface |
| 秘書 chat (RAG ベース汎用 chat) | 秘書 | **V1** | 質問に保存記事から答える、引用元付き |
| Chat answer に「次の問い」3 候補内蔵 | 秘書 | **V1** | Runbook pattern、ユーザーは「次」で迷わない |
| 検索 (全 wiki 横断、relevance ranking) | 秘書 | **V1** | title / essence / KeyFact / entity / concept page を統合 |
| ライブラリ (保存記事一覧) | 秘書 | **V1** | 時系列 / カテゴリー別 |
| カテゴリー詳細ビュー | 秘書 | V1 | 同カテゴリー記事の横断ビュー |
| グラフ可視化 (entity 関係) | 秘書 | V1 | SwiftUI Canvas、static layout |
| Widget (ambient surface) | 秘書 | **V1** | Home screen / Lock screen で glanceable |
| Spotlight 統合 | 秘書 | V3+ | OS 検索からヒット |
| Voice input (chat に音声で) | 秘書 | V2 | Speech framework、通勤・両手塞がり対応 |
| 秘書 chat の multi-turn context | 秘書 | V1 | 直前 4-5 message を context に |
| 引用元から原文 jump | 秘書 | V1 | chat 答えの引用 → 元記事 detail |

---

## E. 家庭教師 UI (Understanding)

| 機能 | ループ | priority | 中身 |
|---|---|---|---|
| 学習タブ (起動 default) | 家庭教師 | **V1** | アプリ起動時 default = ここ |
| 学習カード surface (1 枚ずつ) | 家庭教師 | **V1** | 「今のあなたへ」概念 / 仮説 / 気付きを 1 枚ずつ |
| 「✓ わかった」「🤔 もっと」ボタン | 家庭教師 | **V1** | 2 択、不正解概念なし |
| 深堀り chat (カード → 会話に展開) | 家庭教師 | **V1** | カードを context にして対話 |
| カード関連リンク (連鎖) | 家庭教師 | V1 | 「関連カード: A / B / C」で次に jump |
| userUnderstanding スコア (内部) | 家庭教師 | V1 | 概念ごとの理解度、surface 優先度に反映 |
| カードキュー優先度ロジック | 家庭教師 | **V1** | 新着 / pin / userUnderstanding 低 / idle / ランダムの重み付け |
| 興味のピン (フォロー) | 家庭教師 | V1 | 能動キュレーション、surface 優先 |
| 「もっと知りたい」スワイプ | 家庭教師 | V2 | gesture-based UX |
| Spaced Repetition (久しぶり surface) | 家庭教師 | V2 | 「3 ヶ月前に わかった カード」を再 surface (テスト感なく) |
| 学習 reminder (週 1 opt-in) | 家庭教師 | V2 | 「カードが届きました」soft notif、default OFF |

---

## F. 共通基盤

| 機能 | ループ | priority | 中身 |
|---|---|---|---|
| WikiLint (健全性チェック自動) | 共通 | **V1** | 同義異名 / 孤立 entity / 概念候補 / 「次に聞くべき問い」検出、週 1 BGTask |
| 「気づきの種」セクション (lint 結果表示) | 共通 | **V1** | calm UX、soft proposal 形式 |
| ConflictDetection (事実矛盾) | 共通 | V1 | 既存記事 vs 新記事の事実衝突 |
| Catalog View (全 wiki 横断 index) | 共通 | V2 | concept / community / saved answer を横断 list |
| **Export (zip + markdown)** | 共通 | **V1** | 全 knowledge を zip 出力、user が email / cloud で転送可 |
| Markdown 単体 export (記事 1 件単位) | 共通 | V1 | 個別 share 用 |
| Obsidian 互換 export (vault 形式) | 共通 | V2 | Obsidian で開ける形 |
| Settings (各種 toggle) | 共通 | **V1** | グラフ表示 / 学習通知 / log 表示 / 翻訳 setup |
| Tag 管理 (rename / merge / delete) | 共通 | V1 | spec 024 同パターン |
| Graph node 管理 (rename / merge / delete) | 共通 | V1 | spec 041 同パターン |
| アクティビティログ表示 (Settings opt-in) | 共通 | V2 | log.md 相当の UI 露出、default OFF |
| Web search (BYOK) | 共通 | **V2** | Brave / Tavily / Exa BYOK、user opt-in |
| iCloud sync (multi-device) | 共通 | V3+ | Mac / iPad / iPhone 同期 |
| Voice memo 統合 | 共通 | V3+ | Apple Voice Memos 共有 |

---

## V1 機能のみの一覧 (MVP)

V1 リリースに含まれる機能を一気に見る:

### 必須投入経路
- Share Sheet (Web / PDF / 画像 / AI スクショ / プレーンテキスト)
- Safari Web Extension

### 必須抽出
- 本文抽出 / 翻訳 / 要約 / KeyFact / Entity / 概念ページ / Graph / Community / Auto-Tag / Auto-Category / 矛盾検出

### 必須蓄積
- 保存記事 / 概念ページ / Knowledge Graph / Entity Community / SavedAnswer / Category Digest / ActivityLog (内部)

### 必須秘書 UI
- News Clip 風カード / 秘書 chat (RAG + 次の問い 3 候補) / 検索 / ライブラリ / カテゴリー詳細 / グラフ可視化 / Widget

### 必須家庭教師 UI
- 学習タブ (起動 default) / 学習カード surface / ✓/🤔 ボタン / 深堀り chat / カード関連リンク / userUnderstanding / カードキュー / 興味ピン

### 必須共通
- WikiLint / 気づきの種 / ConflictDetection / **Export (zip + markdown)** / Settings / Tag/Graph 管理

→ 規模見込み: **大規模** (現知積の v1.5 相当を超える)

---

## 機能を「ループ」で集計

| 帰属 | V1 機能数 | V2 機能数 | V3+ 機能数 |
|---|---|---|---|
| 秘書 (Loop 1) | 9 | 2 | 1 |
| 家庭教師 (Loop 2) | 8 | 3 | 0 |
| 共通 | 13 | 4 | 3 |
| **合計** | **30** | **9** | **4** |

→ V1 で 30 機能、現実的には spec 単位で 8-12 個に集約して 3 ヶ月以内で実装可能 (詳細は migration plan で議論)。

---

## 機能の依存関係 (重要)

実装順序を決めるための主要 dependency:

```
A. 投入経路 (Share Sheet等)
     ↓ (depends)
B. 抽出パイプライン
     ↓
C. 蓄積層 (記事 / 概念ページ / Graph)
     ↓
     ├→ D. 秘書 UI (新 UI 層)
     ↓
     └→ E. 家庭教師 UI (Loop 2 の核)
              ↓
              └→ F. Compound moment (E と D を繋ぐ)
```

→ **C (蓄積層、特に概念ページ) が完成しないと D / E は表示するものがない**。実装順序: C → D & E 並行 → F polish。

---

## V2 / V3+ で追加される機能 (将来)

### V2 (V1 安定後 3-6 ヶ月)

- Reading List / Pocket / Instapaper 一括 import
- Voice input (chat に音声で)
- Web search (BYOK)
- Obsidian 互換 export
- 「気づきの種」拡張 (web 補完候補)
- Spaced Repetition (Loop 2)

### V3+ (将来検討)

- iPad / Mac native アプリ
- iCloud sync (multi-device)
- Spotlight 統合
- ポッドキャスト音声 文字起こし
- 画像内容理解 (vision LLM)
- 個人特化 fine-tune

---

## 次に読むファイル

- `05-information-architecture.md` — 蓄積層のデータ構造詳細
- `06-ux-flows.md` — 上記機能を繋ぐ主要 UX フロー
- `07-tech-constraints.md` — 実装の技術前提

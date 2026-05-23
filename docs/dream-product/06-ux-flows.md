# 06 — UX Flows

## このファイルの目的

主要なユーザー操作を **画面遷移 + タップ位置 + 内部処理 + 結果** で記述する。
ペルソナ (02 章) と中核ループ (03 章) が、実際の画面でどう体験されるかを示す。

---

## 想定タブ構成 (4 タブ案)

```
┌─────────────────────────────────────────┐
│ ★ 学習 (起動 default)                    │  ← 家庭教師ループ
│   Understanding Card UX                  │
├─────────────────────────────────────────┤
│ AI チャット                              │  ← 秘書ループ (能動 query)
│   General agent (RAG)                    │
├─────────────────────────────────────────┤
│ 知識 Clip                                │  ← 秘書ループ (受動 surface) + Wiki ブラウズ
│   News Clip card / 概念 / コミュニティ   │
│   / 気づきの種 / SavedAnswer             │
├─────────────────────────────────────────┤
│ ライブラリ                               │  ← Raw 層閲覧
│   保存ソース一覧 / 検索                  │
└─────────────────────────────────────────┘

(+ Widget: ambient surface、タブ外)
```

Settings は AI チャット or 知識 Clip の toolbar から。

---

## Flow 1: 初回起動 (Onboarding)

```
1. App 起動 (初回のみ)
   ↓
2. Welcome screen
   ─ 「読んだ知識を AI が体系化する、優しい第二の脳」
   ─ 「Apple Intelligence をあなた専用に進化させます」
   ─ [次へ]
   ↓
3. 価値の説明 (3 step swipe)
   Step 1: 共有 → 「Share Sheet から記事 / PDF / 写真 / スクショ」
   Step 2: 整理 → 「AI が読み解き、概念ページが育つ」
   Step 3: 活用 → 「聞けば答える秘書 + 腹落ちまで伴走する家庭教師」
   ↓
4. 必須権限リクエスト
   ─ Apple Intelligence 有効化確認 (まだなら設定 deeplink)
   ─ 通知 → 「全てオフ、必要なら後で Settings で」(opt-in、push しない)
   ↓
5. 最初の保存を促す
   「まず気になった記事を 1 つ Share Sheet で共有してみましょう」
   ─ [Safari で開く] (任意)
   ─ [スキップ → 学習タブへ]
   ↓
6. 学習タブ (空状態)
   「まだカードがありません。3 つ以上記事を共有すると、AI が概念を見つけて
    あなたへのカードを surface し始めます」
```

**設計判断**:
- 5 step 以内、短く軽く (Calm UX)
- 価値を伝える、機能を教えない (「タップしてここを見て」 はしない)
- 必須権限は最小限、通知は完全 OFF default

---

## Flow 2: 情報投入 (Share Sheet → 蓄積)

```
[Safari で記事を読んでいる状態]
   ↓
1. 共有ボタンタップ
   ↓
2. iOS Share Sheet 表示
   ↓
3. アプリのアイコンタップ
   ↓
4. アプリの Share Extension 画面 (一瞬)
   ─ 「保存しました」soft toast
   ─ プログレスインジケータなし、即閉じる (摩擦ゼロ)
   ↓
5. (バックグラウンド)
   ─ Raw 層に保存ソース + 本文テキスト 永続化
   ─ 翻訳前処理 (英語等なら日本語化)
   ─ 要約 / KeyFact / entity 抽出
   ─ 関連概念ページ自動生成 / 更新 (markStale)
   ─ グラフ triple 抽出
   ─ Auto-Tag / Auto-Category
   ─ 矛盾検出
   ─ ActivityLog 記録
   ↓
6. (完了通知なし、ユーザーは何もしない)
   ↓
7. 次にアプリを開いた時:
   ─ 知識 Clip タブ「最近のあなた」セクションに反映
   ─ 学習タブのカードキューに新トピック追加
```

**設計判断**:
- Share Sheet タップから「保存しました」表示まで **1-2 秒以内**
- バックグラウンド処理は ユーザー待たせない
- 進捗バー / プログレス表示なし (Calm UX)
- 完了通知なし、次回起動時に変化を見せる

### バリエーション

- 写真 / スクショ: Share Sheet 後に「OCR プレビュー」表示、確認して保存
- AI 会話スクショ: 「ChatGPT 会話 / Gemini 会話 / 通常画像」を判定、Q&A 構造の場合は「発話者分離プレビュー」表示
- PDF: 受け取り後 PDFKit 抽出、バックグラウンド処理同じ
- 連続投入: 5 件連続 Share しても全部別々に処理、ユーザーは待たされない

---

## Flow 3: 朝の通勤 (受動消費フロー)

ペルソナ: タブ太郎 / 好奇さん / 七六さん がメイン。

```
1. アプリ起動 (アイコンタップ)
   ↓
2. ★ 学習タブが default で開く ★
   ↓
3. 1 枚のカードが画面中央に表示
   ─ 概念名 + 1 行サマリー + 関連記事数 (例: "Apple Intelligence · 5 記事から · 3 日前更新")
   ─ 200-300 字のサマリー本文
   ─ 「✓ わかった」「🤔 もっと」ボタン
   ↓
4. ユーザー判断 (5 秒 - 30 秒)
   
   Case A: 知っている内容 → 「✓ わかった」タップ
     ↓
     ─ 「次のカード」へ即遷移 (アニメーション 200ms)
     ─ (内部) userUnderstanding +1、関連 1-hop +0.3 波及
   
   Case B: もっと知りたい → 「🤔 もっと」タップ
     ↓
     ─ 深堀り chat 画面へ展開 (Flow 5 参照)
   
   Case C: 流す → 下スワイプ
     ↓
     ─ スキップ、次のカードへ
     ─ (内部) スコア変化なし
   ↓
5. これを 3-5 回繰り返して終わり
   ↓
6. アプリ閉じる、終わり
```

**設計判断**:
- カード 1 枚の情報量は **5-30 秒で消費** できる範囲
- スワイプ + 2 ボタン、それ以上の操作なし
- カード遷移は速い (200ms 程度のアニメーション)
- 連続 何枚読んだか、streak、未読数 一切表示しない (Calm UX)

---

## Flow 4: 質問フロー (秘書 chat)

ペルソナ: タブ太郎 / 学さん / 営みさん がメイン。

```
1. アプリ起動
   ↓
2. 「AI チャット」タブをタップ (or chat icon)
   ↓
3. Chat 画面表示
   ─ 過去のセッション一覧 (sidebar)
   ─ 「新しいチャット」ボタン
   ─ 既存セッションを開く or 新規開始
   ↓
4. 入力欄に質問
   例: 「先月読んだ AI 関連の主要 trend は?」
   ↓
5. 送信
   ↓
6. (内部)
   ─ 質問を embedding 化
   ─ 関連保存ソース top-K + 関連概念ページ + 関連 SavedAnswer を retrieval
   ─ Foundation Models で答え生成 (引用付き)
   ─ ハルシネーション post-process (cited 空 → 「分かりません」)
   ↓
7. AI 答え表示
   ─ 本文 (3 段落以内)
   ─ 引用元カード (タップで原文 jump)
   ─ ★ 「次の問い」3 候補 (Runbook pattern) inline 表示
     例: 「もっと詳しく」「他の trend は?」「具体例を教えて」
   ─ 「📌 この答えを保存」ボタン (引用 ≥ 2 なら表示)
   ↓
8. Case A: ユーザーが「次の問い」タップ
   ─ 候補が入力欄に補完、必要に応じて編集して送信
   ─ multi-turn 対話継続
   
   Case B: 「📌 保存」タップ
   ─ SavedAnswer として永続化
   ─ 関連概念ページに Q&A セクション append
   ─ 知識 Clip タブで後から閲覧可
   
   Case C: そのまま閉じる
   ─ session に保存、後で再開可
```

**設計判断**:
- 答えは **3 段落以内** (モバイル UX)
- 引用元タップで即原文 jump (信頼性 + 検証可能性)
- 「次の問い」3 候補は **inline、押し付けず提案**
- 「📌 保存」は明示 button、自動保存しない (ユーザー主体)

---

## Flow 5: 深堀りフロー (家庭教師 chat、カード起点)

ペルソナ: 学さん / 好奇さん / 育子さん がメイン。

```
[学習タブで カードを見ている状態]
   ↓
1. 「🤔 もっと」タップ
   ↓
2. 深堀り chat 画面に展開
   ─ 画面上部: 元カードの concept 名 + 要約 (常に context として見える)
   ─ 画面下部: chat UI
   ─ AI から最初のメッセージ
     「このカードについて、何が知りたいですか?」
     候補: 「具体例は?」「他とどう違う?」「実際の使い方は?」
   ↓
3. ユーザーが質問
   ↓
4. AI 答え (Flow 4 と同じパイプライン、ただし context にカード元概念を含む)
   ↓
5. 2-5 ターン会話
   ↓
6. 腹落ちしたら 「✓ わかった」ボタン (画面下、常時表示)
   ↓
7. タップ時
   ─ 会話全体を analyze
   ─ 新 insight (元カードに無かった理解) を概念ページに append
   ─ soft toast: 「✨ Apple Intelligence に新しい insight が追加されました」
   ─ 元カードに戻る、次のカードへ
   ↓
8. (内部 Compound moment)
   ─ 概念ページの crossSourceInsights に追記
   ─ userUnderstanding +1
   ─ ActivityLog に compound event 記録
```

**設計判断**:
- カードの context が常に上部に見える (どこから来たか分かる)
- chat 終了は user の任意 (「✓ わかった」タップ、または閉じる)
- 「分かった」までの時間制限なし、ストレスゼロ
- Compound 発火は soft toast、押し付けない

---

## Flow 6: 概念ページ閲覧フロー

ペルソナ: 学さん / 花子 / 好奇さん。

```
1. 知識 Clip タブを開く
   ↓
2. 「あなたが追っている人物・モノ」セクション
   ─ ConceptPage カード一覧 (更新日 desc)
   ─ 各カード: 名前 + 関連記事数 + 最終更新 + 1 行サマリー
   ↓
3. カードタップ
   ↓
4. ConceptPage Detail 画面
   ─ ヘッダ: 概念名 + categoryRaw + 統計 (関連記事数 / userUnderstanding バー任意)
   ─ Section 1: 「今わかっていること」(summary、200-400 字)
   ─ Section 2: 「横断的知見」(crossSourceInsights、3-7 件の bullet)
   ─ Section 3: 「関連記事」(関連保存ソース list、タップで原文)
   ─ Section 4: 「つながる人物・モノ」(関連 ConceptPage link、graph 1-hop)
   ─ Section 5: 「Q&A」(SavedAnswer 一覧、過去の質問結果)
   ─ Toolbar: [編集] (rename / merge / delete)、[ピン] (フォロー toggle)
   ↓
5. 任意操作
   ─ 関連記事タップ → ArticleDetailView
   ─ 関連概念タップ → 別の ConceptPage Detail
   ─ Q&A タップ → 該当 SavedAnswer Detail
   ─ ピン → このカードが学習タブで優先 surface される
   ─ 編集 → rename / merge / delete sheet
```

**設計判断**:
- 1 ページに「これだけ知ってればOK」が収まる構造
- 関連 link で 1 タップで隣の概念に jump (探索性)
- 編集は toolbar 経由、誤タップ防止

---

## Flow 7: Widget glance (5 秒)

ペルソナ: 育子 / 七六 / 営み が特にメイン。

```
[Home screen or Lock screen]
   ↓
1. Widget 表示
   ─ Small サイズ: 1 概念 + 1 文 (「Apple Intelligence: M5 発表で...」)
   ─ Medium サイズ: 2-3 概念カード + 1 行ずつ
   ─ Large サイズ: 「今のあなた」digest + 最近のあなた + 翻訳セットアップ status
   ↓
2. Widget タップ
   ↓
3. アプリ起動 → 該当 ConceptPage Detail (deep link)
   ↓
4. そのまま読む or 深堀り
```

**設計判断**:
- Widget は **glanceable** に徹する、操作不要
- タップ先は **最も関連性高い ConceptPage** (キュー優先度ロジック準拠)
- 更新頻度: 数時間に 1 回 (WidgetKit timeline)
- バッジ / 数字 一切表示しない (Calm UX)

---

## Flow 8: Export フロー

ペルソナ: 花子 / 営み / タブ太郎 (全ペルソナ可)。

```
1. Settings を開く (AI チャットタブ or 知識 Clip タブの toolbar 歯車)
   ↓
2. 「データ管理」セクション
   ─ 「ナレッジを export」
   ↓
3. タップ
   ↓
4. Export オプション画面
   ─ Option A: zip 全体 export (全 ConceptPage / SavedAnswer / 要約 / Raw メタ)
   ─ Option B: Markdown vault (Obsidian 互換、ディレクトリ構造付き、V2)
   ─ Option C: 個別概念ページのみ (絞り込み export)
   ↓
5. 選択 → 「Export」
   ↓
6. (内部)
   ─ 全 Wiki 層 + Raw メタを markdown 化
   ─ 画像 / 添付ファイル含めて zip
   ─ Files app の一時領域に保存
   ↓
7. iOS Share Sheet 起動
   ─ 「メール」「Mail」「クラウドドライブ」「AirDrop」等選択
   ─ ユーザーが共有先を選択
   ↓
8. 共有完了
   ─ アプリ側は何も追跡しない (プライバシー)
```

**設計判断**:
- Export は **完全に user 主体**、アプリは外部送信しない
- 共有先選択は iOS Share Sheet (Apple 標準)
- 出力後の流れはアプリ管轄外 (例: user が ChatGPT に貼り付ける等)

### Export 形式の中身 (zip 内構造)

```
i-knowledge-base-export-2026-05-23.zip
├── README.md                       — このエクスポートの説明
├── concepts/
│   ├── apple-intelligence.md       — 概念ページ markdown
│   ├── foundation-models.md
│   └── ...
├── queries/
│   ├── 2026-05-15-trend-question.md — SavedAnswer markdown
│   └── ...
├── sources/
│   ├── manifest.json               — 保存ソース メタ
│   └── (オプション) snapshots/     — 本文テキスト
├── communities/
│   └── ai-industry.md
└── activity-log.md                 — タイムライン
```

---

## Flow 9: 「気づきの種」フロー (Lint 結果との対話)

```
1. 知識 Clip タブを開く
   ↓
2. 「💡 こんな発見があります」セクション (週 1 BGTask 結果)
   ─ 「Apple とアップルを 1 つにまとめませんか?」(同義異名検出)
     [一緒にする] [別物のまま]
   ─ 「Tim Cook と Sundar Pichai が同じ記事に出てきました」
     [概念ページ作成] [スキップ]
   ─ 「先月の AI 関連記事 5 本に共通テーマ『on-device』があります」
     [新コミュニティ作成] [スキップ]
   ↓
3. ユーザーが選択
   ─ Accept → 該当処理実行
   ─ Reject → そのまま消える (一定期間 silent)
```

**設計判断**:
- soft proposal、強制しない
- 1 つの判断あたり 2-3 秒で済む
- Reject も「無視」と等価、罪悪感ゼロ

---

## アンチパターン (避ける UX)

| アンチパターン | なぜダメ |
|---|---|
| 「整理しましょう」ナビゲーション | ユーザーに整理を要求しない、AI が全部やる |
| 進捗バー / プログレス表示 | バックグラウンド処理、user 待たせない |
| 「カードが届きました!」push 通知 | calm UX、通知 default OFF |
| 「3 日連続学習中!」streak 表示 | 不安喚起 UI、避ける |
| 強制 onboarding tour (画面ごとに矢印) | 重い、Calm UX 違反、Apple HIG 違反 |
| 課金画面 / 広告 | 一切なし (08 章) |
| chat 答えが返ってこない時に何も表示しない | spinner だけは出す、無音にしない |

---

## 主要画面の階層

```
TabView (root)
├── 学習タブ (default)
│   ├── UnderstandingCardView (root)
│   └── DeepDiveChatView (NavigationDestination)
├── AI チャットタブ
│   ├── ChatSessionListView (sidebar)
│   ├── ChatView (selected session)
│   └── ArticleDetailView (引用 jump)
├── 知識 Clip タブ
│   ├── KnowledgeClipView (root、複数セクション)
│   ├── ConceptPageDetailView
│   ├── ConceptPageEditSheet
│   ├── SavedAnswerDetailView
│   ├── EntityCommunityDetailView
│   └── CategoryDetailView
└── ライブラリタブ
    ├── ArticleListView (検索バー付き)
    ├── ArticleDetailView
    └── (任意) PhotoPickerSheet

Settings (タブ外、toolbar 経由)
├── データ管理 (Export)
├── 翻訳セットアップ
├── タグ管理
├── グラフ表示 toggle
├── 学習通知 (opt-in)
├── Activity Log 表示 (opt-in)
└── Apple Intelligence セットアップ deeplink

Widget (タブ外)
├── Small
├── Medium
└── Large
```

---

## 次に読むファイル

- `07-tech-constraints.md` — このフローを支える技術前提
- `08-non-goals.md` — UX で「やらない」と決めたこと

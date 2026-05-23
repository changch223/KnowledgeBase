# 05 — 統合プロダクトビジョン (v2)

## Status: WIP — v2 (2026-05-17 全面改訂)

v1 → v2 改訂内容:
- Karpathy 3 層アーキテクチャを知積 @Model に完全マッピング
- 7 提案 (A〜G) を spec 番号付き機能群として正式に統合
- 「成功の定義」を Karpathy 5 項目 → 知積版 5 項目に翻訳
- 「データ形式の差分」修正 (知積でも raw 以外は LLM 自由編集可、Karpathy と原則同じ)
- Karpathy 流ディレクトリ構造 → 知積 @Model 群への翻訳マッピング追加
- 3 オペレーション (Ingest/Query/Lint) と特殊ファイル (index/log) の知積実装を明示

---

## 0. このドキュメントの位置づけ

`01〜04` で Karpathy LLM Wiki / GraphRAG の分析と知積への接続を個別に検討。本ドキュメントは **「結局、知積として何を作るのか」** をユーザー視点で 1 枚に統合する。

決定 → VISION.md 更新 → spec 045+ 実装 の起点。

---

## 1. 一文ビジョン

> **「スマホで触れたあらゆる情報 (Web / PDF / 写真 / 他 AI 会話) を AI が読み解き、繋ぎ、要約し、理解できるまで会話で深堀りできる、優しい第二の脳」**

旧 VISION との差分:
- 旧: 「読んだ知識を AI が自動で体系化・更新し、必要な時だけ開けば最新の自分が見える」
- 新: **入力源を「読んだ記事」から「あらゆる情報」に拡張** + **「理解できるまで会話で深堀り」を明示**

→ Karpathy が未解決と認めた **「outsource thinking, but not understanding」のボトルネック** を、知積独自の Understanding Chat で初めて UI 解決する。

---

## 2. 3 層アーキテクチャ (Karpathy 踏襲 + 知積実装)

Karpathy の 3 層構造をそのまま継承、ただし markdown ファイル群を SwiftData @Model に翻訳する。

```
┌─────────────────────────────────────────────────────────────┐
│ Schema (アプリ内部、隠す)                                     │
│   - Karpathy: CLAUDE.md / AGENTS.md                          │
│   - 知積: Services/ に hardcode、Settings で部分 opt-in       │
│   - 命名規約 / 概念粒度 / Lint ルール / ingest skill 定義     │
└─────────────────────────────────────────────────────────────┘
                          ↓ guides
┌─────────────────────────────────────────────────────────────┐
│ Wiki = 知識層 (LLM 自動メンテ、user は閲覧 + 部分編集可)      │
│   - Karpathy: markdown ファイル群 (wiki/concepts/, queries/) │
│   - 知積: @Model 群 (ConceptPage, KnowledgeDigest, etc.)     │
│   - 直接編集の自由度: LLM 100%、user は rename/merge/delete   │
│     等 spec 024/041 同パターンで部分編集可                    │
└─────────────────────────────────────────────────────────────┘
                          ↑ extract / synthesize
┌─────────────────────────────────────────────────────────────┐
│ Raw Sources = 記事層 (immutable、人間キュレーション)          │
│   - Karpathy: vault/raw/ の PDF / 記事クリッピング            │
│   - 知積: Article + ArticleBody @Model (Share Sheet で投入)   │
│   - 規則: LLM は読むだけ、user は追加・削除のみ、編集は不可    │
└─────────────────────────────────────────────────────────────┘
```

### 各層の所有権 (Karpathy と同原則)

| 層 | 書き手 | 読み手 | 編集自由度 |
|---|---|---|---|
| Schema | 人間 (アプリ開発者、LLM が共進化提案) | LLM | 内部 hardcode、Settings で一部 opt-in |
| Wiki | **LLM が主**、user は補正 | 人間 (mobile UI) | LLM = 自由、user = rename/merge/delete |
| Raw | 人間 (Share Sheet) | LLM (read-only) | 追加・削除のみ、本文編集不可 |

→ **Karpathy 原則と原理的に同じ**。「raw 以外は LLM が自由編集」の前提も維持。

---

## 3. データ入力 (Ingest 対象)

### V1 で対応

| 入力源 | 入力経路 | 抽出方法 | 知積実装状態 |
|---|---|---|---|
| Web 記事 | Share Sheet / Safari Extension | OG + body extractor + 知識抽出 | ✅ spec 001/002/003 |
| PDF | Share Sheet | PDFKit + 知識抽出 | ✅ spec 034 |
| 写真 / スクリーンショット | Share Sheet / Photo picker | Vision framework OCR → text 経路 | ❌ **spec 050 新規** |
| 他 AI 会話 (ChatGPT/Gemini/Claude スクショ) | Share Sheet | OCR + 発話者構造判定 + Q&A 分離 | ❌ **spec 050 内で対応** |
| プレーンテキスト | Share Sheet | 既存パス | ⚠️ 部分実装 |
| Twitter/X 投稿 | Share Sheet | OG + body extractor | ⚠️ 既存パスで動く想定 |

### V2 以降

- web search (Brave / Tavily / Exa いずれか、BYOK 推奨) — spec 051
- YouTube transcript
- ポッドキャスト音声 (Speech framework)
- メール / メッセージ転送

### V3+ 検討

- カメラリアルタイム OCR (限定 use case)
- Apple Watch voice capture
- Spotlight システム統合

---

## 4. データ処理 (3 オペレーション、Karpathy 完全踏襲)

### 4.1 Ingest (取り込み)

| 観点 | Karpathy | 知積 |
|---|---|---|
| 主体 | ユーザーが CLI で「ingest これ」指示 | Share Sheet タップで自動発火 |
| スタイル | one-by-one + 監督 | batch + 自動 (一般ユーザー前提) |
| 1 ソースで波及更新 | 10-15 ページ | 既存パス: enrichment / body / extraction / auto-tag / category / digest stale / embedding / conflict / graph / **+ concept page** (spec 045 新規) |
| 概念ページ更新 | 既存 markdown に追記 | ConceptPage @Model を markStale → 後で再合成 |

→ 知積の ingest は既に Karpathy の「1 ソースで 10-15 ページに波及」を構造的に実現済 (spec 002〜040 の hook chain)。**追加で ConceptPage を組み込むだけで Karpathy 同等になる**。

### 4.2 Query (質問)

| 観点 | Karpathy | 知積 |
|---|---|---|
| 場所 | CLI または Claude Code チャット | AI Chat タブ + Understanding Chat タブ |
| retrieval | index 経由 → drill down | embedding RAG + spec 040 graph augmentation + 044 search |
| 答え | markdown / slide / chart | テキスト + 引用カード + 関連 ConceptPage link |
| **filing back** | 良い回答を markdown ページ化 | **chat 答え → SavedAnswer @Model + 関連 ConceptPage 更新** (spec 046 新規) |
| compound moment | query → wiki page 化 | chat answer post-process で自動 compound (spec 046 と spec 045 連動) |

### 4.3 Lint (健全性チェック)

| 観点 | Karpathy | 知積 |
|---|---|---|
| トリガー | ユーザーが定期実行 | 週 1 BGTask 自動 + Settings で手動も可 |
| 検出対象 | 矛盾 / orphan / 欠落 / 同義異名 / web 補完候補 | 同じ + 概念候補 (2+ 記事登場で未生成) + 「次に聞くべき問い」生成 |
| 既存 | なし (CLI 都度) | ConflictDetectionService 部分実装、**WikiLintService で拡張** (spec 047 新規) |
| 結果表示 | LLM が提案文返す | 知識 Clip タブ「気づきの種」セクション (calm UX、soft proposal) |

---

## 5. 特殊ファイル (index / log) の知積実装

Karpathy の 2 ファイルは LLM ナビゲーション用、知積でも内部的に等価物が必要:

### 5.1 index 相当

| 観点 | Karpathy index.md | 知積 |
|---|---|---|
| 中身 | 全 wiki ページの 1 行サマリー catalog | (内部) ConceptPage / SavedAnswer / Digest / GraphNode の統合 list view |
| 用途 | LLM 質問時に最初に読む | 同左 + UI として **「Catalog タブ or 知識 Clip 内セクション」** で user も閲覧可 |
| 規模 | markdown 1 ファイル | SwiftData @Query で動的生成、UI ビュー (spec 048 with Index View) |
| 実装方針 | 単一ファイル | UI 上の Index View (提案 D) で具現化 ⚠️ **要確認: UI 露出する?** |

### 5.2 log 相当

| 観点 | Karpathy log.md | 知積 |
|---|---|---|
| 中身 | ingest / query / lint の時系列 | 同左 |
| 既存 | なし | os_log でカテゴリ別ログ (Console.app) |
| UI 露出 | Karpathy: markdown で raw 表示 | 知積: **要確認、デフォルト非表示**。Settings の「活動ログ」で opt-in 表示が calm UX 適合 |
| 実装方針 | log.md ファイル | (案) ActivityLog @Model (時系列、append-only)、UI は opt-in |

---

## 6. UI 機能 5 つ (ユーザー視点)

### 6.1 保存記事ビュー (Library)

- 既存 `ArticleListView`
- search bar (spec 044 relevance ranking 実装済)
- swipe で削除 (spec 022)
- **改修なし**

### 6.2 検索

- Library 内 `.searchable()` (spec 044 既存)
- 対象拡張: 既存 8 フィールド + **ConceptPage** (spec 045 含む) + **SavedAnswer** (spec 046 含む)
- 検索 service に MatchField 拡張

### 6.3 クラスター / コミュニティ + 概念カード (知識 Clip タブ)

統合する要素:
- 既存: 最近のあなた (spec 035) / 動的トピック (spec 036) / カテゴリーダイジェスト (spec 018) / 矛盾提案 (spec 037) / Graph 仮説 (spec 041)
- **新規 ★ ConceptPage カード一覧** (spec 045) ← 「あなたが追っている人物・モノ」
- **新規 EntityCommunity カード一覧** (spec 048) ← AI が自動グループ化
- **新規 SavedAnswer カード一覧** (spec 046) ← AI Chat の保存済 Q&A
- **新規 「気づきの種」セクション** (spec 047 WikiLint 結果) ← 同義異名提案 / 概念候補 / 矛盾
- **任意** 「Catalog 全件」サブビュー (提案 D)

### 6.4 ★ Understanding Chat (Main、起動時 default)

**知積独自の差別化機能**、Karpathy 未解決の「理解のボトルネック」を解く UI。

- カード形式で「今のあなたへ」(概念 / 仮説 / 気づき) を 1 つずつ surface
- **「✓ わかった」** → ConceptPage.userUnderstanding up、次のカード
- **「🤔 もっと」** → そのカードを context にして chat 開始 → 理解できるまで深堀り
- chat 答えは compound moment で自動 file (spec 046 SavedAnswer + spec 045 ConceptPage 更新)
- カードキュー source (優先度順):
  1. 最近 ingest で更新された ConceptPage
  2. ユーザーがピン (フォロー) した ConceptPage
  3. userUnderstanding が低い ConceptPage
  4. EntityCommunity が新規発見 / 大きく変化したもの
  5. WikiLint の「次に聞くべき問い」
  6. 久しぶり (idle が長い) の重要 ConceptPage
  7. ランダム織り交ぜ (発見性)

→ 規模: spec 049 で実装、大スコープ (~600-800 行)

### 6.5 General Chat Agent (AI チャットタブ)

- 既存 `ChatTabView` (spec 021/033)
- 何でも聞ける汎用 RAG
- V1: 保存記事のみが答えのソース
- V2: web search opt-in (spec 051)

---

## 7. タブ構成 (推奨: 4 タブ案 B)

```
1. 学習 (Understanding Chat、Main、起動時 default) ★ 新規
2. AI チャット (General agent、既存)
3. 知識 Clip (cluster / digest / community / カタログ、既存拡張)
4. ライブラリ (raw articles + search、既存)
```

- 旧 AI ブレインタブの内容 (graph view / stats) は **知識 Clip に統合**
- Settings は タブではなく AI チャット or ライブラリの toolbar から
- 起動時 default を **「学習」** に変更 (旧: 知識 Clip)

⚠️ **要確認: タブ構成 B でいいか、または A (5 タブ並列) / C (3 タブ radical) を選ぶか**

---

## 8. 知積独自の機能 (Karpathy 未踏)

| 機能 | Karpathy | 知積 | 理由 |
|---|---|---|---|
| **Understanding Chat (Main)** | 課題提起のみ、UI 解決なし | カード + わかった/もっと深堀り | Karpathy 未解決の「理解ボトルネック」UI 解決 |
| **モバイル ambient surface** | デスクトップ前提 | Widget (spec 043) + glanceable card | スマホスキマ消費 UX |
| **on-device 100%** | クラウド LLM 前提 | Foundation Models | プライバシー + 無料 |
| **Voice Input** (V2 候補) | なし | Speech framework (V2 検討) | 通勤・寝る前 UX |
| **Markdown Export** (V2 候補) | 元から markdown | 後付け (spec 提案 G) | データ可搬性 / ロックイン回避 |

---

## 9. 7 提案 (A〜G) → spec 番号マッピング

`04-knowledge-tree-application.md` で提案された 7 つの全部 v2 で位置づけ:

| 元提案 | 名称                             | spec 番号                                          | V1/V2/将来 | 規模               |
| --- | ------------------------------ | ------------------------------------------------ | -------- | ---------------- |
| A   | **ConceptPage @Model (概念ページ)** | **spec 045**                                     | V1       | 中-大 (~600-800 行) |
| B   | **SavedAnswer (Query filing)** | **spec 046**                                     | V1       | 小 (~200-300 行)   |
| C   | **WikiLint 拡張 (健全性)**          | **spec 047**                                     | V1       | 中 (~400-500 行)   |
| D   | **Index View (Catalog)**       | **spec 048** ⚠️ 確認                               | V1 (任意)  | 中 (~300-400 行)   |
| E   | **動的 Schema 進化ループ**            | spec 053 (将来) ⚠️ 確認                              | V3+      | 小 (~200 行) 効果限定  |
| F   | **理解 mode (クイズ)**              | **廃案** → Understanding Chat (spec 049) に統合 ⚠️ 確認 | V1 (統合形) | F 単独はキャンセル       |
| G   | **Markdown Export**            | **spec 052**                                     | V2       | 小 (~200-300 行)   |

追加で確定:
- **spec 048 EntityCommunity 検出 (GraphRAG)** ← 04 で提案、知積独自に必要
- **spec 049 Understanding Chat (Main)** ← 知積独自の核
- **spec 050 写真 / スクショ入力** ← V1 必須
- **spec 043 Widget** ← 旧 ROADMAP 既存
- **spec 051 web search (V2)**

→ **V1 必要 spec = 045, 046, 047, 048 (Community), 049 (Main), 050 (写真), 043 (Widget) = 7 spec**
→ V2 追加 = 051 (web), 052 (export), 048 (Index 任意)
→ V3+ = 053 (動的 schema)

---

## 10. 成功の定義 (Karpathy 5 項目 → 知積版翻訳)

Karpathy 本人発言から導かれる 5 つを、知積 (モバイル一般ユーザー向け) に翻訳:

| Karpathy 版 | 知積版 |
|---|---|
| 維持コストが価値より小さい状態が持続 | **ユーザーが「保存するだけ」で知識が育つ感覚を持続できる**。「整理しなきゃ」ストレスが消える |
| 理解の増幅 (人間の判断・洞察が増える) | **Understanding Chat で「読んだものを自分のものにする」体験ができる**。カード + 深堀り会話のループ |
| 新しいカテゴリの製品として量産化 | **「LLM Wiki for 一般人」の最初の量産製品として確立**。Karpathy が "incredible new product" と呼んだもの |
| agent native, 人間向けマニュアル廃止 | **ユーザーが「保存・聞く・わかる」だけで完結**、教育コスト ゼロ、CLI も markdown 知識も不要 |
| 個人/組織/チームのキュレーション格差 = 知識資産の格差 | **「知識をもつ人」と「もたない人」の格差を埋める一般向け第二の脳**。誰でも持てる Memex |

---

## 11. Karpathy 流ディレクトリ構造 → 知積 @Model マッピング

Karpathy / Tsurubee が示す物理ファイル構造を知積 @Model 群に翻訳:

```
Karpathy llm-wiki/                  →  知積 @Model 群
─────────────────────────────────────────────────────────────────
llm-wiki/                           →  KnowledgeTree.app/
│                                       (SwiftData container)
│
├── CLAUDE.md (schema)               →  Services/ にアプリコードで埋め込み
│                                       Settings で部分 opt-in (例: graphVisible)
│
├── .claude/skills/                  →  Services/ (各 Service ≒ 1 skill)
│   ├── ingest-paper                 →  ArticleSavingService + 全パイプライン
│   │                                    (enrichment → body → extraction → tag →
│   │                                     category → digest → graph → concept)
│   ├── ingest-article               →  同上
│   ├── query                        →  ChatService (Local) + GlobalSearch (新)
│   └── lint                         →  WikiLintService (spec 047 新規)
│
└── vault/                           →  SwiftData store (App Group container)
    │
    ├── raw/ (immutable)             →  Article + ArticleBody @Model
    │   ├── papers/ (PDF)            →  Article (sourceType=pdf、spec 034 経由)
    │   ├── articles/ (web)          →  Article (sourceType=web)
    │   ├── photos/ ★ V1 新規        →  Article (sourceType=image、OCR text 内包)
    │   └── ai_conversations/ ★ V1   →  Article (sourceType=aiChat、構造化抽出)
    │
    └── wiki/ (LLM が自動メンテ)      →  各種 @Model 群
        │
        ├── index.md                  →  (内部) @Query で動的生成
        │                                 (UI 露出は提案 D = spec 048 任意)
        │
        ├── log.md                    →  ActivityLog @Model (新規、内部のみ)
        │                                 UI 露出は Settings opt-in
        │
        ├── papers/                   →  ExtractedKnowledge (1:1 Article)
        │   summaries                    spec 004 既存
        │
        ├── articles/                 →  ExtractedKnowledge (1:1 Article) 同上
        │   summaries
        │
        ├── concepts/ ★ 本体価値      →  ConceptPage @Model (spec 045 新規)
        │   - 人物 / モノ / テーマ        - name + categoryRaw + summary +
        │   - 複数 source 横断 synthesis    crossSourceInsights + 関連 Article +
        │                                   userUnderstanding + isFollowing
        │
        ├── queries/                  →  SavedAnswer @Model (spec 046 新規)
        │   - 良い Q&A の保存             - question + answer + citedArticles +
        │                                   relatedConceptIDs + savedAt
        │
        ├── (新規) entity_communities →  EntityCommunity @Model (spec 048 新規)
        │   - K-means / Louvain クラスター - name (AI 生成) + summary +
        │                                   memberNodes + memberCount
        │
        └── (既存) digests            →  KnowledgeDigest @Model (spec 018 既存)
            - Category 単位サマリー
```

→ **Karpathy 物理ファイル群と 1:1 に @Model 翻訳できる**。差は実装形式のみ、概念は完全等価。

---

## 12. バージョンロードマップ (確定案)

### V1 (MVP、約 3 ヶ月想定)

新規 spec 7 つ:

| spec | 内容 | 規模 | 依存 |
|---|---|---|---|
| spec 043 | Widget (ambient surface) | 中 | 既存 spec 018/035 |
| spec 045 | ConceptPage @Model + Service + UI | 中-大 | spec 040 GraphNode |
| spec 046 | SavedAnswer + Chat filing | 小 | spec 021/033 |
| spec 047 | WikiLint 拡張 | 中 | spec 037 |
| spec 048 | EntityCommunity (Community 検出) + Index View | 中 | spec 040 + 036 |
| spec 049 | Understanding Chat (Main) | 大 | spec 045/046 |
| spec 050 | 写真 / スクショ入力 (Vision OCR) | 中 | 既存 ingest pipeline |

合計: ~7 spec、新規実装 ~3500-4500 行、改修 ~500 行

### V2 (拡張、V1 後)

| spec | 内容 |
|---|---|
| spec 051 | web search (Tool protocol、BYOK Tavily 推奨) |
| spec 052 | Markdown Export (Obsidian 互換 vault 出力) |
| Voice Input | Speech framework 統合 (spec 番号 TBD) |
| 他 AI 会話パース改善 | ChatGPT/Gemini レイアウト判定 |

### V3+ (将来)

| 機能 | 内容 |
|---|---|
| spec 053 | 動的 Schema 進化ループ (LLM が schema 改善提案) |
| YouTube transcript | URL 共有で取り込み |
| 音声入力 (Voice memo / podcast) | Speech framework + Whisper-like |
| Mac / iPad 展開 | Multi-platform |
| iCloud sync | Cross-device |
| 個人特化 fine-tune | wiki から個人モデル生成 (Karpathy "Further explorations") |

---

## 13. 5 vs 5 差分 / 共通点 (v2 確定版)

### 重要な「違い」5 つ (差分順)

| # | 項目 | Karpathy LLM Wiki | 知積 (v2 構想) |
|---|---|---|---|
| **1** | **使うシーン** | 集中 research セッション (デスクトップ前、1-2 時間) | スマホスキマ時間 (通勤 / 寝る前 / 5 分) |
| **2** | **データ実装形式** | Markdown ファイル群、LLM 直接編集 + git 履歴 | SwiftData @Model、**LLM 直接編集 (raw 以外) + Settings で部分 user 編集**。原則 (LLM が wiki を所有) は **同じ** |
| **3** | **★ 学習 UI** | **未解決の課題** ("理解はボトルネック" と認めつつ UI 解決なし) | **カード学習 + 「わかった/もっと」深堀り会話** が知積独自の解答 |
| **4** | **LLM 実行環境** | Claude Code / Codex / GPT-4 クラウド API (課金 + 外部送信) | Apple Intelligence Foundation Models 完全 on-device (無料 + プライバシー) |
| **5** | **ターゲット** | 研究者・engineer (CLI + Obsidian + Markdown literacy 前提) | iPhone 一般ユーザー (タップだけで完結、教育コスト ゼロ) |

### 重要な「共通点」5 つ (本質順)

| # | 項目 | 中身 |
|---|---|---|
| **1** | **bookkeeping の LLM 代行** | 人間が「読む・問う・考える」、LLM が「整理・繋ぐ・更新・矛盾検出」を全部やる根本思想 |
| **2** | **Knowledge compounds (複利的蓄積)** | RAG の使い捨て検索ではなく、**持続的に成長する成果物**。新ソースで wiki が太る |
| **3** | **「概念ページ」が本体価値** | 単一記事のサマリーじゃなく、複数ソース横断 synthesis (知積 ConceptPage = Karpathy concept page) |
| **4** | **Compound moment (filing back)** | Query 答えが消えず wiki に永続化 (Karpathy: markdown page 化 / 知積: SavedAnswer + ConceptPage 更新) |
| **5** | **3 オペレーション (Ingest / Query / Lint)** | アーキテクチャ完全同型: 新ソース取り込み + 質問応答 + 定期 health check |

### 1 行で言うと

**「知積は Karpathy LLM Wiki の中核思想 (3 層 + 3 オペレーション + bookkeeping 自動化 + compound + 概念ページ) を完全継承しながら、Karpathy 自身が未解決と認めた『理解のボトルネック』を Understanding Chat で初めて解きに行く、一般人向けの mobile native 実装」**

---

## 14. 残課題 / 要確認質問 (8 個)

v2 を書く中で defaults を埋めたが、要 user 確認:

### Q1 [§7 タブ構成] 4 タブ案 B で確定?

- A: 5 タブ並列
- **B: 4 タブ (AI ブレイン → 知識 Clip 統合)** ← 私の推奨、v2 採用
- C: 3 タブ radical 簡略化

→ 確定?

### Q2 [§7 起動 default] 「学習」タブ default で OK?

- 旧: 知識 Clip
- 提案: **学習 (Understanding Chat)**
- 理由: 中核体験を最初に見せる

→ OK?

### Q3 [§5.1 Index View UI 露出] 提案 D を V1 に入れるか?

- A: 入れる (Catalog タブ or 知識 Clip 内サブビュー、規模 中)
- **B: V1 は内部のみ、UI 露出は V2** ← デフォルト推奨
- C: そもそも不要 (検索 spec 044 で代替)

→ どれ?

### Q4 [§5.2 log UI 露出] ActivityLog を user に見せるか?

- A: Settings opt-in でのみ表示 (デフォルト OFF) ← v2 案
- B: 知識 Clip 内に常時表示 (Karpathy の log.md 同等)
- C: 表示しない、内部のみ

→ どれ?

### Q5 [§9 提案 E 動的 Schema 進化] V3+ で残す? 完全廃案?

- A: V3+ に残す (規模小、効果限定的)
- **B: 完全廃案** ← デフォルト推奨
- 理由: 「優しい第二の脳」原則と相性悪い、user に schema 設計判断を求めるのは負担

→ どれ?

### Q6 [§9 提案 F 理解 mode (クイズ)] 完全廃案 → Main に統合で OK?

- A: クイズ機能を spec 049 内に部分統合
- **B: 完全廃案、Main の「カード + わかった/もっと」UX に置き換え** ← v2 採用
- 理由: クイズ = テスト感 = 不安喚起 = Constitution V 違反リスク

→ OK?

### Q7 [§3] 写真入力の範囲

- A: OCR テキスト抽出のみ (V1 で確定) ← v2 案
- B: 画像内容理解も V1 で (Foundation Models vision がない、技術的に困難)

→ A で OK?

### Q8 [§3] 他 AI 会話 (ChatGPT/Gemini) の入力主軸

- A: スクショ → OCR + 発話者構造判定 (LLM で Q&A 分離)
- B: ユーザーが手動でテキスト copy/paste
- C: 両方サポート、A メイン
- → 推奨は **C** (両方、A メイン)

→ どれ?

---

## 15. 決定ログ

| 日付 | 決定事項 | 根拠 |
|---|---|---|
| 2026-05-17 | v2 作成 | user 指示「全部整理して v2 作って」 |
| 2026-05-17 | 3 層アーキテクチャ Karpathy 完全踏襲 | Karpathy 原則維持 |
| 2026-05-17 | データ形式の差分修正 (raw 以外は LLM 自由編集) | user 指摘「2 番目も raw 以外は LLM 自由」 |
| 2026-05-17 | 7 提案 (A〜G) を spec 番号 045〜052 にマッピング | 4 章を v2 で正式統合 |
| 2026-05-17 | 提案 F (クイズ) → Main 統合で廃案 | calm UX 原則、unless Q6 で反論 |
| 2026-05-17 | 成功の定義を 知積版 5 項目に翻訳 | user 指示「これも参考にして」 |
| 2026-05-17 | Karpathy 物理構造 → 知積 @Model マッピング table 化 | user 指示「file の作り方もこれで」 |
| 2026-05-17 | V1 MVP = 7 新規 spec (045-050 + 043) | §12 ロードマップ |
| TBD | Q1-Q8 回答 | 議論待ち |
| TBD | VISION.md 更新承認 | Q1-Q8 全回答後 |

---

## 16. 次のアクション

1. **ユーザー**: Q1〜Q8 に回答
2. **私**: 回答反映 → v3 (もしあれば) or VISION.md 更新案作成
3. **ユーザー**: VISION.md 更新内容を approve
4. **私**: VISION.md 実書き換え (`vision-spec-035-038` ブランチ or 新ブランチ)
5. **私**: spec 045 (ConceptPage) から実装着手、順次 V1 spec 群を消化

---

## 17. 矛盾チェック (v2 内部一貫性)

書きながら検出した内部矛盾を解消した結果:

| 検出した矛盾 / 不明点 | v2 での解決 |
|---|---|
| 「LLM が wiki を所有」(Karpathy) vs 「user が rename/merge できる」(知積 spec 024/041) | **§2 で hybrid 明示**: LLM が主、user は補正可能 |
| 提案 F (クイズ) と Main の関係不明 | **§9 + Q6 で F → Main 統合の方針案明示** |
| ConceptPage と既存 KnowledgeDigest の粒度差 | **§6.3 で「Category 単位 = Digest、Entity/Concept 単位 = ConceptPage」と並立を明示** |
| Index View が V1 必須かどうか | **§5.1 + Q3 で「内部実装は必須、UI 露出は V2」を default、Q3 で確認** |
| Karpathy「one-by-one 監督」と知積「自動 batch」の哲学差 | **§4.1 で表として明示、判断は知積 = 一般ユーザー前提として後者を採用** |
| 提案 E (動的 Schema) を V1 に入れるか | **§9 + Q5 で V3+ or 完全廃案、defaults は廃案** |
| 写真入力で vision LLM が無いこと | **§3 で OCR テキスト経路を明示、画像内容理解は技術的に V1 不可** |
| 他 AI 会話の入力経路 | **§3 で OCR + 構造判定 (V1)、手動 paste も並列、Q8 で主軸確認** |

→ 内部矛盾は全て解消、残るは user 確認待ちの 8 項目のみ。

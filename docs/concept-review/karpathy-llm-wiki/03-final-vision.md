# 03 — 最終的にどうなりたいか (Final Vision)

## Status: WIP (初稿、2026-05-16)

---

## 1. Karpathy 本人が明示している最終像

LLM Wiki は単独製品の vision というより、**より大きな思想 (Software 3.0 / Memex 実現 / 理解の増幅) の象徴例**。彼の発言を整理すると 3 つのレベルがある。

### レベル 1: 個人のための実用ツール (現在)

> "tools to enhance understanding"

- 個人が大量の情報を読み・繋げ・蓄積する作業を LLM に委託
- Obsidian + Claude Code / Codex で動く現在の運用
- 維持コスト ≈ 0、wiki が compounding
- 「自分自身のための第二の脳」

### レベル 2: 製品化された新カテゴリ (期待)

> "I think there is room here for an incredible new product instead of a hacky collection of scripts."

- 現在は CLI + Obsidian + 個別 skill の組み合わせ
- これを **専用 UI + データモデル + ワークフロー一体型の製品** にできる余地
- 個人 / チーム / 企業向けの市場
- Karpathy 自身は製品化しないと明言、誰かが作ることを期待

### レベル 3: Software 3.0 ネイティブ世界 (5-10 年)

動画より:

> "completely neural computers in a certain sense [...] imagine a device taking raw videos or audio into basically what's a neural net and uses diffusion to render a UI that is kind of like unique for that moment"

- ニューラルネットが **ホストプロセス**、CPU が co-processor
- UI が diffusion で動的レンダリング
- agent native infrastructure (人間向け doc 廃止、agent 向け doc が主流)
- agent 同士の対話で人間の用事が処理される ("I'll have my agent talk to your agent")

→ LLM Wiki はこの世界への踏み台、agent native knowledge stack の最初の実例。

---

## 2.「成功」の定義 (本人の言葉から推定)

明示はされていないが、本人発言を綴ると以下が成功条件:

| 条件                                     | 根拠                                                                                         |
| -------------------------------------- | ------------------------------------------------------------------------------------------ |
| **維持コストが価値より小さい状態が持続**                 | "Humans abandon wikis because the maintenance burden grows faster than the value." を反転したもの |
| **理解の増幅 (人間の判断・洞察が増える)**               | "tools to enhance understanding"                                                           |
| **新しいカテゴリの製品として量産化**                   | "incredible new product"                                                                   |
| **agent native, 人間向けマニュアル廃止**          | "I don't want to do anything. What is the thing I should copy paste to my agent?"          |
| **個人 / 組織 / チームのキュレーション格差が知識資産の格差に直結** | Memex の系譜、bookkeeping の社会化                                                                 |

---

## 3. ターゲット領域 (gist が挙げる適用例)

gist が列挙する LLM Wiki の応用領域。これが彼の想定する「ユーザー像」を示唆する:

| 領域 | 詳細 |
|---|---|
| **Personal (個人)** | 自分の目標 / 健康 / 心理 / 自己改善のトラッキング、日記・記事・podcast の蓄積 |
| **Research (研究)** | 数週間〜数ヶ月のディープダイブ、論文 / レポートから thesis を進化 |
| **Reading a book** | 章ごとに ingest、キャラ・テーマ・プロット軸でページ作成 (Tolkien Gateway 並の個人 wiki) |
| **Business/team** | 内部 wiki、Slack / 議事録 / 顧客通話を流す、人間レビュー可 |
| **Competitive analysis / due diligence / trip planning / course notes / hobby deep-dives** | 「時間とともに累積し、整理が欲しい」あらゆる文脈 |

→ Karpathy の想定は **特定領域に閉じない汎用パターン**。「時間とともに知識が累積する」あらゆる文脈に適用可能。

---

## 4. 1 年後 / 3 年後 / 10 年後の射程

明示はないが、現状からの自然な発展軌道:

### 1 年 (2027 春想定)

- 製品: 「Obsidian + LLM 統合」型の専用アプリが複数登場
  - Web Clipper レベルの UX を内蔵
  - schema が pre-built (research / business / personal モード)
  - lint が自動スケジュール
- 一部の知識ワーカー (研究者・consultant・analyst) が標準ツールとして採用
- まだ「techies の道具」、一般化はしていない

### 3 年 (2029)

- 製品: モバイル + デスクトップ両対応の knowledge OS
  - ingest が podcast / 動画 / 会議文字起こしまで自動
  - agent 同士の連携 (Tsurubee の wiki が他の研究者の wiki と「対話」)
  - 個人特化 fine-tune モデルがコモディティ化
- 教育 / 法律 / 医療など「知識資産が成果に直結する職種」で標準
- Karpathy が触れた "agent representation for people" が現実に

### 10 年 (2036)

- 製品: 知識 OS が PC の OS のような基盤
- Software 3.0 ネイティブ UI (動的 diffusion rendering、agent first)
- 個人の wiki = アバター / digital twin
  - その人の判断パターンを embed
  - 死後も wiki が稼働して「彼ならこう考えただろう」と回答
- Memex のフル実現

---

## 5.「ユーザー像」の進化

Karpathy 自身がツールを使う側として描く像:

| フェーズ | 人間の役割 | LLM の役割 |
|---|---|---|
| 現在 | キュレーション + 直接編集 + 質問 + 監督 | サマリー + 整理 + ファイリング + 多くの bookkeeping |
| 1 年後 | キュレーション + 質問 + 戦略指示 | wiki 全自動メンテ + 自動 lint + 提案 |
| 3 年後 | テーマ選択 + 「何を知りたいか」 + 統合判断 | sourcing 提案 + 横断 synthesis + 個人特化 fine-tune |
| 10 年後 | 「方向性」のみ | sourcing + ingest + synthesis + 思考の補助シミュレーション |

人間の役割が **「やる」から「方向づける」に縮退** していくが、Karpathy は「**understanding** を outsource できない」点を不変としている。

---

## 6.「これは何の新カテゴリか?」(製品分類)

Karpathy のフレームに従うと:

- **NOT** ノートアプリの拡張 (Obsidian / Notion の next gen ではない)
- **NOT** RAG ベース AI 検索 (NotebookLM / Glean とは別)
- **NOT** メモ自動分類 (Bear / Roam Research の AI 版でもない)

**新カテゴリの本質**:
- 「読んだものを蓄積する」 = 既存
- 「蓄積を能動的に整理・接続する」 = LLM Wiki 固有
- 「整理結果を context として再利用 (Query)」 = compounding
- 「最終的に個人の理解を増幅する」 = 目的

→ **個人 knowledge OS** または **第二の脳 (Second Brain) の真の実現**。Tiago Forte の "Building a Second Brain" の概念は人間が頑張る前提だったが、LLM Wiki は LLM が代行する。

---

## 7. 競合・近接製品との位置づけ

| 製品 | LLM Wiki との関係 |
|---|---|
| **NotebookLM** | RAG 型、クエリ時統合、蓄積なし。Karpathy が明示的に「足りない」と指摘 |
| **ChatGPT file upload** | NotebookLM と同型、worse maintenance |
| **Obsidian + Smart Connections plugin** | 部分実装。LLM 連携あるが ingest/lint/query の autonomous 運用までは届かない |
| **Mem.ai** | "Self-organizing workspace" を謳う AI ノート。方向性近いが「概念ページの自動生成」までは見える形では実装されていない |
| **Reflect** | AI ノートアプリ、要約・繋がり提案あり。LLM Wiki の自動メンテほどの規律性はない |
| **Roam Research / LogSeq** | Backlink を売りにする bidirectional notes、人間が手で書く前提 |
| **Anytype** | Object-graph 型。schema 重視だが LLM 統合は限定的 |
| **Heptabase** | Card-based visual thinking、AI 機能あるが Software 2.0 寄り |
| **Tiago Forte's BASB (Building a Second Brain)** | 方法論、ツール非依存、人間が全 maintenance |

→ **未だに「LLM Wiki を製品化したもの」は存在しないか、市場で広く認知されていない**。これが Karpathy が "incredible new product" と言う所以。

---

## 8. KnowledgeTree (知積) との位置関係 — 暫定

詳細は `04-knowledge-tree-application.md` で書くが、暫定の位置づけ:

- 知積は **モバイル特化の Second Brain 候補** (iPhone first)
- 既に「保存 → 自動抽出 → カテゴリー → タグ → グラフ → digest → AI Chat」のパイプラインを持つ
- ただし **概念ページの自動生成という Karpathy の中核アイデアは未実装**
- 既存 KnowledgeDigest は「カテゴリー単位のまとめ」だが、Karpathy の「概念単位のページ」とは粒度が違う

→ 知積は **Karpathy の発想を一部すでに先取りしているが、概念ページの compounding という核は未着手**。これが今後の vision update の最大論点。

# 02 — どう実現しようとしているか (Implementation Approach)

## Status: WIP (初稿、2026-05-16)

---

## 1. 三層アーキテクチャ

Karpathy の LLM Wiki は **3 層** で構成される (gist より):

```
┌─────────────────────────────────────────────────────────────┐
│ Schema (CLAUDE.md / AGENTS.md)                              │
│   - wiki の構造規約、命名規則、ワークフロー定義             │
│   - 人間が書く、LLM が参照する                              │
│   - 「LLM を「規律あるwiki 管理人」化する設定ファイル」     │
└─────────────────────────────────────────────────────────────┘
                          ↓ guides
┌─────────────────────────────────────────────────────────────┐
│ Wiki (LLM が所有、人間は読む)                                │
│   - サマリーページ (一次資料 1:1)                            │
│   - 概念ページ (複数ソース横断 synthesis、★ 本体価値)        │
│   - query ページ (Q&A 結果のファイリング)                    │
│   - index.md (カタログ)、log.md (時系列ログ)                 │
└─────────────────────────────────────────────────────────────┘
                          ↑ reads
┌─────────────────────────────────────────────────────────────┐
│ Raw sources (immutable、人間がキュレーション)                │
│   - 論文 PDF、Web 記事、画像、データファイル                 │
│   - LLM は読み取り専用                                       │
└─────────────────────────────────────────────────────────────┘
```

### 各層の所有権

| 層 | 書き手 | 読み手 | 目的 |
|---|---|---|---|
| Raw | 人間が curate / drop | LLM (read-only) | source of truth |
| Wiki | **LLM が全部書く** | 人間 (browse) | compounding 知識ベース |
| Schema | 人間 (LLM と共進化) | LLM | wiki 規律の定義 |

> "You and the LLM co-evolve this [schema] over time as you figure out what works for your domain."

Schema は **静的設定ではなく動的成果物**。運用しながら LLM 自身に「規約と実体の乖離」を見つけさせて改善する (Tsurubee 記事 Step 3)。

---

## 2. 三つのオペレーション (Ingest / Query / Lint)

### Ingest (取り込み)

新しいソースを `raw/` に置いて LLM に処理を依頼。**1 ソースの ingest で 10〜15 ページが波及更新される**。

具体フロー (gist より):
1. LLM がソースを読む
2. 重要点をユーザーと議論
3. サマリーページを wiki に作成
4. index.md を更新
5. 関連 entity / concept ページを横断更新
6. log.md に追記

Tsurubee の実装スキル (`ingest-paper`) の核:
- 「3〜7 個の主要概念」を抽出
- 既存 concept ページがあれば追記、なければ新規作成
- **概念ページの「横断的知見」セクションを更新するのが価値の本体**

ingest スタイルは 2 通り:
- **one-by-one + 監督** (Karpathy 自身が推奨): 一本ずつ ingest、要約を読みながら誘導
- **batch + 任せる**: 多数ソースを一気に投入、監督薄

→ Tsurubee は明示的に one-by-one + 自分でソース選択を採用。自動 ingest (例: arXiv 新着自動投入) は「理解ボトルネック」を悪化させるとして避けている。

### Query (質問)

wiki に質問を投げる。LLM が関連ページを探して合成し、回答を出す。

**重要な insight**: 良い回答は wiki に新ページとして file back する。

> "good answers can be filed back into the wiki as new pages. A comparison you asked for, an analysis, a connection you discovered — these are valuable and shouldn't disappear into chat history."

→ **Q&A も wiki の compounding artifact の一部**。ChatGPT のチャット履歴に消えるのは損失。

出力形式の多様化: markdown ページ / 比較表 / Marp スライド / matplotlib グラフ / Obsidian Canvas。「質問に最も適した形」を LLM に選ばせる。

### Lint (健全性チェック)

定期的に wiki の整合性チェックを LLM に依頼。検出対象 (gist より):

- ページ間の矛盾
- 新しいソースで supersede された古い主張
- 入リンクのない orphan ページ
- 概念として言及されているがページがないもの
- 欠落クロスリファレンス
- web search で埋められるデータギャップ

Tsurubee 記事の補足:
- 「壊れた wikilink」「孤立ページ」「同義異名 (Apple vs アップル、reinforcement-learning vs rl)」を検出
- LLM が「次に調べるべき問い」を提案

→ **Lint = wiki が時間とともに荒れるのを防ぐ予防整備**。RAG にはない概念。

---

## 3. 特殊ファイル: index.md と log.md

両者は wiki ナビゲーション用の対照的なファイル。

### index.md (コンテンツ指向、ページ catalog)

- 全 wiki ページの一覧 + 1 行サマリー + メタデータ
- カテゴリ別整理 (entities / concepts / sources)
- ingest のたびに LLM が更新
- **質問時に LLM が最初に読む**: index → 関連ページに drill down

> "This works surprisingly well at moderate scale (~100 sources, ~hundreds of pages) and avoids the need for embedding-based RAG infrastructure."

→ **embedding RAG は不要**。100 ソース規模なら index + grep で十分。

### log.md (時系列、追記のみ)

- ingest / query / lint の出来事を時系列で記録
- 一貫プレフィックス (例: `## [2026-04-02] ingest | Article Title`) で grep 可能
- wiki の進化タイムラインを保持

---

## 4. ツーリング (Obsidian エコシステム)

Karpathy は具体ツールを示している:

| ツール | 役割 |
|---|---|
| **Obsidian** | wiki の IDE。markdown ビュー + graph view + plugin |
| **Obsidian Web Clipper** | ブラウザ拡張、Web 記事を markdown 化して raw に投入 |
| **Marp** | markdown ベースのスライドフォーマット (Obsidian plugin) |
| **Dataview** | wiki ページの frontmatter (tags / dates) で動的テーブル生成 |
| **qmd** | markdown ファイルのローカル検索エンジン (BM25 + vector + LLM rerank)、CLI + MCP |
| **git** | wiki は markdown の git repo、version history と branching が無料 |
| **Claude Code / OpenCode / Codex** | LLM エージェント本体 |

→ **「Obsidian = IDE、LLM = プログラマ、wiki = codebase」のフレーミングが運用上の核**。

### Schema ファイル

`CLAUDE.md` (Claude Code) または `AGENTS.md` (Codex) などエージェント別の規約ファイル。Tsurubee 例の Claude Code 構成:

```
llm-wiki/
├── CLAUDE.md                       # schema
├── .claude/skills/
│   ├── ingest-paper/SKILL.md
│   ├── ingest-article/SKILL.md
│   ├── query/SKILL.md
│   └── lint/SKILL.md
└── vault/                          # Obsidian Vault
    ├── raw/
    │   ├── papers/
    │   └── articles/
    └── wiki/
        ├── index.md
        ├── log.md
        ├── papers/
        ├── articles/
        ├── concepts/               # ★ 本体価値
        └── queries/
```

`SKILL.md` が各オペレーションを定義 (ingest 手順 / 概念ページの構造 / 横断的知見セクションの作り方など)。

---

## 5. 「概念ページ」が本体価値

Tsurubee 1 ヶ月運用で得た最大の洞察:

> 「LLM Wiki の真価が要約集の便利さではなく、複数のソースを横断して整理された概念ページが LLM の手で自動的に組み上がっていくこと、すなわち『繋げる力』にある」

| ページタイプ | 性質 | 代替可能? |
|---|---|---|
| サマリーページ (一次資料 1:1) | 1 ソースの内容凝縮 | NotebookLM / ChatGPT で代替可能 |
| **概念ページ (複数ソース横断)** | **複数ソースの統合・対立・補完を合成** | **代替不能、LLM Wiki 固有の価値** |
| Query ページ | 質問への合成回答 | 通常のチャットでも作れるが、ファイリングで蓄積 |

### Tsurubee の具体事例

**事例 1 (多数同種ソースの統合)**: AI Scientist 系論文 10 本を順次 ingest
- LLM が `automated-scientific-discovery.md` 概念ページを自動生成・更新
- 個別論文に散らばっていた評価方式が **4 つのカテゴリ** に整理: (1) 標準化ベンチマーク (2) 人間ピアレビュー (3) LLM-as-Judge (4) wet-lab 検証
- 「LLM-as-Judge の評価バイアス」という単一パターンの 3 観測面 (2.3 ポイント差 / 9/10 reject / 68 ポイント変動) を別論文間で統合

**事例 2 (少数異質ソースの対比抽出)**: Altman 氏 1 本 + Amodei 氏 3 本のエッセイ
- 別々のタイミングで ingest
- AGI 定義の **対比軸が自動生成**: Altman = 段階移行 (AGI → superintelligence)、Amodei = 機能要件 (5 つの能力リスト)
- 「比較分析を意図して投入したわけではない」のに対立軸が立ち上がる

→ **「繋げる力」は LLM が新ソース ingest 時に既存ページを読み直して整合性を取るループから生まれる**。NotebookLM などの「クエリ時統合」とは質的に違う。

---

## 6. 役割分担: 人間 vs LLM

| タスク | 担当 |
|---|---|
| ソースキュレーション (何を読むか) | **人間** |
| ソース投入 (ingest トリガー) | 人間 |
| 質問 (何が知りたいか) | **人間** |
| 要約・サマリー生成 | LLM |
| 概念抽出・概念ページ作成 | LLM |
| クロスリファレンス維持 | LLM |
| 矛盾検出 | LLM |
| 数十ページの一貫性維持 | LLM |
| Linting / 規約整備 | LLM (人間が方針指示) |
| 出力形式選択 (slide / table / chart) | LLM (人間が初期指定) |
| **意味の理解、判断、方向性** | **人間 (不可代替)** |

> "Humans abandon wikis because the maintenance burden grows faster than the value. LLMs don't get bored, don't forget to update a cross-reference, and can touch 15 files in one pass. The wiki stays maintained because the cost of maintenance is near zero."

→ **核は「維持コスト ≒ 0」化**。人間が wiki を諦めない理由ができる。

---

## 7. 拡張ロードマップ (Karpathy が示唆する次)

X 投稿末尾の「Further explorations」:

> "As the repo grows, the natural desire is to also think about synthetic data generation + finetuning to have your LLM 'know' the data in its weights instead of just context windows."

→ wiki を context として使うだけでなく、weights に焼き付ける fine-tuning パイプライン。これが実現すると wiki は「学習データ生成器」になり、ユーザーの個人特化モデルが作れる。

X 投稿の結語:

> "I think there is room here for an incredible new product instead of a hacky collection of scripts."

→ **「素晴らしい新しい製品の余地がある」と本人が明言**。誰かが製品化することを期待している。

---

## 8. 未解決 / 限界 (Tsurubee 指摘)

### 限界 1: 人間の「理解」がボトルネック

> 「LLM が概念ページを綺麗に整理してくれても、それを人間が読んで自分の理解として消化しないと、本当の意味で『自分の知識』にはならない」

具体問題:
- wiki が増えると全ページを読みきれない
- 「辞書的な使い方」(query を投げて回答だけ消費) に堕すると、人間側の能動的理解が深まらない
- Karpathy の「人間はほとんど直接編集しない」設計は、ドメイン理解を深める動機を弱める可能性

Tsurubee の対策:
- ソース選定を意図的に「自分の手で」(自動 ingest 拒否)
- 時間を見つけて Obsidian で概念ページを能動的に読む
- 重要ソースは原文も読む

→ 「読み解く作業は自動化できない」。

### 限界 2: 「辞書的消費 vs 能動的理解」のテンション

これは Karpathy 自身も動画末尾で問題視している ("I'm becoming a bottleneck")。LLM Wiki だけでは解決しない。**製品化する側の責任で「能動的理解を促す UI」を設計する必要がある**。

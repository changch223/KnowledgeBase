# 07 — 外部リファレンス調査ノート

## Status: WIP (初版、2026-05-23)

---

## 0. このドキュメントの位置づけ

`05-product-vision-consolidated.md` (v2) で固めた知積 v2 ビジョンを実装に落とす前に、**外部で先行している類似事例・関連技術** を整理する参照ノート。各事例から「取り込むべき pattern」と「取り込まない判断」を明示し、 spec 045-052 の設計判断に反映する。

対象 (2026-05 時点で追加されたもの):

1. **SAGE** — 自己進化型 GraphRAG (Writer/Reader 相互強化学習)
2. **Tableau Auto Knowledge Graph** — 2026/07 GA 予定、Salesforce Waii 買収ベース、MCP 前提
3. **cortex Product Graph (cpg)** — airCloset CTO 辻氏 / AIハーネス engineering の実例、JSDoc-based KG

→ 共通テーマ: **「自己進化 + Graph + AI Agent + Knowledge as compounding artifact」**。Karpathy LLM Wiki と思想的に強く共鳴。

---

## 1. SAGE: 自己進化型 GraphRAG

### 1.1 一文要約

**「書き込み (Writer) と読み込み (Reader) がお互いを強化学習で鍛え合うことで、データ特性に自動最適化される自己進化型 GraphRAG」**。最大 +9.1pt、NQ では R@2 で +36.9pt の精度改善。

### 1.2 仕組み

- データを **(主語, 関係, 目的語) のトリプル** でグラフに保存
- Writer は LLM、強化学習で「正解を引き出せるトリプル抽出方針」に最適化
- Reader は 3 工夫: **質問分解 (シノニム考慮) + ソフトアドレッシング + 評価伝搬**
- Reader は 2 学習: **構造 (関係性一般化) + 内容 (重みづけ)**
- 検索時間は他手法より最速 (仕組みがシンプル)

### 1.3 知積への示唆

| 取り込みタイミング | 内容 |
|---|---|
| **V1 で取り込む** | なし — 強化学習は on-device で重い |
| **V2 候補** | **Reader 側の「質問分解 (シノニム考慮)」** ← Foundation Models で 1 prompt 追加で実装可能、~50 行 / ChatService に組み込み |
| V3+ 候補 | 「ソフトアドレッシング + 評価伝搬」 (純アルゴリズム、Swift で実装可能、spec 045 ConceptPage / spec 048 Community 検索精度改善) |
| 取り込まない | Writer 強化学習 — on-device Foundation Models で fine-tune 不可、Karpathy の "Further explorations" 路線 |

### 1.4 関連 spec

- spec 045 (ConceptPage) - 検索精度改善時に SAGE Reader 3 工夫を参考
- spec 048 (EntityCommunity) - Community 内 query で SAGE 評価伝搬パターン候補
- spec 049 (Understanding Chat) - 質問分解で「もっと」深堀り時の候補生成

---

## 2. Tableau Auto Knowledge Graph (AKG)

### 2.1 一文要約

**「データスタック全体のメタデータを 1 グラフ層に unify し、ユーザーエンゲージメントで継続再学習する自己進化型 KG エンジン」**。2026/07 GA、Salesforce が買収した Waii (text-to-SQL) が技術母体、**MCP 前提**で外部 AI (Claude/ChatGPT/Slack/Teams 等) から共通アクセス可能。

### 2.2 重要ポイント

- **Knowledge Engine** ピラー (Agentic Analytics Platform 6 本柱の 1 つ)
- 3,300 万件のセマンティックモデルを grounding 基盤として活用
- **Open Semantic Interchange** (Snowflake / dbt 共同) で拡張可能
- 単独では動作せず **MCP 経由で初めて機能** (「ユニバーサル翻訳機」位置づけ)
- ユーザーエンゲージメントで継続学習 = **使うほど賢くなる**

### 2.3 知積への示唆

| 観点 | Tableau AKG | 知積 v2 |
|---|---|---|
| 規模 | エンタープライズ (3300 万 semantic model) | 個人 (数百〜数千 ConceptPage) |
| データ源 | 企業のデータスタック全体 | スマホで触れた情報すべて |
| MCP 露出 | 必須 (外部 AI から使う前提) | **将来検討候補** ← 知積の Wiki を MCP 公開できれば Claude/ChatGPT からも参照可 |
| 自己進化 | ユーザー再学習 | (V1) 自動 ingest で compound、(V3+) 個人特化 fine-tune |

### 2.4 取り込むかの判断

| 要素 | 判断 |
|---|---|
| **「使うほど賢くなる」自己進化** | ✅ 既に取り込み済 (ConceptPage compound + Understanding Chat フィードバック) |
| **MCP 露出** (知積 wiki を外部 AI から参照可能に) | **V3+ 候補** ← ローカル MCP server を立てれば Mac の Claude/Cursor から知積 wiki を query 可能、ただし mobile では意味薄い |
| **オープンスキーマ標準** (Open Semantic Interchange 相当) | V1-V2 範囲外、知積規模では不要 |

### 2.5 関連 spec

- spec 052 (Markdown Export、V2) — 似た役割 (他ツールから知積 wiki を参照可能にする)
- 将来 spec — MCP server 公開 (Mac/iPad app での運用時)

---

## 3. cortex Product Graph (cpg) ★ 最重要参考事例

### 3.1 一文要約

**「コード・ドキュメント・DB スキーマ・インフラ定義を JSDoc アノテーションをベースに 1 グラフ統合し、AI ハーネスとして MCP 経由で AI agent に提供する社内基盤」**。airCloset CTO 辻氏が 4 ヶ月で本格開発、現在月 500+ PR 自動マージ、非エンジニア (PMO 等) も PR を出せる。

→ **「Karpathy LLM Wiki」「GraphRAG」「AI Harness Engineering」の交差点に位置する実装事例**。知積 v2 設計の最も近い実例。

### 3.2 重要ポイント (知積 v2 に直接効くもの)

#### A. 「コードからの推論を捨て、JSDoc を SSoT に」

- 静的解析だけの code-graph は「機械的に正確だが意味の重みづけがない」
- 解決: **すべての宣言に専用 JSDoc 5 タグを書く**
  - `@graph-node`: ノード種別
  - `@graph-stack`: 所属 stack
  - `@graph-domain`: ビジネスドメイン
  - **`@graph-business`: 何をやるかの固有説明 (Embedding 入力の本体)** ← 最重要
  - `@graph-connects`: 接続先 (複数可、エッジ生成)
- JSDoc を選んだ理由: **ランタイムゼロ依存、コードと物理的に同じ場所、AST だけで取れる、PR diff に出る、IDE ホバーで二次利用**

**知積への翻訳**: コードの JSDoc に相当するのは **@Model のコメント or ConceptPage.summary 自体**。「説明文を物がある場所に書く、それが Embedding 入力になる」原則は完全に同じ。

#### B. Runbook Pattern (★ 知積 Understanding Chat に直接応用可)

- **MCP ツール返却値の末尾に「次のアクション候補」が必ず付く**
- AI は次に何をすべきか迷わない、レスポンス見て次のツール call を即決定
- 例: 検索結果 → 「コード詳細を見るには `get_product_graph_node_detail("...")` を、上流を辿るには `trace_product_graph_connections(...)` を」

**知積への翻訳**: Understanding Chat (spec 049) のカードに **「次のアクション候補」を内蔵** すべき。
- 例: ConceptPage カード → 「✓ わかった」「🤔 もっと」+ 「関連カード: A / B / C」(次に surface する候補)
- AI Chat 答え → 「次に聞くべき問い (3 候補)」を末尾に inline 表示

#### C. usecase パラメータでツール挙動を切り替え

- 同じツールでも `usecase: "design"` / `"impact"` / `"bug"` / `"code-review"` で返答の優先度を変える
- AI に「いま自分は何の調査をしているか」を宣言させる
- 効果: 同じグラフから違う角度の応答が得られる

**知積への翻訳**: ChatService.send に **usecase 引数追加**:
- `usecase: "deepdive"` — Understanding Chat の「もっと」から呼ばれる
- `usecase: "global"` — 知識 Clip タブで「全体まとめ」を聞く
- `usecase: "specific"` — AI チャットで質問
- `usecase: "review"` — WikiLint の検出根拠を聞く

各 usecase で retrieval 戦略 / prompt / 返答形式を分岐。

#### D. ハルシネーションの位置を変える設計

cpg の判断:
- graph 構築フェーズ: **ハルシネーションゼロ** (AST 解析 + BQ MERGE は決定論的、LLM 介在なし)
- graph 参照フェーズ: **ハルシネーションゼロ** (BQ から事実のみ返却)
- JSDoc 記述フェーズ: ハルシネーションの入口、ただし自動 PR レビューで物理的に潰す

**知積への翻訳**: ConceptPage 生成時の Foundation Models 抽出だけがハルシネーション入口、それ以外 (検索 / 表示 / 編集) は決定論的。spec 045 の Generable Guide 強化 + WikiLint で位置を絞る。

#### E. CLAUDE.md (Schema) で「まずグラフを叩け」を強制

- ルート CLAUDE.md に「Product Graph MCP を最初に叩け、grep は補完」と明記
- 「cpg が落ちている場合は作業即停止、grep に degrade 禁止」
- これで AI 行動が固定化される

**知積への翻訳**: 知積 schema には User-facing メッセージはないが、内部 prompt (ChatService の prompt template) に **「まず ConceptPage を確認、なければ Article 検索」** の優先順位を hardcode できる。

#### F. 「人が書く前提では維持不能、AI が書く前提で初めて成立する設計」

著者の本音引用:

> 「すべての宣言に 5 タグを書け」というルールを人間に強制したら、たぶん 3 日でレビューが荒れます (...)
> これが成立しているのは、コードを書くのが基本 AI だからです。AI にとって JSDoc を 5 つ書く労力は、コード本体を書く労力に対して誤差みたいなものです。

**知積への翻訳**: ConceptPage の summary / crossSourceInsights を全て LLM が書く設計は同じ哲学。**「人間が書く UI」を作ろうとした瞬間に維持不能になる**。Karpathy 思想と完全一致。

### 3.3 cortex の実装スタック (参考)

| 層 | 技術 | 知積換算 |
|---|---|---|
| アプリ | TypeScript モノレポ | Swift / SwiftUI |
| Graph storage | BigQuery (2 テーブル: nodes/edges) | SwiftData @Model (GraphNode/GraphEdge) ✅ |
| Embedding | Vertex AI (gemini-embedding-2) | NLEmbedding (on-device) ✅ |
| MCP | Node.js MCP server | (将来) Local MCP server で公開 |
| AST 解析 | ts-morph | (該当なし、知識抽出は LLM 経由) |
| 差分 Embedding | $0.001/push | 知積は無料 (on-device) |
| 規模 | 8000+ ノード | 想定: 数百〜数千 ConceptPage |

→ **cortex は Mac/Cloud 前提の TS、知積は iPhone 前提の Swift、ただし設計原則は完全に転写可能**。

### 3.4 知積 v2 に取り込む pattern (まとめ)

| Pattern | 取り込み先 | 優先度 |
|---|---|---|
| **Runbook Pattern (次アクション内蔵)** | spec 049 Understanding Chat カード + spec 021 AI Chat 答え末尾 | ★★★ V1 |
| **usecase パラメータでツール挙動切替** | ChatService.send に usecase 引数追加 | ★★ V1 (spec 049 と同時) |
| **JSDoc-like SSoT 原則 (説明文を物の場所に)** | ConceptPage.summary が source of truth、別途解説 doc を作らない | ★★★ V1 (spec 045 設計時に意識) |
| **ハルシネーション位置の明示** | spec 045 plan で「抽出時のみ LLM、検索/表示/編集は決定論的」と明記 | ★★ V1 |
| **「AI が書く前提だから成立する」哲学** | VISION.md 更新時に明記、人間編集 UI を最小化 | ★★★ V1 (philosophy) |
| Schema (CLAUDE.md) で AI 行動を固定 | ChatService prompt template に検索優先順位を hardcode | ★ V1 (spec 045 と同時) |
| AST-based graph 構築 | (該当なし、知積は LLM 抽出経路) | — |
| MCP server 公開 | 将来 (Mac/iPad app 化時) | V3+ |

---

## 4. 3 つの共通パターン (抽出された普遍原則)

3 事例から共通して見えてくる、**「2026 年の AI knowledge stack 設計原則」**:

### 原則 1: Knowledge as compounding artifact (Karpathy + SAGE + Tableau AKG + cortex)

- RAG の使い捨て検索 ではなく、 **永続的に成長する構造**
- 知積: ConceptPage / Article / GraphNode が時間と共に育つ ✅

### 原則 2: 「説明文 (business context)」が Embedding 入力 = 検索精度の本体 (SAGE + cortex)

- 単純な名前 / コード だけでは意味検索が効かない
- 各ノードに固有の「何をやるか」「なぜここにあるか」が必須
- 知積: KnowledgeEntity.name だけでは弱い、**ConceptPage.summary が Embedding 対象** であるべき (spec 045 設計時)

### 原則 3: AI ハーネス (Guides + Sensors) で品質を構造的に担保 (cortex + Karpathy)

- Guides (事前制御): schema / lint / 規約
- Sensors (事後制御): 自動レビュー / lint / health check
- **「人間が書く前提の品質基準」を AI が書く世界に翻訳すると Lint 自動化**
- 知積: WikiLint (spec 047) がこれに該当

### 原則 4: Runbook pattern (cortex)

- ツール返答に「次の選択肢」を同梱
- AI agent が迷わない、user が学習しやすい
- 知積: Understanding Chat カード末尾 + AI Chat 答え末尾に必ず「次」を inline

### 原則 5: 自己進化 (SAGE + Tableau AKG + Karpathy + cortex)

- 使うほど賢くなる仕組み
- 知積: ingest 毎の compound + Understanding Chat フィードバック (userUnderstanding score) + Lint 改善

### 原則 6: ハルシネーション位置の意識的設計 (cortex)

- 「ハルシネーションは消えない、位置が変わるだけ」
- 入口 = LLM 抽出だけに絞り、参照は決定論的
- 知積: ConceptPage 生成のみ LLM、検索 / 表示 / 編集は決定論的

### 原則 7: AI が書く前提だから成立する設計 (cortex)

- 「人が書く設計」と「AI が書く設計」は別物
- 維持コスト = 0 の仕組みは AI 前提でのみ成立
- 知積: Karpathy 思想と完全一致、VISION.md に明記

---

## 5. 知積 v2 spec 045-052 への具体反映

| spec | 反映する pattern | ソース |
|---|---|---|
| **spec 045 ConceptPage** | (1) Knowledge compounds + (2) summary が Embedding 入力 + (6) ハルシネーション位置明示 + (7) AI が書く前提 | Karpathy / cortex / SAGE |
| **spec 046 SavedAnswer** | (1) Knowledge compounds (chat 答えを永続化) | Karpathy / cortex |
| **spec 047 WikiLint** | (3) AI ハーネス Sensors + (4) Runbook (lint 結果に「次のアクション」内蔵) | cortex |
| **spec 048 EntityCommunity** | (5) 自己進化 (Community が ingest で再検出) + (2) Community summary が Embedding 入力 | cortex / SAGE |
| **spec 049 Understanding Chat** | **(4) Runbook (カード末尾に「次のアクション」) + usecase パラメータ + (5) 自己進化 (userUnderstanding feedback)** | cortex (最重要) |
| **spec 050 写真 / AI 会話入力** | (6) ハルシネーション位置 (OCR は決定論的、構造判定のみ LLM) | cortex |
| **spec 043 Widget** | (1) compound 結果を ambient surface | Karpathy |
| V2 spec 051 Web Search | (3) Sensors (lint で穴埋め) | Karpathy / Tableau AKG |
| V2 spec 052 Markdown Export | データ可搬性 | (一般) |

---

## 6. Action Items

### 6.1 即座にやること (この session 内)

- [x] 07-external-references.md 作成 (本ファイル)
- [ ] **06-migration-plan.md に「外部 reference pattern を反映」セクション追記**
- [ ] **05-product-vision-consolidated.md v3 で「設計原則 7 つ」セクション追加**

### 6.2 spec 045 specify+plan 着手前に

- [ ] ConceptPage.summary を Embedding 対象にする設計判断を明記
- [ ] Runbook pattern (カード末尾「次のアクション」) を contracts に組み込む
- [ ] ハルシネーション位置 (生成時のみ LLM、参照は決定論的) を plan に明記
- [ ] AI prompt template の優先順位 (まず ConceptPage、なければ Article) を hardcode

### 6.3 spec 049 specify+plan 着手前に

- [ ] Runbook pattern を Understanding Chat カードに組み込む詳細設計
- [ ] usecase パラメータ (deepdive / global / specific / review) の ChatService 引数設計
- [ ] cortex の MCP ツール構造 (search/detail/traverse + 補助) を Understanding Chat の internal API として再現

### 6.4 将来検討 (V2-V3+)

- [ ] SAGE 流「質問分解」(V2 spec 候補)
- [ ] SAGE 流「ソフトアドレッシング + 評価伝搬」(V3 spec 候補)
- [ ] MCP server 公開 (Mac/iPad app 化時、V3+)
- [ ] 個人特化 fine-tune (Karpathy "Further explorations"、V3+)

---

## 7. 取り込まない判断 (明示しておく)

判断を明示することで、将来の議論で迷子にならない:

| 要素 | 取り込まない理由 |
|---|---|
| SAGE の Writer 強化学習 | on-device Foundation Models で fine-tune 不可、効果と複雑度のバランス悪い |
| Tableau AKG のオープンスキーマ標準 | 個人規模では不要、エンタープライズ向けの規模 |
| cortex の AST-based code graph | 知積はコードベースではなく知識ベース、AST 解析は対象外 |
| cortex の Pulumi インフラ統合 | 知積は iOS app、インフラ層がない |
| MCP server 公開 (V1) | mobile app 単独運用では意味薄い、Mac/iPad app 化後 |

---

## 8. 決定ログ (running)

| 日付 | 決定 | 根拠 |
|---|---|---|
| 2026-05-23 | 07-external-references.md 作成 (SAGE + Tableau AKG + cortex cpg を統合) | user 指示「これも入れて 07 として記録」 |
| 2026-05-23 | Runbook pattern を spec 049 Understanding Chat に必須要素として組み込む | cortex 事例から最も効く pattern と判断 |
| 2026-05-23 | usecase パラメータ pattern を ChatService に追加候補化 | cortex 事例、Understanding Chat の「もっと」と AI Chat の汎用 query で経路分岐したい |
| 2026-05-23 | ConceptPage.summary を Embedding 入力にする設計を spec 045 plan に明記 | SAGE + cortex 共通の「説明文が検索精度の本体」原則 |
| 2026-05-23 | SAGE の Writer 強化学習は取り込まない | on-device 不可、Karpathy の Further explorations 路線 |
| 2026-05-23 | MCP server 公開は V3+ 候補に | 知積 mobile app 単独運用では意味薄い |
| 2026-05-23 | 「設計原則 7 つ」を 05 v3 で追加予定 | 共通パターンを VISION に格上げ |

---

## 9. 次のアクション

1. **06-migration-plan.md に reference pattern 反映セクション追加** (短時間)
2. **05-product-vision-consolidated.md v3 で「設計原則 7 つ」セクション追加** (短時間)
3. **Q1-Q8 (05 v2 の質問) 回答** ← user 待ち
4. **VISION.md 更新案 (07 が完了したので情報揃った)**
5. **spec 045 (ConceptPage) specify+plan 着手** ← ハーネス原則を組み込んだ contracts で

---

## 10. 参考 URL / Source

| 事例 | source |
|---|---|
| SAGE | (user 提供記事、原典 paper 未確認) |
| Tableau Auto Knowledge Graph | Tableau Conference 2026 keynote / Salesforce プレスリリース / Waii 買収記事 |
| cortex Product Graph | airCloset CTO 辻氏 Zenn 連載 Part 1 (総論) + Part 2 (Product Graph) |
| 関連: Mitchell Hashimoto | "Agent = Model + Harness" |
| 関連: Martin Fowler | "Harness Engineering for Coding Agent Users" (2026-04) |
| 関連: OpenAI | "Harness Engineering: leveraging Codex in an agent-first world" (2026-02) |

→ 「2025 was the year of agents. 2026 is the year of harnesses.」 = 業界トレンド合言葉。

# 04 — KnowledgeTree (知積) でどうブラッシュアップできるか

## Status: WIP (初稿、2026-05-16) — ユーザー議論用ドラフト

---

## 1. 現状の知積 = どこまで Karpathy パターンを満たしているか

### 知積の現パイプライン (spec 001-044 集約)

```
Share Extension (URL 受領)
  ↓ ArticleSavingActor
[Article (raw)]
  ↓ DefaultArticleEnrichmentService (spec 002)
[ArticleEnrichment (OG metadata)]
  ↓ DefaultBodyExtractionService (spec 003 + 034 PDF)
[ArticleBody (本文)]
  ↓ KnowledgeExtractor (spec 004 + 042 翻訳前処理)
[ExtractedKnowledge (essence / summary / KeyFacts / KnowledgeEntities)]
  ↓ 各種 hook
[Tag] (spec 008/012/013 + 015 Category)
[Embedding] (spec 021)
[KnowledgeDigest] (spec 018, Category 単位)
[GraphNode/Edge] (spec 040)
[ConflictProposal] (spec 037)
[UserTopic] (spec 036)
[RecentDigest] (spec 035)
```

### 知積 vs LLM Wiki マッピング

| Karpathy LLM Wiki の概念 | 知積の現状 | 一致度 |
|---|---|---|
| **Raw sources (immutable)** | Article + ArticleBody | ✅ 完全一致 |
| **Schema (CLAUDE.md)** | CLAUDE.md (本リポジトリ) + AGENTS.md (Codex 用) + 各 SKILL.md | ✅ 一致、ただし wiki 規律よりは spec 駆動開発の規律 |
| **サマリーページ (1 ソース 1:1)** | ExtractedKnowledge (essence / summary / KeyFacts) | ⚠️ 同等情報を持つが、@Model なのか markdown なのか形式が違う |
| **概念ページ (★ 本体価値)** | **存在しない** | ❌ 未実装、最大の gap |
| Query ページ | ChatSession / ChatMessage (spec 021) | ⚠️ 質問は記録されるが「wiki にファイリングする」発想がない |
| index.md (catalog) | Library tab + AIBrainView Categories | ⚠️ UI 上の一覧はあるが、navigation 用の単一 catalog はない |
| log.md (時系列) | 各 service の os_log (Console.app) | ⚠️ ユーザーには見えない、wiki の進化タイムラインの可視化なし |
| **Ingest operation** | Share Extension → 自動パイプライン | ✅ 自動化されている (Karpathy より automated) |
| **Query operation** | AI Chat (RAG、spec 021/033) | ✅ 実装済、ただしファイリング欠 |
| **Lint operation** | ConflictDetectionService (spec 037) + TagStore.merge + GraphNodeStore.merge | ⚠️ 部分実装、wiki 全体の health check はない |
| Cross-source synthesis | KnowledgeDigest (Category 単位) | ⚠️ Category 粒度のみ、概念粒度ではない |
| User curation | iPhone Share Sheet | ✅ |
| "LLM が書き、人間が読む" | Auto-tag / Auto-Category / Auto-Graph | ✅ 設計思想は同じ |
| 動的 schema 進化 | spec 駆動の進化、ユーザー手動 | ⚠️ LLM 自己改善ループはない |

### 観察

知積は **Karpathy パターンを 70% 実現しているが、最大の価値ポイント (概念ページ) が欠けている**。

- 既に: 自動化 / 静かな UX / on-device / category 粒度の synthesis
- 不在: **「Apple」というエンティティ専用のページが時間とともに育つ** ような単位の蓄積

KnowledgeEntity は @Model として存在するが、それは「記事 1 本の中のエンティティ参照」であって、横断的な「Apple とは何か、知積の中ではどう語られてきたか」のページにはなっていない。

---

## 2. 思想的差分 (なぜ知積は Karpathy と違うのか)

### 差分 A: モバイル vs デスクトップ

| 軸 | Karpathy | 知積 |
|---|---|---|
| プラットフォーム | Mac + Obsidian + CLI | iPhone (iPadOS 26+) |
| 入力 | 手で Obsidian Web Clipper | Share Sheet タップ |
| 出力 | markdown / Marp / matplotlib | SwiftUI ビュー (グラフ Canvas / Card / Chat) |
| ユーザー注意力 | 集中作業時間 | スキマ時間 / 通勤 / 寝る前 |

→ **知積は「読んだ後の glanceable 振り返り」に最適化、Karpathy は「能動的な research セッション」に最適化**。

### 差分 B: データ構造

| Karpathy | 知積 |
|---|---|
| markdown ファイル (LLM が直接編集可) | SwiftData @Model (structured) |
| `[[wikilink]]` で繋がり表現 | `@Relationship` で繋がり表現 |
| 自由形式の概念ページ | スキーマ固定の Category / Tag / Entity / Graph |
| LLM が wiki に直接 write | LLM が @Generable 経由で structured output、Store が永続化 |

→ **知積のスキーマ拘束は「型安全 + iPhone 体験」のメリットだが、Karpathy の「LLM 主導の自由な概念ページ生成」と相性悪い**。

### 差分 C: 自動 vs 半自動

| Karpathy | 知積 |
|---|---|
| 1 ソース ingest = LLM が 10-15 ページに波及更新 | 1 記事保存 = 数本の @Model に分解 (essence, KeyFacts, entities) + 自動 tag / category / graph hook |
| 人間がフローを「監督」 | 人間は基本 fire-and-forget、後で結果を見る |
| 質問は能動的 (Research セッション) | 質問は AI Chat タブで時々 |

→ **知積はより「automatic + ambient」、Karpathy は「actively managed」**。知積の方がモバイル UX として正しいが、active な knowledge maintenance のメリットを取りこぼしている。

### 差分 D: 「理解の増幅」の扱い

| Karpathy | 知積 |
|---|---|
| 「outsource thinking but not understanding」を明示課題化 | VISION の「優しい第二の脳」「必要な時だけ開けば見える」は近いが、理解増幅の能動的促し UI なし |
| Tsurubee は「能動的に概念ページを読む」習慣を自分で作る必要があると指摘 | 知積も基本同じ問題を抱える、まだ未対応 |

→ 両方の限界、共通課題。

---

## 3.「ブラッシュアップ案」候補 (spec 045+ candidates)

Karpathy の発想で知積が取り込める要素を、影響度順に整理。

### 🌟 提案 A: 概念ページ (ConceptPage @Model) — **最重要**

**問題**: 知積は記事ベース、entity / concept 単位の compounding がない。
**Karpathy**: 概念ページが wiki の本体価値。

**実装案**:
- `ConceptPage @Model`: name + categoryRaw + 関連 Article 群 + AI 合成 essence + AI 合成「横断的知見」+ updatedAt
- 同 entityName が 2 + 記事に出現したら自動生成
- 新記事 ingest 時に既存 ConceptPage を見つけて regenerate (markStale + 再合成)
- 既存 KnowledgeDigestService と似たパターン、ただし Category ではなく Concept 粒度

**UI**:
- 「AI ブレイン」または「知識 Clip」タブ内に「概念」一覧
- ConceptDetailView: 関連記事 + AI 合成 + 矛盾フラグ + Graph Node link

**規模**: 中規模 (~600-800 行、5 ファイル新規 + 既存 3 ファイル改修)
**VISION 整合**: ★★★ 「体系化」「更新」「最新の自分が見える」すべて該当

### 🌟 提案 B: Query Filing (AI Chat の「保存」機能)

**問題**: AI Chat の良い回答が ChatSession 履歴に消える。Karpathy の言う「filed back to wiki」がない。
**Karpathy**: 良い Q&A は wiki の compounding artifact の一部。

**実装案**:
- `SavedAnswer @Model`: question + answer + citedArticles + savedAt
- AI Chat メッセージに「📌 保存」アクション追加
- 「知識 Clip」タブに `SavedAnswerSection`
- 検索対象 (spec 044 SearchService) に SavedAnswer.question / answer を追加

**規模**: 小規模 (~200-300 行)
**VISION 整合**: ★★ 「必要な時だけ開けば見える」を強化

### 🌟 提案 C: Wiki Lint (健全性チェック) 拡張

**問題**: 既存 ConflictDetectionService は事実矛盾のみ、孤立 entity / 同義異名 / 概念候補の検出はなし。
**Karpathy**: 定期 lint で wiki が荒れるのを防ぐ。

**実装案**:
- `WikiLintService`: 月 1 回 (or 起動 N 回ごと) に自動実行
- 検出対象:
  - 同義異名 entity (Apple vs アップル) → TagStore.merge と同パターン
  - 孤立 entity (1 記事のみ言及、graph 接続なし) → アーカイブ提案
  - 概念候補 (2+ 記事で言及されるが ConceptPage 未生成) → 自動生成提案
  - 矛盾 (既存 ConflictDetection 拡張)
  - 「次に調べるべき問い」AI 生成
- 結果は知識 Clip タブの「health check」セクションに表示

**規模**: 中規模 (~400-500 行)
**VISION 整合**: ★★ 「自動で更新」を強化

### 提案 D: Index View (catalog 一覧)

**問題**: 全 entity / concept / digest / saved answer を横断する catalog ビューがない。
**Karpathy**: index.md が wiki ナビゲーションの起点。

**実装案**:
- 新タブ or AIBrainView 内に「カタログ」セクション
- ConceptPage / GraphNode / Tag / SavedAnswer / KnowledgeDigest を統合 list
- 各エントリに 1 行サマリー + 更新日 + 関連記事数
- 検索 (spec 044) との連携: catalog 全体に対する横断検索

**規模**: 中規模 (~300-400 行)
**VISION 整合**: ★ 「必要な時だけ開けば見える」だが、既存 4 タブとの重複感あり

### 提案 E: 動的 Schema 進化ループ

**問題**: 知積の spec 進化はユーザー (= 人間) が判断、LLM が自己改善する仕組みなし。
**Karpathy**: schema は静的設定ではなく動的成果物、LLM と共進化。

**実装案**:
- AI Brain タブに「健全性レビュー」ボタン
- LLM に 現状の Tag 一覧 / Category 分布 / ConceptPage 集合 / Conflict 件数 を渡して「規約と実体の乖離」を提案させる
- 提案を spec 化候補として表示 (実装はユーザーが手動で判断)

**規模**: 小規模 (~200 行) だが効果は限定的
**VISION 整合**: ★ 「優しい」第二の脳の枠で UX 設計が難しい

### 提案 F: 能動的理解の補助 (「理解 mode」)

**問題**: Karpathy / Tsurubee 共通の「理解はボトルネックのまま」。知積も同じ限界。
**Karpathy**: 未解決と認めている。

**実装案**:
- ConceptPage を開いた時に「クイズで確認」ボタン
- KeyFacts から AI が選択肢 3 つ生成
- 正答すると ConceptPage.userUnderstanding スコア up
- 知識 Clip タブで「理解度が低い概念」を優先表示

**規模**: 中規模 (~400-500 行)、教育系 UX のチューニング必要
**VISION 整合**: ★ ただし「優しい第二の脳」のトーンと衝突するリスク (テスト = 不安喚起)

### 提案 G: Markdown Export / Obsidian Bridge

**問題**: 知積のデータは SwiftData lock-in、ユーザーが Obsidian / 他ツールで使えない。
**Karpathy**: Obsidian がデファクト IDE。

**実装案**:
- 設定に「Obsidian Vault に export」(全 ConceptPage / SavedAnswer / Article summary を markdown 化)
- ユーザーは Mac で Obsidian を開いて知積の wiki を browse
- 双方向にせず、export のみ (knowledge tree が source of truth)

**規模**: 小規模 (~200-300 行)
**VISION 整合**: ★ ロックイン回避、信頼性増、ただし「優しい」の枠とはずれる

---

## 4. 推奨ロードマップ

仮の優先順位:

| 順 | spec | 規模 | VISION 整合 | 効果 |
|---|---|---|---|---|
| 1 | **A: ConceptPage @Model** | 中-大 | ★★★ | 最大、Karpathy パターンの核を取り込む |
| 2 | **B: Query Filing (SavedAnswer)** | 小 | ★★ | 速い勝利、AI Chat の価値倍増 |
| 3 | **C: WikiLint 拡張** | 中 | ★★ | 概念候補の自動発見 = A をブースト |
| 4 | D: Index View | 中 | ★ | UI 整理だが効果は中庸 |
| 5 | G: Obsidian export | 小 | ★ | データロックイン回避 |
| 後回し | E: 動的 Schema / F: 理解モード | — | ? | 限界領域、要 PoC |

**最小 MVP for vision update**: A 単独でも VISION の core promise が一段強化される。A + B でユーザー体験は大きく前進。A + B + C で Karpathy パターンの 90% を MVP 充実。

---

## 5. 既存 VISION.md との整合性検証

(VISION.md は `vision-spec-035-038` ブランチに未 commit、現状の記述から要約)

> 「読んだ知識を AI が自動で体系化・更新し、必要な時だけ開けば最新の自分が見える、優しい第二の脳」

| 既存 VISION の要素 | Karpathy 由来の強化案 |
|---|---|
| **読んだ知識** | Raw sources (Article + Body) — 既に一致 |
| **AI が自動で体系化** | ConceptPage @Model (A) で「概念単位」に体系化を拡張 |
| **更新** | WikiLint (C) で自動健全性維持を実現、SavedAnswer (B) で query 履歴も体系化 |
| **必要な時だけ開けば** | Widget (spec 043 既存候補) + Index View (D) で glanceable 増強 |
| **最新の自分が見える** | ConceptPage の updatedAt / 「最近変化したページ」UI |
| **優しい第二の脳** | calm UX 維持 (E / F は要慎重)、F は「不安喚起 UI 禁止」原則と衝突注意 |

→ **VISION 自体は維持、4 機能 (X / Y / Z / W) に「U: Concept synthesis」を加える形が自然**。

VISION 更新案 (草稿):

> 「読んだ知識を AI が自動で『記事 → 概念 → 体系』へ三段階に統合し、必要な時だけ開けば最新の自分が見える、優しい第二の脳」

key change: 「体系化」を 3 階層 (記事サマリー / 概念ページ / カテゴリーダイジェスト) に明示化。

---

## 6. リスクと懸念

### リスク 1: スキーマ拘束 vs 自由な概念ページ

知積は SwiftData @Model 縛り、Karpathy は markdown 自由形式。

**対応**: ConceptPage @Model に `aiSynthesis: String` (Markdown 可) フィールドを置き、構造化 (関連 Article) + 半構造化 (AI が書く free text) の hybrid に。

### リスク 2: Foundation Models のコンテキスト制限

ConceptPage 生成時に 10+ 記事の essence を context に積むと、Foundation Models (on-device、4096 token context) では足りない可能性。

**対応**: Hierarchical synthesis (spec 010 既存パターン): 関連記事を essence chunk として分け、meta-summary で統合。spec 010 のロジックを再利用可能。

### リスク 3: 「能動的理解」を促す UI と「優しい第二の脳」の矛盾

提案 F (理解モード = クイズ) は「不安喚起 UI 禁止」原則と衝突する可能性。

**対応**: F は別ブランチで PoC → ユーザー feedback で採否決定。

### リスク 4: モバイル UX で wiki 操作が辛い

Karpathy の Obsidian + キーボード前提と iPhone の指タップは UX が違う。

**対応**: 知積は「読む」「探す」「保存する」までで、「編集」は Obsidian export (G) に逃がす。Karpathy パターンの 100% 取り込みは目指さない。

### リスク 5: 既存 spec との衝突

- spec 040 GraphNode と ConceptPage の役割が被る ⇒ ConceptPage = entity の「ページ」、GraphNode = entity の「ノード」として補完的に並立
- spec 018 KnowledgeDigest (Category 単位) と ConceptPage (Entity 単位) の粒度差を明示

---

## 7. ユーザーへの問いかけ (議論ポイント)

1. **Karpathy の「概念ページ」の compounding を知積に取り込むか?**
   - はい (提案 A 着手) / 部分的 (まず B から) / いいえ (現状維持)

2. **Obsidian 連携 (提案 G) は欲しいか?**
   - 「ロックイン回避が大事」/ 「知積で完結したい」

3. **「能動的理解」(提案 F、クイズ) は知積の方向性か?**
   - 「優しい」と相反する / 「実は欲しい」 / 「別アプリでやる」

4. **VISION 更新の射程**
   - 「概念ページ」を VISION の 1 要素に追加するだけ? それとも「Software 3.0 ネイティブ knowledge OS」の方向に大刷新?

5. **モバイル単独 vs Mac / iPad 展開**
   - 知積は iPhone 専用継続? それとも Karpathy 流の「Mac で Obsidian + iPhone で知積」のハイブリッドを目指す?

6. **「ingest = automatic」vs「ingest = curated」**
   - Tsurubee は明示的に自動 ingest 拒否。知積は Share Sheet タップで「半自動」。さらに能動キュレーション (Tsurubee 的 one-by-one + 自分選択) を促す UX 入れる?

7. **概念ページの自動言語選択**
   - 日本語? 英語? 記事元言語? 知積は spec 042 で「保存層は原文、知識層は日本語」と確定。ConceptPage も同方針?

8. **fine-tuning 路線への興味 (Karpathy の Further explorations)**
   - 「wiki を context として使う」現状で良い / 「個人特化モデルを fine-tune したい」野心あり

---

## 8. 次のアクション (合意できれば)

WIP 議論完了後の流れ案:

1. ユーザーが上記 8 つの問いに回答
2. 私が議論を反映して `04-knowledge-tree-application.md` を v2 に
3. 合意できた提案 (A 単独 / A+B / etc.) を VISION.md 更新案として `05-vision-update-proposal.md` を新規作成
4. 合意で OK なら VISION.md を実際に書き換え
5. その後の spec 045+ 着手は別 conversation で

# 05 — 統合プロダクトビジョン (Consolidated)

## Status: WIP — 議論進行中、決定が固まり次第 VISION.md 更新の素材になる

最終更新: 2026-05-17

---

## 0. このドキュメントの位置づけ

`01〜04` で Karpathy LLM Wiki / GraphRAG の分析と知積への接続を個別に検討してきた。本ドキュメントは **「結局、知積として何を作るのか」** をユーザー視点で 1 枚に統合する。

決定 → VISION.md 更新 → spec 045+ 実装、の起点になる。

---

## 1. 一文ビジョン (draft)

> 「**スマホで触れたあらゆる情報 (Web / PDF / 写真 / 他 AI 会話) を AI が読み解き、繋ぎ、要約し、必要な時には会話で深堀りできる、優しい第二の脳**」

既存 VISION との差分:
- 旧: 「読んだ知識を AI が自動で体系化・更新し、必要な時だけ開けば最新の自分が見える」
- 新: **入力源を「読んだ記事」から「スマホで触れたあらゆる情報」に拡張** + **会話で深堀り** を明示

---

## 2. データ入力 (Information Sources)

### V1 で対応

| 入力源 | 入力経路 | 知識抽出方法 | 現状実装 |
|---|---|---|---|
| Web 記事 | Share Sheet / Safari Extension | spec 001/002/003 既存 | ✅ |
| PDF | Share Sheet | spec 034 PDFKit | ✅ |
| **写真 / スクリーンショット** | Share Sheet / Photo picker | Vision framework OCR + Foundation Models 知識抽出 | ❌ **新規** |
| **他 AI 会話 (ChatGPT/Gemini/Claude 等)** | Share (screenshot or text copy) | OCR + 構造判定 (発話者分離 + Q&A 抽出) | ❌ **新規** |
| プレーンテキスト | Share Sheet 経由 | spec 001 既存パスで処理 | ⚠️ 部分実装 |
| Twitter/X 投稿 | Share Sheet | OG + body extractor | ⚠️ 既存パスで動くはず |

### V2 以降で対応

- web search による外部知識補完 (Brave / Tavily / Exa いずれか、BYOK 推奨)
- YouTube transcript
- ポッドキャスト音声 (Speech framework + Whisper-like)
- メール / メッセージスレッド
- 物理書籍ページ写真 → 連続 OCR + 章単位 ingest
- 音声メモ (Apple Voice Memos 共有)

### V3+ で検討

- カメラリアルタイム OCR (デモ的、限定 use case)
- Apple Watch から voice capture
- Spotlight 統合 (システム検索からヒット)

---

## 3. データ処理 (Data Foundation)

Karpathy LLM Wiki + Knowledge Graph + GraphRAG を統合した **「ローカル GraphRAG ベース第二の脳」** を作る。

### 3 層構造 (Karpathy 流)

```
┌─────────────────────────────────────────────────────┐
│ Schema (隠す、アプリ内部規約)                       │
│   - 知識粒度 / カテゴリー 10 種 / 抽出ルール        │
└─────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────┐
│ Wiki = 知識層 (LLM 自動メンテ)                       │
│   - ConceptPage (人物・モノ・テーマ) ★新規          │
│   - KnowledgeDigest (カテゴリーまとめ)              │
│   - GraphNode/Edge (Knowledge Graph)                │
│   - EntityCommunity (コミュニティ) ★新規            │
│   - SavedAnswer (chat ファイリング) ★新規           │
└─────────────────────────────────────────────────────┘
                          ↑ extract / synthesize
┌─────────────────────────────────────────────────────┐
│ Raw Sources = 記事層 (immutable)                     │
│   - Article + ArticleBody (本文 + OG meta)           │
│   - 画像/PDF 添付ファイル                            │
└─────────────────────────────────────────────────────┘
```

### 処理オペレーション

| Karpathy 用語 | 知積実装 | トリガー |
|---|---|---|
| Ingest | Share Sheet → 自動パイプライン | ユーザー保存時 |
| Query | AI Chat (Local + Global Search) | ユーザー質問時 |
| Lint | ConflictDetection + WikiLint | 週 1 BGTask |
| **Compound moment** | chat 答えの post-process | 毎 chat answer |

### GraphRAG / Community 検出

- spec 040 GraphNode/GraphEdge をベースに **EntityCommunity 検出** (Option A: K-means、spec 036 流用)
- Local Search: 既存 ChatService + spec 040 graph augmentation
- Global Search: community summary 群を map-reduce 統合 (新規)

---

## 4. ユーザーインターフェイス (5 機能)

### 4.1 保存記事ビュー (Library タブ)

- 既存 ArticleListView
- search bar (spec 044 + relevance ranking 実装済)
- swipe で削除 (spec 022)
- 既存実装で OK、追加要素なし

### 4.2 検索

- Library 内 `.searchable()` (spec 044 既存)
- 検索対象: title / canonicalTitle / essence / summary / KeyFact / entity / tag / **ConceptPage** (新規)
- 検索結果 ranking: SearchService 既存 + ConceptPage hit に score 加算

### 4.3 クラスター / コミュニティビュー (知識 Clip タブ拡張)

- 既存セクション: 最近のあなた / Topic / Digest / Conflict / Graph Proposals
- **追加セクション: 知識コミュニティ** (EntityCommunity カード)
- カード形式: タイトル (AI 生成) + 主要 entity 3 個 + 関連記事数 + 1 行要約
- tap → CommunityDetailView (関連 entity / 関連記事 / 内部 graph)

### 4.4 Understanding-focused Chat ⭐ MAIN

これが**新しい中核 UX**。「カードで問いかけ → 理解できたら OK → 理解できなければ深堀り会話」。

```
┌────────────────────────────────┐
│ Main (学習チャット)              │
│                                  │
│ ┌────────────────────────┐      │
│ │ 💡 今のあなたへ          │      │
│ │                           │      │
│ │ 🍎 Apple Foundation       │      │
│ │    Models フレームワーク  │      │
│ │                           │      │
│ │ on-device LLM を SwiftUI  │      │
│ │ アプリから呼び出せる新    │      │
│ │ 機能。@Generable で型安全 │      │
│ │ な structured output...   │      │
│ │                           │      │
│ │ [✓ わかった] [🤔 もっと]  │      │
│ └────────────────────────┘      │
│                                  │
│ ← 前のカード   次のカード →     │
└────────────────────────────────┘
```

**「もっと」を押す** → そのカードの context で chat 開始:

```
┌────────────────────────────────┐
│ ← 🍎 Apple Foundation Models     │
│                                  │
│ AI: このカードの内容について    │
│     何が分からないですか?       │
│                                  │
│ User: 「@Generable って何?」    │
│                                  │
│ AI: @Generable は Swift マクロで │
│     LLM が JSON 構造を保証して  │
│     出力する仕組みです...       │
│     [関連カード: Swift マクロ]  │
│                                  │
│ User: ...                       │
│                                  │
│ [✓ わかった] [🤔 もっと]         │
└────────────────────────────────┘
```

**「わかった」を押す**:
- ConceptPage.userUnderstanding を up
- カードキューから外す
- 次のカードへ

**カードキューの source**:
- ConceptPage の updatedAt が最近 (= 新しい情報入った)
- userUnderstanding が低い
- ユーザーがピンしたもの
- ランダム織り交ぜ (発見性)

**Compound moment**: 「もっと」→ chat の答えが ConceptPage に file される + Q&A が SavedAnswer に保存。

→ **「outsource thinking, but not understanding」を実装するための UI**。Karpathy / Tsurubee の懸念に直接答える。

### 4.5 General-purpose Chat Agent

- 既存 AI Chat タブ (spec 021/033)
- 何でも聞ける、wiki ベースの RAG
- V1: 保存記事のみが答えのソース
- V2: web search opt-in で外部知識補完

---

## 5. タブ構成 (案、要議論)

現状 4 タブ + Understanding が増えると 5 タブだが、iOS HIG では 5 タブが上限 (それ以上は More 行き)。

### 案 A: 5 タブ並列

```
1. 学習 (Understanding chat、Main、起動時 default)
2. AI チャット (General agent)
3. 知識 Clip (cluster / digest / community)
4. ライブラリ (raw articles + search)
5. AI ブレイン (graph view / stats)
```

### 案 B: 4 タブ (AI ブレインを知識 Clip 統合)

```
1. 学習 (Main, default)
2. AI チャット
3. 知識 Clip (digest + community + graph、AI ブレインの内容も統合)
4. ライブラリ
```

### 案 C: 3 タブ (radical 簡略化)

```
1. 学習 (Main)
2. チャット
3. ライブラリ (検索 + concept browse + community browse 全部統合)
```

→ **要議論**: B が現状からの自然な拡張で推奨候補。

---

## 6. バージョンロードマップ (案)

### V1 (MVP) — 4-6 spec、~2 ヶ月

| spec | 内容 | 規模 |
|---|---|---|
| spec 045 | ConceptPage @Model + service + UI (Karpathy 概念ページ) | 中-大 |
| spec 046 | SavedAnswer + Chat filing | 小 |
| spec 047 | WikiLint 拡張 (健全性チェック自動) | 中 |
| spec 048 | EntityCommunity 検出 + UI (GraphRAG Community) | 中 |
| spec 049 | Understanding-focused Chat (Main、学習 UI) | 大 |
| spec 050 | 写真 / スクリーンショット入力 (OCR + 抽出) | 中 |
| (既存 043) | ホーム画面 Widget (ambient surface) | 中 |

### V2 — Web Search 追加

| spec | 内容 |
|---|---|
| spec 051 | Tool protocol + Web search (BYOK) |
| spec 052 | 他 AI 会話 (ChatGPT/Gemini export) 入力対応 |

### V3+ — 拡張

- YouTube transcript / 音声 / Watch app / Spotlight 統合
- Mac/iPad アプリ展開
- iCloud sync (multi-device)
- Markdown/JSON export (Obsidian bridge)

---

## 7. 知積 現状マッピング

| ビジョン要素 | 既存 spec | 状態 |
|---|---|---|
| Web 記事入力 | spec 001/002/003 | ✅ |
| PDF 入力 | spec 034 | ✅ |
| 写真 / スクショ入力 | — | ❌ V1 で実装 |
| 他 AI 会話入力 | — | ❌ V2 |
| 知識抽出 (essence/KeyFacts/entity) | spec 004 | ✅ |
| Auto-Tag | spec 012/013 | ✅ |
| Category 分類 | spec 015 | ✅ |
| Knowledge Graph | spec 040/041 | ✅ |
| Embedding (RAG) | spec 021 | ✅ |
| Local Search RAG | spec 021 + 040 | ✅ |
| 翻訳 (English → 日本語) | spec 042 | ✅ |
| カテゴリー Digest | spec 018 | ✅ |
| Conflict 検出 | spec 037 | ✅ |
| 動的トピック | spec 036 | ✅ |
| 最近のあなた | spec 035 | ✅ |
| 検索 (relevance ranking) | spec 044 | ✅ |
| **ConceptPage (Karpathy 概念ページ)** | — | ❌ **spec 045 新規** |
| **SavedAnswer (filing)** | — | ❌ **spec 046 新規** |
| **WikiLint** | 部分 (spec 037) | ⚠️ **spec 047 拡張** |
| **EntityCommunity (GraphRAG)** | — | ❌ **spec 048 新規** |
| **Understanding Chat (Main)** | — | ❌ **spec 049 新規** |
| General Chat | spec 021/033 | ✅ |
| Widget | — | ❌ **spec 043 新規** |
| Web search | — | ❌ **V2 spec 051** |

→ **V1 完成までに新規 spec 6 個必要**、既存 spec の追加改修は最小限。

---

## 8. 抜け漏れ・追加提案 (私から)

### 🚨 重要な抜け漏れ

#### A. 写真入力時の知識抽出方法

- **Foundation Models on-device は現状 vision input 持っていない** (iOS 26 時点、WWDC 26 で発表されるかも)
- **代替案**:
  - Vision framework `VNRecognizeTextRequest` で OCR → text として既存パスに流す
  - 画像内容説明は Foundation Models ではできない、画像メタのみ extract
  - スクショ判定 (LLM 会話 vs 一般写真) は OCR テキストの構造から推定

→ **「写真は OCR テキストとして扱う、視覚的内容理解は V2 以降」と明示**するべき。

#### B. 「カードキュー」の優先度ロジック

何のカードを surface するか、explicit にしないと運用で破綻:
1. 新しく追加された ConceptPage (latest first)
2. 数日触れていない重要 concept (importance × idle)
3. lint で「次に学ぶべき」と提案された問い
4. ユーザーがピンしたもの (manual queue)
5. ランダム織り交ぜ (発見性)

→ ロジックを spec 049 で明示する必要あり。

#### C. 「わかった / もっと」フィードバックの扱い

- explicit button (今提案中) → 信頼性高、ユーザー摩擦あり
- implicit (滞在時間で推定) → 摩擦ゼロ、誤判定リスク
- **hybrid**: button 推奨だが、スワイプで「わかった」も発火、長時間滞在でも「わかった」推定

→ 提案: hybrid、ボタンを optional 化。

#### D. 通知設計

知積は「不安喚起 UI 禁止」(Constitution V) なので push 通知は基本なし。
ただし学習機能には「優しい reminder」が活きる場面ある:
- 「今日のカードが届きました」(週 1 回)
- 「Apple について 5 件の新記事が読まれました」(silent badge)
- → **「reminder は完全 opt-in、デフォルト OFF」が calm UX**

→ 提案: 通知は default OFF、設定で「優しい reminder」を opt-in できる。

#### E. オンボーディング

新規ユーザーは「保存しろ」と言われても何を保存すべきか分からない。
- 「最初の 3 記事を共有してみよう」サンプル提示
- 「3 記事溜まると 概念カード が出始めます」期待値設定
- 「もっと貯まると コミュニティ が見えます」段階的解禁感

→ 提案: spec 049 内で onboarding を carve out、または別 spec で。

### 💡 加えると価値が増す要素

#### F. Voice Input (チャットの音声化)

- 通勤中 / 寝る前 = 両手塞がってる時 = 学習に最適なタイミング
- iOS Speech framework で簡単実装
- Understanding Chat の「もっと」を **音声でも入力可** にすれば実用性激増

#### G. Markdown Export (データ可搬性)

- Constitution I (ローカルファースト) と整合
- 「ロックインしない」信頼の象徴
- Obsidian / Notion で開ける markdown 群を書き出す
- 規模小、価値大

#### H. Spaced Repetition (忘却対策)

- 「3 ヶ月前に わかった カードを再提示」
- 純粋な学習効果増
- ただし「テスト」感を出さない care 必要

#### I. ConceptPage の「フォロー」機能

- 興味あるトピックを explicit にフォロー
- 新記事追加で「フォロー中の Apple に新情報」surface
- 受動的ではなく能動的キュレーション選択肢

#### J. Compound moment の可視化

- chat 答えのあとに「✨ 3 個の概念が更新されました」soft toast
- compound が見える → ユーザーが「育っている感」を体感
- これがないと chat = 単なる ChatGPT 体験で終わる

#### K. Cross-app share format detection

- ChatGPT app の screenshot は特徴的レイアウト (アバター / 発話者 / バブル)
- OCR 結果から「これは LLM 会話だな」と判定 → 質問/答えに分離して別個に extract
- 「Geminiの会話」「Claude の会話」も同様
- → 入力時の知識粒度を上げる

#### L. 元情報 (raw) と派生情報 (concept/community) の繋がり可視化

- Karpathy 流の「ソースに戻れる」を強化
- ConceptPage 詳細 → 「この知見の元になった文 (記事 抜粋)」を inline 表示
- 信頼性 + 検証可能性

---

## 9. 質問 (要回答、優先度順)

### Q1: タブ構成 (案 A / B / C)
- A: 5 タブ並列
- **B (推奨): 4 タブ (AI ブレイン → 知識 Clip 統合)**
- C: 3 タブ radical 簡略化

### Q2: 起動時 default タブ
- 現状: 知識 Clip
- 提案: **学習 (Main、Understanding Chat)** に変更?
- 理由: VISION の中核体験を最初に見せる

### Q3: 「学習 Chat」と「General Chat」を分けるか統合するか
- 分ける (案 A/B): 2 タブ、目的別 UI
- 統合 (radical): 1 タブで mode 切替 (「カード mode」「フリー mode」)
- **どちら?**

### Q4: 写真入力の範囲
- OCR テキストのみ抽出 (V1) ← 推奨
- それとも画像内容理解も V1 で求める? (技術的にハードル高)

### Q5: 他 AI 会話 (ChatGPT 等) の入力
- スクショ (OCR + 構造推定) で対応
- またはユーザーが手動でテキスト copy/paste
- どちら主軸?

### Q6: カードキューの優先度
- 新着順 / 重要度 / 久しぶり / ランダム織り交ぜ
- **どの組み合わせ?** デフォルト weight は私が提案?

### Q7: 通知 (reminder)
- 完全なし
- opt-in で「優しい reminder」(週 1 程度)
- **どちら?**

### Q8: 「わかった/もっと」フィードバック
- explicit button のみ
- implicit (滞在時間) のみ
- hybrid (button + swipe + 時間)
- **どれ?**

### Q9: 既存 Category (10 固定) と EntityCommunity の関係
- 並列展開 (両方表示)
- Category 内に Community 表示 (階層)
- Community が Category を置き換え
- **どれ?**

### Q10: Markdown Export (V1 入れる? V2?)
- データ可搬性 = 信頼性、入れたい
- V1 / V2 / V3?

### Q11: Voice Input (V1 入れる?)
- 通勤・寝る前 UX で大きく効く
- Speech framework で簡単
- V1 / V2?

### Q12: ConceptPage に「フォロー」機能
- ユーザー能動キュレーション
- 入れる / 入れない?

### Q13: Compound moment の可視化 toast
- 「✨ 3 個の概念が更新されました」表示
- calm UX と矛盾しないか? それとも価値ある教育効果?

### Q14: バージョン区切り
- V1 規模が大きい (新規 spec 6 個 + 既存改修)、3 ヶ月想定で OK?
- V1 を更に細分化したい?

### Q15: 既存 VISION.md (現 1 文ビジョン) の更新タイミング
- このドキュメント決着後すぐ?
- spec 045 着手前?
- V1 完成後?

---

## 10. 決定ログ (running)

このセクションは議論進行に応じて追記される。

| 日付 | 決定事項 | 根拠 / 出典 |
|---|---|---|
| 2026-05-17 | 本ドキュメント (`05-product-vision-consolidated.md`) を WIP で起こす | ユーザー指示「整理して新規 md」 |
| 2026-05-17 | データ入力源は Web/PDF/写真/他 AI 会話 (V1)、web search は V2 | ユーザー明示 |
| 2026-05-17 | データ処理は Karpathy + KG + GraphRAG の 3 統合 | ユーザー明示 |
| 2026-05-17 | UI は 5 機能 (raw / search / cluster / Main 学習 chat / general chat) | ユーザー明示 |
| 2026-05-17 | Main 画面 = Understanding-focused chat (カード + 深堀り会話) | ユーザー明示、Karpathy「理解は委ねられない」を実装する UI |
| TBD | タブ構成 (Q1) | 議論中 |
| TBD | 起動時 default (Q2) | 議論中 |
| TBD | 学習 / General chat 分離 (Q3) | 議論中 |
| TBD | 写真入力範囲 (Q4) | 議論中 |
| TBD | カードキュー優先度 (Q6) | 議論中 |
| TBD | 通知設計 (Q7) | 議論中 |
| TBD | Q8〜Q15 | 議論中 |

---

## 11. 次のアクション

1. ユーザーが Q1〜Q15 に回答 (優先 Q1-Q5 + Q9-Q11)
2. 私が決定ログに反映 + 本ドキュメント v2 化
3. 議論が collapsed したら `06-vision-update-proposal.md` で VISION.md 更新案を起こす
4. ユーザー approve で VISION.md 実更新
5. spec 045 (ConceptPage) から実装着手、順次 V1 spec 群を消化

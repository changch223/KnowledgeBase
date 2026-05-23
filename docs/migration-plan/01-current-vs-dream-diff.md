# 01 — 現知積 vs Dream (iKnow) Diff Check ★

## このファイルの目的

**ユーザー確認用** — 現在の知積アプリ (spec 001-044 実装済) を iKnow に進化させる時、**何が継続 / 改修 / 新規追加 / 廃止 / 統合** されるかを 1 表で見える化する。

凡例:
- ✅ **継続活用**: そのまま使う
- 🔧 **改修**: 拡張 / 修正
- ➕ **新規追加**: ゼロから作る
- ❌ **廃止**: 削除する
- 🔀 **統合**: 他と統合

---

## 1. アプリ全体 / Branding diff

| 項目 | 現知積 | → | iKnow | 変化 |
|---|---|---|---|---|
| アプリ名 | 知積 (KnowledgeTree) | → | iKnow | 🔧 リブランディング |
| Bundle ID | (現状維持) | → | (同じ) | ✅ 継承 |
| App Store ID | (現状維持) | → | (同じ) | ✅ 継承、評価累積継続 |
| バージョン | v1.x (現知積) | → | v2.0 (iKnow) | 🔧 メジャー跳ね上げ |
| ロゴ / Icon | 現アイコン | → | iKnow 新アイコン | 🔧 新規制作 |
| App Store description | 知積向け | → | iKnow 向け | 🔧 全面刷新 |
| キャッチコピー | 「読んだ知識を AI が自動で体系化」 | → | 「Apple Intelligence をあなた専用に進化」 | 🔧 |

---

## 2. タブ構成 diff

### 現知積 (4 タブ)

```
1. ライブラリ          (起動 default)
2. 知識 Clip
3. AI ブレイン         ← ★ 廃止
4. AI チャット
```

### iKnow (4 タブ)

```
1. 学習                (起動 default、新規) ← 家庭教師ループ
2. AI チャット         (継続)
3. 知識 Clip           (拡張、AI ブレインの内容を統合)
4. ライブラリ          (継続)
```

### diff

| 項目 | 現知積 | → | iKnow | 変化 |
|---|---|---|---|---|
| 起動 default | ライブラリ | → | 学習 | 🔧 |
| 学習タブ | なし | → | あり (Understanding Chat、新規) | ➕ |
| AI ブレインタブ | あり | → | なし | ❌ 撤去 |
| 知識 Clip タブ | あり | → | あり (大幅拡張) | 🔧 |
| AI チャットタブ | あり | → | あり (compound moment 追加) | 🔧 |
| ライブラリタブ | あり | → | あり (改修なし) | ✅ |

---

## 3. データ層 (@Model) diff

### 現知積の @Model 16 個

| # | @Model | 役割 | iKnow での扱い |
|---|---|---|---|
| 1 | Article | 保存ソース | ✅ 継続 (+ `sourceType` フィールド追加 🔧) |
| 2 | ArticleEnrichment | OG メタ | ✅ 継続 |
| 3 | ArticleBody | 本文 | ✅ 継続 |
| 4 | ExtractedKnowledge | 要約 | ✅ 継続 |
| 5 | KeyFact | 事実 | ✅ 継続 |
| 6 | KnowledgeEntity | entity | ✅ 継続 |
| 7 | Tag | タグ | ✅ 継続 (or 🔀 ConceptPage と並立、要確認) |
| 8 | KnowledgeChunkProgress | chunked 進捗 | ✅ 継続 (内部) |
| 9 | BackgroundExtractionQueueEntry | BG queue | ✅ 継続 (内部) |
| 10 | KnowledgeDigest | カテゴリーダイジェスト | ✅ 継続 |
| 11 | ChatSession | チャット session | ✅ 継続 |
| 12 | ChatMessage | メッセージ | 🔧 改修 (`savedAnswerID` 追加) |
| 13 | ConflictProposal | 矛盾検出 | ✅ 継続 |
| 14 | UserTopic | 動的トピック | 🔀 EntityCommunity と統合検討 |
| 15 | GraphNode | グラフノード | ✅ 継続 |
| 16 | GraphEdge | グラフエッジ | ✅ 継続 |

### iKnow で新規追加する @Model 4 個

| # | 新 @Model | 役割 | spec |
|---|---|---|---|
| 17 | **ConceptPage ★** | 概念ページ (Karpathy 思想の本体) | spec 045 |
| 18 | **SavedAnswer** | 質問結果ファイリング | spec 046 |
| 19 | **EntityCommunity** | コミュニティ (GraphRAG) | spec 048 |
| 20 | **ActivityLog** | 時系列ログ (内部のみ) | spec 047 |

### 集計

- 継続: 13 個 (15 個 - 統合検討 2 個)
- 改修: 2 個 (Article + ChatMessage)
- 新規: 4 個
- 統合候補: 2 個 (Tag, UserTopic)

→ **データ層は ほぼ 全て継承、追加 4 個** = lightweight migration で対応可能

---

## 4. Service 層 diff

### 現知積の主要 Service (~35 個)

| カテゴリ | Service | iKnow での扱い |
|---|---|---|
| 投入 | ArticleSavingActor | 🔧 sourceType 判定追加 |
| 投入 | ArticleSavingService | 🔧 写真 / AI 会話入力対応 |
| 抽出 | ArticleEnrichmentService | ✅ 継続 |
| 抽出 | BodyExtractionService | ✅ 継続 |
| 抽出 | KnowledgeExtractor | ✅ 継続 |
| 抽出 | KnowledgeExtractionService | 🔧 ConceptPage hook 追加 |
| 抽出 | LanguageDetector (spec 042) | ✅ 継続 |
| 抽出 | TranslationAvailability (spec 042) | ✅ 継続 |
| 抽出 | LanguageModelSessionProtocol | 🔧 ConceptPage 用 prompt 追加 |
| 蓄積 | SwiftDataArticleStore | ✅ 継続 |
| 蓄積 | SwiftDataArticleEnrichmentStore | ✅ 継続 |
| 蓄積 | SwiftDataArticleBodyStore | ✅ 継続 |
| 蓄積 | SwiftDataArticleKnowledgeStore | ✅ 継続 |
| 蓄積 | TagStore | ✅ 継続 |
| 蓄積 | GraphNodeStore (spec 041) | ✅ 継続 |
| Auto | AutoTagApplier | ✅ 継続 |
| Auto | AutoTagBackfillRunner | ✅ 継続 |
| Auto | AutoCategoryClassifier | ✅ 継続 |
| Auto | AutoCategoryBackfillRunner | ✅ 継続 |
| Digest | KnowledgeDigestService | 🔧 graph traversal は継続、ConceptPage と並立 |
| Digest | RecentDigestService (spec 035) | ✅ 継続 |
| Topic | TopicClusteringService (spec 036) | 🔧 CommunityDetectionService に発展 |
| Conflict | ConflictDetectionService (spec 037) | 🔧 WikiLintService に拡張統合 |
| Graph | GraphExtractionService (spec 040) | ✅ 継続 |
| Graph | GraphTraversalService (spec 040) | ✅ 継続 |
| Graph | GraphProposalReviewService (spec 041) | ✅ 継続 |
| Embedding | EmbeddingService (spec 021) | ✅ 継続 |
| Chat | ChatService (spec 021, 033) | 🔧 compound moment hook 追加 + Global Search 追加 |
| Backfill | BackgroundExtractionRunner (spec 009) | ✅ 継続 |
| Backfill | BackgroundExtractionScheduler (spec 009) | ✅ 継続 |
| Backfill | SwiftDataChunkProgressStore (spec 009) | ✅ 継続 |
| 他 | LastOpenedStore (spec 035) | ✅ 継続 |
| 他 | SearchService (spec 044) | 🔧 ConceptPage / SavedAnswer hit 対応 |
| 他 | SearchPredicate (spec 008) | 🔧 同上 |
| 他 | CategorySeed (spec 015) | ✅ 継続 |

### iKnow で新規追加する Service 5-6 個

| Service | spec | 役割 |
|---|---|---|
| **ConceptSynthesisService** | spec 045 | 概念ページ自動生成 + 再合成 |
| **SavedAnswerStore** | spec 046 | chat 答えのファイリング |
| **WikiLintService** | spec 047 | 健全性チェック (ConflictDetection 拡張統合) |
| **CommunityDetectionService** | spec 048 | コミュニティ検出 (TopicClustering 流用) |
| **UnderstandingCardQueueService** | spec 049 | カードキュー優先度ロジック |
| **ImageOCRService** | spec 050 | Vision OCR + AI 会話構造判定 |

### 集計

- 継続: ~28 個
- 改修: ~7 個
- 新規: 5-6 個

→ **Service 層は 80% 継続活用**

---

## 5. View 層 diff

### 現知積の主要 View (~50+ 個)

#### Library 系 (継続)
- ArticleListView ✅
- ArticleDetailView ✅
- ArticleRow ✅
- CategoryFilteredListView ✅
- CategoryKnowledgeDetailView ✅
- EntityFilteredListView ✅
- TagFilteredListView ✅
- SwipeToDeleteRow ✅

#### 知識 Clip 系 (大幅拡張)
- KnowledgeClipView 🔧 (新セクション 5 つ追加)
- RecentDigestSection ✅
- FactConflictsSection ✅
- DynamicTopicsSection ✅
- GraphProposalsSection (spec 041) ✅
- TagManagementView ✅
- CategoryGraphView (spec 041) ✅
- GraphNodeDetailView (spec 041) ✅
- GraphNodeEditSheet (spec 041) ✅
- GraphEdgeEditSheet (spec 041) ✅

#### AI チャット系 (継続改修)
- ChatTabView 🔧 (📌 保存 button 追加)
- ChatMessageRow 🔧 (pin icon 表示)
- ChatHistorySidebar (spec 033) ✅
- ChatSessionRow (spec 033) ✅
- ChatInputField ✅

#### AI ブレイン系 (★ 全廃)
- ❌ AIBrainView
- ❌ PowerGaugeCard
- ❌ KnowledgeMap (force-directed Canvas)
- ❌ RecentActivityCards
- ❌ AIInsightCard
- ❌ KnowledgeCategoryRow (AI ブレイン版)

#### Settings 系 (継続)
- SettingsView 🔧 (新項目追加: 学習通知 / Activity Log / Export 等)
- SafariSetupView ✅
- TranslationSetupView (spec 042) ✅

#### Share Extension (継続改修)
- ShareViewController 🔧 (image / aiChat sourceType 対応)

### iKnow で新規追加する View (主なもの)

| View | spec | 親 |
|---|---|---|
| **UnderstandingChatView** (root) | spec 049 | TabView (新タブ) |
| **UnderstandingCardView** | spec 049 | UnderstandingChatView |
| **DeepDiveChatView** | spec 049 | UnderstandingChatView nav |
| **ConceptPageDetailView** | spec 045 | NavigationDestination |
| **ConceptPageEditSheet** | spec 045 | ConceptPageDetailView |
| **SavedAnswerSection** | spec 046 | KnowledgeClipView |
| **SavedAnswerDetailView** | spec 046 | NavigationDestination |
| **EntityCommunityCard** | spec 048 | KnowledgeClipView |
| **EntityCommunityDetailView** | spec 048 | NavigationDestination |
| **WikiLintProposalsSection** | spec 047 | KnowledgeClipView |
| **ImageInputPreviewView** | spec 050 | Share Extension |
| **AIConversationStructurePreview** | spec 050 | Share Extension |
| **iKnow Widget** (Small/Medium/Large) | spec 051 | WidgetKit Extension |
| **ExportSheet** | spec 052 | SettingsView |

### 集計

- 継続: ~35 view
- 改修: ~8 view
- 新規: ~13 view
- 廃止: 6 view (AI ブレイン関連)

---

## 6. spec (機能仕様) diff

### 現知積 spec 001-044

すべて **既に実装済み**:
- spec 001-005: 基盤 (記事保存 / fetch / 本文 / 抽出 / UI)
- spec 006-010: 拡張 (chunked / multipage / search / BG / hierarchical)
- spec 011: AI ブレインタブ ← 撤去対象
- spec 012-014: Auto-Tag / backfill / DesignSystem
- spec 015: Category 階層
- spec 016-018: Category 詳細 / Dark Mode / 知識 Clip
- spec 019: Chrome 連携 (撤回済)
- spec 020: Safari Web Extension
- spec 021: AI Chat (RAG)
- spec 022: 削除手段
- spec 024: Tag 編集
- spec 030: LazyVStack 削除
- spec 033: AI Chat モダン UI
- spec 034: PDF
- spec 035-038: VISION 関連 (RecentDigest / DynamicTopics / Conflict / 用語整理)
- spec 040-041: Knowledge Graph A/B
- spec 042: 英語翻訳
- spec 044: 検索 ranking

### iKnow V1 で新規追加する spec 045-054

| spec | 内容 | 規模 |
|---|---|---|
| spec 045 | ConceptPage @Model + Service + UI | 大 (~800 行) |
| spec 046 | SavedAnswer + Chat filing | 小 (~300 行) |
| spec 047 | WikiLint 拡張 + 気づきの種 | 中 (~500 行) |
| spec 048 | EntityCommunity 検出 + Catalog | 中 (~500 行) |
| spec 049 | Understanding Chat (Main、新タブ) | **大 (~1000 行) ★** |
| spec 050 | 写真 / AI 会話入力 (OCR + 判定) | 中 (~500 行) |
| spec 051 | Widget (3 サイズ) | 中 (~500 行) |
| spec 052 | Export (zip + markdown) | 小 (~300 行) |
| spec 053 | タブ再編 + AI ブレイン廃止 | 中 (~400 行) |
| spec 054 | iKnow リブランディング (icon + xcstrings + App Store) | 小 (~200 行) |

**合計新規実装: ~5000 行 / 10 spec / 4-5 ヶ月**

### 撤回・撤去する spec

| 元 spec | 内容 | 撤去理由 |
|---|---|---|
| spec 011 | AI ブレインタブ | dream で廃止、知識 Clip 統合 |
| spec 019 (撤回済) | Chrome 連携 | 既に撤回済 |

→ 既存 spec 011 の view 群は **spec 053 で撤去** 予定。

---

## 7. 入力源 diff

| 入力源 | 現知積 | iKnow | 変化 |
|---|---|---|---|
| Web 記事 (Share Sheet) | ✅ spec 001 | ✅ | ✅ 継続 |
| PDF (Share Sheet) | ✅ spec 034 | ✅ | ✅ 継続 |
| Safari Web Extension | ✅ spec 020 | ✅ | ✅ 継続 |
| **画像 / スクリーンショット** | ❌ なし | ✅ spec 050 | ➕ **新規** |
| **AI 会話 (ChatGPT/Gemini スクショ)** | ❌ なし | ✅ spec 050 | ➕ **新規** |
| プレーンテキスト | ⚠️ 部分 | ✅ | 🔧 改善 |

---

## 8. 出力 / Export diff

| 出力 | 現知積 | iKnow | 変化 |
|---|---|---|---|
| **zip 全体 export** | ❌ | ✅ spec 052 | ➕ **新規** |
| **Markdown 個別 export** | ❌ | ✅ spec 052 | ➕ **新規** |
| iOS Share Sheet 経由共有 | ❌ | ✅ | ➕ **新規** |

---

## 9. UX フロー diff

### Compound moment

| Compound 条件 | 現知積 | iKnow | 変化 |
|---|---|---|---|
| 1. chat 答えに引用 ≥ 2 → SavedAnswer | ❌ | ✅ spec 046 | ➕ |
| 2. 深堀り会話終了 → ConceptPage update | ❌ | ✅ spec 049 | ➕ |
| 3. 「✓ わかった」 → userUnderstanding スコア | ❌ | ✅ spec 049 | ➕ |
| 4. 新記事 ingest → 関連 ConceptPage stale | ❌ | ✅ spec 045 | ➕ |

→ **Compound moment は完全新規**、これが iKnow の核心。

### 受動 surface

| surface | 現知積 | iKnow | 変化 |
|---|---|---|---|
| 「最近のあなた」セクション | ✅ spec 035 | ✅ | ✅ 継続 |
| 「動的トピック」 | ✅ spec 036 | ✅ (Community に発展) | 🔧 |
| カテゴリーダイジェスト | ✅ spec 018 | ✅ | ✅ 継続 |
| **News Clip 風 概念カード** | ❌ | ✅ spec 045 | ➕ **新規** |
| **学習タブ Understanding Card** | ❌ | ✅ spec 049 | ➕ **新規** |
| **Widget (Home/Lock screen)** | ❌ | ✅ spec 051 | ➕ **新規** |
| **「気づきの種」(Lint 結果)** | ❌ | ✅ spec 047 | ➕ **新規** |

---

## 10. Diff サマリ (集計)

| カテゴリ | 継続 ✅ | 改修 🔧 | 新規 ➕ | 廃止 ❌ | 統合 🔀 |
|---|---|---|---|---|---|
| アプリ全体 / Branding | 2 | 5 | 0 | 0 | 0 |
| タブ構成 | 1 | 2 | 1 | 1 | 0 |
| @Model (データ) | 13 | 2 | 4 | 0 | 2 |
| Service | ~28 | ~7 | 5-6 | 0 | 0 |
| View | ~35 | ~8 | ~13 | 6 | 0 |
| 入力源 | 3 | 1 | 2 | 0 | 0 |
| 出力 | 0 | 0 | 3 | 0 | 0 |
| Compound moment | 0 | 0 | 4 | 0 | 0 |
| 受動 surface | 3 | 1 | 4 | 0 | 0 |

### キーポイント

✅ **80% 継続活用** (既存 知積 の資産を最大活用)
🔧 **改修は限定的** (主に追加 hook + フィールド追加)
➕ **新規は核心部分** (ConceptPage / Understanding Chat / Widget / Export / Compound moment)
❌ **廃止は限定** (AI ブレインタブ関連の 6 view のみ)

---

## 11. ユーザー視点での「何が変わる?」

既存 知積 ユーザーが iKnow にアップデートした瞬間に体感する変化:

### 良い変化 (新規体験)

1. **起動すると「学習」タブが開く** ← 旧: ライブラリだった
2. **「今のあなたへ」カードが surface される** ← 旧: なかった
3. **「もっと」ボタンで深堀り会話できる** ← 旧: なかった
4. **「✓ わかった」で自分の理解度が貯まる** ← 旧: なかった
5. **概念ページが時間とともに育つ** ← 旧: なかった
6. **AI チャットの良い答えを「📌 保存」できる** ← 旧: 履歴に消えた
7. **「気づきの種」セクションが現れる** ← 旧: 一部 (Conflict のみ)
8. **写真 / スクショを保存できる** ← 旧: できなかった
9. **AI 会話スクショ (ChatGPT/Gemini) を保存できる** ← 旧: できなかった
10. **Home screen / Lock screen に Widget** ← 旧: なかった
11. **データを zip / markdown で export 可能** ← 旧: できなかった

### 違和感が起きうる変化 (ケア必要)

1. **AI ブレインタブが消える** ← Onboarding overlay で説明
2. **起動 default タブが変わる** ← 一度だけ overlay 説明
3. **アプリ名が「知積」→「iKnow」になる** ← Onboarding でリブランディング理由説明
4. **アイコンが変わる** ← App Store update notes で明示

### データ的には何も失わない

- 既存の保存記事 / 抽出データ / グラフ / カテゴリーダイジェスト / チャット履歴 すべて保持
- SwiftData lightweight migration で 自動移行
- 既存 ConflictProposal / GraphNode / 等の編集状態も保持

---

## 12. ユーザー確認チェックリスト

このマトリクスを見て、確認してほしいポイント:

- [ ] **タブ構成変更** (AI ブレイン廃止 + 学習タブ追加) を受け入れる?
- [ ] **起動 default が「学習」に変わる** ことを受け入れる?
- [ ] **アプリ名「知積」→「iKnow」** を受け入れる?
- [ ] **既存 spec 011 関連 view 廃止** (PowerGauge / KnowledgeMap / RecentActivity / AIInsight) を受け入れる?
- [ ] **新規 @Model 4 個追加** (ConceptPage / SavedAnswer / EntityCommunity / ActivityLog) で OK?
- [ ] **Article に sourceType フィールド追加** で OK (lightweight migration)?
- [ ] **Tag と ConceptPage は並立** (統合せず) で OK?
- [ ] **UserTopic と EntityCommunity は統合** で OK?
- [ ] **V1 ビッグバン (10 spec を 4-5 ヶ月で一気)** で OK?

→ 全 ✅ なら次のフェーズ (02 詳細マッピング) に進める。
→ ❌ あれば該当行を議論 → 修正反映。

---

## 決定ログ (User Approved)

**2026-05-23 ユーザー承認 (全項目)**:

### ✅ Q1: 廃止対象 — 全 廃止 OK
- AI ブレインタブ (1 タブ)
- AI ブレイン関連 view 6 個 (AIBrainView / PowerGaugeCard / KnowledgeMap / RecentActivityCards / AIInsightCard / KnowledgeCategoryRow + KnowledgeMapBuilder)
- 関連 test 3 個 (KnowledgeMapBuilderTests / RecentActivitySnapshotBuilderTests / AIBrainTabUITests)
- @Model 1 個 (UserTopic → EntityCommunity に統合)

### ✅ Q2: 改修対象 — 全 改修 OK
- アプリ全体: 5 件 (名前 / バージョン / Icon / description / キャッチコピー)
- タブ構成: 2 件 (起動 default / 知識 Clip タブ拡張)
- @Model: 2 件 (Article.sourceType / ChatMessage.savedAnswerID)
- Service: ~10 件 (各 service への hook 追加 + 拡張統合)
- View: ~8 件 (KnowledgeClipView 新セクション 5 つ等)
- 入力源: 1 件 (プレーンテキスト改善)
- **合計 ~28 改修件**

### ✅ Q3: 統合 3 パターン — 全 統合 OK
- TopicClusteringService → **CommunityDetectionService** (spec 036 → 048)
- ConflictDetectionService → **WikiLintService** に拡張統合 (spec 037 → 047)
- UserTopic @Model → **EntityCommunity @Model** に統合 (UserTopic 廃止)

### ✅ 並立 (統合しない) 確認済
- Tag vs ConceptPage — 並立 (役割違う、Tag = 軽量、ConceptPage = 重い)
- KnowledgeDigest (Category) vs ConceptPage (Entity) — 並立 (粒度違う)
- GraphNode vs ConceptPage — 並立 (1:1 リンク、構造 vs 読み単位)

→ **この diff で V1 進行確定**、次は VISION.md 更新 + spec 045 specify+plan 着手。

---

## 次に読むファイル

- `02-feature-mapping.md` — 現 spec ↔ dream feature の 1:1 対応詳細
- `03-data-migration.md` — SwiftData migration 戦略
- `04-implementation-roadmap.md` — spec 045-054 の順序 + 期間

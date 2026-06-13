# KnowledgeTree (iKnow) アーキテクチャ全体ドキュメント

**最終更新**: 2026-06-07 / **対象**: main (`9c1a49d` 相当) + ローカル `072-category-fix` ブランチ
**注**: ファイル名:行番号は調査時点の「目安」。リファクタで前後する。

このドキュメントは「何をどこに置いているか」「記事を共有してから何がどう処理されるか」「Wiki ページがどう作られるか」「各 AI 処理の prompt とファイルの置き場所」「実装済み/今後のプラン」「抜け漏れ」を 1 つにまとめたもの。新しく入る人が最初に読む地図。

---

## 1. 概要 & 一文ビジョン

**iKnow** = 「読んだ知識を AI が自動で体系化・更新し、必要な時だけ開けば最新の自分が見える、優しい第二の脳」(VISION v2 = LLM Wiki)。

Karpathy の **LLM Wiki** に倣った 3 層構造:

| 層 | iKnow での実体 | 性質 |
|---|---|---|
| **Raw sources** (生情報) | `Article` (+ ArticleBody / ArticleEnrichment / ExtractedKnowledge) | 不変。ユーザーが保存した記事そのもの |
| **The wiki** (編さん物) | `ConceptPage` (= Wiki ページ。人物/概念/プロジェクト) | AI が記事から生成・更新する百科事典ページ |
| **The schema** (編集規約) | `Resources/iknow-schema.md` | AI への指示書 (Wiki 本文ルール / Hedge phrase 等) |

**運用ループ**: Karpathy の 3 操作 (Ingest / Lint / Query) のうち iKnow は **Ingest (記事取り込み→自動編さん)** と **Lint (週次お掃除)** を採用。Query (質問→ページ化) はやらない。

**技術スタック**:
- Swift 6 / SwiftUI (iOS 26.4+)
- SwiftData + CloudKit (private DB 同期、App Group 共有)
- Apple Foundation Models (on-device LLM、`SystemLanguageModel` / `LanguageModelSession`)
- NLEmbedding (on-device 文章 embedding)、Apple Translation framework (英→日)

すべて **on-device**。記事本文・知識は外部送信しない (privacy 原則)。

---

## 2. ターゲット構成 (4 target)

```
KnowledgeTree.xcodeproj
├── KnowledgeTree                  メインアプリ (176 swift)
├── KnowledgeTreeShareExtension    Safari 等の「共有」から記事保存
├── KnowledgeTreeSafariExtension   Safari Web Extension (自動保存)
└── iKnowWidget                    ホーム画面ウィジェット (学習カード)
```

**共有の要**: `SharedSchema.swift` が全 @Model を 1 箇所で定義し、**App Group コンテナ + CloudKit private DB** を共有設定。Share Extension / Widget / メインアプリが同じ SwiftData ストアを読む。
- CloudKit 鉄則: **@Model は削除・rename しない** (record type `CD_X` を壊すとデータ消失)。フィールド追加は必ず default 付き (lightweight migration 安全)。

---

## 3. フォルダ構造マップ (何をどこに)

### `KnowledgeTree/` root (4)
| ファイル | 役割 |
|---|---|
| `KnowledgeTreeApp.swift` | アプリ起動・`init()` で BGTask 登録・`bootstrap()` で全 service 構築/DI/backfill・TabView (3 タブ) |
| `SharedSchema.swift` | 全 @Model のスキーマ定義 + CloudKit/App Group 設定 |
| `AppGroup.swift` | App Group コンテナのパス解決 |
| `DesignSystem.swift` | デザイントークン (`DS.Spacing` / `DS.Color` / `DS.Radius`、色は adaptive) |

### `Models/` (21) — @Model (永続) + transient
| 分類 | ファイル |
|---|---|
| 記事系 | `Article` / `ArticleBody` / `ArticleEnrichment` / `ExtractedKnowledge` (essence/keyFacts/entities を内包) / `Tag` |
| Wiki・知識系 | `ConceptPage` (=Wiki) / `KnowledgeDigest` / `ConflictProposal` / `SavedAnswer` / `GraphNode` / `GraphEdge` / `UserTopic` (退役済) |
| Chat | `ChatSession` / `ChatMessage` / `AgentAction` |
| フィード・学習 | `FeedItem` (transient) / `MixedSurfaceCard` / `UnderstandingInteraction` / `LintLog` |
| 背景 | `BackgroundExtractionQueueEntry` / `KnowledgeChunkProgress` |

### `Services/` (69) — ロジック層 (品質の核心)
| 分類 | 代表ファイル | 役割 |
|---|---|---|
| **AI 生成** | `KnowledgeExtractor` / `KnowledgeExtractionService` / `ConceptSynthesisService` / `AutoCategoryClassifier` / `LanguageModelSessionProtocol` | 記事→知識、概念合成、分類。**LanguageModelSessionProtocol が全 @Generable と AI 呼び出しの中心** |
| **チャンク処理** | `ChunkSplitter` / `ChunkedKnowledgeAggregator` / `HierarchicalChunkedSummarizer` | 長文の分割要約 |
| **分類/タグ** | `CategorySeed` / `AutoTagApplier` / `SuggestedTagFinder` / `TagNormalizer` / `TagStore` | カテゴリ・タグ付与 |
| **フィード** | `FeedBuilder` / `RecentArticlesService` / `RecentDigestService` | iKnow タブのフィード組み立て |
| **グラフ/関連** | `GraphExtractionService` / `GraphTraversalService` / `EmbeddingService` / `RelatedArticleFinder` | エンティティ関係・embedding 近傍 |
| **取得** | `BodyExtractor` / `MetadataParser` / `MultiPageCrawler` / `PDFFetcher` / `LanguageDetector` / `ArticleEnrichmentService` | HTML/PDF から本文・OGP 抽出 |
| **背景** | `BackgroundExtractionScheduler` / `BackgroundExtractionRunner` / `BackgroundExtractionQueue` | BGTask 制御 |
| **その他横断** | `ServiceContainer` (DI) / `ProcessingMonitor` (進捗) / `RefreshTrigger` / `SchemaLoader` / `LintEngine` / `HealthScoreService` / `ChatService` / `SavedAnswerService` / `ConflictDetectionService` / `KnowledgeDigestService` | |

### `Views/` (82) — SwiftUI 画面
| 分類 | 代表ファイル |
|---|---|
| フィード (iKnow タブ) | `KnowledgeClipView` (root) / `ArticleFeedCard` / `WikiFeedCard` / `ArticleShelfCard` / `WikiShelfCard` / `CategoryHighlightCard` / `TagHighlightCard` / `RecommendCarousel` / `FeedTypeBadge` |
| 詳細 | `ArticleDetailView` / `ConceptPageDetailView` / `CategoryKnowledgeDetailView` / `SavedAnswerDetailView` |
| チャット | `ChatTabView` / `ChatMessageRow` / `ChatHistorySidebar` / `DeepDiveChatView` (家庭教師) |
| ライブラリ/検索 | `ArticleListView` / `ArticleRow` / `TagFilteredListView` / `CategoryFilteredListView` |
| 設定/その他 | `SettingsView` / `OnboardingView` / `HealthScoreCard` / `AvatarMenu` |

### テスト
- `KnowledgeTreeTests/` — **Unit 66 ファイル** (Mock ベース、`LanguageModelSessionProtocol` を差し替えて AI なしで検証)
- `KnowledgeTreeUITests/` — UI 4 ファイル (Simulator cold-launch で flaky、CI なし)

---

## 4. 記事処理パイプライン (保存→知識化の全フロー)

### 入口 3 経路 (いずれも AI 呼び出しなし、Article を作るだけ)
| 経路 | ファイル | 備考 |
|---|---|---|
| **Share Extension** | `KnowledgeTreeShareExtension/ShareViewController.swift` | Safari「共有」→ URL+title 抽出 → 保存 → 1 秒で閉じる |
| **AppIntent** | `AppIntents/SaveURLToKnowledgeTreeIntent.swift` + `ArticleSavingActor.swift` | Shortcuts / Siri / Spotlight |
| **アプリ内** | `Views/AddArticleSheet.swift` | iKnow タブの FAB (+ ボタン) |

すべて `ArticleSavingService.save(url:suppliedTitle:)` に集約。

### 段階チェーン (trigger ベース、fire-and-forget で次段を起動)

```
入口 3 経路
   │
   ▼
ArticleSavingService.save()              URL 正規化 (URLNormalization) / 重複判定 / Article @Model 作成
   │                                     → SwiftData insert (AI なし)
   ▼
ArticleEnrichmentService.enrich()        HTTP GET (UA: KnowledgeTree/1.0) / OGP 解析
   │                                     → ArticleEnrichment (canonicalTitle/summary/ogImageURL/rawHTML)
   │                                     retry: [30s,120s,600s] / オフライン skip (AI なし)
   ▼ (succeeded で trigger)
BodyExtractionService.extract()          rawHTML → 本文テキスト (BodyExtractor、密度スコアリング)
   │                                     100 字未満は failed (AI なし)
   ▼ (succeeded で trigger)
KnowledgeExtractionService.extract()     ★ AI 知識抽出の中心
   ├─ 短文 (本文 ≤ 400 字): 単発パス → 1 回 FM 呼び出し
   └─ 長文 (> 400 字): chunked パス
        ├─ ChunkSplitter で 400 字単位に分割 (max 30 chunk、句点優先)
        ├─ 各 chunk を extractFromChunk (chunk 数だけ FM)
        └─ > 10 chunk なら hierarchical (lvl2/lvl3 meta-summary)
   │  出力 → ExtractedKnowledge (essence / summary / keyFacts / entities)
   │  ※ BGTask で resume 可 (KnowledgeChunkProgress に incremental 保存)
   ▼ (succeeded / partiallySucceeded で)
★★★ 7 つの hook 連鎖 ★★★
```

### 知識抽出後の 7 hook (KnowledgeExtractionService 末尾)
| # | hook | 同期性 | AI | 内容 | 出力先 |
|---|---|---|---|---|---|
| 1 | auto-tag | **同期** | なし | `AutoTagApplier` が salience 上位 entity を tag 化 (top 5) | `Article.tags` |
| 2 | digest stale | **同期** | なし | カテゴリの `KnowledgeDigest.isStale = true` | Digest 再生成予約 |
| 3 | embedding | **同期** | なし(NLEmbedding) | essence/title を [Float] embedding 化 | `Article.essenceEmbedding` |
| 4 | 矛盾検出 | 非同期 | **1 回** | `ConflictDetectionService` が新旧記事の事実矛盾を検出 | `ConflictProposal` |
| 5 | graph 抽出 | 非同期 | **停止中** | `GraphExtractionService` (spec 065 で DI nil 化) | (生成されない) |
| 6 | 概念合成 | 非同期 | **2-3 回** | `ConceptSynthesisService.processNewArticle` → ConceptPage 生成/更新 | `ConceptPage` |
| 7 | SavedAnswer stale | 非同期 | なし | 関連 SavedAnswer の `isStale = true` | WikiLint 用 |

- hook 1-3 は本流内で同期実行。hook 4-7 は `Task { await }` で fire-and-forget (失敗は silent log、本流をブロックしない = calm UX)。
- **1 記事保存あたりの FM 呼び出し**: 知識抽出 (1〜chunk数) + 矛盾検出 (1) + 概念合成 (2-3) + カテゴリ分類 (新規タグ数、最大 5) ≈ **数回〜20回**。spec 065 で graph・topic・起動 digest を停止して削減済み。

### 背景処理 (BGTask 3 種)
| BGTask identifier | 役割 | spec |
|---|---|---|
| `app.KnowledgeTree.chunkedKnowledgeExtraction` | 長文記事の chunked 抽出を非表示時に続行 | 009 |
| `app.KnowledgeTree.conceptResynthesis` | isStale な ConceptPage を再合成 (fetchLimit 5) | 042 |
| `app.KnowledgeTree.weeklyLint` | 週 1 (日曜 3AM) Lint loop (merge/delete/reclassify) | 058 |

`KnowledgeTreeApp.init()` で register、`bootstrap()` 末尾で schedule。

---

## 5. Wiki ページ (ConceptPage) 生成フロー

### 2 階層モデル (spec 074〜) ★現行
ConceptPage は **2 階層の wiki** を形成する: カテゴリ(L0=既存) > **広い概念(L1)** > **具体概念(L2)**。
例: テクノロジー > `生成AI`(broad) > `Text-to-SQL` / `データエンジニアリング`(specific)。
- `ConceptPage.conceptLevelRaw` (`broad`/`specific`) + `parentConceptID` (具体→広いの親 ID)。
- 広い概念ページ自身も Wiki ページ (summary/bodyMarkdown を持ち、子トピックを俯瞰)。

### いつ作られるか — 概念階層抽出 (spec 074、現行の主経路)
記事 ingest 時 (知識抽出 hook) → `ConceptSynthesisService.ingestArticle`:
1. AI で概念階層を抽出 (`generateConceptHierarchy` → `ConceptHierarchyOutput`: 広い概念 1 + 具体概念 2-4)。入力 = title+essence+keyFact、出力が小さく **token 安全**。広い概念は `BroadConceptSeed` のシードを優先 (ハイブリッド)。
2. `processConceptHierarchy` で broad/specific ページを **upsert + 親子 link** (同名+同カテゴリは再利用)。**1 記事目から作る** (entity 共起の 2 件閾値は使わない)。
3. 該当ページを `isStale=true` → resynthesize が summary/bodyMarkdown 生成。
4. **AI 不可 / 抽出失敗 / 広い概念が空** → 旧 entity 共起パス (`processNewArticle`) に degrade。

### (旧) entity 共起トリガ — `processNewArticle`
spec 074 以前の方式。entity が同カテゴリ 2+ 記事に共起したらフラットな ConceptPage を作る。現在は **degrade 経路 + backfill 用に残置** (主経路は階層抽出)。広域語が肥大化する問題があった (docs §12)。

### ConceptPage の何が AI 生成か
| フィールド | 生成方法 | AI | prompt builder |
|---|---|---|---|
| `summary` (200-400字) | `resynthesize` → 1-shot or hierarchical | **Generable** | `buildOneShotPrompt` / `buildMetaPrompt` |
| `crossSourceInsights` (最大7) | 同上 (複数記事を横断した発見) | **Generable** | 同上 |
| `bodyMarkdown` (Wiki 本文) | `generateBodyMarkdown` | **plain string** | `buildWikiBodyPrompt` |
| `kind` (人物/概念/プロジェクト) | `inferKind` (entity type 集計) | なし | — |
| `embedding` | summary を NLEmbedding | なし | — |
| `relatedConceptIDs` (相互リンク) | `nearestConceptIDs` (cosine ≥0.5 top8) + AI 本文リンク | 一部 | `buildWikiBodyPrompt` 内候補 |

- **広い概念 (broad)** (spec 074): 子トピック名 + 記事要点を俯瞰して synth (`buildBroadConceptPrompt`、小入力 = token 安全)
- **1-shot** (≤3 記事): 全記事を 1 prompt にまとめて合成 (具体概念ページ)
- **hierarchical** (≥3 記事): 記事ごとに chunk 要約 → meta-summary で統合
- **plain string の意味**: bodyMarkdown は @Generable を使わない = schema serialization (~1500 token) を節約し、本文に token を回す (spec 063 の核)
- **相互リンク**: bodyMarkdown 内に `[名前](concept-id://UUID)` を AI が埋め、不正/非存在 UUID は `sanitizeConceptLinks` でプレーン化 (dead link ゼロ)
- **ユーザー訂正保護**: `bodyEditedByUser=true` なら再生成スキップ

### Fallback (Apple Intelligence 不可時)
`FallbackConceptSynthesisService`: essence を 3 件並べた簡易 summary + 各先頭文を bullet 化。bodyMarkdown は空。`isStale=false` にしてループ防止。

### 再合成
`resynthesizeAllStale` が isStale な ConceptPage を最新優先 (relatedArticles の最大 savedAt 降順) で上位 5 件再合成。BGTask `conceptResynthesis` でも実行。

---

## 6. AI 処理 & prompt 置き場所マップ

**中心**: `Services/LanguageModelSessionProtocol.swift` が全 `@Generable` 出力型 + `LanguageModelSessionProtocol` (12 種の AI メソッド) + 本番実装 `FoundationModelLanguageModelSession` を持つ。テストは Mock で差し替え。

| # | 機能 | prompt builder (file) | @Generable 出力型 / @Guide | 実装 service |
|---|---|---|---|---|
| 1 | 知識抽出 | `KnowledgeExtractor.buildPrompt` | `ExtractedKnowledgeOutput` (essence 150字 / summary 300字 / keyFacts 最大10 / entities 5-10) | KnowledgeExtractor |
| 1b | meta-summary (chunked) | `KnowledgeExtractor.buildMetaSummaryPrompt` | 同上 | 同上 |
| 1c | 翻訳前処理 (英→日) | `KnowledgeExtractor.prepareForExtraction` | plain string (Apple Translation) | LanguageDetector + translate |
| 2 | カテゴリ分類 | `AutoCategoryClassifier` inline prompt | `CategoryClassificationOutput` (categoryName、**`CategoryRegistry` 駆動 = seed 10 + 動的カテゴリ**、spec 074) | AutoCategoryClassifier |
| 3 | Category Digest | `KnowledgeDigestService.buildPrompt` | `DigestOutput` (cards 1-3: summary 150字 / keyFacts 3 / entities 3) | KnowledgeDigestService |
| 4 | AI Chat (RAG) | `ChatService.buildPrompt` | `ChatAnswerOutput` (answer / citedArticleIDs) | ChatService |
| 4b | Agent Action | `ChatService.buildAgentPrompt` | `AgentAction` (struct + actionType String → enum 変換) | ChatService |
| 5 | 最近のあなた | `RecentDigestService.buildPrompt` | `RecentDigestOutput` (paragraphs 4: headline 60-100字) | RecentDigestService |
| 6 | 矛盾検出 | `ConflictDetectionService.buildPrompt` | `ConflictDetectionOutput` (hasConflict / 各 50字) | ConflictDetectionService |
| 7 | トピック命名 | `TopicClusteringService` 内 | `TopicNameOutput` (name 5-20字) | TopicClusteringService (退役) |
| 8 | Graph triple | `GraphExtractionService.buildPrompt` | `GraphTripleOutput` (triples 最大10、confidence 0-1) | GraphExtractionService (停止) |
| 9 | 概念合成 | `ConceptSynthesisService.buildOneShot/Chunk/MetaPrompt` | `ConceptSynthesisOutput` (summary 150-280字 / insights 4、spec 073 で圧縮) | ConceptSynthesisService |
| 9b | Wiki 本文 | `ConceptSynthesisService.buildWikiBodyPrompt` | plain string (markdown) | 同上 |
| 9c | 広い概念合成 | `ConceptSynthesisService.buildBroadConceptPrompt` | `ConceptSynthesisOutput` (子トピック俯瞰、spec 074) | 同上 |
| 10 | 概念階層抽出 | `ConceptSynthesisService.buildConceptHierarchyPrompt` | `ConceptHierarchyOutput` (broad 1 + specific ≤4、小出力=token安全、spec 074) | ConceptSynthesisService |
| 11 | 家庭教師 | `DeepDiveChatService.buildInitial/ContinuationPrompt` | plain string | DeepDiveChatService |

### iknow-schema.md の埋め込み
`Resources/iknow-schema.md` を `SchemaLoader` が起動時にロードし、`section(named:)` でセクション抽出して prompt に embed:
- **「Wiki 本文生成ルール」** → `buildWikiBodyPrompt` に動的注入
- **「概念階層抽出ルール」** (spec 074) → `buildConceptHierarchyPrompt` に動的注入
- **Hedge phrases** → `HedgePhraseFilter` が「分かりません」等を「私の理解では」に置換
- schema.md 不在時は code 内 fallback (production 安全)

---

## 7. 主要な設計パターン

1. **token 超過対策の階層** (4096 token 制限との戦い):
   - 入力 truncate (本文 400字 / per-article essence 80字 / KeyFact 30字)
   - plain string 出力で @Generable schema コスト回避 (Wiki 本文・家庭教師)
   - `promptCharBudget` で累積文字数ガード (RecentDigest)
   - Fallback service (AI 失敗時の非 AI 経路)
   - **※ これが品質低下の主因でもある (§9・§10・§12 参照)**
   - **★重要 (2026-06-07 実機ログで判明)**: `exceededContextWindowSize` は**入力だけの問題ではない**。`@Generable` は宣言した最大出力サイズ分だけ出力 token を**予約**するため、`ConceptSynthesisOutput` (旧 summary 400字 + insights 7×150字 ≈ 出力予約 2000+ token) や `ExtractedKnowledgeOutput` (keyFacts 最大10 + entities 5-10) のような**大きい出力スキーマは、入力を削っても窓に収まらない**。対策は (a) 出力スキーマの上限を絞る、(b) plain string 化 (spec 063 の Wiki 本文がこれ)。詳細 §12。
2. **availability 3 段階分岐**: embedding 可否 / Foundation Models 可否 / 両方。不可なら Fallback か skip (calm degrade)
3. **@Generable の制約回避**: enum 非対応 → struct + String rawValue を Swift で enum 変換 (AgentAction)。UUID 非対応 → [String] 出力を `UUID(uuidString:)` 変換
4. **fire-and-forget hook**: 本流をブロックしない / 失敗は silent log (calm UX、ユーザーに confirm/alert 出さない)
5. **CloudKit 安全則**: @Model 削除・rename しない / フィールド追加は default 付き / 退役は生成停止のみ (物理削除しない)
6. **DI**: `ServiceContainer` が全 service を保持、SwiftUI Environment で配布。テストは Mock を注入

---

## 8. 実装済みの全体像 (spec 001-072)

| 範囲 | 主な spec | 内容 |
|---|---|---|
| **基盤** | 001-010 | 記事保存 / 本文抽出 / 知識抽出+要約 / chunked / 階層要約 / 背景処理 (BGTask) |
| **知識化** | 011-040 | AI タグ / カテゴリ階層 / 知識 Clip タブ / Dark mode / RAG チャット / PDF / Knowledge Graph |
| **iKnow V1** | 042-058 | ConceptPage (Wiki) / SavedAnswer / 学習タブ (家庭教師) / Tag 編集 / Auto-Lint / Agentic Chat |
| **CloudKit** | 051 | iCloud 同期 (private DB、14 Array Relationship を Optional 化) |
| **LLM Wiki 再設計** | 063-070 | WikiPage 化 (063) / 相互リンク・関係発見 (064) / AI 処理削減 (065) / News+ フィード (066) / UserTopic 退役 (067) / iKnow タブ再設計 (068) / フィード磨き込み (069) / 種別バッジ (070) |
| **コア品質** | 071-072 | token 実測基盤 TokenBudgetProbe (071、PR #30) / カテゴリ誤分類修正 (072、PR #31) |

詳細は repo root の `CLAUDE.md` (各 spec の実装ログ) と `specs/` 配下。

---

## 9. VISION 達成度 (何ができて、何が未達)

VISION v2 (7 原則 + 3 層) に対する現状評価:

| VISION 要素 | 状態 | 補足 |
|---|---|---|
| **Wiki 中心** (ConceptPage に集約) | ✅ | 7 分裂概念を ConceptPage に畳む完了 (063) |
| **相互リンク** (ページ間 [[リンク]]) | ✅ | concept-id:// + embedding 近傍 (064) |
| **News+ フィード** (記事+Wiki mix) | ✅ | iKnow タブ (066/068)、For You Wiki + 4 種カード |
| **on-device privacy** | ✅ | 全 AI が端末内、外部送信ゼロ |
| **日本語ファースト** | ✅ | 生成・UI とも日本語 |
| **AI 管理だが人が直せる** | ✅ | bodyEditedByUser 保護 / Tag・概念の手動編集 |
| **軽さ優先** (AI 呼び出し最小) | 🔧 部分 | graph/topic/起動 digest 停止で削減 (065)。だが入力 truncate で**品質を犠牲にした軽さ** |
| **source 追跡** (記事に辿れる) | 🔧 部分 | relatedArticles で辿れるが entity 正規化不足で分裂 |
| **知識の品質** (essence/事実/要約) | ❌ 課題 | token 制限で本文 400字・essence 80字に削られ、生成材料が貧困 (§10 で対処) |
| **カテゴリ精度** | 🔧 改善中 | 072 で文脈+定義 prompt 化。entity 抽出側の一般語混入は未対処 |
| **旧モデル物理退役** | ❌ 見送り | GraphNode/UserTopic/KnowledgeDigest は生成停止のみ (CloudKit 破壊リスクで @Model 残置) |

**総評**: LLM Wiki の「構造」(Wiki 中心・相互リンク・フィード) は達成。残る最大の壁は **token 制限による知識品質の天井**。これがコア品質ブラッシュアップ (§10) の主目的。

---

## 10. これからのプラン (ロードマップ)

### 直近: コア品質ブラッシュアップ 5 段階
2 エージェント監査で「token 逃れの入力削りすぎ」が品質低下の真因と判明。**iOS 26.4 SDK に `tokenCount`/`contextSize` API が実在**すると発見 → 勘の truncate から実測ベースへ移行する。

| spec | 内容 | token リスク | 状態 |
|---|---|---|---|
| **071** token 実測基盤 | TokenBudgetProbe で実 token をログ化 (デバッグ専用) | なし | 実装済 (PR #30 OPEN、実機検証待ち) |
| **072** カテゴリ誤分類修正 | タグ名 1 語→記事文脈込み + 定義/例/反例 prompt | なし | 実装済 (PR #31 OPEN、実機検証待ち) |
| **073 (第一歩)** concept synthesis 出力スキーマ圧縮 | overflow の真因=@Generable 出力予約。summary/insights 縮小 | 低 | 実装済 (未 commit)。残=知識抽出側 keyFacts |
| **074** 概念階層 + 動的カテゴリ + 概念抽出再設計 | フラット概念→2階層 wiki (broad>specific) + CategoryDefinition 動的カテゴリ + 概念階層 AI 抽出 | 中 | **実装済 (未 commit、新規記事のみ階層化)** |
| **075** 階層 UI | 親子表示・ドリルダウン + カテゴリ管理 UI | 低 | 未着手 |
| **076** agent loop メンテ + backfill | 再親付け(ルール)/週1AI 正規化/カテゴリ昇格(その他クラスタ検知→新カテゴリ自動追加)/既存データ backfill | 中 | 未着手 |

詳細 memory: `project_core_quality_brushup` / 設計 `docs/concept-page-hierarchy-design.md`。

### 中期
- spec 062 (KnowledgeExtractor token、073 と統合可能) — 棚上げ中
- 旧モデル物理退役 (066+、CloudKit リスクで見送り、生成停止のまま放置で無害)
- フィードの「3 タイミング」完成 (周期ダイジェストの磨き込み)

### 長期 (VISION 完全達成)
- Wiki の compound (ページが互いに育つ) を体感できる導線強化
- 学習ループ (家庭教師) の強化
- 検索・カテゴライズの精度向上

---

## 11. 抜け漏れ・リスク (シニア視点の指摘)

| 項目 | 内容 | 優先度 |
|---|---|---|
| **未マージ PR #30/#31** | 実機検証待ち。マージ前にローカル main が遅れがち (要 pull) | 中 |
| **token 品質問題が根深い** | essence/summary/keyFact/entity/concept 全層に波及。**2026-06-07 実機ログで確証**: concept synthesis が ~4090 token で intermittent 失敗 → OpenAI/Anthropic/AI/CLAUDE が essence-list fallback に劣化。**concept 出力スキーマ圧縮で一次対応済 (§12)**。知識抽出側 (keyFacts 10) は未対応 | **高** |
| **概念の分裂** | 同名 entity がカテゴリ違いで複数ページ (例: AI が [テクノロジー]×16 と [その他]×10)、CLAUDE/Claude Code/Anthropic/クロード 重複、Hacker News (サイト名) が概念昇格。spec 074 (entity 正規化 + ConceptPage キー設計) | **高** |
| **カテゴリ分類の根本** | 072 で文脈追加したが**実機で `男性→スポーツ` 等が残存**。原因は分類側でなく entity 抽出側が一般語 (男性/企業/ユーザー/彼女は/創設者) を拾うこと。072 では構造的に直らない → spec 074 | 中 |
| **旧 @Model 残存** | GraphNode/UserTopic/KnowledgeDigest が DB に残る (生成停止済、無害だが整理されていない) | 低 |
| **UI テスト flaky** | Simulator cold-launch 起因で不安定、CI なし。実機検証に依存 | 低 |
| **CI/CD 不在** | ビルド/テストは手動。回帰検知が人手頼み | 中 |
| **積み重ねブランチ事故の前科** | PR を stack すると「merged 表示でも main 未反映」の罠 (PR #25/#27 で発生)。連続 spec は前段 main マージ後に切る運用に | 中 |
| **英語記事の token 膨張** | 翻訳後も日本語より token 効率が悪く overflow しやすい。073 で言語別上限を検討 | 中 |

---

## 12. 実機ログ所見と対応 (2026-06-07)

`main + spec 072` ビルドの実機ログを解析して判明した事項と、その場で行った修正。

### 判明したこと
1. **concept synthesis の token 超過 (最重要)**: AI 要約が intermittent に `exceededContextWindowSize` (実測 4089〜4092 token、天井 4096) で失敗し、**OpenAI / Anthropic / AI / CLAUDE という主要概念がちょうど essence-list fallback (劣化版) に落ちていた**。
   - **真因**: 入力 (meta prompt) は既に cap 済みだった。犯人は **`@Generable` の出力予約**。`ConceptSynthesisOutput` が summary 400字 + crossSourceInsights 7×150字 を宣言 → 出力予約だけで窓の半分超 → 入力と合算で intermittent に天井超過。
2. **知識抽出 (KnowledgeExtractor) の chunk 脱落**: `knowledge chunk 2/10 failed … 4092 tokens` 等。`ExtractedKnowledgeOutput` の keyFacts 最大10 + entities 5-10 という大出力スキーマが同じ原理で窓を圧迫 (**未対応**)。
3. **概念の分裂**: `AI [テクノロジー]×16` と `AI [その他]×10` が別ページ / `CLAUDE`・`Claude Code`・`Anthropic`・`クロード` 重複 / `Hacker News` (サイト名) が概念化。
4. **一般語の entity 化**: `男性→スポーツ`、`ユーザー`、`企業`、`彼女は`、`創設者`。spec 072 (文脈+定義 prompt) は正しく動作していたが、抽出側が一般語を拾う問題は別レイヤ。候補外生成 (`政治`/`数学`) も残存 (fallback で救済)。
5. **無駄な再合成**: 同概念 (OpenAI/Claude Code) が 1 セッションで 6 回以上 synthesize。stale 連鎖が過剰。
6. **良性ノイズ**: `updateTaskRequest failed … BGSystemTaskSchedulerErrorDomain Code=3` 多発は CloudKit BG export の Apple 内部ノイズ (ほぼ無害)。`Unsupported locale ja` / `detected=tr` は言語検出の軽微な誤り。

### 行った修正 (concept synthesis 出力スキーマ圧縮 = 論理的に spec 073 の第一歩)
`LanguageModelSessionProtocol.swift` + `ConceptSynthesisService.swift`:
- `ConceptSynthesisOutput.summary`: 200〜400字 → **150〜280字**
- `ConceptSynthesisOutput.crossSourceInsights`: 最大7件×50-150字 → **最大4件×40-90字**
- `ConceptSummaryChunk.chunkSummary`: 100-200字 → **80-140字**
- `buildMetaPrompt` 入力 cap: 5件×100字 → **4件×90字**、出力要件文も整合
- `buildOneShotPrompt` / chunk prompt の出力要件文も整合
- **トレードオフ**: AI 要約がやや短くなるが、「失敗して essence-list 劣化版」より「成功する 280字 要約」の方が圧倒的に良い。
- **検証**: build SUCCEEDED + ConceptSynthesisServiceTests 10/10 PASS (回帰なし)。実機での `exceededContextWindowSize` 消失はユーザー確認待ち。

### 残タスク (優先度順)
1. **知識抽出側の同種修正** (keyFacts 10→絞る or 分割)。concept より波及が広い。spec 073 本体。
2. **概念分裂の解消** — spec 074 で**新規記事は 2 階層 wiki 化**して構造的に対処済 (§5)。残: 既存フラットデータの階層 backfill + 広い概念の表記揺れ統合 (生成AI/LLM/AI) = **spec 076** (agent loop)。一般語フィルタは概念階層抽出ルール (schema.md) で対処、entity 抽出側の正規化は 076。
3. **再合成の重複抑制** (stale 連鎖のデバウンス) = spec 076。

---

## 付録: クイックリファレンス

- **記事保存の入口を変えたい** → `ArticleSavingService` + 各入口 (ShareViewController / SaveURLToKnowledgeTreeIntent / AddArticleSheet)
- **知識抽出の prompt を変えたい** → `KnowledgeExtractor.buildPrompt`
- **Wiki 本文の質を変えたい** → `ConceptSynthesisService.buildWikiBodyPrompt` + `Resources/iknow-schema.md`「Wiki 本文生成ルール」
- **カテゴリ分類を変えたい** → `AutoCategoryClassifier` + `CategorySeed`
- **新しい AI 処理を足したい** → `LanguageModelSessionProtocol` にメソッド + @Generable 型追加 → `FoundationModelLanguageModelSession` 実装 + Mock 追従
- **フィードの見た目を変えたい** → `KnowledgeClipView` + `*FeedCard` / `*ShelfCard` / `*HighlightCard`
- **token を実測したい** → `TokenBudgetProbe` (spec 071、デバッグ起動でログ)
- **全 spec の実装履歴** → repo root `CLAUDE.md`

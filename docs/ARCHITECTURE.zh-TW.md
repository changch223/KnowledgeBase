# KnowledgeTree (iKnow) 整體架構文件

**最後更新**: 2026-06-07 / **對象**: main (`9c1a49d` 相當) + 本機 `072-category-fix` 分支
**註**: 檔名:行號為調查當下的「概略值」，重構後會前後浮動。

本文件把「東西放在哪裡」「分享文章後會經過什麼處理」「Wiki 頁面如何被產生」「各個 AI 處理的 prompt 與檔案位置」「已實作/未來規劃」「缺漏與風險」整理成一份。新加入的人最先讀的地圖。

---

## 1. 概覽 & 一句話願景

**iKnow** = 「把讀過的知識交給 AI 自動體系化、持續更新，只在需要時打開就能看到最新的自己，溫柔的第二大腦」(VISION v2 = LLM Wiki)。

仿照 Karpathy 的 **LLM Wiki** 三層結構:

| 層 | iKnow 中的實體 | 性質 |
|---|---|---|
| **Raw sources** (原始資訊) | `Article` (+ ArticleBody / ArticleEnrichment / ExtractedKnowledge) | 不可變。使用者儲存的文章本身 |
| **The wiki** (編纂物) | `ConceptPage` (= Wiki 頁面。人物/概念/專案) | AI 從文章產生、更新的百科頁面 |
| **The schema** (編輯規約) | `Resources/iknow-schema.md` | 給 AI 的指示書 (Wiki 內文規則 / Hedge phrase 等) |

**運作迴圈**: Karpathy 的三操作 (Ingest / Lint / Query) 中,iKnow 採用 **Ingest (文章匯入→自動編纂)** 與 **Lint (每週整理)**。不做 Query (提問→生成頁面)。

**技術堆疊**:
- Swift 6 / SwiftUI (iOS 26.4+)
- SwiftData + CloudKit (private DB 同步、App Group 共享)
- Apple Foundation Models (裝置端 LLM、`SystemLanguageModel` / `LanguageModelSession`)
- NLEmbedding (裝置端文章 embedding)、Apple Translation framework (英→日)

全部 **裝置端 (on-device)**。文章內文與知識不外傳 (隱私原則)。

---

## 2. Target 組成 (4 個 target)

```
KnowledgeTree.xcodeproj
├── KnowledgeTree                  主 App (176 swift)
├── KnowledgeTreeShareExtension    從 Safari 等的「分享」儲存文章
├── KnowledgeTreeSafariExtension   Safari Web Extension (自動儲存)
└── iKnowWidget                    主畫面 Widget (學習卡片)
```

**共享關鍵**: `SharedSchema.swift` 把所有 @Model 集中定義於一處,並設定 **App Group 容器 + CloudKit private DB** 共享。Share Extension / Widget / 主 App 讀同一個 SwiftData store。
- CloudKit 鐵則: **@Model 不可刪除、不可改名** (破壞 record type `CD_X` 會導致資料遺失)。新增欄位一定要帶 default (lightweight migration 才安全)。

---

## 3. 資料夾結構地圖 (東西放哪裡)

### `KnowledgeTree/` root (4)
| 檔案 | 角色 |
|---|---|
| `KnowledgeTreeApp.swift` | App 啟動・`init()` 註冊 BGTask・`bootstrap()` 建構所有 service/DI/backfill・TabView (3 分頁) |
| `SharedSchema.swift` | 所有 @Model 的 schema 定義 + CloudKit/App Group 設定 |
| `AppGroup.swift` | App Group 容器路徑解析 |
| `DesignSystem.swift` | 設計 token (`DS.Spacing` / `DS.Color` / `DS.Radius`,顏色為 adaptive) |

### `Models/` (21) — @Model (持久化) + transient
| 分類 | 檔案 |
|---|---|
| 文章類 | `Article` / `ArticleBody` / `ArticleEnrichment` / `ExtractedKnowledge` (內含 essence/keyFacts/entities) / `Tag` |
| Wiki・知識類 | `ConceptPage` (=Wiki) / `KnowledgeDigest` / `ConflictProposal` / `SavedAnswer` / `GraphNode` / `GraphEdge` / `UserTopic` (已退役) |
| Chat | `ChatSession` / `ChatMessage` / `AgentAction` |
| Feed・學習 | `FeedItem` (transient) / `MixedSurfaceCard` / `UnderstandingInteraction` / `LintLog` |
| 背景 | `BackgroundExtractionQueueEntry` / `KnowledgeChunkProgress` |

### `Services/` (69) — 邏輯層 (品質核心)
| 分類 | 代表檔案 | 角色 |
|---|---|---|
| **AI 生成** | `KnowledgeExtractor` / `KnowledgeExtractionService` / `ConceptSynthesisService` / `AutoCategoryClassifier` / `LanguageModelSessionProtocol` | 文章→知識、概念合成、分類。**LanguageModelSessionProtocol 是所有 @Generable 與 AI 呼叫的中樞** |
| **Chunk 處理** | `ChunkSplitter` / `ChunkedKnowledgeAggregator` / `HierarchicalChunkedSummarizer` | 長文切割摘要 |
| **分類/標籤** | `CategorySeed` / `AutoTagApplier` / `SuggestedTagFinder` / `TagNormalizer` / `TagStore` | 分類・標籤標記 |
| **Feed** | `FeedBuilder` / `RecentArticlesService` / `RecentDigestService` | iKnow 分頁的 feed 組裝 |
| **圖譜/關聯** | `GraphExtractionService` / `GraphTraversalService` / `EmbeddingService` / `RelatedArticleFinder` | 實體關係・embedding 鄰近 |
| **抓取** | `BodyExtractor` / `MetadataParser` / `MultiPageCrawler` / `PDFFetcher` / `LanguageDetector` / `ArticleEnrichmentService` | 從 HTML/PDF 抽出內文・OGP |
| **背景** | `BackgroundExtractionScheduler` / `BackgroundExtractionRunner` / `BackgroundExtractionQueue` | BGTask 控制 |
| **其他橫切** | `ServiceContainer` (DI) / `ProcessingMonitor` (進度) / `RefreshTrigger` / `SchemaLoader` / `LintEngine` / `HealthScoreService` / `ChatService` / `SavedAnswerService` / `ConflictDetectionService` / `KnowledgeDigestService` | |

### `Views/` (82) — SwiftUI 畫面
| 分類 | 代表檔案 |
|---|---|
| Feed (iKnow 分頁) | `KnowledgeClipView` (root) / `ArticleFeedCard` / `WikiFeedCard` / `ArticleShelfCard` / `WikiShelfCard` / `CategoryHighlightCard` / `TagHighlightCard` / `RecommendCarousel` / `FeedTypeBadge` |
| 詳細 | `ArticleDetailView` / `ConceptPageDetailView` / `CategoryKnowledgeDetailView` / `SavedAnswerDetailView` |
| 聊天 | `ChatTabView` / `ChatMessageRow` / `ChatHistorySidebar` / `DeepDiveChatView` (家教模式) |
| 資料庫/搜尋 | `ArticleListView` / `ArticleRow` / `TagFilteredListView` / `CategoryFilteredListView` |
| 設定/其他 | `SettingsView` / `OnboardingView` / `HealthScoreCard` / `AvatarMenu` |

### 測試
- `KnowledgeTreeTests/` — **單元測試 66 檔** (Mock 為主,把 `LanguageModelSessionProtocol` 換掉,不靠 AI 也能驗證)
- `KnowledgeTreeUITests/` — UI 4 檔 (Simulator 冷啟動下不穩定 flaky、無 CI)

---

## 4. 文章處理流水線 (儲存→知識化的完整流程)

### 入口 3 條路徑 (都不呼叫 AI,只建立 Article)
| 路徑 | 檔案 | 備註 |
|---|---|---|
| **Share Extension** | `KnowledgeTreeShareExtension/ShareViewController.swift` | Safari「分享」→ 抽出 URL+title → 儲存 → 1 秒後關閉 |
| **AppIntent** | `AppIntents/SaveURLToKnowledgeTreeIntent.swift` + `ArticleSavingActor.swift` | Shortcuts / Siri / Spotlight |
| **App 內** | `Views/AddArticleSheet.swift` | iKnow 分頁的 FAB (+ 按鈕) |

全部匯流到 `ArticleSavingService.save(url:suppliedTitle:)`。

### 階段鏈 (trigger 觸發,以 fire-and-forget 啟動下一段)

```
入口 3 條路徑
   │
   ▼
ArticleSavingService.save()              URL 正規化 (URLNormalization) / 重複判定 / 建立 Article @Model
   │                                     → SwiftData insert (無 AI)
   ▼
ArticleEnrichmentService.enrich()        HTTP GET (UA: KnowledgeTree/1.0) / OGP 解析
   │                                     → ArticleEnrichment (canonicalTitle/summary/ogImageURL/rawHTML)
   │                                     retry: [30s,120s,600s] / 離線 skip (無 AI)
   ▼ (succeeded 後 trigger)
BodyExtractionService.extract()          rawHTML → 內文文字 (BodyExtractor,密度評分)
   │                                     不足 100 字則 failed (無 AI)
   ▼ (succeeded 後 trigger)
KnowledgeExtractionService.extract()     ★ AI 知識抽出的中樞
   ├─ 短文 (內文 ≤ 400 字): 單次 → 呼叫 1 次 FM
   └─ 長文 (> 400 字): chunked
        ├─ ChunkSplitter 以 400 字為單位切割 (最多 30 chunk、句號優先)
        ├─ 每個 chunk 做 extractFromChunk (chunk 數量次 FM)
        └─ > 10 chunk 則 hierarchical (lvl2/lvl3 meta-summary)
   │  輸出 → ExtractedKnowledge (essence / summary / keyFacts / entities)
   │  ※ 可由 BGTask resume (KnowledgeChunkProgress 增量儲存)
   ▼ (succeeded / partiallySucceeded 後)
★★★ 7 個 hook 連鎖 ★★★
```

### 知識抽出後的 7 個 hook (KnowledgeExtractionService 末端)
| # | hook | 同步性 | AI | 內容 | 輸出目標 |
|---|---|---|---|---|---|
| 1 | auto-tag | **同步** | 無 | `AutoTagApplier` 把 salience 前段的 entity 變成標籤 (top 5) | `Article.tags` |
| 2 | digest stale | **同步** | 無 | 設定該分類的 `KnowledgeDigest.isStale = true` | Digest 重新生成預約 |
| 3 | embedding | **同步** | 無(NLEmbedding) | 把 essence/title 變成 [Float] embedding | `Article.essenceEmbedding` |
| 4 | 矛盾偵測 | 非同步 | **1 次** | `ConflictDetectionService` 偵測新舊文章的事實矛盾 | `ConflictProposal` |
| 5 | graph 抽出 | 非同步 | **停用中** | `GraphExtractionService` (spec 065 已將 DI 設為 nil) | (不生成) |
| 6 | 概念合成 | 非同步 | **2-3 次** | `ConceptSynthesisService.processNewArticle` → 生成/更新 ConceptPage | `ConceptPage` |
| 7 | SavedAnswer stale | 非同步 | 無 | 把相關 SavedAnswer 設為 `isStale = true` | WikiLint 用 |

- hook 1-3 在主流程內同步執行。hook 4-7 以 `Task { await }` fire-and-forget (失敗只 silent log、不阻塞主流程 = calm UX)。
- **每儲存 1 篇文章的 FM 呼叫次數**: 知識抽出 (1〜chunk 數) + 矛盾偵測 (1) + 概念合成 (2-3) + 分類 (新標籤數,最多 5) ≈ **數次〜20 次**。spec 065 已停掉 graph・topic・啟動時 digest 來減量。

### 背景處理 (BGTask 3 種)
| BGTask identifier | 角色 | spec |
|---|---|---|
| `app.KnowledgeTree.chunkedKnowledgeExtraction` | App 不在前景時繼續長文 chunked 抽出 | 009 |
| `app.KnowledgeTree.conceptResynthesis` | 重新合成 isStale 的 ConceptPage (fetchLimit 5) | 042 |
| `app.KnowledgeTree.weeklyLint` | 每週一次 (週日 3AM) Lint loop (merge/delete/reclassify) | 058 |

`KnowledgeTreeApp.init()` 註冊,`bootstrap()` 末端 schedule。

---

## 5. Wiki 頁面 (ConceptPage) 生成流程

### 2 階層模型 (spec 074〜) ★現行
ConceptPage 形成 **2 階層 wiki**: 分類(L0=既有) > **廣概念(L1)** > **具體概念(L2)**。
例: 科技 > `生成AI`(broad) > `Text-to-SQL` / `數據工程`(specific)。
- `ConceptPage.conceptLevelRaw` (`broad`/`specific`) + `parentConceptID` (具體→廣的父 ID)。
- 廣概念頁本身也是 Wiki 頁 (有 summary/bodyMarkdown,俯瞰子主題)。

### 何時被建立 — 概念階層抽出 (spec 074、現行主路徑)
文章 ingest 時 (知識抽出 hook) → `ConceptSynthesisService.ingestArticle`:
1. 用 AI 抽出概念階層 (`generateConceptHierarchy` → `ConceptHierarchyOutput`: 廣概念 1 + 具體概念 2-4)。輸入 = title+essence+keyFact,輸出小 = **token 安全**。廣概念優先用 `BroadConceptSeed` 的種子 (混合)。
2. `processConceptHierarchy` upsert broad/specific 頁 + **父子 link** (同名+同分類重用)。**從第 1 篇就建立** (不用 entity 共現的 2 篇門檻)。
3. 該頁 `isStale=true` → resynthesize 生成 summary/bodyMarkdown。
4. **AI 不可 / 抽出失敗 / 廣概念為空** → 退回舊 entity 共現路徑 (`processNewArticle`)。

### (舊) entity 共現觸發 — `processNewArticle`
spec 074 以前的方式。entity 在同分類 2+ 篇共現就建立扁平 ConceptPage。現為 **退回路徑 + backfill 用而保留** (主路徑是階層抽出)。有廣域詞肥大問題 (docs §12)。

### ConceptPage 哪些是 AI 生成
| 欄位 | 生成方式 | AI | prompt builder |
|---|---|---|---|
| `summary` (200-400字) | `resynthesize` → 1-shot 或 hierarchical | **Generable** | `buildOneShotPrompt` / `buildMetaPrompt` |
| `crossSourceInsights` (最多7) | 同上 (跨多篇文章的發現) | **Generable** | 同上 |
| `bodyMarkdown` (Wiki 內文) | `generateBodyMarkdown` | **plain string** | `buildWikiBodyPrompt` |
| `kind` (人物/概念/專案) | `inferKind` (彙總 entity type) | 無 | — |
| `embedding` | 對 summary 做 NLEmbedding | 無 | — |
| `relatedConceptIDs` (相互連結) | `nearestConceptIDs` (cosine ≥0.5 top8) + AI 內文連結 | 部分 | `buildWikiBodyPrompt` 內候選 |

- **廣概念 (broad)** (spec 074): 用子主題名 + 文章要點俯瞰來 synth (`buildBroadConceptPrompt`,小輸入 = token 安全)
- **1-shot** (≤3 篇): 把全部文章放進 1 個 prompt 合成 (具體概念頁)
- **hierarchical** (≥3 篇): 每篇文章先做 chunk 摘要 → 用 meta-summary 整合
- **plain string 的意義**: bodyMarkdown 不用 @Generable = 省下 schema serialization (~1500 token),把 token 留給內文 (spec 063 核心)
- **相互連結**: AI 在 bodyMarkdown 內埋入 `[名稱](concept-id://UUID)`,不存在/錯誤 UUID 由 `sanitizeConceptLinks` 變回純文字 (零死連結)
- **使用者修正保護**: `bodyEditedByUser=true` 則跳過重新生成

### Fallback (Apple Intelligence 不可用時)
`FallbackConceptSynthesisService`: 把 3 篇 essence 並排成簡易 summary + 取各首句變 bullet。bodyMarkdown 留空。設 `isStale=false` 防迴圈。

### 重新合成
`resynthesizeAllStale` 把 isStale 的 ConceptPage 以最新優先 (relatedArticles 的最大 savedAt 降冪) 取前 5 筆重合成。BGTask `conceptResynthesis` 也會執行。

---

## 6. AI 處理 & prompt 位置地圖

**中樞**: `Services/LanguageModelSessionProtocol.swift` 擁有所有 `@Generable` 輸出型別 + `LanguageModelSessionProtocol` (12 種 AI 方法) + 正式實作 `FoundationModelLanguageModelSession`。測試以 Mock 替換。

| # | 功能 | prompt builder (檔案) | @Generable 輸出型 / @Guide 字數 | 實作 service |
|---|---|---|---|---|
| 1 | 知識抽出 | `KnowledgeExtractor.buildPrompt` | `ExtractedKnowledgeOutput` (essence 150字 / summary 300字 / keyFacts 最多10 / entities 5-10) | KnowledgeExtractor |
| 1b | meta-summary (chunked) | `KnowledgeExtractor.buildMetaSummaryPrompt` | 同上 | 同上 |
| 1c | 翻譯前處理 (英→日) | `KnowledgeExtractor.prepareForExtraction` | plain string (Apple Translation) | LanguageDetector + translate |
| 2 | 分類 | `AutoCategoryClassifier` inline prompt | `CategoryClassificationOutput` (categoryName,**`CategoryRegistry` 驅動 = seed 10 + 動態分類**,spec 074) | AutoCategoryClassifier |
| 3 | Category Digest | `KnowledgeDigestService.buildPrompt` | `DigestOutput` (cards 1-3: summary 150字 / keyFacts 3 / entities 3) | KnowledgeDigestService |
| 4 | AI Chat (RAG) | `ChatService.buildPrompt` | `ChatAnswerOutput` (answer / citedArticleIDs) | ChatService |
| 4b | Agent Action | `ChatService.buildAgentPrompt` | `AgentAction` (struct + actionType String → enum 轉換) | ChatService |
| 5 | 最近的你 | `RecentDigestService.buildPrompt` | `RecentDigestOutput` (paragraphs 4: headline 60-100字) | RecentDigestService |
| 6 | 矛盾偵測 | `ConflictDetectionService.buildPrompt` | `ConflictDetectionOutput` (hasConflict / 各 50字) | ConflictDetectionService |
| 7 | 主題命名 | `TopicClusteringService` 內 | `TopicNameOutput` (name 5-20字) | TopicClusteringService (已退役) |
| 8 | Graph triple | `GraphExtractionService.buildPrompt` | `GraphTripleOutput` (triples 最多10、confidence 0-1) | GraphExtractionService (停用) |
| 9 | 概念合成 | `ConceptSynthesisService.buildOneShot/Chunk/MetaPrompt` | `ConceptSynthesisOutput` (summary 150-280字 / insights 4,spec 073 壓縮) | ConceptSynthesisService |
| 9b | Wiki 內文 | `ConceptSynthesisService.buildWikiBodyPrompt` | plain string (markdown) | 同上 |
| 9c | 廣概念合成 | `ConceptSynthesisService.buildBroadConceptPrompt` | `ConceptSynthesisOutput` (俯瞰子主題,spec 074) | 同上 |
| 10 | 概念階層抽出 | `ConceptSynthesisService.buildConceptHierarchyPrompt` | `ConceptHierarchyOutput` (broad 1 + specific ≤4,小輸出=token安全,spec 074) | ConceptSynthesisService |
| 11 | 家教模式 | `DeepDiveChatService.buildInitial/ContinuationPrompt` | plain string | DeepDiveChatService |

### iknow-schema.md 的嵌入
`SchemaLoader` 在啟動時載入 `Resources/iknow-schema.md`,以 `section(named:)` 抽出區塊嵌入 prompt:
- **「Wiki 本文生成ルール」(Wiki 內文生成規則)** → 動態注入 `buildWikiBodyPrompt`
- **「概念階層抽出ルール」(概念階層抽出規則)** (spec 074) → 動態注入 `buildConceptHierarchyPrompt`
- **Hedge phrases** → `HedgePhraseFilter` 把「不知道」等改成「就我理解」
- schema.md 不存在時用 code 內 fallback (production 安全)

---

## 7. 主要設計模式

1. **token 超量對策的層次** (對抗 4096 token 限制):
   - 輸入 truncate (內文 400字 / 每篇 essence 80字 / KeyFact 30字)
   - 用 plain string 輸出避開 @Generable schema 成本 (Wiki 內文・家教)
   - 用 `promptCharBudget` 做累積字數防護 (RecentDigest)
   - Fallback service (AI 失敗時的非 AI 路徑)
   - **※ 這同時也是品質下降的主因 (見 §9・§10・§12)**
   - **★重要 (2026-06-07 實機 log 發現)**: `exceededContextWindowSize` **不只是輸入的問題**。`@Generable` 會依宣告的最大輸出尺寸**預留**輸出 token,所以像 `ConceptSynthesisOutput` (舊 summary 400字 + insights 7×150字 ≈ 預留 2000+ token)、`ExtractedKnowledgeOutput` (keyFacts 最多10 + entities 5-10) 這種**大輸出 schema,就算削輸入也塞不進視窗**。對策是 (a) 縮小輸出 schema 上限、(b) 改 plain string (spec 063 的 Wiki 內文就是)。細節見 §12。
2. **availability 三段分歧**: embedding 可否 / Foundation Models 可否 / 兩者皆可。不可用就走 Fallback 或 skip (calm degrade)
3. **@Generable 限制的迴避**: 不支援 enum → 用 struct + String rawValue 再於 Swift 端轉 enum (AgentAction)。不支援 UUID → 輸出 [String] 再 `UUID(uuidString:)` 轉換
4. **fire-and-forget hook**: 不阻塞主流程 / 失敗只 silent log (calm UX,不對使用者跳 confirm/alert)
5. **CloudKit 安全準則**: @Model 不刪不改名 / 新增欄位帶 default / 退役只停止生成 (不做實體刪除)
6. **DI**: `ServiceContainer` 持有所有 service,透過 SwiftUI Environment 配送。測試注入 Mock

---

## 8. 已實作的整體樣貌 (spec 001-072)

| 範圍 | 主要 spec | 內容 |
|---|---|---|
| **基礎** | 001-010 | 文章儲存 / 內文抽出 / 知識抽出+摘要 / chunked / 階層摘要 / 背景處理 (BGTask) |
| **知識化** | 011-040 | AI 標籤 / 分類階層 / 知識 Clip 分頁 / Dark mode / RAG 聊天 / PDF / Knowledge Graph |
| **iKnow V1** | 042-058 | ConceptPage (Wiki) / SavedAnswer / 學習分頁 (家教) / Tag 編輯 / Auto-Lint / Agentic Chat |
| **CloudKit** | 051 | iCloud 同步 (private DB,14 個 Array Relationship 改 Optional) |
| **LLM Wiki 重新設計** | 063-070 | WikiPage 化 (063) / 相互連結・關係發現 (064) / AI 處理減量 (065) / News+ feed (066) / UserTopic 退役 (067) / iKnow 分頁重新設計 (068) / feed 打磨 (069) / 類型徽章 (070) |
| **核心品質** | 071-072 | token 實測基盤 TokenBudgetProbe (071、PR #30) / 分類錯誤修正 (072、PR #31) |

細節見 repo root 的 `CLAUDE.md` (各 spec 的實作紀錄) 與 `specs/` 下。

---

## 9. VISION 達成度 (什麼做到了、什麼還沒)

對 VISION v2 (7 原則 + 3 層) 的現況評估:

| VISION 要素 | 狀態 | 補充 |
|---|---|---|
| **Wiki 中心** (集中到 ConceptPage) | ✅ | 把 7 分裂概念收進 ConceptPage 完成 (063) |
| **相互連結** (頁面間 [[連結]]) | ✅ | concept-id:// + embedding 鄰近 (064) |
| **News+ feed** (文章+Wiki 混排) | ✅ | iKnow 分頁 (066/068)、For You Wiki + 4 種卡片 |
| **裝置端隱私** | ✅ | 全部 AI 在裝置內,零外傳 |
| **日文優先** | ✅ | 生成・UI 皆日文 |
| **AI 管理但人可修改** | ✅ | bodyEditedByUser 保護 / Tag・概念可手動編輯 |
| **輕量優先** (AI 呼叫最少) | 🔧 部分 | 停掉 graph/topic/啟動 digest 來減量 (065)。但靠輸入 truncate **犧牲品質換來的輕量** |
| **來源追溯** (可回到文章) | 🔧 部分 | 用 relatedArticles 可追溯,但 entity 正規化不足導致分裂 |
| **知識品質** (essence/事實/摘要) | ❌ 課題 | 受 token 限制,內文 400字・essence 80字被削,生成素材貧乏 (§10 處理) |
| **分類精度** | 🔧 改善中 | 072 改成帶上下文+定義的 prompt。entity 抽出端混入一般詞的問題未處理 |
| **舊模型實體退役** | ❌ 暫緩 | GraphNode/UserTopic/KnowledgeDigest 只停止生成 (因 CloudKit 破壞風險,@Model 留著) |

**總評**: LLM Wiki 的「結構」(Wiki 中心・相互連結・feed) 已達成。剩下最大的牆是 **token 限制造成的知識品質天花板**。這正是核心品質打磨 (§10) 的主目的。

---

## 10. 未來規劃 (Roadmap)

### 近期: 核心品質打磨 5 階段
2 個 explore agent 的稽核發現「為了躲 token 把輸入削太多」是品質下降的真因。**發現 iOS 26.4 SDK 內實際存在 `tokenCount`/`contextSize` API** → 從憑感覺 truncate 改成以實測為依據。

| spec | 內容 | token 風險 | 狀態 |
|---|---|---|---|
| **071** token 實測基盤 | 用 TokenBudgetProbe 把實際 token 記到 log (僅 debug) | 無 | 已實作 (PR #30 OPEN,待實機驗證) |
| **072** 分類錯誤修正 | 標籤名 1 詞→帶文章上下文 + 定義/例/反例 prompt | 無 | 已實作 (PR #31 OPEN,待實機驗證) |
| **073 (第一步)** 壓縮 concept synthesis 輸出 schema | overflow 真因=@Generable 輸出預留。縮小 summary/insights | 低 | 已實作 (未 commit)。剩=知識抽出端 keyFacts |
| **074** 概念階層 + 動態分類 + 概念抽出重設計 | 扁平概念→2 階層 wiki (broad>specific) + CategoryDefinition 動態分類 + 概念階層 AI 抽出 | 中 | **已實作 (未 commit,只有新文章會階層化)** |
| **075** 階層 UI | 父子顯示・下鑽 + 分類管理 UI | 低 | 未開始 |
| **076** agent loop 維護 + backfill | 重新掛父(規則)/週1AI 正規化/分類升格(其他叢集偵測→新分類自動追加)/既有資料 backfill | 中 | 未開始 |

細節 memory: `project_core_quality_brushup` / 設計 `docs/concept-page-hierarchy-design.md`。

### 中期
- spec 062 (KnowledgeExtractor token,可與 073 整合) — 擱置中
- 舊模型實體退役 (066+,因 CloudKit 風險暫緩,維持停止生成即無害)
- feed 的「3 種出現時機」完成 (週期 digest 打磨)

### 長期 (VISION 完全達成)
- 強化能體感 Wiki compound (頁面互相成長) 的動線
- 強化學習迴圈 (家教模式)
- 提升搜尋・分類精度

---

## 11. 缺漏・風險 (資深視角的指摘)

| 項目 | 內容 | 優先度 |
|---|---|---|
| **未合併 PR #30/#31** | 待實機驗證。合併前本機 main 容易落後 (需 pull) | 中 |
| **token 品質問題很深** | essence/summary/keyFact/entity/concept 全層受影響。**2026-06-07 實機 log 確證**: concept synthesis 在 ~4090 token intermittent 失敗 → OpenAI/Anthropic/AI/CLAUDE 劣化成 essence-list fallback。**已先壓縮 concept 輸出 schema 應急 (§12)**。知識抽出端 (keyFacts 10) 未處理 | **高** |
| **概念分裂** | 同名 entity 因分類不同變多頁 (例: AI 同時有 [科技]×16 與 [其他]×10)、CLAUDE/Claude Code/Anthropic/クロード 重複、Hacker News (網站名) 升格成概念。spec 074 (entity 正規化 + ConceptPage key 設計) | **高** |
| **分類的根本** | 072 已加上下文但**實機仍出現 `男性→運動` 等**。原因不在分類端,而是 entity 抽出端撿了一般詞 (男性/企業/使用者/她是/創辦人)。072 結構上修不掉 → spec 074 | 中 |
| **舊 @Model 殘留** | GraphNode/UserTopic/KnowledgeDigest 留在 DB (已停生成、無害但未整理) | 低 |
| **UI 測試 flaky** | Simulator 冷啟動造成不穩,無 CI。依賴實機驗證 | 低 |
| **無 CI/CD** | build/test 都手動。回歸偵測靠人力 | 中 |
| **堆疊分支事故前科** | PR 堆疊時有「顯示 merged 但 main 未反映」的陷阱 (PR #25/#27 發生過)。連續 spec 要在前段 merge 進 main 後再切 | 中 |
| **英文文章 token 膨脹** | 翻譯後 token 效率仍比日文差、易 overflow。073 要考慮分語言上限 | 中 |

---

## 12. 實機 log 發現與處理 (2026-06-07)

解析 `main + spec 072` 版本的實機 log,以下是發現的事項與當下的修正。

### 發現
1. **concept synthesis 的 token 超量 (最重要)**: AI 摘要 intermittent 以 `exceededContextWindowSize` (實測 4089〜4092 token、上限 4096) 失敗,**OpenAI / Anthropic / AI / CLAUDE 這些主要概念剛好都掉到 essence-list fallback (劣化版)**。
   - **真因**: 輸入 (meta prompt) 早就有 cap。兇手是 **`@Generable` 的輸出預留**。`ConceptSynthesisOutput` 宣告 summary 400字 + crossSourceInsights 7×150字 → 光輸出預留就超過視窗一半 → 加上輸入就 intermittent 撞天花板。
2. **知識抽出 (KnowledgeExtractor) chunk 掉落**: `knowledge chunk 2/10 failed … 4092 tokens` 等。`ExtractedKnowledgeOutput` 的 keyFacts 最多10 + entities 5-10 大輸出 schema 同原理擠壓視窗 (**未處理**)。
3. **概念分裂**: `AI [科技]×16` 與 `AI [其他]×10` 變兩頁 / `CLAUDE`・`Claude Code`・`Anthropic`・`クロード` 重複 / `Hacker News` (網站名) 變概念。
4. **一般詞變 entity**: `男性→運動`、`使用者`、`企業`、`她是`、`創辦人`。spec 072 (上下文+定義 prompt) 確實有作用,但抽出端撿一般詞是另一層問題。候選外生成 (`政治`/`數學`) 也殘留 (被 fallback 救回)。
5. **重複再合成**: 同概念 (OpenAI/Claude Code) 一個 session 內 synthesize 6 次以上,stale 連鎖過度。
6. **良性雜訊**: `updateTaskRequest failed … BGSystemTaskSchedulerErrorDomain Code=3` 大量出現是 CloudKit BG export 的 Apple 內部雜訊 (幾乎無害)。`Unsupported locale ja` / `detected=tr` 是語言偵測的輕微誤判。

### 已做的修正 (壓縮 concept synthesis 輸出 schema = 邏輯上 spec 073 的第一步)
`LanguageModelSessionProtocol.swift` + `ConceptSynthesisService.swift`:
- `ConceptSynthesisOutput.summary`: 200〜400字 → **150〜280字**
- `ConceptSynthesisOutput.crossSourceInsights`: 最多7件×50-150字 → **最多4件×40-90字**
- `ConceptSummaryChunk.chunkSummary`: 100-200字 → **80-140字**
- `buildMetaPrompt` 輸入 cap: 5件×100字 → **4件×90字**,輸出要求文字一併對齊
- `buildOneShotPrompt` / chunk prompt 的輸出要求文字也對齊
- **取捨**: AI 摘要會稍短,但「失敗掉到 essence-list 劣化版」遠不如「成功的 280字 摘要」。
- **驗證**: build SUCCEEDED + ConceptSynthesisServiceTests 10/10 PASS (無回歸)。實機上 `exceededContextWindowSize` 是否消失待使用者確認。

### 待辦 (依優先度)
1. **知識抽出端的同類修正** (keyFacts 10→收斂 or 拆分)。比 concept 波及更廣,是 spec 073 本體。
2. **解決概念分裂** — spec 074 已讓**新文章變 2 階層 wiki**結構性處理 (§5)。剩: 既有扁平資料的階層 backfill + 廣概念的表記揺れ合併 (生成AI/LLM/AI) = **spec 076** (agent loop)。一般詞過濾用概念階層抽出規則 (schema.md) 處理,entity 抽出端正規化在 076。
3. **抑制重複再合成** (stale 連鎖 debounce) = spec 076。

---

## 附錄: 快速查詢

- **想改文章儲存入口** → `ArticleSavingService` + 各入口 (ShareViewController / SaveURLToKnowledgeTreeIntent / AddArticleSheet)
- **想改知識抽出 prompt** → `KnowledgeExtractor.buildPrompt`
- **想改 Wiki 內文品質** → `ConceptSynthesisService.buildWikiBodyPrompt` + `Resources/iknow-schema.md`「Wiki 本文生成ルール」
- **想改分類** → `AutoCategoryClassifier` + `CategorySeed`
- **想加新的 AI 處理** → 在 `LanguageModelSessionProtocol` 加方法 + @Generable 型別 → `FoundationModelLanguageModelSession` 實作 + Mock 跟進
- **想改 feed 外觀** → `KnowledgeClipView` + `*FeedCard` / `*ShelfCard` / `*HighlightCard`
- **想實測 token** → `TokenBudgetProbe` (spec 071,debug 啟動會記 log)
- **所有 spec 的實作歷史** → repo root `CLAUDE.md`

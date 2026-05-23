# 06 — 既存プロダクトから v2 への変更点 (Migration Plan)

## Status: WIP (初稿、2026-05-17)

## 0. 位置づけ

`05-product-vision-consolidated.md` (v2) で固めた到達点と、現在の知積 (spec 001-044 実装済) との **差分を列挙し、実装順序を決める** ためのドキュメント。

このファイルは spec 045-052 の specify+plan に進む直前の「総点検チェックリスト」として使う。

---

## 1. 全体マップ (Before / After)

### Before (現在の知積、spec 044 まで実装済)

```
┌─────────────┬──────────────┬──────────────┬──────────────┐
│  ライブラリ  │  知識 Clip   │ AI ブレイン  │  AI チャット │
│             │              │              │              │
│ 記事 list   │ 最近のあなた │ Stats Row    │ Chat (RAG)   │
│ 検索 (044)  │ AI 仮説      │ 知識マップ   │ History      │
│ swipe 削除  │ Topic        │ Category list│ 引用 inline  │
│             │ Digest       │ Insight Card │              │
│             │ Conflict     │ PowerGauge   │              │
│             │ Graph 提案   │              │              │
└─────────────┴──────────────┴──────────────┴──────────────┘
起動時 default: 知識 Clip
```

### After (v2 target、spec 050+ 完了時)

```
┌──────────────┬──────────────┬──────────────┬──────────────┐
│ ★ 学習 ★    │ AI チャット  │  知識 Clip   │  ライブラリ  │
│   (Main)     │              │              │              │
│              │              │              │              │
│ Understanding│ General Chat │ + Stats統合  │ 記事 list    │
│ Card UX      │ (現状維持)   │ + Graph view │ 検索拡張     │
│ わかった/    │              │ + Category   │ swipe 削除   │
│ もっと深堀り │              │ + ConceptPage│              │
│              │              │ + Community  │              │
│              │              │ + SavedAns   │              │
│              │              │ + 気づきの種 │              │
└──────────────┴──────────────┴──────────────┴──────────────┘
起動時 default: 学習 (Main)
```

主要構造変更:
1. **新タブ「学習」追加** (起動 default)
2. **AI ブレインタブ撤去** → 内容は 知識 Clip に統合
3. **タブ並び**: 学習 / AI チャット / 知識 Clip / ライブラリ
4. **新規 @Model 4 つ** (ConceptPage / SavedAnswer / EntityCommunity / ActivityLog)
5. **既存 Article に sourceType 追加** (image / aiChat の新入力源対応)

---

## 2. タブ構造の変更

### 2.1 タブ再編 (KnowledgeTreeApp.swift)

| 変更 | 内容 | 影響範囲 |
|---|---|---|
| `AppTab` enum 拡張 | `.learning` ケース追加 | `KnowledgeTreeApp.swift` |
| `AppTab` enum 整理 | `.aibrain` 削除 (内容は知識 Clip へ) | 同上 |
| 起動 default 変更 | `.knowledgeClip` → `.learning` | 同上 line 35 |
| `TabView` 並び替え | 学習 / Chat / Clip / Library | 同上 line 62-94 |
| tab icon | 学習 = `brain.head.profile` 等、新規 | xcstrings + tabItem |

### 2.2 AI ブレインタブ撤去手順

撤去対象 view 群と移行先:

| 撤去要素 | 移行先 | 備考 |
|---|---|---|
| `AIBrainView` (root) | 削除 | タブ自体撤去 |
| `PowerGaugeCard` (spec 011) | 知識 Clip 内に格下げ統合 (任意) | あるいは Widget (spec 043) に |
| `KnowledgeMap` (Canvas force-directed) | 知識 Clip 内サブビュー | 静的 layout (spec 041) で代替可能 |
| `RecentActivity` | 知識 Clip 内に統合 (spec 035 と重複しているなら統合) | 既存 RecentDigest と冗長性確認必要 |
| `AIInsightCard` | 知識 Clip 内に統合 | 既存スタイルでカード化 |
| Category list | 知識 Clip 内にあるカテゴリーセクションへ統合 | spec 018/015 と被るので統合 |
| 歯車 (Settings 入口) | AI チャット or 知識 Clip の toolbar に移設 | |

→ **AI ブレインタブを完全削除する spec を追加検討**: `spec X: AI ブレインタブ撤去 + 知識 Clip 内統合再編`

---

## 3. データモデル (@Model) 変更

### 3.1 新規 @Model (V1 で 4 つ)

| @Model | 役割 | 含む field (概略) | spec |
|---|---|---|---|
| **ConceptPage** | 人物・モノ・テーマの横断ページ | `id, name, categoryRaw, summary, crossSourceInsights:[String], relatedArticles:[Article], relatedGraphNodes:[GraphNode], userUnderstanding:Int, isFollowing:Bool, isStale:Bool, createdAt, updatedAt` | 045 |
| **SavedAnswer** | AI Chat 答えのファイリング | `id, question, answer, citedArticleIDs:[String], relatedConceptIDs:[UUID], sessionID:UUID, savedAt` | 046 |
| **EntityCommunity** | GraphRAG Community 検出結果 | `id, name, summary, categoryRaw, level:Int, memberNodeIDs:[UUID], memberCount, articleCount, createdAt, updatedAt` | 048 |
| **ActivityLog** | log.md 相当の時系列記録 | `id, eventType:String, message:String, relatedArticleID:UUID?, createdAt` | 047 or 048 |

### 3.2 既存 @Model 改修

| @Model | 改修内容 | spec | migration 種別 |
|---|---|---|---|
| **Article** | `sourceType: String` 追加 (web/pdf/image/aiChat、default "web") | 050 | lightweight (optional default 付き) |
| **Article** | `relatedConceptPageIDs: [UUID]` (新規 inverse は ConceptPage 側で持つ) | 045 | lightweight |
| **ExtractedKnowledge** | (改修なし、既存で十分) | — | — |
| **KnowledgeEntity** | (改修なし、ConceptPage は別 @Model) | — | — |
| **GraphNode** | (改修なし、EntityCommunity は別 @Model でメンバー ID 配列で参照) | — | — |
| **ChatMessage** | `savedAnswerID: UUID?` 追加 (ピン留め時に紐付け) | 046 | lightweight |

### 3.3 SharedSchema.swift 改修

```swift
static var all: Schema {
    Schema([
        // 既存 16 種類
        Article.self, ArticleEnrichment.self, ArticleBody.self,
        ExtractedKnowledge.self, KeyFact.self, KnowledgeEntity.self,
        Tag.self, KnowledgeChunkProgress.self, BackgroundExtractionQueueEntry.self,
        KnowledgeDigest.self, ChatSession.self, ChatMessage.self,
        ConflictProposal.self, UserTopic.self,
        GraphNode.self, GraphEdge.self,
        // ★ 新規 4 種類 (v2 で追加)
        ConceptPage.self,         // spec 045
        SavedAnswer.self,         // spec 046
        EntityCommunity.self,     // spec 048
        ActivityLog.self,         // spec 047
    ])
}
```

---

## 4. Service 層変更

### 4.1 新規 Service (V1 で 6 つ)

| Service | 役割 | DI 先 | spec |
|---|---|---|---|
| **ConceptSynthesisService** | 2+ 記事に登場する entity から ConceptPage 生成・更新、Foundation Models で summary + crossSourceInsights 合成 | KnowledgeExtractionService の hook | 045 |
| **SavedAnswerStore** | AI Chat 答えのピン留め保存、関連 ConceptPage 更新 | ChatService.send post-process | 046 |
| **WikiLintService** | 週 1 BGTask で同義異名 / 孤立 / 概念候補 / 次に聞くべき問い検出、ActivityLog に記録 | KnowledgeTreeApp bootstrap | 047 |
| **CommunityDetectionService** | K-means or Louvain で EntityCommunity 検出、AI で命名 | KnowledgeTreeApp bootstrap | 048 |
| **UnderstandingCardQueueService** | 学習タブのカードキュー優先度ロジック | UnderstandingChatView | 049 |
| **ImageOCRService** | Vision framework `VNRecognizeTextRequest` で写真 → text 抽出、AI 会話判定 (発話者構造) | ArticleSavingActor の手前 | 050 |

### 4.2 既存 Service 改修

| Service | 改修内容 | spec |
|---|---|---|
| **ChatService** | post-process で compound moment 実装 (関連 ConceptPage update + SavedAnswer 自動候補化 / pin 機構) | 046, 045 |
| **ChatService** | Global Search 経路追加 (Community summary 検索) | 048 |
| **ChatService** | query 側 entity 抽出 + graph augmentation (議論済の spec 045 path) | 045 |
| **KnowledgeExtractionService** | extract 末尾に `synthesizeConceptIfPossible(article:)` hook 追加 | 045 |
| **ArticleSavingActor** | `sourceType` 判定 + 画像/AI会話の場合は ImageOCRService 経由 | 050 |
| **SearchService** (spec 044) | MatchField 拡張: ConceptPage / SavedAnswer hit | 045, 046 |
| **ConflictDetectionService** | WikiLintService から呼ばれる経路追加 (既存と並列) | 047 |
| **KnowledgeDigestService** | ConceptPage との粒度差を明示、削除不要 | — |

---

## 5. View 層変更

### 5.1 新規 View

| View | 役割 | 親 View | spec |
|---|---|---|---|
| **UnderstandingChatView** (root) | 学習タブのルート | TabView | 049 |
| **UnderstandingCardView** | カード 1 枚 (タイトル + 要点 + わかった/もっと button) | UnderstandingChatView | 049 |
| **CardDeepDiveChatView** | カード → chat 深堀り | UnderstandingChatView nav stack | 049 |
| **ConceptPageView** | 概念の詳細 (横断的知見 / 関連記事 / 関連 entity) | NavigationDestination | 045 |
| **ConceptPageEditSheet** | rename / merge / delete (TagStore パターン) | ConceptPageView | 045 |
| **SavedAnswerSection** | 知識 Clip 内、ピン留め Q&A list | KnowledgeClipView | 046 |
| **SavedAnswerDetailView** | Q&A 詳細 + 関連 ConceptPage link | NavigationDestination | 046 |
| **EntityCommunityCard** | コミュニティカード | KnowledgeClipView | 048 |
| **EntityCommunityDetailView** | コミュニティ詳細 (member entities / 関連記事) | NavigationDestination | 048 |
| **WikiLintProposalsSection** | 「気づきの種」セクション | KnowledgeClipView | 047 |
| **CatalogView** (任意、Q3 次第) | 全 @Model 横断 index ビュー | 知識 Clip サブビュー or 別タブ | 048 (任意) |
| **ImageInputPreviewView** | 写真共有時の OCR プレビュー + 確認 | Share Sheet 経由 | 050 |
| **AIConversationStructurePreview** | AI 会話 OCR の発話者分離プレビュー | 同上 | 050 |

### 5.2 既存 View 改修

| View | 改修内容 | spec |
|---|---|---|
| **KnowledgeTreeApp** | tab 再編 + 起動 default 変更 | — |
| **KnowledgeClipView** | AI ブレインタブから移管されてくる要素を吸収 + 新セクション 5 つ追加 (ConceptPage / Community / SavedAnswer / WikiLint / Catalog) | 045-048 |
| **ChatTabView** | message 横に「📌 保存」ボタン (citations ≥ 2 のみ) | 046 |
| **ChatMessageRow** | savedAnswer 紐付けあれば pin icon 表示 | 046 |
| **ArticleListView** | 検索結果に ConceptPage / SavedAnswer hit を inline 表示 (任意) | 045, 046 |
| **ArticleDetailView** | 「この記事から派生した概念ページ」セクション追加 | 045 |
| **SettingsView** | 新項目: 翻訳 setup の隣に「学習通知」「Activity Log 表示」「Web 検索 (V2)」 | 047, V2 spec 051 |
| **CategoryFilteredListView / CategoryKnowledgeDetailView** | CategoryGraphView (spec 041) 既存、EntityCommunity との関係明示 | 048 |

### 5.3 削除候補 view

AI ブレインタブ撤去で削除 or 統合される view:

| 既存 view | 処理 |
|---|---|
| `AIBrainView` | 削除 |
| `PowerGaugeCard` | (任意) Widget へ移管 or 削除 |
| `KnowledgeMap` (force-directed Canvas) | (任意) 知識 Clip 内に格下げ、または削除 |
| `RecentActivityCards` | spec 035 RecentDigest と重複なら削除 |
| `AIInsightCard` | 知識 Clip 内のカード形式に統合 |
| `KnowledgeCategoryRow` (AI ブレイン版) | 知識 Clip の Category 表示と統合 |

→ **削除に伴う既存 spec 011 関連の test も削除**

---

## 6. 入力源拡張 (spec 050)

### 6.1 写真 / スクリーンショット

| 要素 | 実装 |
|---|---|
| Share Sheet 受け入れ | Info.plist の `NSExtensionAttributes.NSExtensionActivationRule` に image type 追加 (ShareExtension 改修) |
| Photo picker (アプリ内) | `PhotosPicker` SwiftUI (iOS 16+) 採用 |
| OCR | `VNRecognizeTextRequest` (Vision framework)、日本語 + 英語混在対応 |
| OCR 失敗時 | Article は作成、本文 = (OCR 失敗) として残す (calm UX) |

### 6.2 AI 会話スクショ (ChatGPT / Gemini / Claude)

| 要素 | 実装 |
|---|---|
| 判定 | OCR テキストから「発話者バブル」「Q-A 交互」構造を推定 |
| 抽出 | Foundation Models で発話分離 + Q-A ペア化 |
| 保存 | Article として保存、`sourceType = aiChat`、Article.title = 先頭 Q から自動生成 |
| 既存パス | 抽出後は通常パイプライン (essence/keyFacts/entities) に流す |

### 6.3 手動 paste 経路

- 既存 Share Sheet (テキスト) の経路で対応可能
- AI 会話 markdown 形式の paste も同様処理

---

## 7. Bootstrap 改修 (KnowledgeTreeApp.swift)

### 7.1 新規 Service の構築・inject

```swift
// 既存 bootstrap に追加 (順序考慮: ConceptPage 先、Chat 後)

// spec 045
let conceptSynthesisService = ConceptSynthesisService(
    context: context, session: session, availability: availability
)

// spec 048
let communityDetectionService = CommunityDetectionService(
    context: context, session: session, availability: availability
)

// spec 047
let wikiLintService = WikiLintService(
    context: context, session: session, availability: availability,
    refreshTrigger: refreshTrigger
)

// spec 046
let savedAnswerStore = SavedAnswerStore(
    context: context, refreshTrigger: refreshTrigger
)

// spec 049
let cardQueueService = UnderstandingCardQueueService(context: context)

// spec 050
let imageOCRService = ImageOCRService()

// 既存 knowledgeService に concept hook を inject
let knowledgeService = DefaultKnowledgeExtractionService(
    // 既存 dependencies +
    conceptSynthesisService: conceptSynthesisService,
)

// 既存 chatService に savedAnswer + concept hook
let chatService = ChatService(
    // 既存 dependencies +
    conceptSynthesisService: conceptSynthesisService,
    savedAnswerStore: savedAnswerStore,
    graphTraversal: graphTraversalService,  // 既存
)

// ServiceContainer に登録
serviceContainer.conceptSynthesisService = conceptSynthesisService
serviceContainer.savedAnswerStore = savedAnswerStore
serviceContainer.wikiLintService = wikiLintService
serviceContainer.communityDetectionService = communityDetectionService
serviceContainer.cardQueueService = cardQueueService
serviceContainer.imageOCRService = imageOCRService
```

### 7.2 BGTask 追加

- WikiLint 週 1 (BGTaskScheduler 経由、spec 009 同パターン)
- CommunityDetection 週 1 (同上)
- ConceptPage backfill (起動時 1 回、既存記事に対する初期生成)

---

## 8. Settings 拡張

| 新規項目 | 役割 | デフォルト | spec |
|---|---|---|---|
| 「学習通知」(週 1 reminder opt-in) | 「カードが届きました」soft notif | OFF | 049 |
| 「Activity Log を表示」 | log.md 相当の閲覧 UI | OFF | 047 |
| 「Web 検索 (V2)」 | Tavily/Brave/Exa BYOK | OFF | V2 spec 051 |
| 「Markdown Export」 (V2) | 全 ConceptPage / SavedAnswer / Digest を vault エクスポート | — | V2 spec 052 |

既存項目維持:
- 翻訳セットアップ (spec 042)
- ナレッジグラフ表示 (spec 041)
- タグ管理 (spec 024)
- AI チャット履歴削除 (spec 021)
- Safari Web Extension (spec 020)

---

## 9. xcstrings (i18n) 追加

新規必要文言の見積もり (大雑把):

| spec | 追加文言数 |
|---|---|
| 045 ConceptPage | ~25 (タイトル / セクション / アクション) |
| 046 SavedAnswer | ~10 |
| 047 WikiLint | ~20 (検出種別 / アクション) |
| 048 EntityCommunity | ~15 |
| 049 Understanding Chat | ~30 (カード UI / 「わかった/もっと」/ オンボーディング) |
| 050 写真入力 | ~15 (OCR プレビュー / エラー) |
| 学習タブ icon label | ~3 |
| 合計 | **~120 文言** |

→ 既存 ~300 文言 + 新規 ~120 = ~420 文言。

---

## 10. Tests

### 10.1 各 spec 新規 test

| spec | テスト数見込み |
|---|---|
| 045 ConceptSynthesisServiceTests | ~8 |
| 046 SavedAnswerStoreTests | ~5 |
| 047 WikiLintServiceTests | ~7 |
| 048 CommunityDetectionServiceTests | ~6 |
| 049 UnderstandingCardQueueServiceTests | ~5 |
| 050 ImageOCRServiceTests | ~4 (実画像で flaky 注意) |
| 合計 | **~35 新規テスト** |

### 10.2 既存 test の改修

- ChatServiceTests に compound moment / Global Search の test 追加 (~5)
- KnowledgeExtractionServiceTests に concept hook の test 追加 (~2)
- SearchServiceTests に ConceptPage / SavedAnswer hit の test 追加 (~3)

合計 ~45 件のテスト追加。

---

## 11. SwiftData Migration 戦略

### 11.1 Migration の種類

| 変更 | Migration 種別 | リスク |
|---|---|---|
| 新規 @Model 追加 (4 つ) | Lightweight (自動) | 低 |
| Article.sourceType 追加 (optional + default "web") | Lightweight | 低 |
| ChatMessage.savedAnswerID 追加 (optional) | Lightweight | 低 |
| 既存 @Model の field 変更 | (該当なし) | — |

→ **全て lightweight migration、custom migration plan 不要**。spec 042 の Article.essenceEmbedding 追加と同パターン。

### 11.2 既存データ backfill

| 対象 | backfill 戦略 |
|---|---|
| ConceptPage (既存記事から逆生成) | アプリ起動時に 1 回、BGTask で漸進 (spec 045 で実装) |
| EntityCommunity (既存 GraphNode から検出) | 同上 (spec 048) |
| Article.sourceType | default "web" で初期化、過去記事は web として扱う |

---

## 12. 後方互換性 / 既存ユーザー影響

| 変更 | 既存ユーザー体感 | 対策 |
|---|---|---|
| 起動 default が「学習」に変わる | 「あれ?」と感じる | 初回起動時 1 回だけ onboarding overlay (3 秒 dismiss 可) |
| AI ブレインタブが消える | 慣れた UI が消える | 知識 Clip 内に内容を可視的に再構成、Settings に「旧 AI ブレイン要素」リンク (任意) |
| ConceptPage が自動生成され始める | 「何これ?」感 | 知識 Clip に「★ 新機能: 概念ページ」と一時 banner、3 タップで dismiss |
| 写真入力が新 surface | (新規 surface 増、negative ナシ) | Share Sheet にひっそり登場 |
| 通知 (学習 reminder) | opt-in なので影響なし | — |

→ **破壊的変更は最小、ほぼ加算更新**。

---

## 13. リスク評価

| リスク | 重大度 | 対策 |
|---|---|---|
| ConceptPage 自動生成の精度低 | 高 | spec 045 で `@Generable` Guide 強化、初回生成は backfill で時間取る |
| Understanding Chat の UX 不適合 (一般人が使いこなせない) | 高 | spec 049 でユーザビリティ テスト、AB compare |
| Community 検出 K-means の品質 | 中 | Option A (K-means) でまず PoC、不満なら Option B (Louvain) に upgrade |
| 写真 OCR の精度 (日本語混在) | 中 | Vision framework 標準、不足なら開発者向け追加 LLM 補完 |
| Foundation Models context window 4k で ConceptPage synthesis 足りない | 中 | spec 010 chunked + 階層 summary パターン流用 |
| 既存 @Model migration 失敗 | 低 | lightweight のみ、テスト環境で確認 |
| AI ブレインタブ撤去で慣れたユーザー離反 | 中 | onboarding overlay + 知識 Clip での再構成で緩和 |
| 学習通知が「不安喚起」になる | 中 | 完全 opt-in default OFF + 文言を「優しい reminder」に統一 |

---

## 14. 実装順序 (推奨)

### Phase A (基盤、~3-4 週間)

依存関係順:

1. **spec 045 ConceptPage @Model + ConceptSynthesisService + ConceptPageView**
   - 最重要、全ての V1 機能の基盤
   - 既存 KnowledgeExtractionService の hook 追加で自動生成
   - 既存 Article への backfill 経路
   
2. **spec 050 写真 / AI 会話入力**
   - 入力源拡張、他 spec から独立 (並行実装可)
   - ShareExtension 改修 + ImageOCRService 新規

### Phase B (compound + lint、~2-3 週間)

3. **spec 046 SavedAnswer + Chat filing**
   - ConceptPage に依存 (filing 先として)
   - ChatService post-process 改修

4. **spec 047 WikiLint 拡張**
   - ConceptPage / GraphNode を健全性チェック対象に
   - 同義異名 / 孤立 / 概念候補 検出
   - 「気づきの種」セクション

### Phase C (Community + Understanding、~3-4 週間)

5. **spec 048 EntityCommunity + (任意) Catalog View**
   - GraphNode から K-means で Community 検出
   - 知識 Clip に新セクション
   - (任意) Catalog View

6. **spec 049 Understanding Chat (Main、新タブ)** ★ **最大スコープ**
   - UnderstandingCardQueueService
   - Card UX + わかった/もっと
   - CardDeepDiveChatView
   - **同時に: 起動 default 変更 + AI ブレインタブ撤去 + タブ再編**

### Phase D (Widget + 統合 polish、~1-2 週間)

7. **spec 043 Widget** (ROADMAP 既存)
   - 「今のあなた」「最近のあなた」「翻訳セットアップ」を WidgetKit
   - ambient surface

8. **タブ再編 / AI ブレインタブ撤去の最終仕上げ**
   - 既存 view の削除 / 移管
   - onboarding overlay
   - 既存 test の削除
   - xcstrings 整理

### V2 (Phase E 以降、別 cycle)

9. spec 051 Web search (BYOK)
10. spec 052 Markdown Export
11. Voice Input
12. 他

---

## 15. spec 別タスク数見積もり (粗見積)

| spec | タスク数 | 規模 (LoC) |
|---|---|---|
| 045 ConceptPage | ~12-15 | 600-800 |
| 046 SavedAnswer | ~6-8 | 200-300 |
| 047 WikiLint | ~8-10 | 400-500 |
| 048 EntityCommunity (+ Catalog 任意) | ~10-12 | 400-600 |
| 049 Understanding Chat | ~15-20 | 800-1000 |
| 050 写真 / AI 会話入力 | ~10-12 | 400-500 |
| 043 Widget | ~8-10 | 400-500 |
| **V1 合計** | **~70-85** | **~3500-4500** |

3 ヶ月想定 (週 ~30 タスク消化ペース)。

---

## 16. 削除・撤去するもの (整理)

| 削除対象 | spec | タイミング | 影響 |
|---|---|---|---|
| `AppTab.aibrain` enum case | tab 再編 | spec 049 と同時 | 既存 view 全部削除 |
| `AIBrainView` | 同上 | 同上 | 子 view も削除 |
| `PowerGaugeCard` 等 spec 011 残骸 | 同上 | 同上 | Widget に部分移管 or 削除 |
| `KnowledgeMap` (force-directed Canvas、spec 011) | 同上 | 同上 | spec 041 の static layout で代替 |
| `RecentActivityCards` (spec 011) | 同上 | 同上 | spec 035 RecentDigest と重複なら削除 |
| 既存 AI ブレイン関連 test | 同上 | 同上 | 削除 |
| 旧 default tab (`.knowledgeClip`) 起動経路 | 起動時 default 変更 | spec 049 同時 | コード変更 1 行 |

→ **削除によるコード削減も発生する** (~500 行程度の view コードが消える想定)。

---

## 17. 「決定 → ブランチ戦略」案

実装作業を整理:

| 段階 | ブランチ | spec 範囲 |
|---|---|---|
| 1 | `045-concept-page` | spec 045 単独 |
| 2 | `050-image-input` | spec 050 単独 (045 と並行可) |
| 3 | `046-saved-answer` | spec 046 (045 ベース) |
| 4 | `047-wikilint` | spec 047 (045 ベース) |
| 5 | `048-community` | spec 048 (040 ベース) |
| 6 | `049-understanding-main` | spec 049 + タブ再編 + AI ブレイン撤去 (大型) |
| 7 | `043-widget` | spec 043 単独 |
| 統合 | main マージ | 各 spec 完了で順次 |

各 spec で specify → plan → tasks → implement → quickstart → commit/push の通常 spec kit フロー。

---

## 18. 残課題 / 要回答 (v2 §14 から refresh)

実装着手前に確定したいもの:

| Q | 内容 | デフォルト案 |
|---|---|---|
| Q1 | タブ構成 | **B: 4 タブ** |
| Q2 | 起動 default | **学習** |
| Q3 | Catalog View (Index 相当) を V1 に入れる? | **V1 内部のみ、UI 露出は V2** |
| Q4 | Activity Log UI 露出 | **Settings opt-in (OFF default)** |
| Q5 | 動的 Schema 進化 (提案 E) | **完全廃案** |
| Q6 | クイズ機能 (提案 F) | **廃案、Main に統合** |
| Q7 | 写真入力範囲 | **OCR テキストのみ V1** |
| Q8 | AI 会話入力主軸 | **両方、スクショ主軸** |

これら回答後、spec 045 から specify+plan に進む。

---

## 19. 決定ログ (running)

| 日付 | 決定 | 根拠 |
|---|---|---|
| 2026-05-17 | 本ファイル `06-migration-plan.md` 作成 | user 指示「既存 product の変更点を新規 md で整理」 |
| 2026-05-17 | V1 = 7 spec (043, 045, 046, 047, 048, 049, 050) | §1 と §12 |
| 2026-05-17 | Phase A→D の実装順序 | §14 |
| 2026-05-17 | 全 SwiftData migration は lightweight | §11 |
| 2026-05-17 | AI ブレインタブ撤去は spec 049 と同時 | §2 |
| 2026-05-17 | 削除 view 群リスト確定 | §5.3, §16 |
| TBD | Q1-Q8 回答 | 議論待ち |
| TBD | spec 045 specify 開始 | Q1-Q8 確定後 |

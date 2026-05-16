<!-- SPECKIT START -->
Active features in flight:
- spec 001-008 — ✅ 実装 + main マージ済 (spec 001-005 commit `0fad9fd` / spec 006 `74d167b` / spec 007 `640c89c` / spec 008 `8f3ce4a` + hot-fix `fbcde69`).
- spec 009-010 — ✅ 実装 + commit `adc2221` (BGTaskScheduler incremental save + 階層的 chunked summarization).
- spec 011 — UI リブランディング + AI ブレインタブ追加 — ✅ 実装 + commit `8b8671e` (本ブランチ `011-ai-brain-tab`、未マージ)。Tab 化 / PowerGauge / KnowledgeMap (Canvas + force-directed) / RecentActivity / 知積リブランディング 全部完成。Unit テスト 18/18 PASS。実機検証 (quickstart.md SC-001〜SC-008) と Instruments 60fps 計測のみ未実施。
- spec 012 — タグ自動付与 (AI Auto-Tag) — ✅ 実装 + commit `0e6e299` (本ブランチ `012-auto-tag`、未マージ)。AutoTagApplier 純粋関数 + KnowledgeExtractionService の hook 2 箇所 + bootstrap で TagStore inject。新 schema ゼロ。Unit テスト 7/7 PASS、既存テスト全回帰 PASS。
- spec 013 — 既存記事への auto-tag backfill — ✅ 実装 + commit `dc877bd` + main マージ済 (PR #2 / merge `47a9338`)。AutoTagBackfillRunner + BackfillFlagStore + ProcessingMonitor.Phase `.tagBackfilling`。Unit テスト 7/7 PASS。
- spec 014 — 統一デザインシステム + Phase 3/4 視覚改善 — ✅ 実装 + commit `b78c2f4` + PR #3 OPEN (本ブランチ `014-design-system`)。
- spec 015 — AI ブレイン v2 + DesignSystem migration + Category 階層 — ✅ 実装 (本ブランチ `015-ai-brain-v2-categories`、未 commit)。AIBrainView v2 (Stats Row + Insight Card + Category List) + DESIGN.md target に DesignSystem 移行 (9 token alias 残し + 5 token 追加) + Tag.categoryRaw lightweight migration + AutoCategoryClassifier + AutoCategoryBackfillRunner + ProcessingMonitor.Phase `.categoryClassifying` + BottomStatusBar phase tint actionBlue 統一。Unit テスト 12/12 PASS、既存テスト全回帰 PASS。実機検証で B1 バグ + 4 UX 要望が判明 → spec 016 へ。
- spec 016 — Category 詳細画面 + ArticleRow 時間軸 + 本文折りたたみ — ✅ 実装 + main マージ済 (PR #4 / merge `66ab948`)。CategoryFilteredListView 新設 + CategoryFilter 純関数 enum で B1 バグ根本解決 (タップ先 = Category 全 Tag union 記事一覧、数字 = 実体一致) + タグフィルター OR (上位 5 + 「+N ▼」展開) + ArticleRow に SavedAtFormatter 時間軸表示 (今日/昨日/N 日前/絶対) + ArticleDetailView bodySection を DisclosureGroup 折りたたみ + KnowledgeCategoryRow.topTagName 削除。Unit テスト 15/15 PASS。実機検証 SC-001/002/003/006/008 ✅、SC-004/005/007 は次回検証。
- spec 017 — Dark/Light Mode 自動切り替え対応 — ✅ 実装 (本ブランチ `018-knowledge-clip-tab` 内に内包、未 commit)。DesignSystem.swift に `Color.adaptive(light:dark:)` extension 新設 + 5 tokens を adaptive 化。Unit テスト 7/7 PASS。実機検証 SC-001〜SC-009 未実施 (まとめて後で)。
- spec 018 — 知識 Clip タブ + Category 統合 AI ダイジェスト + Category 知識総まとめ詳細画面 — ✅ 実装 + main マージ済 (PR #5 / merge `9c41d60`)。新タブ「知識 Clip」(`lightbulb.fill`) + KnowledgeDigest @Model + KnowledgeDigestService (Foundation + Fallback) + 3 view + markStale hook + 起動時 regenerateAllStale。Unit テスト 10/10 PASS。実機検証は基本 ✅、ブラッシュアップは spec 023+ 候補で別途。
- spec 019 — Chrome 連携 (App Intents + iOS Shortcut + 設定画面 Setup Guide) — 🔧 実装中 (本ブランチ `019-chrome-app-intent`、未 commit)。T001-T008 完成、Build SUCCEEDED。残: T012 全テスト回帰 + T013 CLAUDE.md + T014 実機検証 (ユーザー)。
- spec 020 — Safari Web Extension + 自動保存モード — 🔧 実装中 (本ブランチ `019-chrome-app-intent` 継続、未 commit)。Safari Web Extension target 追加 (Apple template ベース) + manifest.json (`*://*/*` 全ページ content_scripts) + content.js (DOM 抽出 + 8 種 blacklist + 滞在時間遅延 immediate/5/10/30 秒) + background.js (toolbar tap で即時保存) + SafariWebExtensionHandler.swift (saveURL + getAutoSaveSettings handlers) + SafariSetupView (3 ステップ + 自動保存 Toggle + 遅延 Picker + 確認 alert) + SettingsView 拡張 (Chrome / Safari 2 エントリ) + 11 ファイル分の Target Membership pbxproj 自動編集。Build SUCCEEDED、scheme test action は Safari target 追加で破損 (要再構成、別途対応)。実機検証未実施。
- spec 021 — AI Chat (RAG) — ✅ 全実装完了 (本ブランチ `019-chrome-app-intent` 継続、未 commit、2026-05-06)。Phase 1-8 (T001-T024) 完成、T025 実機検証のみ未実施。
  - **Phase 1-2 (T001-T008)**: xcstrings 15 文言 + SharedSchema 拡張 + ChatSession/ChatMessage @Model + Article.essenceEmbedding (`@Attribute(.externalStorage) Data?`) lightweight migration + [Float]↔Data zero-copy ext + EmbeddingService (NLEmbedding.sentenceEmbedding(for: .japanese) + Accelerate vDSP_dotpr で L2 正規化 cosine similarity)。**EmbeddingServiceTests 6/6 PASS**
  - **Phase 3 (T009-T012)**: ChatAnswerOutput @Generable + ChatService protocol+実装 (3 段階 availability 分岐 / 50 件 FIFO / 3 段階ハルシネーション post-process: low-similarity 早期 return / cited 空 → 「分かりません」上書き / 存在しない ID filter) + KnowledgeExtractionService に embedding 生成 hook 追加 (単一 + chunked 両パス)。**ChatServiceTests 8/8 PASS**
  - **Phase 4-5 (T013-T017)**: ChatMessageRow (user 右寄せ actionBlue / assistant 左寄せ dsCardBackground + 引用 DisclosureGroup) + ChatInputField (1〜4 行 vertical TextField + 送信 Button) + ChatTabView (.task で session 復元 + LazyVStack messages + ScrollViewReader auto scroll + NavigationDestination → ArticleDetailView)
  - **Phase 6 (T018-T019)**: Fallback 経路 (Embedding 不可 → keyword マッチ retrieval / FM 不可 → essence + KeyFact 並べ整形)
  - **Phase 7 (T020-T021)**: SettingsView に「チャット履歴を全削除」エントリ + 確認 alert + ChatService.deleteAllSessions
  - **Phase 8 (T022-T024)**: 4 タブ目「AI チャット」(`bubble.left.and.bubble.right.fill`) + Build SUCCEEDED + シリアル実行で全テスト PASS
  - **解決済 (2026-05-16)**: BodyExtractorTests/extractsFromMainTag + extractsByDensityScoringWhenNoSemanticTag の deterministic fail は、誤診断だった (「global state mutation」「順序依存」ではない)。真の原因は **テストフィクスチャ自体が BodyExtractor の 100 字閾値を超えられない** こと。`mainTagHTML` の本文は htmlToText 後 79 字、`noSemanticHTML` は density score が 200 閾値に届かなかった。`-only-testing` の identifier が paren 無しだとテストが選択されず "実行されないまま SUCCEEDED 扱い" になっていたため isolated PASS と誤認していた。修正は **フィクスチャ拡張のみ** (BodyExtractor 本体は無改修)。全 9/9 PASS。
  - **scheme test action 復元 (2026-05-06 完了)**: `KnowledgeTree.xcscheme` を xcshareddata に復元、`xcodebuild test -scheme KnowledgeTree` で動作確認済 (ShareExtension scheme 経由は引き続き動作)。次セッションから両 scheme 利用可能
  - **2026-05-06 実機検証で判明 → fix 済**: (1) ChatTabView が @State currentSession.messages を読んでいて SwiftData @Relationship 追加を reactive 検知できず画面更新されない問題 → @Query + sessionID filter に変更、(2) prompt 通り answer 本文に UUID を書く LM の挙動 → prompt に「本文に ID を書くな」明示 + ChatService.stripUUIDsFromBody post-process 追加 (テスト 3 件追加で計 ChatServiceTests 11/11 PASS)、(3) keyboard 閉じない問題 → `.scrollDismissesKeyboard(.interactively)` 追加 (iMessage 風)、(4) **致命**: 履歴全削除後に質問送信すると履歴が部分復活 + 画面フリーズ → currentSession を `@State` ではなく `@Query allSessions` から動的算出 (`pinnedSessionID` + 最新 fallback) に変更、dead reference 問題を根本解決
  - **残**: T025 実機検証 (quickstart 12 シナリオ) ユーザー実施
  - **次世代要望 (spec 033+ 候補)**: モダン Chat UI (Gemini/Claude/ChatGPT 風) — 履歴サイドバー + multi-turn context + token streaming + 引用 inline link 化、大規模 ~600 行、別 spec で実施
- spec 022 — ArticleRow swipe 削除 — ✅ 部分実装完了 (本ブランチ `019-chrome-app-intent` 継続、main 未マージ、2026-05-06)。List 系 3 view 完了: `ArticleListView` (spec 001 から既実装) + `TagFilteredListView` + `EntityFilteredListView`。swipe 方向は `.trailing` (iOS 標準)。LazyVStack 系 2 view は spec 030 で対応予定。Build SUCCEEDED。
- spec 030 — LazyVStack 系 view の削除手段 (Category 詳細 / 知識 Clip 詳細) — 📝 specify+plan 完了 (本ブランチ、未 commit、2026-05-06)。contextMenu (長押し → メニュー) 採用、~30 行極小、新規ファイルゼロ、Phase 1 必須 + Phase 2 (List 系 UX 統合) optional。実装はユーザー判断後に着手。
- spec 034 — PDF サポート (内部 metadata + 本文抽出) — ✅ main マージ済 (PR #7、commit `06cc2a9`、2026-05-06)。PDFKit で title / subject / author / 全 page text を抽出、擬似 HTML 化して既存フローに乗せる。PDFFetcherTests 10/10 PASS。
- **VISION.md 確定版** (本ブランチ `vision-spec-035-038`、未 commit、2026-05-08) — プロダクト戦略を 17 質問のユーザー対話で固める。「読んだ知識を AI が自動で体系化・更新し、必要な時だけ開けば最新の自分が見える、優しい第二の脳」を一文ビジョン、6 設計原則、4 タブ構成、4 機能 (X/Y/Z/W) を確定。
- spec 035 — 「最近のあなた」差分ダイジェスト (機能 X) — ✅ 実装完了 (本ブランチ、未マージ、2026-05-08)。LastOpenedStore + RecentDigestService + RecentDigestSection 新規 + KnowledgeClipView 改修 + KnowledgeTreeApp で起動時 default = .knowledgeClip。**RecentDigestServiceTests 6/6 PASS**。
- spec 036 — 動的トピック自動発見 (機能 Y) — ✅ 実装完了 (本ブランチ、未マージ、2026-05-08)。UserTopic @Model + TopicClusteringService (K-means + Accelerate vDSP) + AI 命名 + Fallback + DynamicTopicsSection + UserTopicCandidateRow + UserTopicDetailView。起動時 + 7 日 batch、minArticles=10/minClusterSize=3/maxK=20。**TopicClusteringServiceTests 6/6 PASS**。
- spec 037 — 時系列事実上書き提案 (機能 Z) — ✅ 実装完了 (本ブランチ、未マージ、2026-05-08)。ConflictProposal @Model + Article.isObsolete 追加 + ConflictDetectionService + KnowledgeExtractionService に hook 追加 (単一+chunked) + FactConflictsSection + ConflictProposalRow。**ConflictDetectionServiceTests 7/7 PASS**。
- spec 024 — Tag 編集 / 統合 / 削除 UI — ✅ 実装完了 (本ブランチ、未マージ、2026-05-08)。TagStore.rename / merge / delete 拡張 + TagManagementView + TagEditSheet + SettingsView エントリ。AI Auto-Tag (spec 012) の誤訂正手段、VISION「AI 自動 + ユーザー確認」原則の完成形。**TagStoreEditTests 8/8 PASS**、xcstrings 19 文言追加。
- spec 040 — Knowledge Graph 抽出 + Digest + RAG 統合 (Phase A) — ✅ 実装完了 (本ブランチ、未 commit、2026-05-16)。Phase 1-7 全て完成。GraphNode/GraphEdge @Model + SharedSchema 拡張 + pbxproj に Share/Safari Extension target 登録 + GraphTripleOutput @Generable + MockLanguageModelSession 拡張 + GraphExtractionService (AI triple → upsert / 30 node 上限 deactivate / 確信度 3 段階 / Fallback 共起) + GraphTraversalService (resolveNodes/neighbors/topByDegree) + KnowledgeExtractionService に extractGraphIfPossible hook (single + chunked) + KnowledgeDigestService prompt に「## このカテゴリーの主要エンティティと関係性」セクション + ChatService prompt に「## 関連エンティティ」セクション (top-k 記事 entity → 1-hop neighbor) + ServiceContainer + KnowledgeTreeApp bootstrap 配線。**Unit テスト全 PASS**: GraphExtractionServiceTests 10/10 + GraphTraversalServiceTests 5/5 + ChatServiceTests 18/18 (新規 graph 統合 3 件含む) + KnowledgeExtractorTests 6/6。Build SUCCEEDED (iPhone 17 Simulator)。BodyExtractorTests 2 件 fail は **既存 bug** (spec 021 既知、HEAD revert しても再現、spec 040 と無関係)。残: 実機検証 (quickstart 未作成、Phase B = spec 041 で UI 検証時に併せて実施)。
- spec 044 — 検索 relevance ranking + matched field — ✅ 実装完了 (本ブランチ、未 commit、2026-05-16)。spec 008 SearchPredicate は既に 8 フィールド substring match を提供していたが結果は savedAt 順のみで title 一致が下位に埋もれていた。本 spec で SearchService 純関数を追加 (title 完全一致 100 / title 部分 50 / entity・tag 20 / essence・summary 10 / canonicalTitle・KeyFact 5、同 score は savedAt desc tiebreak) + MatchField enum (title/essence/summary/keyFact/entity/tag) + ArticleListView.filteredArticles を SearchService 経由に切替。**Unit テスト全 PASS**: SearchServiceTests 5/5 (空 query / title 完全 > 部分 / entity > essence / tag match in fields / savedAt tiebreak)。Build SUCCEEDED + 全 unit suite regression なし (BodyExtractor 既知 bug も同セッションで解消済)。MVP では ArticleRow badge は未実装 (MatchField.localizationKey は将来 spec 用に残置)。
- spec 042 — 英語記事の翻訳前処理 (KnowledgeExtractor) — ✅ 実装完了 (本ブランチ、未 commit、2026-05-16)。原因: 全パイプライン (prompt / @Generable Guide / NLEmbedding.japanese / Auto-Category / Digest / Conflict / Graph) が日本語固定で、英語記事は essence truncate / hallucination / RAG retrieval 不能と多段で連鎖失敗。解決策: 入口翻訳で本文を日本語化 → 既存パイプライン全レイヤを無改修で再利用。実装: 新規 `LanguageDetector.swift` (純関数、NLLanguageRecognizer 経由) + `LanguageModelSessionProtocol.generateTranslation(prompt:)` 追加 (plain String 返却、Generable 不要) + FoundationModelLanguageModelSession 実装 + MockLanguageModelSession 拡張 + `KnowledgeExtractor.prepareForExtraction` (英語のみ翻訳、失敗 / 空 / 1/4 未満は raw fallback) + `buildTranslationPrompt` (固有名詞は英語維持指示) + extract / extractFromChunk 経路 hook。保存ポリシー: title / ArticleBody.body は英語のまま、知識層 (essence / KeyFact / entities) は日本語化。schema 変更ゼロ。**Unit テスト全 PASS**: LanguageDetectorTests 3/3 + KnowledgeExtractorTests 9/9 (新規 3: 日本語スキップ / 英語翻訳 + 訳出本文で抽出 / 翻訳 throws → raw fallback)。Build SUCCEEDED。残: 実機検証 (英語記事 BBC / Wired / TechCrunch 等で SC-1〜SC-5)。
- spec 041 — Knowledge Graph UI + 編集 (Phase B) — ✅ 実装完了 (本ブランチ、未 commit、2026-05-16)。段階 1-5 全て完成。Settings の Graph 表示 toggle (default OFF、`@AppStorage("settings.graphVisible")`) + CategoryGraphView (SwiftUI Canvas、中心 = degree 最大 / 周辺 = 円形配置 / 実線 = label 付き / 破線 = 共起 / 薄色 = isUncertain) + GraphLayout 純関数 + GraphNodeDetailView (関連記事 + edges + 編集 toolbar) + GraphNodeEditSheet (rename/merge/delete + 確認 alert、TagStore 同パターン) + GraphEdgeEditSheet (label rename/delete) + GraphProposalsSection (知識 Clip タブで isUncertain edge を採用/却下/ラベル変更) + GraphProposalReviewService + ConflictDetectionService.detectGraphConflicts (同 source+predicate 複数 target → ConflictProposal 作成、graphEdgeID 付き、ConflictProposal に optional `graphEdgeID: UUID?` lightweight migration) + CategoryFilteredListView / CategoryKnowledgeDetailView に CategoryGraphView 連動表示 + node tap → GraphNodeDetailDestinationLoader push 遷移。**Unit テスト全 PASS**: GraphLayoutTests 3/3 + GraphNodeStoreTests 7/7 + GraphProposalReviewServiceTests 3/3 + ConflictDetectionServiceTests 9/9 (新規 graph 2 件含む)。Build SUCCEEDED (iPhone 17 Simulator)。BodyExtractorTests 2 件 fail は **既存 bug** (spec 021 既知、HEAD revert しても再現)。残: 実機検証 (spec 040 と併せて)。
- spec 033 — AI Chat モダン UI 刷新 — ✅ 実装完了 (本ブランチ、未マージ、2026-05-08)。NavigationSplitView (iPad sidebar / iPhone overlay) + ChatHistorySidebar + ChatSessionRow (相対時刻 + アクティブハイライト + swipe 削除 + 「+ 新しいチャット」) + multi-turn context (直前 4 message) + 擬似 streaming (15ms/文字、Apple Intelligence streaming API 不要) + inline 引用 link (`[タイトル](article-id://UUID)` を AttributedString で描画) + session 個別削除。**ChatServiceTests 15/15 PASS** (新規 4 ケース: multi-turn / deleteSession / inline link prompt / strip preserves link)。R1 streaming API は MVP では擬似 streaming で割り切り、真 streaming は将来 spec。
- spec 038 — 用語のやさしさ整理 (機能 W) — 📝 specify+plan 完了 (本ブランチ、未 commit、2026-05-08)。KeyFact → 事実、entity → 人物・場所・モノ、Category → 分野、Auto-Tag → AI タグ等、xcstrings value 修正 + DESIGN.md Vocabulary 追加、コード型名は維持、~200-300 行。
- spec 019 撤回 — ✅ 撤回完了 (2026-05-06)。Chrome 自動化 (Setup Guide / Personal Automation 連携) は Chrome iOS の x-callback-url が「現在のタブ URL」を返さない技術制約で実用化不可と判明。SettingsView から Chrome エントリ削除 + `ChromeShortcutSetupView.swift` 削除。Chrome は Share Extension (spec 001) のみで運用、ユーザー判断による方針確定。AppIntent / AppShortcutsProvider / ArticleSavingActor 実装は Safari Web Extension が依存するため残置。

Read these first for the current planning context (spec 019 = newest plan):

**spec 019 (Chrome 連携 App Intents + iOS Shortcut + 設定画面)**:
- plan: `specs/019-chrome-app-intent/plan.md` — 新規 4 + 改修 2 + 新規テスト 1 = ~7 ファイル / Constitution Check 全 PASS
- research: `specs/019-chrome-app-intent/research.md` — R1〜R12 (AppIntent 構成 / AppShortcutsProvider 自動登録 / ArticleSavingActor SwiftData 経路 / SwiftData lifecycle / SettingsView Form / Step Card UI / 歯車 toolbar / Info.plist 不要 / xcstrings 13 文言 / static performSave テスト戦略 / Personal Automation 「実行前通知 OFF」 / Chrome x-callback-url 制約)
- data-model: `specs/019-chrome-app-intent/data-model.md` — 既存 Article 再利用 + transient AppIntent / Provider / Destination + actor + UserDefaults flag 1 つ
- contracts: `specs/019-chrome-app-intent/contracts/{save-url-to-knowledgetree-intent, app-shortcuts-provider, article-saving-actor, settings-view, chrome-shortcut-setup-view}.md`
- quickstart: `specs/019-chrome-app-intent/quickstart.md` — 12 検証シナリオ (自動登録 / 手動実行 / 重複 / 無効 URL / Personal Automation / 歯車 / SettingsView / Setup Guide / deeplink / Complete-Reset / fallback / 既存回帰)

**spec 018 (知識 Clip タブ + Category 統合 AI ダイジェスト)**:
- plan: `specs/018-knowledge-clip-tab/plan.md` — 新規 6 + 改修 5 + 新規テスト 2 = ~13 ファイル / Constitution Check 全 PASS
- research: `specs/018-knowledge-clip-tab/research.md` — R1〜R12 (KnowledgeDigest @Model / @Generable DigestOutput / Foundation+Fallback service / markStale hook / pull-to-refresh / KnowledgeClipCard layout / 包括サマリ / 期間フィルター / SwiftData migration / テスト戦略 / fallback トリガー / トークン上限)
- data-model: `specs/018-knowledge-clip-tab/data-model.md` — 新 @Model KnowledgeDigest (sourceArticles non-optional、Constitution III) + Article inverse + transient 4 つ
- contracts: `specs/018-knowledge-clip-tab/contracts/{knowledge-digest-model, knowledge-digest-service, knowledge-clip-view, knowledge-clip-card, category-knowledge-detail-view}.md`
- quickstart: `specs/018-knowledge-clip-tab/quickstart.md` — 12 検証シナリオ (新タブ / カード / 期間 / 詳細画面遷移 / stale / refresh / fallback / Empty / マルチカード / 既存回帰)

**spec 017 (Dark/Light Mode 自動切り替え対応)**:
- plan: `specs/017-dark-mode-tokens/plan.md` — DesignSystem.swift 一元 + DESIGN.md 更新 + ColorAdaptiveTests 新規、Constitution Check 全 PASS
- research: `specs/017-dark-mode-tokens/research.md` — R1〜R10 (Color.adaptive 実装方式 / Dark variant 値選定 / opacity auto adapt / 9 alias 経由 / テスト戦略 / DESIGN.md 更新範囲 / iOS 14+ サポート / Reduce Transparency 自動対応)
- data-model: `specs/017-dark-mode-tokens/data-model.md` — 既存 @Model 無関係、Color extension のみ
- contracts: `specs/017-dark-mode-tokens/contracts/color-adaptive.md` — Color.adaptive(light:dark:) 契約 + 7 unit test ケース
- quickstart: `specs/017-dark-mode-tokens/quickstart.md` — 9 検証シナリオ (Light 保持 / Dark 切替 / Auto / 各 view Dark 視覚 / Reduce Transparency / パフォーマンス / 廃止 view)

**spec 016 (Category 詳細画面 + ArticleRow 時間軸 + 本文折りたたみ)**:
- plan: `specs/016-category-detail-view/plan.md` — 新規 1 view + 改修 5 view + Hashable destination 1 つ / Constitution Check 全 PASS
- research: `specs/016-category-detail-view/research.md` — R1〜R10 (destination 配置 / +N 展開 UX / savedAt フォーマット / DisclosureGroup 位置 / Tag 集計 / カウント仕様 / テスト戦略 / xcstrings / navigationDestination / topTagName 削除)
- data-model: `specs/016-category-detail-view/data-model.md` — 既存 @Model 再利用 + transient struct 1 つ (CategoryFilteredDestination)
- contracts: `specs/016-category-detail-view/contracts/{category-filtered-list-view, category-filtered-destination, article-row-saved-at, article-detail-body-disclosure}.md`
- quickstart: `specs/016-category-detail-view/quickstart.md` — 9 検証シナリオ (B1 修正 / OR フィルター / +N 展開 / 60 秒以内反映 / savedAt 表示 / 本文折りたたみ / Reduce Motion / 既存回帰 / unit test)

**spec 015 (AI ブレイン v2 + DesignSystem migration + Category)**:
- plan: `specs/015-ai-brain-v2-categories/plan.md`
- research: `specs/015-ai-brain-v2-categories/research.md` (R1〜R10)
- data-model: `specs/015-ai-brain-v2-categories/data-model.md`
- contracts: `specs/015-ai-brain-v2-categories/contracts/{auto-category-classifier, auto-category-backfill-runner, ai-brain-stats-row, ai-insight-card, knowledge-category-row}.md`
- quickstart: `specs/015-ai-brain-v2-categories/quickstart.md` (12 検証シナリオ)

**spec 013 (既存記事への auto-tag backfill)**:

**spec 013 (既存記事への auto-tag backfill)**:
- plan: `specs/013-auto-tag-backfill/plan.md` — bootstrap 末尾 1 ブロック / 純 UI 拡張 / 新 service 1 つ + protocol 1 つ
- research: `specs/013-auto-tag-backfill/research.md` — R1〜R5 (ProcessingMonitor.Phase 拡張 / UserDefaults キー / MainActor 並行性 / fetch 戦略 / テスト隔離)
- data-model: `specs/013-auto-tag-backfill/data-model.md` — 既存 @Model 再利用 + UserDefaults キー 1 つ + Phase enum 拡張
- contracts: `specs/013-auto-tag-backfill/contracts/{auto-tag-backfill-runner,backfill-flag-store}.md`
- quickstart: `specs/013-auto-tag-backfill/quickstart.md` — 7 検証シナリオ (1 度限り backfill / 2 回目 early return / 100 件 30 秒 / 整理済保持 / 新記事競合 / 強制終了復帰 / 新規インストール)

**spec 012 (タグ自動付与 / AI Auto-Tag)**:
- plan: `specs/012-auto-tag/plan.md` — KnowledgeExtractionService への hook 2 箇所 / 新 service ゼロ / Constitution Check 全 pass
- research: `specs/012-auto-tag/research.md` — R1〜R5 (hook 位置 / API 形 / early return / DI / テスト戦略)
- data-model: `specs/012-auto-tag/data-model.md` — 既存 @Model 再利用、transient struct ゼロ
- contracts: `specs/012-auto-tag/contracts/{auto-tag-applier,knowledge-extraction-service-hook}.md`
- quickstart: `specs/012-auto-tag/quickstart.md` — 7 検証シナリオ (新規 5 タグ付与 / 既存タグ skip / 全削除復活 / 失敗時非付与 / spec 011 波及 / 既存挙動回帰 / 100 件取りこぼし)

**spec 011 (UI リブランディング + AI ブレインタブ)**:

**spec 011 (UI リブランディング + AI ブレインタブ)**:
- plan: `specs/011-ai-brain-tab/plan.md` — TabView 化 / 純 UI 拡張 / 新 @Model ゼロ / Constitution Check 全 pass
- research: `specs/011-ai-brain-tab/research.md` — R1〜R8 (TabView 環境注入、Canvas force-directed、@Query 集計、7 日 predicate、CFBundleDisplayName、エッジ計算、新繋がり判定)
- data-model: `specs/011-ai-brain-tab/data-model.md` — 既存 @Model 再利用 + transient 型 (MapNode / MapEdge / MapGraph / RecentActivitySnapshot)
- contracts: `specs/011-ai-brain-tab/contracts/{ai-brain-view,knowledge-map-builder,power-gauge-card,recent-activity-cards}.md`
- quickstart: `specs/011-ai-brain-tab/quickstart.md` — 7 検証シナリオ (空状態 / カウントアップ / 60fps / live update / 既存回帰 / タブステート保持 / a11y)

**spec 009 / 010 (実装済)**:
- spec 009 plan: `specs/009-background-extraction/plan.md`
- spec 010 plan: `specs/010-hierarchical-summary/plan.md`

For spec 006-008 reference:
- spec 006 plan: `specs/006-chunked-summarize/plan.md`
- spec 007 plan: `specs/007-multipage-fetch/plan.md`
- spec 008 plan: `specs/008-search-tags-graph/plan.md`

For spec 001 〜 005 reference:
- spec 001 plan: `specs/001-save-article/plan.md`
- spec 005 spec + quickstart: `specs/005-detail-status-ui/spec.md` + `quickstart.md`

Project constitution: `.specify/memory/constitution.md` (v1.0.0, 7 Japanese-first
product principles + secondary engineering quality gates).
<!-- SPECKIT END -->

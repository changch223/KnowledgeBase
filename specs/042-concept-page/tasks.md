---

description: "Task list for spec 042 — ConceptPage (概念ページ) / iKnow V1 第 1 弾"
---

# Tasks: ConceptPage (概念ページ)

**Input**: Design documents from `/specs/042-concept-page/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ (7 ファイル), quickstart.md

**Tests**: 含む (ユーザー指定。Mock LM + in-memory ModelContainer による単体テストを Phase 3 / 6 内に配置)

**Organization**: タスクは User Story 別に編成。各 P1 story (US1 / US2 / US3) は独立 testable な MVP increment、P2 (US4 / US5) と P3 (US6) は順次追加。

## Format

```text
- [ ] [TaskID] [P?] [Story?] Description (file path)
```

- **[P]**: 並列実行可 (異なるファイル、相互依存なし)
- **[Story]**: US1〜US6 に対応 (Phase 1/2/Polish は Story ラベルなし)
- ファイルパスは project-relative

## Path Convention

iOS app (Xcode multi-target):
- 実装: `KnowledgeTree/` (main target)
- テスト: `KnowledgeTreeTests/`
- Localization: `KnowledgeTree/Localization/Localizable.xcstrings`
- Project file: `KnowledgeTree.xcodeproj/project.pbxproj` (Info.plist / target membership 編集時のみ)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: ローカライズ文言の準備。新規 ~15 文言を `Localizable.xcstrings` に追加 (Constitution 「View body 内 literal 禁止」)。

- [x] T001 Localizable.xcstrings に ConceptPage 関連の ~15 文言を追加 (`KnowledgeTree/Localization/Localizable.xcstrings`)
  - キー: `ConceptPage.sectionTitle` = "あなたが追っている人物・モノ"
  - キー: `ConceptPage.detail.summary.title` = "今わかっていること"
  - キー: `ConceptPage.detail.crossSourceInsights.title` = "横断的知見"
  - キー: `ConceptPage.detail.relatedArticles.title` = "関連記事"
  - キー: `ConceptPage.detail.relatedConcepts.title` = "つながる人物・モノ"
  - キー: `ConceptPage.detail.synthesisInProgress` = "整理中… AI が複数記事を統合しています"
  - キー: `ConceptPage.card.relatedCount` = "関連記事 %lld 件"
  - キー: `ConceptPage.card.synthesisInProgress` = "整理中…"
  - キー: `ConceptPage.showAll` = "+%lld すべて見る"
  - キー: `ConceptPage.editSheet.title` = "概念ページの編集"
  - キー: `ConceptPage.editSheet.rename` = "名前を変更"
  - キー: `ConceptPage.editSheet.merge` = "他の概念と統合"
  - キー: `ConceptPage.editSheet.delete` = "削除"
  - キー: `ConceptPage.editSheet.pin` = "ピン"
  - キー: `ConceptPageStore.error.emptyName` = "概念名を入力してください"
  - キー: `ConceptPageStore.error.nameTooLong` = "概念名は 30 文字以内にしてください"
  - キー: `ConceptPageStore.error.duplicateInCategory` = "同じカテゴリーに同名の概念ページが既に存在します"
  - キー: `ConceptPageStore.error.sameSourceTarget` = "統合元と統合先は別の概念ページを選んでください"
  - 全文言の日本語 value を埋める (英訳は V1 では不要)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 全 User Story の前提となる core データモデル + AI structured output schema。**全 US の開始を block する**。

**⚠️ CRITICAL**: T002〜T004 完了まで US1 以降の実装は着手不可。

- [x] T002 [P] `ConceptPage` @Model 新規作成 (`KnowledgeTree/Models/ConceptPage.swift`)
  - 12 フィールド: `id` / `name` / `nameAliases` / `categoryRaw` / `summary` / `crossSourceInsights` / `relatedArticles` / `relatedConceptIDs` / `userUnderstanding` / `isFollowing` / `isStale` / `embedding` (Data?) / `createdAt` / `updatedAt`
  - `@Attribute(.unique)` for id、`@Relationship(deleteRule: .nullify)` for relatedArticles (片方向、Article 側に inverse 追加しない)、`@Attribute(.externalStorage)` for embedding
  - `init` で `isStale = true` をデフォルト
  - computed property: `searchableNames` (lowercased + aliases) / `summaryPreview` / `isSynthesisInProgress`
  - 詳細仕様: `specs/042-concept-page/contracts/concept-page-model.md`

- [x] T003 `SharedSchema.swift` に `ConceptPage.self` を追加 (`KnowledgeTree/SharedSchema.swift`)
  - `static let all: [any PersistentModel.Type]` 配列の末尾に `ConceptPage.self` を追加
  - T002 完了に依存 (同 import パス)

- [x] T004 [P] `ConceptSynthesisOutput` + `ConceptSummaryChunk` @Generable + LanguageModelSession 拡張 (`KnowledgeTree/Services/LanguageModelSessionProtocol.swift`)
  - `@Generable struct ConceptSynthesisOutput: Codable` に `summary: String` (200-400 字、推測禁止、断定調) + `crossSourceInsights: [String]` (最大 7 件、各 50-150 字) を `@Guide` description 付きで定義
  - `@Generable struct ConceptSummaryChunk: Codable` に `chunkSummary: String` (100-200 字) を `@Guide` 付きで定義
  - protocol method 追加: `func generateConceptSynthesis(prompt: String) async throws -> ConceptSynthesisOutput` / `func generateConceptSummaryChunk(prompt: String) async throws -> ConceptSummaryChunk`
  - `FoundationModelLanguageModelSession` に session.respond(to:generating:) を使った実装追加
  - `MockLanguageModelSession` 拡張: `mockConceptSynthesis: ConceptSynthesisOutput?` / `mockConceptSummaryChunk: ConceptSummaryChunk?` / `conceptSynthesisCallCount: Int` / `conceptSummaryChunkCallCount: Int` / `shouldFailConceptSynthesis: Bool` プロパティ + method 実装 (deterministic fixture 返却、failure 時 throw)
  - 詳細仕様: `specs/042-concept-page/contracts/concept-synthesis-output.md`

**Checkpoint**: Foundation ready — US1 (P1) 以降の実装に着手可能

---

## Phase 3: User Story 1 — 概念ページの自動生成 (Priority: P1) 🎯 MVP

**Goal**: 2+ 件の同名 entity を含む記事保存で ConceptPage が自動生成され、BGTask で AI 合成 summary + crossSourceInsights が更新される。spec.md US1 + FR-001/004/005/007/008/009/010/013 + SC-001/002/003/004/005/008/009 を実装。

**Independent Test**: 「Apple」を含む記事 2 件を Share Sheet で保存 → ConceptPage が DB に出現 (30 秒以内)。BGTask 完了後に summary が 200-400 字日本語で記録される (quickstart.md SC-001/002/003)。

### Implementation for User Story 1

- [x] T005 [US1] `ConceptSynthesisServiceProtocol` 定義 + `FallbackConceptSynthesisService` 実装 (`KnowledgeTree/Services/ConceptSynthesisService.swift`)
  - protocol method: `processNewArticle(article:)` / `resynthesize(_:)` / `resynthesizeAllStale()` / `backfillFromExistingArticles()` (全 `async`、`AnyObject` 制約、`@MainActor`)
  - `enum ConceptSynthesisError` (内部 silent log 用、throw しない)
  - `FallbackConceptSynthesisService` 実装: `relatedArticles` を savedAt desc で sort → 上位 3 件の essence を `\n\n` join で summary に、crossSourceInsights は essence 先頭文 3 件
  - Fallback の `processNewArticle` / `resynthesize` 両方を実装 (`isStale = false` を最後に設定)
  - 詳細仕様: `specs/042-concept-page/contracts/concept-synthesis-service.md`

- [x] T006 [US1] `FoundationModelsConceptSynthesisService` 実装 — processNewArticle + resynthesize + 1-shot + hierarchical (`KnowledgeTree/Services/ConceptSynthesisService.swift` 同ファイル末尾)
  - init で `session: LanguageModelSessionProtocol` / `availability: AvailabilityChecker` / `fallback: ConceptSynthesisServiceProtocol` / `embeddingService: EmbeddingServiceProtocol` / `context: ModelContext` / `refreshTrigger: RefreshTrigger` を受け取る
  - `processNewArticle(article:)`: article.extractedKnowledge.entities 走査 → 各 entity (name, categoryRaw) で in-memory 大文字小文字無視 fetch (`searchableNames.contains`) → 既存あり: isStale = true、無し & 過去出現 1+ 件: 新規生成 + relatedArticles に 2 件 (過去 + 今回)
  - `resynthesize(_:)`: `availability.isAvailable == false` → fallback に委譲 / 4 件以下 → 1-shot prompt (R4 形式) で `session.generateConceptSynthesis(prompt:)` 呼び出し / 5+ 件 → hierarchical (chunked size=4) → 各 chunk を `generateConceptSummaryChunk` → 全 chunk summaries を meta prompt 化 → `generateConceptSynthesis`
  - 結果は post-process: `summary.prefix(497) + "…"` (500 chars 超 trim) / `crossSourceInsights.prefix(7)` / `embeddingService.embed(text: summary)` を embedding に保存
  - 最終 `conceptPage.isStale = false; updatedAt = .now`、`context.save()`、`refreshTrigger.bump()`
  - 全例外を catch して silent fail (isStale 維持)、`[weak self]` capture
  - prompt template: `specs/042-concept-page/contracts/concept-synthesis-output.md` の「Prompt Templates」セクション通り

- [x] T007 [US1] `resynthesizeAllStale` + `backfillFromExistingArticles` 実装 (`KnowledgeTree/Services/ConceptSynthesisService.swift` 同ファイル末尾)
  - `resynthesizeAllStale`: `FetchDescriptor<ConceptPage>(predicate: #Predicate { $0.isStale }, sortBy: [SortDescriptor(\.updatedAt)])` + `fetchLimit = 5` → for-await で順次 `resynthesize(_:)` 呼び出し
  - `backfillFromExistingArticles`: `UserDefaults.standard.bool(forKey: "ConceptPage.backfillCompleted") == true` なら return → 全 Article fetch → 順次 `processNewArticle(article:)` 呼び出し → 完了で `set(true, forKey: "ConceptPage.backfillCompleted")`
  - エラー silent fail、`[weak self]` capture
  - Fallback service も同 2 メソッドを実装 (`backfill` は同 flag を使い回し)

- [x] T008 [US1] `KnowledgeExtractionService` extract 末尾に concept hook 追加 + DI (`KnowledgeTree/Services/KnowledgeExtractionService.swift`)
  - init parameter に `conceptSynthesisService: ConceptSynthesisServiceProtocol? = nil` 追加、weak property として保持
  - `extract(article:)` 末尾の hook 群 (spec 037 / 040 既存) と並列で `Task { [weak self] in await self?.conceptSynthesisService?.processNewArticle(article: article) }` 追加
  - chunked extract 経路の末尾にも同じ Task hook を追加 (spec 010 経路、同 article ref)
  - 詳細仕様: `specs/042-concept-page/contracts/knowledge-extraction-service-hook.md`

- [x] T009 [US1] `ConceptResynthesisScheduler` 追加 + Info.plist BGTask identifier 登録 (`KnowledgeTree/Services/BackgroundExtractionScheduler.swift` + `KnowledgeTree.xcodeproj/project.pbxproj` 経由 Info.plist)
  - `BackgroundExtractionScheduler` に `static func registerConceptResynthesisTask(synthesisService:)` 追加: `BGTaskScheduler.shared.register(forTaskWithIdentifier: "app.KnowledgeTree.conceptResynthesis", using: nil)` → handler 内で `Task { @MainActor in await synthesisService?.resynthesizeAllStale(); task.setTaskCompleted(success: true) }` + `task.expirationHandler` 設定
  - `static func scheduleNextConceptResynthesis()` 追加: `BGAppRefreshTaskRequest` で earliestBeginDate = 1 時間後で submit
  - Info.plist の `BGTaskSchedulerPermittedIdentifiers` array に `app.KnowledgeTree.conceptResynthesis` を追加 (pbxproj 内 INFOPLIST_KEY_BGTaskSchedulerPermittedIdentifiers or Info.plist 別ファイル直編集、既存 spec 009 と同手順)

- [x] T010 [US1] `ServiceContainer` に conceptSynthesisService / conceptPageStore 追加 + KnowledgeExtractionService に inject (`KnowledgeTree/Services/ServiceContainer.swift`)
  - property 追加: `let conceptSynthesisService: ConceptSynthesisServiceProtocol` / `let conceptPageStore: ConceptPageStore`
  - init 内で `FallbackConceptSynthesisService` を先に構築 → `FoundationModelsConceptSynthesisService` に fallback として inject → `ConceptPageStore(context:refreshTrigger:)` 構築 → `KnowledgeExtractionService` 構築時に `conceptSynthesisService:` 引数で渡す
  - 注: ConceptPageStore は T018 で実装するため、本タスクでは forward reference のみ (compile error 回避のため空 class でも先に作る、または T018 を先に着手)
  - 簡略化: T018 を Phase 2 に前倒しせず、本 T010 は ConceptPageStore コンパイル後 (T018 完了後) に最終調整。MVP では `conceptSynthesisService` のみ inject、`conceptPageStore` は Phase 6 で T018 後に追加 split 可

- [x] T011 [US1] `KnowledgeTreeApp.swift` で BGTask register + .task で backfill + resynthesizeAllStale (`KnowledgeTree/KnowledgeTreeApp.swift`)
  - `init` 内で `BackgroundExtractionScheduler.registerConceptResynthesisTask(synthesisService: serviceContainer.conceptSynthesisService)` 呼び出し
  - main `WindowGroup` 内 `ContentView` に `.task { await serviceContainer.conceptSynthesisService.backfillFromExistingArticles(); await serviceContainer.conceptSynthesisService.resynthesizeAllStale() }` 追加
  - 既存 spec 009 / 037 / 040 と並列で動作 (互いに干渉しない)

### Tests for User Story 1

- [x] T012 [P] [US1] `ConceptSynthesisServiceTests` 新規 (10 ケース) (`KnowledgeTreeTests/ConceptSynthesisServiceTests.swift`)
  - fixture: `ModelContainer(for: SharedSchema.all, configurations: ModelConfiguration(isStoredInMemoryOnly: true))` + `MockLanguageModelSession` + `MockAvailabilityChecker` + `MockEmbeddingService`
  - ケース 1: `processNewArticle` で同 entity 1 件のみ → ConceptPage fetch count == 0
  - ケース 2: 2+ 件 → ConceptPage 新規生成 + isStale=true、name/categoryRaw 一致
  - ケース 3: 既存 ConceptPage + 新記事 → isStale=true 設定、summary 内容保持
  - ケース 4: `resynthesize` (Foundation 経路、Mock fixture) → summary 更新、isStale=false、embedding=non-nil
  - ケース 5: `resynthesize` (4 記事、1 chunk) → conceptSummaryChunkCallCount == 0、conceptSynthesisCallCount == 1
  - ケース 6: `resynthesize` (5 記事、chunked パス) → conceptSummaryChunkCallCount >= 1、conceptSynthesisCallCount == 1 (最終 meta)
  - ケース 7: Fallback 経路 (availability=false) → essence 並べ summary 生成、isStale=false
  - ケース 8: Foundation 経路 throw (`shouldFailConceptSynthesis = true`) → silent fail、isStale 維持、例外 throw なし
  - ケース 9: `backfillFromExistingArticles` (50 件 article、10 entity) → ConceptPage 10 件生成、UserDefaults flag = true
  - ケース 10: 大文字小文字違い ("Apple" vs "apple") → 同 ConceptPage に統合 (count 1)
  - 各テスト @MainActor、async/await、`#expect` macro (Swift Testing) or XCTAssert

- [x] T013 [P] [US1] `KnowledgeExtractionServiceTests` に hook 検証 1-2 ケース追加 (`KnowledgeTreeTests/KnowledgeExtractionServiceTests.swift`)
  - 新規 `MockConceptSynthesisService` クラス (テスト内 private、`processNewArticleCallCount: Int` + 他 method は no-op)
  - ケース A: `extract(article:)` 呼び出し後、await で Task 完了待ち → `mockConceptSynthesisService.processNewArticleCallCount == 1`
  - ケース B: chunked extract 経路でも同 callCount == 1 (重複呼び出しなし)

**Checkpoint**: US1 完成 → 自動生成 + Stale 再合成 + Fallback degrade + backfill が動作。MVP minimum increment (まだ UI 露出なし)。

---

## Phase 4: User Story 2 — 知識 Clip タブで概念ページ一覧 (Priority: P1)

**Goal**: 知識 Clip タブの「あなたが追っている人物・モノ」セクションに ConceptPage カード一覧 (上位 5 件 + 「+N すべて見る」) を表示、タップで DetailView (US3 で実装) へ遷移可能。spec.md US2 + FR-019/020/021 + SC-007 を実装。

**Independent Test**: US1 で 3+ ConceptPage 生成済の状態で知識 Clip タブを開く → セクションが出現、3 カード表示。10+ 件で「+N すべて見る」link 出現 (quickstart.md SC-001/007)。

### Implementation for User Story 2

- [x] T014 [P] [US2] `ConceptPageCard` view 新規 (`KnowledgeTree/Views/ConceptPageCard.swift`)
  - 3 行 layout: 1) SF Symbol (categoryRaw 別) + name (`font(.dsBodyEmphasized)`) + isFollowing pin icon (条件付き) + 関連記事数 badge / 2) summary preview 1 行 (`isSynthesisInProgress` 時「整理中…」gray) / 3) 最終更新 (`SavedAtFormatter.relative(from:)` 流用、spec 016 既存)
  - DesignSystem token: `.dsCardBackground` / `.dsContentPadding` / `clipShape(RoundedRectangle(cornerRadius: 12))` / `.dsActionBlue` for pin
  - SF Symbol mapping: 人物→`person.fill` / 組織→`building.2.fill` / モノ→`cube.fill` / 概念→`lightbulb.fill` / その他→`tag.fill` (categoryRaw enum で switch)
  - accessibility: `accessibilityIdentifier("conceptPageCard_\(conceptPage.id.uuidString)")`、`accessibilityLabel` で name + count + summaryPreview 合成、`accessibilityElement(children: .combine)`
  - 詳細仕様: `specs/042-concept-page/contracts/concept-page-card.md`

- [x] T015 [US2] `KnowledgeClipView` に「あなたが追っている人物・モノ」セクション追加 (`KnowledgeTree/Views/KnowledgeClipView.swift`)
  - 既存 view に `@Query(filter: #Predicate<ConceptPage> { $0.relatedArticles.count >= 2 }, sort: [SortDescriptor(\.isFollowing, order: .reverse), SortDescriptor(\.updatedAt, order: .reverse)], animation: .default) private var conceptPages: [ConceptPage]` を追加
  - 配置位置: FactConflictsSection の **下**、DynamicTopicsSection の **上** (research.md R7 通り)
  - body: `if !conceptPages.isEmpty` でセクション全体を包む / セクションタイトル `Text(LocalizedStringKey("ConceptPage.sectionTitle")).font(.dsSectionTitle)` / `ForEach(conceptPages.prefix(5)) { NavigationLink(value: ConceptPageDetailDestination(id: $0.id)) { ConceptPageCard(conceptPage: $0) } }` / `if conceptPages.count > 5 { NavigationLink(LocalizedStringKey("ConceptPage.showAll"), value: ConceptPageListDestination()).font(.dsCaption) }`
  - 全 NavigationLink は親 NavigationStack の `.navigationDestination` (T017 で配線) に依存

**Checkpoint**: US2 完成 → 知識 Clip タブで ConceptPage カード一覧表示。タップは US3 完成後に DetailView 遷移可能。

---

## Phase 5: User Story 3 — 概念ページ詳細画面 (Priority: P1)

**Goal**: ConceptPage 詳細画面で 4 セクション (今わかっていること / 横断的知見 / 関連記事 / つながる人物・モノ) + toolbar (ピン Toggle + 編集 ⋯) を表示。spec.md US3 + FR-022/023/024/025/026 + SC-010 を実装。

**Independent Test**: US1/US2 完成状態で知識 Clip カードタップ → ConceptPageDetailView 表示 → 4 セクション全て表示、関連記事タップで ArticleDetailView へ 1 秒以内遷移 (quickstart.md SC-010)。

### Implementation for User Story 3

- [x] T016 [P] [US3] `ConceptPageDetailView` view 新規 (`KnowledgeTree/Views/ConceptPageDetailView.swift`)
  - `@Bindable var conceptPage: ConceptPage` + `@Environment(\.modelContext) private var context` + `@State private var showEditSheet: Bool = false`
  - ScrollView + VStack(spacing: 24) で 5 セクション:
    - `headerSection`: name (`.dsHeadlineLarge`) + categoryDisplay chip + 関連記事数 + 最終更新 (`.dsCaption`)
    - `summarySection`: タイトル + `if conceptPage.isSynthesisInProgress` → 「整理中…」placeholder + ProgressView、else → `Text(summary).font(.dsBody)`
    - `crossSourceInsightsSection`: 空なら非表示、else → タイトル + ForEach bullet (`HStack { Text("•"); Text(insight) }`)
    - `relatedArticlesSection`: タイトル「関連記事 (N)」+ 0 件 placeholder or ForEach(savedAt desc) `NavigationLink(value: articleDestination) { ArticleRow(article:) }` (既存 ArticleRow 流用 or 圧縮版作成)
    - `relatedConceptsSection`: 空なら非表示、else → タイトル + relatedConceptIDs を FetchDescriptor で resolve (最大 8 件) + chip layout で `NavigationLink(value: ConceptPageDetailDestination(id: other.id)) { Text(other.name).chip() }` (再帰遷移)
  - `.toolbar { ToolbarItem(placement: .topBarTrailing) { Toggle(...pin...) } ToolbarItem(placement: .topBarTrailing) { Button { showEditSheet = true } label: { Image(systemName: "ellipsis.circle") } } }` — pin Toggle は `@Bindable` で `$conceptPage.isFollowing` を直接バインド (SwiftData autosave) **または** onChange で `conceptPageStore.setFollowing(...)` 呼び出し (Phase 6 完成後)
  - `.sheet(isPresented: $showEditSheet) { ConceptPageEditSheet(conceptPage:, store:) }` — `ConceptPageEditSheet` は T019 で実装、本 T016 では `if let store = ... { sheet(...) }` で conditional 表示で対応 (MVP では sheet 中身は Phase 6 で完成)
  - 全 LocalizedStringKey 経由、accessibility 識別子全要素に付与
  - 詳細仕様: `specs/042-concept-page/contracts/concept-page-detail-view.md`

- [x] T017 [US3] NavigationDestination 配線 (`KnowledgeTree/Views/KnowledgeClipView.swift` + `KnowledgeTree/Models/` 直下 or 同 view ファイル内に Hashable struct 定義)
  - `ConceptPageDetailDestination` Hashable struct: `let id: UUID` を定義 (`KnowledgeTree/Models/ConceptPage.swift` 末尾 or `KnowledgeTree/Views/ConceptPageDestinations.swift` 新規)
  - `ConceptPageListDestination` Hashable struct: `init() {}` のみ
  - 親 NavigationStack (`KnowledgeClipView` を含む ContentView レベル) に `.navigationDestination(for: ConceptPageDetailDestination.self) { dest in /* fetch ConceptPage by id and show ConceptPageDetailView */ }` + `.navigationDestination(for: ConceptPageListDestination.self) { _ in /* 全 ConceptPage 一覧画面 (LazyVStack)、新規 view または KnowledgeClipView 内 inline */ }`
  - 「+N すべて見る」遷移先 (`ConceptPageListView` 簡易版): `@Query` 全件 + `LazyVStack` で `ConceptPageCard` を ForEach、検索バー / フィルターは V1 では不要

**Checkpoint**: US3 完成 → MVP 完成。US1/US2/US3 が連動して自動生成 → 知識 Clip surface → DetailView 閲覧 → ArticleDetailView jump が全部通る。Phase 6 (US4 / US5) は MVP 提供後の追加機能。

---

## Phase 6: User Story 4 — 概念ページの編集 (rename / merge / delete) (Priority: P2)

**Goal**: ConceptPage の rename / merge / delete を 1 秒以内 + バリデーション (空 / 30 字超 / 重複 / 同 source-target) + 確認 alert で実装。spec.md US4 + FR-014/015/016/018 + SC-006 を実装。

**Independent Test**: ConceptPage Edit Sheet で rename → 即時 DB 反映 + UI 更新。merge → 2 ページが 1 つに統合、source 削除。delete → ConceptPage 消滅、Article 残る (quickstart.md SC-006)。

### Implementation for User Story 4

- [x] T018 [P] [US4] `ConceptPageStore` 新規 — rename/merge/delete/setFollowing + error enum (`KnowledgeTree/Services/ConceptPageStore.swift`)
  - `@MainActor final class ConceptPageStore` + `init(context: ModelContext, refreshTrigger: RefreshTrigger)`
  - `enum ConceptPageStoreError: LocalizedError { case emptyName, nameTooLong, duplicateInCategory, sameSourceTarget }` + `errorDescription` で xcstrings 経由文言返却
  - `@discardableResult func rename(_:to:) throws -> ConceptPage`: trim → 空/30 字超チェック → 同 category 重複チェック (lowercased、自身除外) → name 更新 + isStale=true + updatedAt → save + bump → return
  - `func merge(source:into:) throws`: source.id != target.id → relatedArticles union (重複除外) → relatedConceptIDs union (self-ref 除外) → nameAliases に source.name + source.aliases 吸収 → userUnderstanding max → isFollowing OR → target.isStale = true + updatedAt → context.delete(source) → save + bump
  - `func delete(_:) throws`: 全 ConceptPage fetch → 他 ConceptPage.relatedConceptIDs から conceptPage.id 除去 → context.delete(conceptPage) → save + bump (Article は @Relationship.nullify で残る)
  - `func setFollowing(_:isFollowing:) throws`: isFollowing 更新 + updatedAt → save + bump
  - T010 で forward reference してた箇所をここで satisfy
  - 詳細仕様: `specs/042-concept-page/contracts/concept-page-store.md`

- [x] T019 [P] [US4] `ConceptPageEditSheet` view 新規 (`KnowledgeTree/Views/ConceptPageEditSheet.swift`)
  - sheet UI: Form (List style) 3 セクション
    - rename: TextField + 保存ボタン (バリデーション error は `@State var errorMessage: String?` で alert 表示)
    - merge: 他 ConceptPage 選択 picker (NavigationLink for list) + 「統合先を選んで合流」ボタン + 確認 alert (「'{source.name}' を '{target.name}' に統合します」)
    - delete: 削除ボタン (赤 .destructive role) + 確認 alert (「この概念ページを削除します。関連記事は残ります」)
  - Store error catch → 日本語 alert (xcstrings 経由)
  - 全 accessibility identifier 付与 (例: `conceptPageEditSheet_renameButton`, `conceptPageEditSheet_mergeButton`, `conceptPageEditSheet_deleteButton`)
  - sheet dismiss は store 操作成功時に自動、エラー時は維持
  - T016 の sheet presentation を本タスクで完成形に置換

### Tests for User Story 4

- [x] T020 [P] [US4] `ConceptPageStoreTests` 新規 (8 ケース) (`KnowledgeTreeTests/ConceptPageStoreTests.swift`)
  - fixture: in-memory ModelContainer + SharedSchema.all + RefreshTrigger
  - ケース 1: `rename` 正常 → name 更新 + isStale=true + updatedAt > 旧、return value == conceptPage
  - ケース 2: `rename` 空文字 → throw `.emptyName`
  - ケース 3: `rename` 31 字 → throw `.nameTooLong`
  - ケース 4: `rename` 同 category 内重複 (大文字小文字無視) → throw `.duplicateInCategory`、自身は除外される
  - ケース 5: `merge` 2 ConceptPage → relatedArticles union count、source 削除、target.isStale=true、target.nameAliases に source.name 含まれる、target.isFollowing = source OR target
  - ケース 6: `merge` source == target → throw `.sameSourceTarget`
  - ケース 7: `delete` → ConceptPage 削除、他 ConceptPage.relatedConceptIDs から id 除去、Article fetch count 不変
  - ケース 8: `setFollowing` toggle → isFollowing 永続化 (`context.save()` 後 fetch で値一致)

**Checkpoint**: US4 完成 → ユーザー補正手段が揃う。AI 自動生成の誤りを手動修正可能。

---

## Phase 7: User Story 5 — 概念ページのピン (フォロー) (Priority: P2)

**Goal**: ピン (フォロー) 状態の永続化 + 知識 Clip タブで上位表示優先 (`SortDescriptor(\.isFollowing, order: .reverse)` で実装済)。spec.md US5 + FR-017 を実装。

**Independent Test**: ConceptPage 詳細画面の [ピン] Toggle → on/off で isFollowing 永続化、再起動後も維持、知識 Clip カードの上位 5 で pin 優先 (quickstart.md SC-006 末尾)。

### Implementation for User Story 5

- US5 は **追加実装タスクゼロ**:
  - T016 で toolbar pin Toggle が既に実装済
  - T015 の `@Query` SortDescriptor で isFollowing 優先が既に実装済
  - T018 の `setFollowing(_:isFollowing:)` が既に永続化を担当
  - T020 のケース 8 で test 完了済
- 動作確認のみ (quickstart.md SC-006 末尾)

**Checkpoint**: US5 完成 (実装ゼロ、依存先で完了)。

---

## Phase 8: User Story 6 — 検索で概念ページがヒット (Priority: P3)

**Goal**: 既存検索 (spec 044 SearchService) が ConceptPage の name / summary をヒット対象に含める + Article 詳細に「派生概念ページ」セクション追加。spec.md US6 + FR-027/028/029 を実装。

**Independent Test**: 検索バーで ConceptPage 名 (例: "Apple") を入力 → 検索結果に Article + ConceptPage 両方表示。Article 詳細で派生 ConceptPage が一覧表示 (quickstart.md SC-001 補完シナリオ)。

### Implementation for User Story 6

- [x] T021 [P] [US6] `SearchService` 改修 — ConceptPage hit 対応 (`KnowledgeTree/Services/SearchService.swift`)
  - 検索 query に対し `FetchDescriptor<ConceptPage>(predicate: #Predicate<ConceptPage> { page in page.name.localizedStandardContains(query) || page.summary.localizedStandardContains(query) })` で fetch
  - 既存 Article 検索結果と並列で返却 (戻り値の型は既存 spec 044 enum / struct 拡張)
  - score: name 完全一致 100 / name 部分 50 / summary 部分 10 (spec 044 SearchService と整合)
  - MatchField enum に `.conceptPageName` / `.conceptPageSummary` 追加 (将来 badge 用)
  - 既存 `SearchServiceTests` を破壊しないよう新規ケース追加は MVP 後で OK

- [x] T022 [P] [US6] `ArticleDetailView` に「この記事から派生した概念ページ」セクション追加 (`KnowledgeTree/Views/ArticleDetailView.swift`)
  - 既存 view に @Query または fetch logic で `FetchDescriptor<ConceptPage>(predicate: #Predicate { $0.relatedArticles.contains(where: { $0.id == article.id }) })` を実行
  - 結果が 1+ 件あればセクション表示 (「この記事から派生した概念ページ」タイトル + 各 ConceptPage の小型 chip / カード)
  - 各 chip タップで `NavigationLink(value: ConceptPageDetailDestination(id:))` で遷移
  - 0 件ならセクション非表示

**Checkpoint**: US6 完成 → 検索 + Article 連携で ConceptPage が完全に discoverable。

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: 全 US 完成後の品質確認、ドキュメント更新、実機検証。

- [x] T023 Build 警告ゼロ確認 (`xcodebuild clean build -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17'`)
  - 全 target で警告ゼロ
  - SwiftData migration 警告無し
  - 警告あれば修正

- [x] T024 全テスト回帰 (`xcodebuild test -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17'`)
  - 新規: `ConceptSynthesisServiceTests` 10/10 + `ConceptPageStoreTests` 8/8 + `KnowledgeExtractionServiceTests` 既存 + 2 新規
  - 既存 spec 011-041 全テスト suite PASS (spec 040 GraphExtractionServiceTests / spec 037 ConflictDetectionServiceTests / spec 018 KnowledgeDigestServiceTests 等)
  - 既知の BodyExtractorTests 2 件失敗は本 spec と無関係 (spec 021 既知 bug、HEAD revert しても再現)
  - 1 件でも regression あれば修正後再実行

- [x] T025 `CLAUDE.md` の spec 042 entry を 🔧 → ✅ 実装完了に更新 (`CLAUDE.md`)
  - SPECKIT START/END block 内 spec 042 行を更新: 「📝 specify+plan 完了」→「✅ 実装完了 (本ブランチ `042-concept-page`、未 commit、実機検証待ち)」
  - 完成テスト数を反映: 「**Unit テスト全 PASS**: ConceptSynthesisServiceTests 10/10 + ConceptPageStoreTests 8/8 + KnowledgeExtractionServiceTests 拡張 2 件 + 既存全 suite regression なし」
  - 残: 「実機検証 (quickstart.md SC-001〜SC-010、ユーザー実施)」

- [ ] T026 実機検証 (ユーザー実施、quickstart.md SC-001〜SC-010 + 既存回帰)
  - 実機 (iPhone 15 Pro 以降、Apple Intelligence on、iOS 26+) で `KnowledgeTree` を build & install
  - `specs/042-concept-page/quickstart.md` 10 シナリオを順次実施
  - 既存回帰 7 項目 (spec 001 / 021 / 018 / 012 / 040 / 037 / 044) を 1-2 分ずつ確認
  - Pass criteria を満たさない項目があれば issue 起票 + 修正タスク追加
  - 最終 commit はユーザー指示後 (本タスク完了後)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup, T001)**: 依存なし、即時開始可
- **Phase 2 (Foundational, T002-T004)**: T001 完了に依存。T002-T004 で **全 US の開始を block**
- **Phase 3-8 (US1〜US6)**: Phase 2 完了に依存。US1/US2/US3 (P1) は並列実装可だが US2 NavigationLink 遷移先は US3 完成まで動作しない
- **Phase 9 (Polish, T023-T026)**: 全 US 完成に依存

### User Story Dependencies

- **US1 (P1, T005-T013)**: Phase 2 完成のみ依存、独立 testable (UI なしの service 層完成)
- **US2 (P1, T014-T015)**: Phase 2 完成 + US1 (ConceptPage が DB に存在前提) + T016 用の `ConceptPageDetailDestination` 型定義 (T017 で配線)
- **US3 (P1, T016-T017)**: Phase 2 完成のみ依存、独立 testable (DB 上の ConceptPage を表示)
- **US4 (P2, T018-T020)**: Phase 2 完成のみ依存、独立 testable (Store のみ)。T010 ServiceContainer に store inject は T018 完了後
- **US5 (P2)**: 実装タスクなし、US3 + US4 完成で完結
- **US6 (P3, T021-T022)**: Phase 2 完成のみ依存

### Within Each User Story

- T002, T003, T004 は別ファイル → 並列可だが T003 は T002 に compile 依存
- T005, T006, T007 は同 `ConceptSynthesisService.swift` → 順次必須
- T008 は T005 後 (protocol 利用)、T010 と独立
- T011 は T009 + T010 完了に依存
- T012 は T005-T007 完了に依存 (テスト対象が必要)
- T013 は T008 完了に依存
- T014 と T016 は別 view → 並列可
- T015 は T014 + T017 完了に依存 (Card + NavigationDestination)
- T018, T019 は別ファイル → 並列可、T019 は T018 (Store API) に依存
- T020 は T018 完了に依存
- T021, T022 は別ファイル → 並列可

### Parallel Opportunities

- Phase 2 内: **T002, T004** (別ファイル) を並列で着手 → 完了後 T003
- Phase 3 内: **T012, T013** (テスト 2 ファイル) を並列で着手
- US1 (P1) と US3 (P1) は service と view が別領域 → 並列実装可 (Phase 2 完了後)
- Phase 6 内: **T018, T019, T020** (Store / Sheet / Test 3 ファイル) を並列で着手
- Phase 8 内: **T021, T022** (Service / View 別ファイル) を並列で着手

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Phase 2 を最速で抜けるため T002 と T004 を並列着手:
Task: "Create ConceptPage @Model in KnowledgeTree/Models/ConceptPage.swift"
Task: "Add ConceptSynthesisOutput @Generable + LanguageModelSessionProtocol extension in KnowledgeTree/Services/LanguageModelSessionProtocol.swift"

# 両完了後に T003 (SharedSchema 拡張、T002 compile 依存):
Task: "Add ConceptPage.self to SharedSchema.all in KnowledgeTree/SharedSchema.swift"
```

## Parallel Example: Phase 6 (US4)

```bash
# T018, T019, T020 を並列着手:
Task: "Create ConceptPageStore (rename/merge/delete/setFollowing) in KnowledgeTree/Services/ConceptPageStore.swift"
Task: "Create ConceptPageEditSheet view in KnowledgeTree/Views/ConceptPageEditSheet.swift"
Task: "Create ConceptPageStoreTests (8 cases) in KnowledgeTreeTests/ConceptPageStoreTests.swift"
```

---

## Implementation Strategy

### MVP First (Phase 1 + Phase 2 + US1 + US2 + US3)

1. Phase 1: T001 (xcstrings 文言追加)
2. Phase 2: T002 + T004 並列 → T003
3. Phase 3 (US1, P1): T005 → T006 → T007 → T008 → T009 → T010 → T011 → T012 並列 → T013 並列
4. Phase 4 (US2, P1): T014 並列 → T015 (T017 と互いに forward reference)
5. Phase 5 (US3, P1): T016 並列 → T017
6. **STOP and VALIDATE**: 知識 Clip タブで ConceptPage 自動生成 + カード表示 + DetailView 表示 + Article jump 動作確認 (SC-001/002/003/004/005/008/009/010)
7. ここまでで MVP 提供可能 (P1 全完了、~17 タスク)

### Incremental Delivery

1. MVP 提供後 → Phase 6 (US4 編集): T018 + T019 + T020 並列で追加 → 編集 UX 提供
2. Phase 7 (US5 ピン): 追加実装ゼロ、動作確認のみ
3. Phase 8 (US6 検索 + Article 連携): T021 + T022 並列 → 検索統合提供
4. Phase 9 Polish: T023 → T024 → T025 → T026 (ユーザー実機検証)

### Solo Developer Strategy (本 spec の想定)

1 人開発、Claude が実装、ユーザーが実機検証:
1. Phase 1-2 を一気に処理 (4 タスク、~30 分)
2. Phase 3 (US1) を 1 サイクル (9 タスク、~2-3 時間)、test 全 PASS 確認
3. Phase 4-5 (US2/US3) を 1 サイクル (4 タスク、~1-2 時間)、Simulator で UI 確認
4. **MVP commit candidate** (ユーザー判断で commit)
5. Phase 6 (US4) を 1 サイクル (3 タスク、~1 時間)、test PASS
6. Phase 7 動作確認
7. Phase 8 (US6) を 1 サイクル (2 タスク、~30 分)
8. Phase 9 Polish + ユーザー実機検証
9. 最終 commit (ユーザー指示後)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- 各 US は独立 testable / 独立 deployable (MVP は P1 全 3 つ完成で成立)
- テストは Mock LM + in-memory ModelContainer + SharedSchema.all で決定論的
- Commit はユーザー指示後 (実機検証 SC-001〜SC-010 完了後を想定)
- 既知の BodyExtractorTests 2 件失敗は本 spec と無関係 (spec 021 既知)
- Foundation Models context window 制約は hierarchical (chunk_size=4) で対応 (research.md R5)
- Article 側に @Relationship inverse property を追加しない (Article 既存 schema 影響ゼロ、片方向)
- 大文字小文字無視同一視は in-memory `searchableNames.contains` で実装 (SwiftData の case-insensitive 制約回避)

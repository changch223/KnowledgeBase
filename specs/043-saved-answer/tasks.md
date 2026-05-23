---

description: "Task list for spec 043 — SavedAnswer (AI Chat 答えの永続化 + ConceptPage 紐付け) / iKnow V1 Phase A 第 2 弾"
---

# Tasks: SavedAnswer (AI Chat 答えの永続化と概念ページへの紐付け)

**Input**: Design documents from `/specs/043-saved-answer/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ (7 ファイル), quickstart.md

**Tests**: 含む (Mock LM + in-memory ModelContainer による単体テストを Phase 3 / 8 内に配置)

**Organization**: タスクは User Story 別。MVP は P1 全 3 ストーリー (US1 auto-save / US2 ConceptPage section / US3 詳細閲覧)、P2 (US4-6) と P3 (US7) は順次追加。

## Format

```text
- [ ] [TaskID] [P?] [Story?] Description (file path)
```

- **[P]**: 並列実行可 (異なるファイル、相互依存なし)
- **[Story]**: US1〜US7 に対応 (Phase 1/2/Polish は Story label なし)
- ファイルパスは project-relative

## Path Convention

iOS app (Xcode multi-target):
- 実装: `KnowledgeTree/`
- テスト: `KnowledgeTreeTests/`
- Localization: `KnowledgeTree/Localization/Localizable.xcstrings`
- Project file: `KnowledgeTree.xcodeproj/project.pbxproj` (target membership 編集時のみ)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: ローカライズ文言の準備 (Constitution 「View body 内 literal 禁止」)。

- [x] T001 Localizable.xcstrings に SavedAnswer 関連 ~12 文言追加 (`KnowledgeTree/Localization/Localizable.xcstrings`)
  - `SavedAnswer.section.title` = "保存された答え"
  - `SavedAnswer.history.title` = "保存された答えの履歴"
  - `SavedAnswer.empty.title` = "まだ保存された答えはありません"
  - `SavedAnswer.empty.description` = "AI チャットで質問すると、引用が 2 件以上ある答えがここに自動保存されます"
  - `SavedAnswer.search.prompt` = "保存された答えを検索"
  - `SavedAnswer.search.empty.title` = "検索結果が見つかりません"
  - `SavedAnswer.search.empty.description` = "別のキーワードで検索してみてください"
  - `SavedAnswer.row.citedCount` = "%lld 件引用"
  - `SavedAnswer.detail.question.title` = "質問"
  - `SavedAnswer.detail.answer.title` = "答え"
  - `SavedAnswer.detail.citedArticles.title` = "引用された記事 (%lld)"
  - `SavedAnswer.detail.relatedConcepts.title` = "関連する概念ページ (%lld)"
  - `SavedAnswer.detail.delete.confirmTitle` = "この答えを削除"
  - `SavedAnswer.detail.delete.confirmMessage` = "引用された記事は残ります。"
  - `SavedAnswer.detail.auto` = "自動保存"
  - `SavedAnswer.detail.manual` = "手動保存"
  - `ConceptPage.detail.savedAnswers.title` = "この概念についての質問と答え (%lld)"
  - `ConceptPage.detail.savedAnswers.showAll` = "+%lld すべて見る"

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 全 User Story の前提となる Model + Service 基盤。**全 US の開始を block する**。

**⚠️ CRITICAL**: T002〜T004 完了まで US1 以降の実装は着手不可。

- [x] T002 [P] `SavedAnswer` @Model 新規作成 (`KnowledgeTree/Models/SavedAnswer.swift`)
  - 11 フィールド: `id` / `question` / `answer` / `citedArticles` / `relatedConceptIDs` / `chatSessionID` / `isPinned` / `isStale` / `savedAt` / `updatedAt` / `savedAutomatically`
  - `@Attribute(.unique) var id: UUID`、`@Relationship(deleteRule: .nullify) var citedArticles: [Article] = []` (片方向、Article 側 inverse なし)
  - `init` で `isPinned=false`、`isStale=false`、`savedAutomatically=true` をデフォルト
  - computed property: `questionPreview` (40 字 + 「…」)、`normalizedQuestion` (trim 済)
  - ファイル末尾に `SavedAnswerDetailDestination`、`SavedAnswerListByConceptDestination` (Hashable struct) も同 file に定義
  - 詳細仕様: `specs/043-saved-answer/contracts/saved-answer-model.md`

- [x] T003 `SharedSchema.swift` に `SavedAnswer.self` を追加 (`KnowledgeTree/SharedSchema.swift`)
  - `Schema([...])` 配列末尾、`ConceptPage.self` の後に `SavedAnswer.self` 追加
  - T002 完了に依存

- [x] T004 `SavedAnswerService` Protocol + DefaultSavedAnswerService 実装 (`KnowledgeTree/Services/SavedAnswerService.swift`)
  - protocol method: `captureIfWorthy(question:answer:citedArticleIDs:sessionID:)` / `setPinned(_:isPinned:)` / `delete(_:)` / `markStaleForArticle(_:)` 全 `async`、`@MainActor`、`AnyObject` 制約
  - `static let minAnswerChars = 50`、`static let minCitedCount = 2`、`static let maxRelatedConcepts = 5`
  - `DefaultSavedAnswerService(context:refreshTrigger:)` init
  - `captureIfWorthy` 実装: trim → cited >= 2 check → answer >= 50 check → 重複判定 (#Predicate 同 question fetch) → Article fetch → resolveTopConceptIDs (private) → SavedAnswer insert + save + RefreshTrigger bump + logger.notice
  - `markStaleForArticle` 実装: 該当 ConceptPage fetch → SavedAnswer 全 fetch → in-memory filter (relatedConceptIDs ∩ ConceptPage.id 集合 ≠ ∅) → isStale=true + updatedAt 更新 + save + logger.notice
  - `setPinned` / `delete` は throw、シンプル CRUD
  - `private func resolveTopConceptIDs(citedArticles:in:) -> [UUID]`: overlap 数 desc top 5
  - 全 catch して silent fail (captureIfWorthy / markStaleForArticle)
  - 詳細仕様: `specs/043-saved-answer/contracts/saved-answer-service.md`

**Checkpoint**: Foundation ready — US1 (P1) 以降の実装に着手可能

---

## Phase 3: User Story 1 — 答えの自動永続化 (Priority: P1) 🎯 MVP

**Goal**: AI Chat 答えに引用 2+ 件 + 50 字+ あれば SavedAnswer 自動保存。silent fire-and-forget、ユーザー通知ゼロ。spec.md US1 + FR-001/002/003/004/005 + SC-001/002 を実装。

**Independent Test**: AI チャットで 2+ 引用の答えを受け取る → DB に SavedAnswer 1 件出現 (Xcode log + Settings → 履歴で確認)。

### Implementation for User Story 1

- [x] T005 [US1] `ChatService` 改修 — ask 末尾 hook + savedAnswerService DI (`KnowledgeTree/Services/ChatService.swift`)
  - init parameter に `savedAnswerService: SavedAnswerServiceProtocol? = nil` 追加、`private weak var savedAnswerService` property 追加
  - `ask(question:in:)` 末尾、`return assistantMessage` の直前に fire-and-forget `Task { [weak self] in await self?.savedAnswerService?.captureIfWorthy(question: trimmed, answer: cleanedAnswer, citedArticleIDs: filteredCited, sessionID: session.id) }`
  - `persistAssistantUnknown` / `persistAssistantFallback` paths からは hook 呼ばない (citedArticleIDs 空なので Service 側で reject されるが無駄な call 避ける)
  - 詳細仕様: `specs/043-saved-answer/contracts/chat-service-hook.md`

- [x] T006 [US1] ServiceContainer + KnowledgeTreeApp bootstrap 配線 (`KnowledgeTree/Services/ServiceContainer.swift` + `KnowledgeTree/KnowledgeTreeApp.swift`)
  - ServiceContainer に `var savedAnswerService: SavedAnswerServiceProtocol?` property 追加
  - KnowledgeTreeApp.bootstrap() で `let savedAnswerService: SavedAnswerServiceProtocol = DefaultSavedAnswerService(context: context, refreshTrigger: refreshTrigger)` 構築
  - 既存 ChatService 構築箇所に `savedAnswerService: savedAnswerService` 引数追加
  - `serviceContainer.savedAnswerService = savedAnswerService` を ServiceContainer 登録ブロックに追加

### Tests for User Story 1

- [x] T007 [P] [US1] `SavedAnswerServiceTests` 新規 — captureIfWorthy 5-7 ケース (`KnowledgeTreeTests/SavedAnswerServiceTests.swift`)
  - fixture: in-memory `ModelContainer(for: SharedSchema.all, configurations: .init(isStoredInMemoryOnly: true))` + Article 2 件 fixture helper
  - ケース 1: 2+ 引用 + 60 字 answer → SavedAnswer 1 件生成、`savedAutomatically=true`
  - ケース 2: 1 引用 → SavedAnswer 生成しない (fetch count 0)
  - ケース 3: 49 字 answer → SavedAnswer 生成しない
  - ケース 4: 同 question (空白 trim 後完全一致) で 2 回目呼び出し → 2 件目作成しない (重複防止)
  - ケース 5: relatedConceptIDs 解決 — 引用記事と関連する ConceptPage 3 件 (異なる overlap 数) → top 5 制限内で overlap 数 desc に並ぶ
  - ケース 6: 引用 articleID が DB に存在しない UUID → SavedAnswer 生成しない (silent fail)
  - ケース 7: chatSessionID = nil でも生成可能 (履歴のみ用途)
  - 各テスト `@MainActor`、async/await、Swift Testing `#expect` macro

- [x] T008 [P] [US1] `ChatServiceTests` に MockSavedAnswerService + hook 検証 2 ケース追加 (`KnowledgeTreeTests/ChatServiceTests.swift`)
  - 新規 `MockSavedAnswerService` クラス (テスト内 private、`captureIfWorthyCallCount: Int` + その他 method no-op)
  - ケース A: `ask()` 完了後 (`Task.sleep(nanoseconds: 100_000_000)` で hook Task 完了待ち) → `mockSavedAnswer.captureIfWorthyCallCount == 1`
  - ケース B: SavedAnswerService 未注入 (nil) で `ask()` 正常完了 (後方互換)

**Checkpoint**: US1 完成 → 自動保存動作 (UI 未だ surface しないが DB 永続化確認可能)。MVP minimum increment。

---

## Phase 4: User Story 2 — ConceptPage 詳細に質問と答えセクション (Priority: P1)

**Goal**: ConceptPage 詳細画面に「この概念についての質問と答え (N)」セクション追加、関連 SavedAnswer 最大 5 件 (isPinned 優先 + savedAt desc) 表示、6+ 件で「+N すべて見る」リンク。spec.md US2 + FR-012/013/014 + SC-003 を実装。

**Independent Test**: SavedAnswer 1+ 件紐付いた ConceptPage 詳細を開く → セクション + row 表示確認。0 件で非表示。

### Implementation for User Story 2

- [x] T009 [P] [US2] `SavedAnswerRow` view 新規 (`KnowledgeTree/Views/SavedAnswerRow.swift`)
  - 1 行 layout: pin icon (条件付き) + questionPreview + 引用件数 + savedAt (SavedAtFormatter.format 流用)
  - `accessibilityElement(children: .combine)` + `accessibilityLabel` で row 全体まとめ
  - `accessibilityIdentifier("savedAnswerRow_\(id.uuidString)")`
  - DesignSystem token + DS.Spacing 使用
  - 詳細仕様: `specs/043-saved-answer/contracts/saved-answer-history-view.md` (Row セクション)

- [x] T010 [US2] `SavedAnswerSection` view 新規 (`KnowledgeTree/Views/SavedAnswerSection.swift`)
  - `let conceptPageID: UUID` + `@Query` で SavedAnswer 全件 (savedAt desc) fetch
  - `relatedAnswers` computed: in-memory filter (`relatedConceptIDs.contains(conceptPageID)`) + sort (isPinned 優先 + savedAt desc)
  - 0 件で EmptyView 短絡 (Constitution V calm UX)
  - 1+ 件で セクションタイトル「この概念についての質問と答え (N)」 + ForEach `prefix(5)` の NavigationLink(value: SavedAnswerDetailDestination(id:)) → SavedAnswerRow
  - 6+ 件で「+N すべて見る」NavigationLink(value: SavedAnswerListByConceptDestination(conceptPageID:))
  - 詳細仕様: `specs/043-saved-answer/contracts/saved-answer-section.md`

- [x] T011 [US2] `ConceptPageDetailView` の aliveBody に SavedAnswerSection 配置 (`KnowledgeTree/Views/ConceptPageDetailView.swift`)
  - 既存 5 セクション順序: `headerSection → summarySection → crossSourceInsightsSection → relatedArticlesSection → relatedConceptsSection`
  - 新順序: `... → relatedArticlesSection → SavedAnswerSection(conceptPageID: conceptPage.id) → relatedConceptsSection`
  - 「ソース → 蓄積 → 関連」の論理順

**Checkpoint**: US2 完成 → 概念ページに質問と答えが surface (DetailView 未だなのでタップしても何も起きない、Phase 5 で完成)。

---

## Phase 5: User Story 3 — 保存された答えの詳細閲覧 (Priority: P1)

**Goal**: SavedAnswer 詳細画面で 5 セクション (header / question / answer / cited articles / related concepts) + toolbar (pin + delete) + Live check pattern (削除直後の crash 回避)。spec.md US3 + FR-015/016/017 + SC-004 を実装。

**Independent Test**: SavedAnswer Row タップ → 詳細画面 → 引用記事タップで ArticleDetailView 1 秒以内遷移、関連概念ページ chip タップで ConceptPageDetailView 遷移。削除でクラッシュなし、自動 navigation pop。

### Implementation for User Story 3

- [x] T012 [P] [US3] Hashable destination struct (T002 内で同 file に定義済)
  - 確認のみ: `SavedAnswerDetailDestination(id: UUID)` と `SavedAnswerListByConceptDestination(conceptPageID: UUID)` が `Models/SavedAnswer.swift` 末尾に定義されているか確認
  - T002 で実装漏れがあればここで追加

- [x] T013 [US3] `SavedAnswerDetailView` view 新規 (`KnowledgeTree/Views/SavedAnswerDetailView.swift`)
  - `@Bindable var answer: SavedAnswer` + `@Environment(\.dismiss)` + `@Environment(ServiceContainer.self) services` + `@State showDeleteConfirm`
  - `@Query private var liveMatches: [SavedAnswer]` + `init(answer:)` で `_liveMatches = Query(filter: #Predicate { $0.id == id })`、`private var isAlive: Bool { !liveMatches.isEmpty }`
  - body: `if !isAlive { Color.clear.onAppear { dismiss() } } else { aliveBody }` (spec 042 ConceptPageDetailView と同 Live check pattern)
  - aliveBody: ScrollView VStack (header / question / answer / citedArticles / relatedConcepts) + toolbar (pin Toggle + delete Button) + alert (削除確認)
  - header: savedAt (SavedAtFormatter) + 自動/手動 ラベル + pin badge
  - citedArticlesSection: ForEach (citedArticles.sorted savedAt desc) → NavigationLink(value: article) (既存 ArticleDetailView route)
  - relatedConceptsSection: relatedConceptIDs を fetch (in-memory) → FlowingTagsLayout chip → NavigationLink(value: ConceptPageDetailDestination(id:))
  - pin Toggle binding → `services.savedAnswerService?.setPinned(answer, isPinned: newValue)` (try?)
  - delete Button → showDeleteConfirm=true → alert → `services.savedAnswerService?.delete(answer)` (try?)、dismiss は live check が自動でやる
  - 詳細仕様: `specs/043-saved-answer/contracts/saved-answer-detail-view.md`

- [x] T014 [US3] `SavedAnswerDetailLoader` (補助 view) + KnowledgeClipView の navigationDestination 配線 (`KnowledgeTree/Views/KnowledgeClipView.swift` 末尾 + 既存 navigationDestination 拡張)
  - `SavedAnswerDetailLoader` struct: `let destinationID: UUID` + `@Environment(\.dismiss)` + `@Query private var matchingAnswers` (id filter)、init で query setup
  - body: `if let answer = matchingAnswers.first { SavedAnswerDetailView(answer:) } else { Color.clear.onAppear { dismiss() } }`
  - KnowledgeClipView 内 `.navigationDestination(for: ConceptPageDetailDestination.self) { ... }` の隣に追加: `.navigationDestination(for: SavedAnswerDetailDestination.self) { dest in SavedAnswerDetailLoader(destinationID: dest.id) }`
  - 同様に `SavedAnswerListByConceptDestination` 用 placeholder navigationDestination 追加 (本 spec では SavedAnswerHistoryView を流用、conceptPageID は無視 — 完全 filter 版は将来 polish)
  - ConceptPageDetailView を表示するナビゲーションスタック (KnowledgeClipView) が SavedAnswerDetail にも遷移できるよう必須

**Checkpoint**: US3 完成 → MVP 完成。US1/US2/US3 連動: 自動保存 → 概念ページ surface → 詳細閲覧 → Article jump 全部動作。

---

## Phase 6: User Story 4 — 保存された答えの全履歴閲覧 (Priority: P2)

**Goal**: 全 SavedAnswer の履歴画面 (Settings → 「保存された答えの履歴」)、savedAt desc + isPinned 優先で list 表示、100+ 件で 60fps scroll。spec.md US4 + FR-018 + SC-005 を実装。

**Independent Test**: Settings → 履歴 → SavedAnswer 一覧表示、空時は ContentUnavailableView、scroll 滑らか。

### Implementation for User Story 4

- [x] T015 [US4] `SavedAnswerHistoryView` 新規 + SettingsView に NavigationLink (`KnowledgeTree/Views/SavedAnswerHistoryView.swift` + `KnowledgeTree/Views/SettingsView.swift`)
  - SavedAnswerHistoryView: `@Query(sort: [SortDescriptor(\.savedAt, order: .reverse)])` + `@State searchText`、`displayedAnswers` computed (isPinned 優先 + searchText 空なら全件、検索時は SearchService.searchSavedAnswers 経由 — T020 で実装、本 task では search OFF or 検索結果なし扱い)
  - body: `if displayedAnswers.isEmpty { ContentUnavailableView(...) } else { ScrollView LazyVStack ForEach NavigationLink(value: SavedAnswerDetailDestination(id:)) { SavedAnswerRow + Divider } }`
  - `.navigationDestination(for: SavedAnswerDetailDestination.self) { dest in SavedAnswerDetailLoader(destinationID:) }` 追加 (内部 navigation)
  - `.searchable(text: $searchText, prompt: "SavedAnswer.search.prompt")` (T020 SearchService 完成後に hook 化)
  - `.navigationTitle("SavedAnswer.history.title")` + `.navigationBarTitleDisplayMode(.inline)`
  - SettingsView: 適当な Section に `NavigationLink { SavedAnswerHistoryView() } label: { Label("SavedAnswer.history.title", systemImage: "quote.bubble") }` 追加
  - 詳細仕様: `specs/043-saved-answer/contracts/saved-answer-history-view.md`

**Checkpoint**: US4 完成 → 履歴画面アクセス可能 (検索は T020 完成後に hot)。

---

## Phase 7: User Story 5 — ピン / 削除 (Priority: P2)

**Goal**: SavedAnswer のピン (上位表示) と削除 (引用記事は残る)。spec.md US5 + FR-009/010/011 + SC-006 を実装。

**Independent Test**: SavedAnswer 詳細で pin Toggle → 履歴画面に戻ると上位表示。同じ画面で削除 → 履歴から消える、引用記事 Article 一覧に残る。

### Implementation for User Story 5

- US5 は **追加実装タスクゼロ**:
  - T013 で toolbar pin Toggle + delete confirm alert が既に実装済
  - T004 で SavedAnswerService.setPinned / delete が既に実装済
  - 動作確認のみ (quickstart.md SC-006)
- T019 (Phase 8 内) で setPinned + delete のテストケースも追加される

**Checkpoint**: US5 完成 (実装ゼロ、依存先で完了)。

---

## Phase 8: User Story 6 — 新記事 ingest による答えの古さマーク + ConceptPage merge 連動 (Priority: P2)

**Goal**: 新記事 ingest で関連 ConceptPage が更新される時、SavedAnswer.isStale=true を連鎖 (WikiLint 仕込み、UI 影響なし)。ConceptPage merge で SavedAnswer.relatedConceptIDs の source→target 置換 (data integrity)。spec.md US6 + FR-007/008 + SC-007 を実装。

**Independent Test**: 引用記事を含む新記事を保存 → 5 分以内に該当 SavedAnswer.isStale=true (DB 確認)。ConceptPage merge で関連 SavedAnswer の relatedConceptIDs が target.id に置換 (DB 確認)。

### Implementation for User Story 6

- [x] T016 [US6] `KnowledgeExtractionService` 改修 — extract 末尾 markSavedAnswersStaleIfPossible hook + DI (`KnowledgeTree/Services/KnowledgeExtractionService.swift`)
  - init parameter に `savedAnswerService: SavedAnswerServiceProtocol? = nil` 追加、`private weak var savedAnswerService` property
  - `private func markSavedAnswersStaleIfPossible(article:)` 追加: fire-and-forget Task で `await savedAnswerService.markStaleForArticle(article)`
  - 既存 7 hook 群 (applyAutoTagsIfPossible / markDigestStale / generateEmbedding / detectConflicts / extractGraph / synthesizeConcept) の隣に追加 (single + chunked 両経路)
  - 詳細仕様: `specs/043-saved-answer/contracts/knowledge-extraction-stale-hook.md`

- [x] T017 [US6] KnowledgeTreeApp bootstrap で savedAnswerService を KnowledgeExtractionService に inject (`KnowledgeTree/KnowledgeTreeApp.swift`)
  - 既存 `DefaultKnowledgeExtractionService(...)` 構築箇所に `savedAnswerService: savedAnswerService` 引数追加 (T006 で構築した savedAnswerService 流用)

- [x] T018 [US6] `ConceptPageStore.merge` に SavedAnswer.relatedConceptIDs の source→target 置換ロジック追加 (`KnowledgeTree/Services/ConceptPageStore.swift`)
  - 既存 `merge(source:into:) throws` メソッド末尾、`try context.save()` の前に追加:
    ```swift
    let allAnswers: [SavedAnswer] = (try? context.fetch(FetchDescriptor<SavedAnswer>())) ?? []
    for answer in allAnswers where answer.relatedConceptIDs.contains(source.id) {
        var ids = answer.relatedConceptIDs.filter { $0 != source.id }
        if !ids.contains(target.id) { ids.append(target.id) }
        answer.relatedConceptIDs = Array(ids.prefix(DefaultSavedAnswerService.maxRelatedConcepts))
        answer.updatedAt = .now
    }
    ```
  - `DefaultSavedAnswerService.maxRelatedConcepts` 定数を参照 (疎結合、Service 全体は import しない)

### Tests for User Story 6

- [x] T019 [P] [US6] markStaleForArticle + ConceptPageStore.merge 連動 テスト追加 (`KnowledgeTreeTests/SavedAnswerServiceTests.swift` + `KnowledgeTreeTests/ConceptPageStoreTests.swift`)
  - SavedAnswerServiceTests に 3 ケース追加:
    - markStaleForArticle: 引用記事 → 関連 ConceptPage 1 件 → SavedAnswer 1 件の isStale=true 連鎖確認
    - setPinned: false → true → false で永続化 (toggle)
    - delete: SavedAnswer 削除、Article 残存、ChatSession 影響なし
  - ConceptPageStoreTests に 1 ケース追加:
    - merge: source ConceptPage に紐付く SavedAnswer の relatedConceptIDs が target.id に置換、top 5 制限維持、重複なし

**Checkpoint**: US6 完成 → WikiLint 用 isStale 仕込み完了 + merge 時の data integrity 担保。

---

## Phase 9: User Story 7 — 検索 (Priority: P3)

**Goal**: SavedAnswer 履歴画面で question / answer / 引用記事 title の substring 検索。spec.md US7 + FR-019 + SC-008 を実装。

**Independent Test**: 履歴画面で query 入力 → 該当 SavedAnswer のみ表示、空 query で全件。

### Implementation for User Story 7

- [x] T020 [P] [US7] `SearchService` に searchSavedAnswers 純関数 + ScoredSavedAnswer struct 追加 (`KnowledgeTree/Services/SearchService.swift`)
  - `struct ScoredSavedAnswer: Identifiable { var id: UUID { savedAnswer.id }; let savedAnswer: SavedAnswer; let score: Int }`
  - `static func searchSavedAnswers(query: String, in answers: [SavedAnswer]) -> [ScoredSavedAnswer]`
    - 空 query で空配列
    - score: question localizedStandardContains → 50、answer → 20、citedArticles.title → 10
    - score > 0 のみ返却、score desc + savedAt desc tiebreak
  - SavedAnswerHistoryView (T015 で実装済) で `.searchable` が SearchService.searchSavedAnswers 経由呼び出すよう hook (`displayedAnswers` computed の実装を完成)

**Checkpoint**: US7 完成 → 検索 fully 動作。

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: 全 US 完成後の品質確認 + ドキュメント更新 + 実機検証。

- [x] T021 Build 警告ゼロ確認 (`xcodebuild clean build -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17'`)
  - 全 target で警告ゼロ
  - 既存 warnings は spec 021 / 042 由来で本 spec 無関係 (許容)
  - SavedAnswer / SavedAnswerService / 各 View で warning ゼロ

- [x] T022 全テスト回帰 (`xcodebuild test -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17'`)
  - 新規: `SavedAnswerServiceTests` (10 ケース、Phase 3 + 8 で完成)
  - 改修: `ChatServiceTests` 拡張 2 件、`ConceptPageStoreTests` 拡張 1 件
  - 既存全 suite (spec 011-042) regression なし
  - pre-existing flaky UI test 8 件 (AIBrainTabUITests 6 / KnowledgeTreeUITestsLaunchTests 1 / SaveArticleUITests 1) は本 spec 無関係

- [x] T023 `CLAUDE.md` の spec 043 entry を 🔧 → ✅ 実装完了 + 検証 PASS に更新 (`CLAUDE.md`)
  - SPECKIT START/END block 内 spec 043 行を更新
  - 完成テスト数を反映: 「**Unit テスト全 PASS**: SavedAnswerServiceTests 10/10 + ChatServiceTests 拡張 + ConceptPageStoreTests 拡張」
  - 残: 「実機検証 (quickstart.md SC-001〜SC-008、ユーザー実施)」

- [x] T024 実機検証 (ユーザー実施、quickstart.md SC-001〜SC-008 + 既存回帰)
  - 実機 (iPhone、Apple Intelligence on、iOS 26+) で `KnowledgeTree` を build & install
  - `specs/043-saved-answer/quickstart.md` 8 シナリオを順次実施
  - 既存回帰 5 項目 (spec 021 / 042 / 001 / 018 / 044) を確認
  - Pass criteria を満たさない項目があれば issue 起票 + 修正タスク追加
  - 最終 commit はユーザー指示後 (本タスク完了後)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup, T001)**: 依存なし、即時開始可
- **Phase 2 (Foundational, T002-T004)**: T001 完了に依存。T002-T004 で **全 US の開始を block**
- **Phase 3-9 (US1〜US7)**: Phase 2 完了に依存
  - US1 (T005-T008) は MVP の基盤、最初に完成すべき
  - US2 / US3 (T009-T014) は MVP の UI、順次完成
  - US4 (T015) / US5 (実装ゼロ) / US6 (T016-T019) は P2、MVP 後に追加
  - US7 (T020) は P3、optional
- **Phase 10 (Polish, T021-T024)**: 全 US 完成に依存

### User Story Dependencies

- **US1 (P1, T005-T008)**: Phase 2 完成のみ依存、独立 testable (Service 層完成、UI なし)
- **US2 (P1, T009-T011)**: Phase 2 完成 + T012 (destination struct) 依存、独立 testable (ConceptPage 詳細に表示)
- **US3 (P1, T012-T014)**: Phase 2 完成のみ依存、独立 testable (DetailView 単独で表示確認可)
- **US4 (P2, T015)**: Phase 2 + US3 (T013 + T014) 完成 (SavedAnswerDetailDestination 利用)
- **US5 (P2)**: 実装タスクなし、US3 + US4 完成で完結
- **US6 (P2, T016-T019)**: Phase 2 完成のみ依存、独立 testable
- **US7 (P3, T020)**: Phase 2 完成 + US4 (T015) 完成で SearchService hook 化

### Within Each User Story

- T002, T009, T012, T020 は別ファイル → 並列可
- T003 は T002 に compile 依存
- T004 は T002 後 (SavedAnswer 型必要)
- T005-T006 は T004 後 (Service Protocol 必要)
- T007 は T004 後 (Service 単独テスト)
- T008 は T005 + T007 後 (Mock Service 必要)
- T010 は T009 (Row) + T012 (Destination) 後
- T011 は T010 後
- T013 は T002 + T012 + T004 後
- T014 は T013 後
- T015 は T013 + T014 後 (Loader 利用)
- T016 は T004 後
- T017 は T016 後
- T018 は T002 + T004 後 (maxRelatedConcepts 定数参照)
- T019 は T016 + T018 後
- T020 は T002 + T015 後 (UI hook 化)
- T021-T024 は全実装完了後

### Parallel Opportunities

- Phase 2 内: T002, T004 (別ファイル) を並列着手 → 完了後 T003
- Phase 3 内: T007, T008 (テスト 2 ファイル) を並列着手
- Phase 4 内: T009, T012 (別ファイル) を並列着手 → 完了後 T010 → T011
- US2 と US3 と US6 は別領域 → 並列実装可 (Phase 2 完了後)
- Phase 8 内: T016, T018 (別ファイル) を並列、T019 と並列も可
- Phase 9: T020 単独
- Phase 10: T021 → T022 (順次) → T023, T024 並列可

---

## Parallel Example: Phase 2 (Foundational)

```bash
# T002 + T004 を並列着手 (T003 は T002 後):
Task: "Create SavedAnswer @Model in KnowledgeTree/Models/SavedAnswer.swift"
Task: "Create SavedAnswerService Protocol + DefaultSavedAnswerService in KnowledgeTree/Services/SavedAnswerService.swift"

# 完了後 T003:
Task: "Add SavedAnswer.self to SharedSchema.all in KnowledgeTree/SharedSchema.swift"
```

## Parallel Example: Phase 3 (US1) Tests

```bash
# T007 + T008 を並列着手:
Task: "Create SavedAnswerServiceTests with 7 ケース in KnowledgeTreeTests/SavedAnswerServiceTests.swift"
Task: "Extend ChatServiceTests with MockSavedAnswerService + 2 hook 検証 ケース in KnowledgeTreeTests/ChatServiceTests.swift"
```

## Parallel Example: Phase 4 + 5 (US2 + US3)

```bash
# US2 (T009 + T012 並列) と US3 (T013 並列) を同時着手:
Task: "Create SavedAnswerRow view in KnowledgeTree/Views/SavedAnswerRow.swift"
Task: "Create SavedAnswerDetailDestination Hashable struct in KnowledgeTree/Models/SavedAnswer.swift (末尾)"
Task: "Create SavedAnswerDetailView with Live check pattern in KnowledgeTree/Views/SavedAnswerDetailView.swift"
```

---

## Implementation Strategy

### MVP First (Phase 1 + Phase 2 + US1 + US2 + US3 = T001-T014)

1. Phase 1: T001 (xcstrings)
2. Phase 2: T002 + T004 並列 → T003
3. Phase 3 (US1, P1): T005 → T006 → T007 + T008 並列
4. Phase 4 (US2, P1): T009 + T012 並列 → T010 → T011
5. Phase 5 (US3, P1): T013 → T014
6. **STOP and VALIDATE**: AI Chat → auto-save → ConceptPage 詳細に表示 → 詳細画面 → Article jump 全動作確認 (SC-001/003/004)
7. ここまでで MVP 提供可能 (P1 全完了、~14 タスク)

### Incremental Delivery

1. MVP 提供後 → Phase 6 (US4 履歴): T015 追加 → 履歴画面提供
2. Phase 7 (US5 ピン): 追加実装ゼロ、動作確認のみ
3. Phase 8 (US6 isStale + merge): T016 + T018 並列 → T017 → T019 (テスト) — WikiLint 仕込み完了
4. Phase 9 (US7 検索): T020 単独 — 検索完成
5. Phase 10 Polish: T021 → T022 → T023 → T024 (ユーザー実機検証)

### Solo Developer Strategy (本 spec の想定)

1 人開発、Claude が実装、ユーザーが実機検証:
1. Phase 1-2 を一気に処理 (4 タスク、~30 分)
2. Phase 3 (US1) を 1 サイクル (4 タスク、~1-2 時間)、test 全 PASS 確認
3. Phase 4-5 (US2/US3) を 1 サイクル (6 タスク、~1-2 時間)、Simulator で UI 確認
4. **MVP commit candidate** (ユーザー判断で commit)
5. Phase 6 (US4) → Phase 7 動作確認 → Phase 8 (US6) → Phase 9 (US7) 順次 (~2-3 時間)
6. Phase 10 Polish + ユーザー実機検証
7. 最終 commit (ユーザー指示後)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- 各 US は独立 testable / 独立 deployable (MVP は P1 全 3 つ完成で成立)
- テストは in-memory ModelContainer + SharedSchema.all で決定論的、AI 不要 (純粋ロジック層)
- Commit はユーザー指示後 (実機検証 SC-001〜SC-008 完了後を想定)
- 既知の pre-existing flaky UI test 8 件は本 spec と無関係
- SavedAnswer.swift は ShareExtension + SafariExtension target にも追加 (spec 042 同パターン、pbxproj 編集)
- Info.plist 編集なし (BGTask 追加なし、純粋ロジック層)

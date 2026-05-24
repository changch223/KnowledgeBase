# Tasks: UIUX Redesign V3.0 — 3-Tab Simplification

**Input**: Design documents from `/specs/056-uiux-redesign-v3/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ (11 files), quickstart.md

**Tests**: 3 新規 service の unit test 必須 (Mock + 純粋関数)。UI test は 3 ケース新規 (核心 user journey)。既存全 regression PASS 必須。

**Organization**: 13 Phase に分割、各 user story (US1-US15) 独立実装可能。Phase A (P1) = MVP。

## Format

`- [ ] [TaskID] [P?] [Story?] Description with file path`

- `[P]`: 並列実行可能 (別ファイル、依存なし)
- `[Story]`: 対応 user story (US1-US15、Setup/Foundational/Polish には付かない)

## Path Conventions

- iOS app: `KnowledgeTree/Views/`, `KnowledgeTree/Services/`, `KnowledgeTree/Models/`
- Tests: `KnowledgeTreeTests/`, `KnowledgeTreeUITests/`
- Localizable: `KnowledgeTree/Localization/Localizable.xcstrings`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 全 Phase の前提となる localization 文言追加

- [ ] T001 Localizable.xcstrings に ~40 文言追加 (`KnowledgeTree/Localization/Localizable.xcstrings`) — knowledgeClip.* / library.* / addArticle.* / chat.suggested.* / actionItems.* / avatar.* / fab.* / knowledgeGraph.* / common.*

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 全 user story の前提となる transient struct + 3 service + ServiceContainer/KnowledgeTreeApp refactor

**⚠️ CRITICAL**: 全 P1 user story はこの Phase 完了後に開始

- [ ] T002 [P] MixedSurfaceCard enum (Identifiable, priorityScore 共通スケール 0-100) を `KnowledgeTree/Models/MixedSurfaceCard.swift` に新規 — case .understanding(UnderstandingCard) / case .digest(KnowledgeDigest)、displayTitle / displaySubtitle / labelText 含む
- [ ] T003 [P] LibraryDateGroup enum + LibraryDateGrouper 純粋関数 を `KnowledgeTree/Services/LibraryDateGrouper.swift` に新規 (~80 行) — 5 case (today/yesterday/thisWeek/thisMonth/earlier) + `group(_:now:calendar:)` + `classify(_:now:calendar:)` 純粋関数、Date 注入で deterministic test 可能
- [ ] T004 [P] RecentArticlesServiceProtocol + DefaultRecentArticlesService を `KnowledgeTree/Services/RecentArticlesService.swift` に新規 (~120 行) — `fetchRecentArticles(since:limit:in:)` + `cachedRecentArticleIDs` get/set (UserDefaults `spec056_recent_articles_cache` JSON encode、max 3 件) + `clearCache()`、@MainActor
- [ ] T005 [P] SuggestedPromptGeneratorProtocol + DefaultSuggestedPromptGenerator を `KnowledgeTree/Services/SuggestedPromptGenerator.swift` に新規 (~120 行) — `SuggestedPrompt` struct (Identifiable, Codable, Equatable) + `SourceType` enum + `generateSuggestedPrompts(in:)` (最新 ConceptPage 1 + 最新 Category 1 + 固定 1 + fallback) + UserDefaults `spec056_suggested_prompts_cache` (1 日 1 回更新、date key)、@MainActor
- [ ] T006 ServiceContainer に 3 新 service inject を追加 (`KnowledgeTree/Services/ServiceContainer.swift`) — `recentArticlesService: RecentArticlesServiceProtocol` + `suggestedPromptGenerator: SuggestedPromptGeneratorProtocol`、bootstrap で DefaultRecentArticlesService + DefaultSuggestedPromptGenerator 生成 + inject (LibraryDateGrouper は static、inject 不要)
- [ ] T007 KnowledgeTreeApp の AppTab を 5 → 3 case 削減 + 起動 default 知識 Clip 強制 + V3 migration flag (`KnowledgeTree/KnowledgeTreeApp.swift`、~30 行) — enum AppTab: 旧 `.understanding` / `.aiBrain` / `.settings` 削除、`.knowledgeClip` / `.library` / `.chat` のみ。`@State selectedTab: AppTab = .knowledgeClip` 強制、`LastOpenedStore.lastTab` 無視。UserDefaults `spec056_v3_migrated` flag 初回起動で true 永続化

**Checkpoint**: Foundation 完了、Phase 3 以降の user story 実装可能

---

## Phase 3: User Story 1 — 3 タブ構成で起動 default = 知識 Clip (Priority: P1) 🎯 MVP 開始

**Goal**: 4 タブ → 3 タブに削減、起動 default = 知識 Clip、旧 root tab (学習/AI ブレイン/Settings) を完全削除

**Independent Test**: アプリ起動 → 下部に 3 タブのみ → selected = 知識 Clip

### Implementation for User Story 1

- [ ] T008 [US1] 旧 UnderstandingTabView root view 削除 (`KnowledgeTree/Views/UnderstandingTabView.swift` ファイル削除) — 機能は InterestingNextSection に統合済前提 (Phase 5 で実装、本タスクでは file 削除のみ、build 時に未使用となる)
- [ ] T009 [US1] 旧 AIBrainView root view 削除 (`KnowledgeTree/Views/AIBrainView.swift` ファイル削除) — Knowledge Map 部分は KnowledgeGraphFullScreenView (Phase 12) に移行予定、統計部分は SettingsView (Phase 13) に格下げ予定、本タスクでは file 削除のみ
- [ ] T010 [US1] KnowledgeTreeApp から Settings root tab item 削除 (`KnowledgeTree/KnowledgeTreeApp.swift` を編集) — SettingsView.swift 自体は維持 (AvatarMenu 経由で sheet 表示するため)、TabView item から `.settings` case 削除のみ
- [ ] T011 [US1] V3RedesignUITests 新規 (`KnowledgeTreeUITests/V3RedesignUITests.swift`、1 ケース) — `testThreeTabsVisible()` で XCUIApplication 起動 → tabBar.buttons.count == 3 + 1 つ目 selected = 知識 Clip

**Checkpoint**: 3 タブ構成完成、旧 root view 物理削除、起動 default 知識 Clip 動作

---

## Phase 4: User Story 2 — 知識 Clip 「最近の記事」差分キャッチアップ (Priority: P1)

**Goal**: 知識 Clip タブ最上部に LastOpenedStore 以降の新規 3 記事を横スクロール表示、差分ゼロなら前回維持

**Independent Test**: 記事 5 件保存 → kill → 再起動 → 3 件表示 + 差分ゼロで再起動 → 同じ 3 件維持

### Implementation for User Story 2

- [ ] T012 [P] [US2] AvatarMenu component 新規 (`KnowledgeTree/Views/AvatarMenu.swift`、~50 行) — Button + `Image(systemName: "person.crop.circle")` + `.sheet { NavigationStack { SettingsView() } }`、accessibilityIdentifier `toolbar.avatar`
- [ ] T013 [P] [US2] RecentArticlesSection 新規 (`KnowledgeTree/Views/RecentArticlesSection.swift`、~120 行) — `@Environment(ServiceContainer.self)` + `@State var articles: [Article]` + `.task { articles = await services.recentArticlesService.fetchRecentArticles(since: lastOpenedAt, limit: 3, in: context) }` + ScrollView horizontal で 3 カード表示、各カード = thumbnail + essence prefix 50 字 + title + サイト名、4+ 件で「+N もっと見る」 NavigationLink (Layer 2)
- [ ] T014 [US2] KnowledgeClipView 全面再構成 Phase 1 (`KnowledgeTree/Views/KnowledgeClipView.swift`、~150 行 first commit) — 旧 8 セクション削除 (一時的に empty)、NavigationStack(path:) + ScrollView + LazyVStack + RecentArticlesSection 配置 + toolbar に AvatarMenu (`.topBarTrailing`)、accessibilityIdentifier `tab.knowledgeClip`
- [ ] T015 [P] [US2] RecentArticlesServiceTests 新規 (`KnowledgeTreeTests/RecentArticlesServiceTests.swift`、8 ケース、~200 行) — in-memory ModelContainer + Mock UserDefaults (suite name): 1. 空状態 / 2. 差分 5 件 → 上位 3 件 + cache 更新 / 3. 差分ゼロ + cache 3 件 → cache 復元 / 4. cache 永続化 round-trip / 5. max 3 件制限 / 6. since=.now → 全空 / 7. 削除済 ID skip / 8. new install state

**Checkpoint**: 「最近の記事」セクション完成、差分ゼロ時の cache 維持動作、AvatarMenu 経由 Settings 遷移

---

## Phase 5: User Story 3 — 「続きが気になるもの」混在表示 (Priority: P1)

**Goal**: ConceptPage 深掘りカード + Topic Dashboard カードを 1 セクション内で混在表示

**Independent Test**: ConceptPage 3 件 + KnowledgeDigest 2 件存在 → 知識 Clip → 5 件混在 → カードタップで対応詳細遷移

### Implementation for User Story 3

- [ ] T016 [US3] InterestingNextSection 新規 (`KnowledgeTree/Views/InterestingNextSection.swift`、~150 行) — `@Environment(ServiceContainer.self)` + `@Query var digests: [KnowledgeDigest]` (createdAt desc) + `.task` で UnderstandingCardSurfaceService.surfaceTopCards 呼出 → 両方を MixedSurfaceCard でラップ + priorityScore でソート + 上位 5 件 + 「もっと見る ›」NavigationLink、ConceptPage card は `NavigationLink(value: UnderstandingCard)` (DeepDiveChatView 遷移)、Digest card は `NavigationLink(value: KnowledgeDigest)` (CategoryKnowledgeDetailView 遷移)
- [ ] T017 [US3] KnowledgeClipView Phase 2 (`KnowledgeTree/Views/KnowledgeClipView.swift` を編集) — LazyVStack 内 RecentArticlesSection の下に InterestingNextSection 追加 + navigationDestination(for: UnderstandingCard.self) → DeepDiveChatView + navigationDestination(for: KnowledgeDigest.self) → CategoryKnowledgeDetailView 配線

**Checkpoint**: 「続きが気になる」セクション完成、混在表示動作、deep dive + topic 両遷移動作

---

## Phase 6: User Story 4 — 「追っている人物・モノ」 + ⚠️ Action Items badge (Priority: P1)

**Goal**: isFollowing ConceptPage 上位 5 件 + ⚠️ 更新が必要 badge (件数 0 で非表示)

**Independent Test**: ConceptPage 3 件 isFollowing + 1 件 isStale → 知識 Clip → 3 件 + ⚠️ 更新が必要 (1) badge 表示、badge tap → ActionItemsReviewView 遷移

### Implementation for User Story 4

- [ ] T018 [US4] FollowingPeopleSection 新規 (`KnowledgeTree/Views/FollowingPeopleSection.swift`、~120 行) — `@Query(filter: ConceptPage.isFollowing == true, sort: updatedAt desc, fetchLimit: 5)` + `@Query(filter: ConflictProposal undecided)` + `@Query(filter: SavedAnswer.isStale == true)` で 3 fetch、ActionItemBadgeData computed、subheader 位置に `if badgeData.shouldShow { NavigationLink(value: ActionItemsReviewDestination()) { Label(⚠️ 更新が必要 (\(N)), systemImage: "exclamationmark.triangle") } }` 条件表示、ConceptPage card に userUnderstanding 5-dot indicator + 関連記事数
- [ ] T019 [US4] ActionItemsReviewView 新規 (`KnowledgeTree/Views/ActionItemsReviewView.swift`、~100 行) — `@Query` で ConflictProposal + isStale SavedAnswer fetch → List + 2 Section (事実の更新提案 / 確認が必要な答え) + 既存 ConflictProposalRow + SavedAnswerRow 流用、両方 0 件で ContentUnavailableView、navigationTitle "更新が必要"、Hashable struct `ActionItemsReviewDestination` も同ファイルに定義
- [ ] T020 [US4] KnowledgeClipView Phase 3 完成 (`KnowledgeTree/Views/KnowledgeClipView.swift` を編集) — LazyVStack 内 InterestingNextSection の下に FollowingPeopleSection 追加 + navigationDestination(for: ActionItemsReviewDestination.self) → ActionItemsReviewView 配線
- [ ] T021 [US4] 旧 KnowledgeClipView 内 section view 群削除 (`KnowledgeTree/Views/KnowledgeClipView.swift` 内の private struct / extension / `KnowledgeTree/Views/FactConflictsSection.swift` / `KnowledgeTree/Views/StaleSavedAnswersSection.swift` / `KnowledgeTree/Views/DynamicTopicsSection.swift` ファイル削除) — 統合先 (FollowingPeopleSection ⚠️ badge / InterestingNextSection / ActionItemsReviewView) に吸収済確認、import 残骸も cleanup

**Checkpoint**: 知識 Clip 3 セクション全完成、⚠️ badge + ActionItemsReviewView 動作、旧 section 物理削除

---

## Phase 7: User Story 5 — 知識 Clip 右上アバター → Settings (Priority: P1)

**Goal**: アバター icon tap で SettingsView を sheet 表示、既存 Settings 全エントリ保持

**Independent Test**: 知識 Clip タブ右上アバター tap → Settings 表示 → 既存エントリ動作

### Implementation for User Story 5

- [ ] T022 [US5] T012 + T014 で実装済確認 — AvatarMenu 配置 + KnowledgeClipView toolbar 配線が動作、SettingsView 内 entry (Tag 管理 / iCloud sync / Chrome / Safari / AI チャット履歴削除) が新動線経由で全動作することを smoke test (1 entry 開いて閉じる、build error なし確認)

**Checkpoint**: Settings 動線完成

---

## Phase 8: User Story 7 — 既存機能の動線継続性検証 (Priority: P1)

**Goal**: 旧 root tab 削除後も spec 044 家庭教師 / spec 040 Knowledge Graph / spec 042 ConceptPage 詳細 / spec 043 SavedAnswer / spec 024 Tag 管理 / spec 051 CloudKit sync が新動線経由で完全動作

**Independent Test**: 各 spec の主要 user flow を新動線経由で実行、V2.5 と同じ動作確認

### Implementation for User Story 7

- [ ] T023 [US7] 動線継続性 smoke test (build + 手動 tap walkthrough) — `xcodebuild build -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17'` 成功確認 + 主要 user flow 5 つを Simulator で manual smoke test: (1) 知識 Clip 続きが気になる → DeepDiveChatView (spec 044) / (2) アバター → Settings → Tag 管理 (spec 024) / (3) アバター → Settings → iCloud sync (spec 051) / (4) アバター → Settings → AI チャット履歴 (spec 043) / (5) ConceptPage 詳細 「学習する」(spec 042)

**Checkpoint**: P1 MVP 完成、Phase A 出荷可能状態

---

## Phase 9: User Story 8 — ライブラリ日付別 grouping (Priority: P2)

**Goal**: 既存 ArticleListView を Apple Photos 風日付 group + 検索/フィルター pill に再構成

**Independent Test**: 異なる日付の記事 10 件 → ライブラリタブ → 5 date group 表示

### Implementation for User Story 8

- [ ] T024 [US8] LibraryGroupedView 新規 (`KnowledgeTree/Views/LibraryGroupedView.swift`、~150 行) — `@Query(sort: \Article.savedAt, order: .reverse)` + `@State var searchText + selectedCategories + selectedTags` + `filteredArticles` computed + `LibraryDateGrouper.group(filteredArticles)` + LazyVStack + ForEach Section (DisclosureGroup) + ArticleRow + 既存 swipe + contextMenu (spec 022/030) 流用 + `.searchable(text: $searchText)`、accessibilityIdentifier `tab.library`
- [ ] T025 [US8] LibraryFilterPills 新規 (`KnowledgeTree/Views/LibraryFilterPills.swift`、~80 行) — `@Binding selectedCategories: Set<String>` + `@Binding selectedTags: Set<String>` + HStack pill menu × 2 (分野で絞る / タグで絞る)、内部 FilterPillMenu helper struct で multi-select Menu 実装
- [ ] T026 [US8] ArticleListView → LibraryGroupedView 置換 (`KnowledgeTree/KnowledgeTreeApp.swift` の library tab assign 変更 + 旧 `KnowledgeTree/Views/ArticleListView.swift` を削除 or 残置判断) — KnowledgeTreeApp.body 内 `.library:` で `LibraryGroupedView()` 表示、ArticleListView は他で利用されていなければ削除
- [ ] T027 [P] [US8] LibraryDateGrouperTests 新規 (`KnowledgeTreeTests/LibraryDateGrouperTests.swift`、5 ケース、~120 行) — Date 注入で deterministic test: 1. 5 group 分類 / 2. 空配列 / 3. savedAt desc ソート / 4. 境界 (今日 0:00 ちょうど / 23:59 → 別 group) / 5. large data 1000 件 100ms 以内

**Checkpoint**: ライブラリ日付 grouping + 検索/フィルター 完成

---

## Phase 10: User Story 10 — 知識 Clip / ライブラリ FAB で記事手動追加 (Priority: P2)

**Goal**: 右下 FAB (⊕) tap → URL 入力 sheet → 有効 URL → Article 保存

**Independent Test**: FAB tap → URL 入力 → 保存 → ライブラリに表示

### Implementation for User Story 10

- [ ] T028 [P] [US10] FABButton 共通 component 新規 (`KnowledgeTree/Views/FABButton.swift`、~60 行) — Button + Image(systemName:) + 56x56 circle + accentColor + shadow + padding 16、accessibilityLabel
- [ ] T029 [P] [US10] AddArticleSheet 新規 (`KnowledgeTree/Views/AddArticleSheet.swift`、~100 行) — NavigationStack + Form + TextField (URL 入力) + 保存 Button + URL validation (http/https) + 重複検知 (FetchDescriptor) + 既存 ArticleSavingService 経由保存 + duplicate alert + error message
- [ ] T030 [US10] KnowledgeClipView + LibraryGroupedView に FAB + AddArticleSheet 配線 (`KnowledgeTree/Views/KnowledgeClipView.swift` + `KnowledgeTree/Views/LibraryGroupedView.swift` を編集) — `.overlay(alignment: .bottomTrailing) { FABButton(icon: "plus") { showAddArticle = true } }` + `.sheet(isPresented: $showAddArticle) { AddArticleSheet() }`
- [ ] T031 [US10] V3RedesignUITests に FAB tap → URL 入力 sheet test 追加 (`KnowledgeTreeUITests/V3RedesignUITests.swift`、1 ケース) — `testFABOpensAddArticleSheet()` で `fab.addArticle` tap → `sheet.addArticle` visible 確認

**Checkpoint**: FAB + 記事手動追加 完成

---

## Phase 11: User Story 11 — AI チャット 空状態 Suggested prompts (Priority: P2)

**Goal**: 空状態 (ChatSession 履歴ゼロ) で 3 つの suggested prompts 表示、tap で自動送信

**Independent Test**: 履歴削除 → AI チャットタブ → 3 prompt 表示 → tap → AI 応答開始

### Implementation for User Story 11

- [ ] T032 [US11] SuggestedPromptsSection 新規 (`KnowledgeTree/Views/SuggestedPromptsSection.swift`、~80 行) — `@Environment(ServiceContainer.self)` + `@State var prompts: [SuggestedPrompt]` + `.task { prompts = await services.suggestedPromptGenerator.generateSuggestedPrompts(in: context) }` + VStack で 3 Button (各 prompt) + onTap callback で text 渡し、accessibilityIdentifier `prompt.suggested.{index}`
- [ ] T033 [US11] ChatTabView 改修 (`KnowledgeTree/Views/ChatTabView.swift` を編集、~50 行追加) — `if currentSession.messages?.isEmpty ?? true` で SuggestedPromptsSection 表示 (onPromptTap で `chatService.sendMessage(promptText, in: currentSession)`)、placeholder Text "💬 何でも聞いて" 追加
- [ ] T034 [P] [US11] SuggestedPromptGeneratorTests 新規 (`KnowledgeTreeTests/SuggestedPromptGeneratorTests.swift`、6 ケース、~150 行) — in-memory ModelContainer + Mock UserDefaults: 1. 正常 (ConceptPage 5 + Category 3) → 最新 1 + 最新 1 + 固定 1 / 2. データ無し fallback → generic 3 / 3. ConceptPage 1 + Category 0 → 1 + 固定 1 + generic 1 / 4. 30 字 truncate / 5. 同日 cache (call count 1) / 6. 翌日 cache miss (call count 2)
- [ ] T035 [US11] V3RedesignUITests に suggested prompt tap test 追加 (`KnowledgeTreeUITests/V3RedesignUITests.swift`、1 ケース) — `testSuggestedPromptTapSendsMessage()` で AI チャットタブ → `prompt.suggested.0` tap → ChatMessageRow 出現確認

**Checkpoint**: AI チャット 空状態改善完成

---

## Phase 12: User Story 12 — AI チャット 📊 → Knowledge Graph 全体画面 (Priority: P2)

**Goal**: AI チャット toolbar 📊 アイコン → KnowledgeGraphFullScreenView push、Category 単位 subgraph 表示

**Independent Test**: AI チャット → 📊 tap → 2 秒以内に Knowledge Graph 表示 → node tap で詳細

### Implementation for User Story 12

- [ ] T036 [P] [US12] KnowledgeGraphFullScreenView 新規 (`KnowledgeTree/Views/KnowledgeGraphFullScreenView.swift`、~120 行) — `@Query(sort: \GraphNode.salience, order: .reverse) var allNodes` + `allCategories` computed (distinct) + ScrollView + LazyVStack + ForEach(allCategories) で Section + CategoryGraphView (既存 spec 041 流用、`frame(height: 300)`) + 0 件で ContentUnavailableView、navigationTitle "Knowledge Graph"、Hashable struct `KnowledgeGraphFullScreenDestination` も定義
- [ ] T037 [US12] ChatTabView toolbar 📊 + navigationDestination 配線 (`KnowledgeTree/Views/ChatTabView.swift` を編集) — `.toolbar { ToolbarItem(.topBarTrailing) { NavigationLink(value: KnowledgeGraphFullScreenDestination()) { Image(systemName: "chart.dots.scatter") } } }` + `.navigationDestination(for: KnowledgeGraphFullScreenDestination.self) { _ in KnowledgeGraphFullScreenView() }`、accessibilityIdentifier `toolbar.knowledgeGraph`

**Checkpoint**: Knowledge Graph 全体画面動線完成

---

## Phase 13: User Story 11/13/14 — Empty States + V3 Migration Tooltip + Settings 統合 (Priority: P3)

**Goal**: 全 section に親切な empty state、V2.5 → V3.0 初回 tooltip、旧 AI ブレイン統計を Settings 内に統合

**Independent Test**: 新規 install → 全 section に empty state 表示、V2.5 build からアップデート → 初回 tooltip 表示

### Implementation for User Story 11/13/14

- [ ] T038 各セクションの empty state UI 統合確認 (`KnowledgeTree/Views/RecentArticlesSection.swift` + `InterestingNextSection.swift` + `FollowingPeopleSection.swift` + `SuggestedPromptsSection.swift` を確認・追加) — RecentArticlesSection: 新規 install + cache empty 時 ContentUnavailableView (Localizable: `knowledgeClip.empty.recentArticles` "最近の記事はまだありません ✨ 記事を共有してみよう") / InterestingNextSection: ConceptPage + Digest 両 0 件で empty / FollowingPeopleSection: isFollowing 0 件で empty / AI チャット: 既存実装内
- [ ] T039 V3 migration tooltip 表示 (`KnowledgeTree/Views/KnowledgeClipView.swift` を編集、~30 行追加) — `@State var showV3Tooltip: Bool` + `.onAppear { if !UserDefaults.standard.bool(forKey: "spec056_v3_migrated") { showV3Tooltip = true } }` + `.overlay(alignment: .top) { if showV3Tooltip { V3MigrationTooltip(onDismiss: { ... UserDefaults.standard.set(true, forKey: "spec056_v3_migrated"); showV3Tooltip = false }) } }`、V3MigrationTooltip は同ファイル内 private struct
- [ ] T040 SettingsView に UnderstandingStatsSection 統合 (`KnowledgeTree/Views/SettingsView.swift` を編集、~30 行追加) — 旧 AI ブレインタブの統計 (今月 ✓ N 件 / 最近深掘り N 概念) を SettingsView の最下部 Section として追加 (Section header "学習統計")、件数 0 で section 非表示

**Checkpoint**: P3 polish 完成

---

## Phase 14: Polish & Cross-Cutting Concerns

**Purpose**: Build / Test regression / docs

- [ ] T041 Build 警告ゼロ確認 — `xcodebuild clean build -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17'` で BUILD SUCCEEDED + spec 056 由来 warning ゼロ
- [ ] T042 全テスト regression PASS 確認 — `xcodebuild test -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:KnowledgeTreeTests -parallel-testing-enabled NO` で全 suite PASS (新規 19 ケース + 既存 全件)
- [ ] T043 CLAUDE.md 更新 (`CLAUDE.md` を編集) — spec 056 の状態を 📝 → 🔧 実装中 (本ブランチ `056-uiux-redesign-v3`、未 commit) に更新、後の commit + PR + main マージ後に ✅ 完成へ
- [ ] T044 実機検証 (ユーザー実施、quickstart.md SC-001〜SC-018) — Simulator + 実機で 15 シナリオ確認、特に SC-013 (動線継続) + SC-014 (V3 migration tooltip) + SC-008 (60fps)、結果を spec 056 完了 commit に記録

---

## Dependencies

### Phase 順
- **Phase 1** (T001) → Phase 2 開始
- **Phase 2** (T002-T007) → Phase 3 以降全 Phase 開始
- **Phase 3** (T008-T011) MVP の root tab refactor
- **Phase 4-7** (T012-T022) MVP の知識 Clip 主機能 (US2-US5)
- **Phase 8** (T023) MVP の動線継続検証 (US7)
- **Phase 9-12** (T024-T037) P2 機能 (US8/US10/US11/US12)
- **Phase 13** (T038-T040) P3 polish
- **Phase 14** (T041-T044) Polish + 検証

### 個別 task 依存

- T002 → T016 (InterestingNextSection は MixedSurfaceCard 利用)
- T003 → T015 (RecentArticlesServiceTests は service 必要)、T013 (RecentArticlesSection)
- T004 → T032 (SuggestedPromptsSection)、T034 (Tests)
- T005 → T024 (LibraryGroupedView)、T027 (Tests)
- T006 → T013 / T016 / T032 (ServiceContainer 経由 inject 利用)
- T007 → T008 / T009 / T010 / T011 (AppTab 削減後の root view 削除 + UI test)
- T012 + T013 → T014 (KnowledgeClipView Phase 1)
- T014 → T017 (KnowledgeClipView Phase 2)、T020 (Phase 3)、T030 (FAB 配線)、T039 (tooltip)
- T018 + T019 → T020 (KnowledgeClipView Phase 3 完成)
- T020 → T021 (旧 section 削除は KnowledgeClipView 完成後)
- T021 → T023 (動線継続検証は section 削除完了後)
- T024 + T025 → T026 (ArticleListView 置換)
- T028 + T029 → T030 (FAB 配線は両 component 必要)
- T030 → T031 (UI test)
- T032 → T033 (ChatTabView 改修)
- T033 → T035 (UI test)
- T036 → T037 (ChatTabView 配線)
- 全 Phase 完了 → T041 / T042 / T043 / T044

---

## Parallel Execution Examples

### Phase 2 並列 (Foundation 4 tasks)

```text
[T002, T003, T004, T005] を並列実行可
↓
[T006] (ServiceContainer 統合) → [T007] (KnowledgeTreeApp)
```

### Phase 4 並列 (3 components)

```text
[T012 (AvatarMenu), T013 (RecentArticlesSection), T015 (Tests)] を並列実行可
↓
[T014 (KnowledgeClipView Phase 1)] T012 + T013 完了後
```

### Phase 10 並列

```text
[T028 (FABButton), T029 (AddArticleSheet)] を並列実行可
↓
[T030 (配線)] → [T031 (UI test)]
```

### Phase 12 並列

```text
[T036 (KnowledgeGraphFullScreenView)] 単独可、ChatTabView と独立
[T037 (ChatTabView 配線)] T036 完了後
```

---

## Implementation Strategy

### MVP First (Phase A、P1 のみ、~11 タスク、1 週間)

- T001 → T002-T007 → T008-T011 → T012-T015 → T016-T017 → T018-T021 → T022 → T023
- 完了で V3.0 の本質 (3 タブ + 知識 Clip 3 section + 動線継続) 達成、release 可能状態

### Phase B (P2 ライブラリ、~4 タスク、3 日)

- T024-T027 (Library grouping + フィルター + テスト)

### Phase C (P2 FAB + AI チャット、~7 タスク、3 日)

- T028-T031 (FAB + AddArticleSheet + UI test)
- T032-T035 (Suggested prompts + Tests + UI test)
- T036-T037 (Knowledge Graph 全体画面)

### Phase D (P3 polish + final、~7 タスク、2 日)

- T038-T040 (Empty states + tooltip + SettingsView 統合)
- T041-T044 (Build + Test regression + CLAUDE.md + 実機検証)

### 段階 commit 戦略

- Phase A 完了で 1 commit (or 2-3 commit に分割: foundation / root tab refactor / 知識 Clip 3 section)
- Phase B / C / D は各 1 commit
- 最終 PR は全 commit 統合 (V2.5 と一括 V3.0 release)

---

## Notes

- 全 task は `KnowledgeTree/` ディレクトリ内で完結 (新規ファイル + 改修ファイル)
- pbxproj 自動編集なし (SwiftData @Model 変更ゼロ、Share/Safari Extension target 追加不要)
- 既存 spec 044/042/043/040/018/035/036/037/046/051 の機能は全保持、動線変更のみ
- T023 の動線継続 smoke test は Phase A 完成判定の核心 — 既存全機能の動作確認
- 各 Phase 完了 checkpoint で xcodebuild build を回し、regression 防止

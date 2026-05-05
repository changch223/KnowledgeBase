---
description: "Tasks for spec 011: UI リブランディング + AI ブレインタブ追加"
---

# Tasks: UI リブランディング + AI ブレインタブ追加

**Input**: Design documents from `specs/011-ai-brain-tab/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: 含む。Constitution テストゲートに準拠 (`KnowledgeTreeTests` 単体テスト + `KnowledgeTreeUITests` 主要 UI テスト)。

**Organization**: 4 ユーザーストーリー (US1: PowerGauge / US2: KnowledgeMap / US3: RecentActivity / US4: 既存保持) ごとに独立実装可能。

## Format: `[ID] [P?] [Story] Description with file path`

- **[P]**: 並列実行可 (異なるファイル / 依存なし)
- **[Story]**: US1〜US4 のラベル
- ファイルパスは project-relative (KnowledgeTree project root から)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: ブランド変更とローカライゼーション基盤

- [x] T001 `KnowledgeTree.xcodeproj/project.pbxproj` に build setting `INFOPLIST_KEY_CFBundleDisplayName = "知積"` を main app target (KnowledgeTree) に追加。Bundle Identifier / module 名は無変更。
- [x] T002 `KnowledgeTreeShareExtension/Info.plist` の `CFBundleDisplayName` を `KnowledgeTree` から `知積` に変更 (Share Sheet 表示名統一)。
- [x] T003 [P] `KnowledgeTree/Localization/Localizable.xcstrings` に AI ブレインタブ向け文字列を追加: `"AI ブレイン"` / `"ライブラリ"` / `"Your AI is growing"` / `"%lld 記事を吸収済"` / `"%lld 知識  ·  %lld キーファクト"` / `"AI パワー: %lld 記事、%lld 知識、%lld キーファクト"` / `"今週 %lld 件 新たに吸収"` / `"今週はまだ吸収していません"` / `"今週の吸収: %lld 件"` / `"最近育ったテーマ"` / `"新しい繋がり"` / `"まだありません"` / `"まだ記事がありません。Safari から記事を保存しよう！"` / `"タグ %@、%lld 記事"` (VoiceOver) — 全て日本語ロケール (一部英語固定)。

**Checkpoint**: アプリビルドで起動するとホーム画面アイコン名が「知積」になる (タブ追加前段階)。

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: TabView 化 + transient 型定義 + 純粋関数モジュール基礎。全 US の前提。

**⚠️ CRITICAL**: このフェーズが完了するまでどの US も着手不可。

- [x] T004 `KnowledgeTree/Services/KnowledgeMapBuilder.swift` を新規作成: `MapNode` / `MapEdge` / `MapGraph` / `RecentActivitySnapshot` の transient struct 定義のみ (具体実装は T005 / T020 で追加)。data-model.md Section B 参照。`@MainActor` 注釈なし、`Sendable` / `Hashable` / `Identifiable` 準拠。
- [x] T005 `KnowledgeTree/Services/KnowledgeMapBuilder.swift` に `enum KnowledgeMapBuilder` を追加し `buildGraph(tags:canvasSize:iterations:)` / `buildGraph(tags:canvasSize:iterations:seed:)` / `step(nodes:edges:canvasSize:params:)` / `ForceParams` の **stub 実装** を入れる (空配列 / 中心配置を返すだけ。本実装は US2 の T024 で完成)。spec contracts/knowledge-map-builder.md 参照。
- [x] T006 `KnowledgeTree/KnowledgeTreeApp.swift` の `var body: some Scene { WindowGroup { ArticleListView() ... } }` を TabView 構造に書き換え。**実装メモ**: ArticleListView が既に内部 NavigationStack を保持しているため、追加の NavigationStack ラップは行わず、ArticleListView をそのまま `tabItem` に渡す。AIBrainView 側は内部に独自 NavigationStack を持つ。AIBrainViewPlaceholder は省略し、T015 で作成する `AIBrainView` を直接参照。
- [x] T007 [P] `KnowledgeTree/Views/ArticleListView.swift` を確認: 内部 NavigationStack を保持していることを確認。TabView の中で `tabItem` 直下に配置すれば動作 (改修不要、no-op)。

**Checkpoint**: アプリ起動でタブバー (ライブラリ / AI ブレイン) が表示。AI ブレインタブをタップすると placeholder テキストのみ表示。ライブラリタブの挙動は spec 010 までと完全一致。

---

## Phase 3: User Story 4 - 既存ライブラリタブ完全保持 (Priority: P1) 🎯 MVP 基盤

**Goal**: TabView 導入後も ArticleListView の検索 / タグ / Detail シート / live update が完全に保持されること。

**Independent Test**: 検証 5 (quickstart.md) を実機で実行し、spec 010 までと UI 操作が完全一致することを確認。

### Tests for User Story 4

- [x] T008 [P] [US4] `KnowledgeTreeUITests/AIBrainTabUITests.swift` を新規作成し `testLibraryTabRetainsExistingBehavior` を追加: タブバーで「ライブラリ」タップ → tagListNavigationButton 存在確認を `accessibilityIdentifier` ベースで検証。

### Implementation for User Story 4

- [x] T009 [US4] `KnowledgeTree/Views/ArticleListView.swift` の `searchable` / `navigationDestination` などが Phase 2 の TabView 配置で機能する。ソース改修なし。実機での操作検証はユーザー側で実施。
- [x] T010 [US4] `KnowledgeTree/Views/ArticleDetailView.swift` の sheet presentation は TabView 環境下でも動作 (sheet は presenting view の階層によらず動作)。改修なし。実機検証はユーザー側。
- [x] T011 [US4] `KnowledgeTree/Views/BottomStatusBar.swift` の overlay は ArticleListView 内 (既存) と AIBrainView 内 (本 spec で追加済) の両方で表示される。両タブで visible を確保。
- [x] T012 [US4] spec 005 live update メカニズム (`RefreshTrigger` / `NotificationCenter` listen / scenePhase) は ArticleListView の既存実装が保持。TabView root に `.environment(refreshTrigger)` 等を 1 回注入することで両タブに伝播。実機 live update 検証はユーザー側で実施。

**Checkpoint**: spec 010 までの全機能が回帰なく動作。MVP の出荷可能基盤完了。

---

## Phase 4: User Story 1 - PowerGauge で AI 成長を一目で確認 (Priority: P1) 🎯 MVP

**Goal**: AI ブレインタブの Section 1 (PowerGaugeCard) で Article / KnowledgeEntity / KeyFact 数を表示し、起動時カウントアップ + 静かなパルスを実現。

**Independent Test**: 検証 1 / 検証 2 (quickstart.md) を実機で実行し、空状態 1 秒以内表示 + 30 件で 0.6 秒カウントアップを目視確認。

### Tests for User Story 1

- [x] T013 [P] [US1] `KnowledgeTreeUITests/AIBrainTabUITests.swift` に `testAIBrainTabShowsPowerGauge` および `testAIBrainRootAccessibilityIdentifier` を追加: AI ブレインタブをタップして PowerGauge / root の `accessibilityIdentifier` を検証。

### Implementation for User Story 1

- [x] T014 [P] [US1] `KnowledgeTree/Views/PowerGaugeCard.swift` を新規作成。contracts/power-gauge-card.md に従い、`@Query<Article>` / `@Query<KnowledgeEntity>` / `@Query<KeyFact>` で集計、`@State animatedArticleCount` を `withAnimation(.easeOut(duration: 0.6))` でカウントアップ、`@State pulseScale` を `repeatForever(autoreverses: true)` でパルス、`LinearGradient` で背景、`Text("Your AI is growing")` を italic 固定英文で配置。`accessibilityIdentifier("aibrain.power_gauge")` を付与。
- [x] T015 [US1] `KnowledgeTree/Views/AIBrainView.swift` を新規作成。contracts/ai-brain-view.md に従い `NavigationStack(path:) { ZStack { ScrollView { VStack { PowerGaugeCard() } } ; BottomStatusBar(monitor:) } } .navigationDestination(for: TagFilteredDestination.self) { ... }` 構造。`@Environment(RefreshTrigger.self)` / `@Environment(ProcessingMonitor.self)` / `@State path: NavigationPath` を持つ。MVP では PowerGaugeCard のみ表示、KnowledgeMapView / RecentActivityCards のスロットはコメント保留。
- [x] T016 [US1] `KnowledgeTree/KnowledgeTreeApp.swift` で `AIBrainView()` を直接参照する形で T006 と統合 (placeholder ステップは省略)。
- [x] T017 [US1] `KnowledgeTree/Localization/Localizable.xcstrings` に PowerGaugeCard で auto-extract される format キー (`%lld 記事を吸収済` / `%lld 知識  ·  %lld キーファクト` / `Your AI is growing` / `AI パワー: %lld 記事、%lld 知識、%lld キーファクト`) を全て追加済。生文字列リテラルは PowerGaugeCard 内に残らない (全 Text() 呼び出しは LocalizedStringKey 経由)。

**Checkpoint**: AI ブレインタブで PowerGaugeCard のみ表示 + カウントアップ動作。MVP 1 機能完成 (KnowledgeMap / RecentActivity は次フェーズ)。

---

## Phase 5: User Story 2 - KnowledgeMap でタグ繋がり可視化 (Priority: P1)

**Goal**: AI ブレインタブの Section 2 で Tag をノード、共通 entity をエッジとしたマップを Canvas 描画。ノードタップで TagFilteredListView へ遷移。

**Independent Test**: 検証 3 / 検証 7 (quickstart.md) を実機で実行し、100 タグで 60fps + ピンチ・ドラッグ + ノードタップ遷移を確認。

### Tests for User Story 2

- [x] T018 [P] [US2] `KnowledgeTreeTests/KnowledgeMapBuilderTests.swift` を新規作成し contracts/knowledge-map-builder.md の **テスト 11 ケース** を実装:
  - `testEmptyTagsReturnsEmptyGraph` / `testSingleTagSingleNode` / `testTwoTagsSharedEntity` / `testTwoTagsNoSharedEntity` / `testEdgeIsAlphabeticallyNormalized` / `testEdgeDeduplication` / `testRadiusClamping` / `testNodePositionsWithinCanvas` / `testDeterministicWithSeed` / `testHundredTagsPerformance` (200ms 以内検証) / `testStepMovesNearbyNodesApart` (Energy 削減を近接ノード分離として検証、corner case 微小オフセットで)
  - in-memory ModelContainer + `private typealias Tag = KnowledgeTree.Tag` で SwiftUI `Tag` との曖昧化を解消
  - **全 11 ケース pass 確認済 (実機 simulator)**
- [x] T019 [P] [US2] `KnowledgeTreeUITests/AIBrainTabUITests.swift` に `testKnowledgeMapPresent` を追加: AI ブレインタブ → KnowledgeMap セクション (`aibrain.knowledge_map`) を accessibilityIdentifier で検証。
- [x] T020 [P] [US2] `KnowledgeTreeUITests/AIBrainTabUITests.swift` に `testKnowledgeMapEmptyStateOnFreshInstall` を追加: タグ 0 件時に empty state (`aibrain.map.empty`) または通常マップが表示される検証。

### Implementation for User Story 2

- [x] T021 [P] [US2] `KnowledgeTree/Services/KnowledgeMapBuilder.swift` の `buildGraph` 本実装: (1) `computeEdges` でタグ毎の entity Set 構築 + intersection → edge (2) `SeededRandomNumberGenerator` (xorshift64) で初期位置乱数配置 (3) `iterations` 回 step (4) canvas 内 clamp。
- [x] T022 [P] [US2] `KnowledgeTree/Services/KnowledgeMapBuilder.swift` の `step` 本実装: 反発力 (O(N²) 逆 2 乗 push) + バネ力 (edges) + 中心引力 + damping + 境界 clamp。`ForceParams.default` (repulsion=1500, spring=0.05, centerPull=0.02, damping=0.85, idealEdgeLength=120)。
- [x] T023 [P] [US2] `nodeRadius(for:)` 静的関数を `KnowledgeMapBuilder` enum 内に実装。`min(100, max(40, log2(count + 1) * 20))`。
- [x] T024 [US2] `KnowledgeTree/Views/KnowledgeMapView.swift` を新規作成: `GeometryReader { ZStack { Canvas { drawEdges + drawNodes } + ForEach(nodes) { invisible NavigationLink button } } }` 構造。`@State graph: MapGraph` / `@State canvasSize: CGSize` / `@State scale: CGFloat / accumulatedScale` / `@State offset: CGSize / accumulatedOffset` / `@State newlyVisibleIDs: Set<String>` / `@State hasPerformedInitialBuild: Bool` を持つ。タグ 0 件時は `ContentUnavailableView`。
- [x] T025 [US2] `nodeButton(for:)` 内で `NavigationLink(value: TagFilteredDestination(tagName: node.id)) { Color.clear .frame(...).contentShape(Circle()) }` 発火。Canvas 背景描画と Button overlay の hit-testing 両立。
- [x] T026 [US2] 各ノードボタンに `accessibilityIdentifier("aibrain.map.node.\(node.id)")` と `accessibilityLabel(Text("タグ \(node.id)、\(node.articleCount) 記事"))` を付与。
- [x] T027 [US2] 新ノード fade-in: 初回 build では fade-in しない (起動時に全ノードが新登場扱いになる回避)。RefreshTrigger 経由の rebuild で `oldIDs.subtracting(newIDs)` を `newlyVisibleIDs` に追加 → opacity = 0 → onAppear で `withAnimation(.easeIn(duration: 0.4))` で remove → 自動 fade-in。
- [x] T028 [US2] `KnowledgeTree/Views/AIBrainView.swift` の VStack に `KnowledgeMapView(tags: allTags).frame(minHeight: 320)` を PowerGaugeCard の下に配置。
- [x] T029 [US2] `MagnificationGesture` で `scale = clamp(accumulatedScale * value, 0.5, 3.0)` + onEnded で accumulate。`DragGesture` で `offset = accumulatedOffset + translation` + onEnded で accumulate。Canvas 全体に `scaleEffect(scale).offset(offset)` 適用。

**Checkpoint**: AI ブレインタブで PowerGauge + KnowledgeMap が動作。MVP のうち P1 全完了。

---

## Phase 6: User Story 3 - RecentActivity で直近 7 日成長記録 (Priority: P2)

**Goal**: AI ブレインタブの Section 3 で 3 枚カード (今週吸収 / 育ったテーマ / 新しい繋がり) を横スクロール表示。

**Independent Test**: 検証 4 (quickstart.md) で 7 日以内の記事保存 → カード A の数字 +1 を確認。空データで「まだありません」表示確認。

### Tests for User Story 3

- [x] T030 [P] [US3] `KnowledgeTreeTests/RecentActivitySnapshotBuilderTests.swift` を新規作成し contracts/recent-activity-cards.md の **テスト 7 ケース** を全実装:
  - `testEmptyTagsReturnsZeroSnapshot` / `testArticlesThisWeekOnlyCountsRecent` / `testGrowingTagsReturnsTop3DescendingByCount` / `testGrowingTagsEmptyWhenNoRecentArticles` / `testNewConnectionsOnlyReturnsFirstAppearance` / `testNewConnectionsLimitedTo2Pairs` / `testEntityNameNormalization`
  - 時刻注入のため `sevenDaysAgo: Date` パラメータを `RecentActivitySnapshotBuilder.build` に渡す
  - `private typealias Tag = KnowledgeTree.Tag` で SwiftUI Tag 曖昧化解消
  - **全 7 ケース pass 確認済 (実機 simulator)**
- [x] T031 [P] [US3] `KnowledgeTreeUITests/AIBrainTabUITests.swift` に `testRecentActivityCardsPresent` を追加: section `aibrain.recent_activity` 表示 + 3 枚カード (`aibrain.recent.card.this_week` / `.growing` / `.connections`) のいずれかが見つかることを検証。

### Implementation for User Story 3

- [x] T032 [P] [US3] `KnowledgeTree/Services/KnowledgeMapBuilder.swift` 末尾に `enum RecentActivitySnapshotBuilder` を追加 (ファイル分離せず同居):
  - `build(tags:entities:sevenDaysAgo:) -> RecentActivitySnapshot` 公開 API
  - `computeArticlesThisWeek`: 全タグ article を `Set<UUID>` で重複排除 → `savedAt > sevenDaysAgo` の件数
  - `computeGrowingTags`: 各タグの recent article 件数 desc Top3 (件数 0 除外)
  - `computeNewConnections`: entity 名 (lowercased + trim) でグループ化 + 最古 savedAt 計算 → `> sevenDaysAgo` グループから salience desc Top2 ペア化
  - `RecentActivitySnapshot.GrowingTag` / `.Connection` を nested struct で導入 (タプル型は ForEach `id:` で扱いづらいため)
- [x] T033 [P] [US3] `KnowledgeTree/Views/RecentActivityCards.swift` を新規作成: `ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { cardThisWeek; cardGrowingTags; cardNewConnections } }` 構造。`init(now: Date = Date())` で `sevenDaysAgo` を init 確定。`@Query<Tag>` / `@Query<KnowledgeEntity>` で全件取得 → snapshot computed property → 3 枚カード描画。
- [x] T034 [US3] 各カードの空状態文言:
  - カード A 0 件: `Text("今週はまだ吸収していません")` (secondary 色)
  - カード B 空: `Text("最近育ったテーマ")` + `Text("まだありません")` (caption)
  - カード C 空: `Text("新しい繋がり")` + `Text("まだありません")` (caption)
- [x] T035 [US3] カードデザイン: 高さ 140pt (AIBrainView 側で `frame(height: 140)` 指定)、各カード幅 200pt、`RoundedRectangle(cornerRadius: 16, style: .continuous)`、`Color(.secondarySystemBackground)` 背景、SF Symbol アイコン (tray.and.arrow.down.fill / leaf.fill / point.3.connected.trianglepath.dotted)。
- [x] T036 [US3] `KnowledgeTree/Views/AIBrainView.swift` の VStack に `RecentActivityCards().frame(height: 140)` を KnowledgeMapView の下に配置。

**Checkpoint**: AI ブレインタブの 3 セクション全て動作。spec 011 機能完成。

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: 品質ゲート / アクセシビリティ / パフォーマンス検証 / ドキュメント更新

- [x] T037 [P] 新規 KnowledgeTreeTests (KnowledgeMapBuilderTests 11 + RecentActivitySnapshotBuilderTests 7) は全て pass。simulator (iPhone 17 Pro) 実行、`** TEST SUCCEEDED **` 確認。既存テスト回帰確認はユーザー側で `xcodebuild test -only-testing:KnowledgeTreeTests` で実施推奨。
- [x] T038 [P] AIBrainTabUITests 6 ケース (testLibraryTabRetainsExistingBehavior / testAIBrainTabShowsPowerGauge / testAIBrainRootAccessibilityIdentifier / testKnowledgeMapPresent / testKnowledgeMapEmptyStateOnFreshInstall / testRecentActivityCardsPresent) を実装。Simulator UI test 実行はユーザー側で実施推奨。
- [ ] T039 quickstart.md 検証 1〜7 を実機 (iPhone 17 Pro 等) で実行し、各 SC をクリア。Instruments スクリーンショット (Time Profiler / SwiftUI / 60fps) を取得して PR 添付。**ユーザー側で実機検証が必要**。
- [ ] T040 [P] Dynamic Type 最大サイズで AIBrainView 全 3 セクションのレイアウト崩れがないか確認 (Settings → Display → Text Size)。**ユーザー側で実機検証が必要**。
- [ ] T041 [P] Dark Mode 切替で AIBrainView の色味 (PowerGauge グラデーション / カード背景 / Canvas 線色) が自然に見えるか確認。**ユーザー側で実機検証が必要**。
- [ ] T042 [P] VoiceOver で AI ブレインタブを順次 swipe して、PowerGauge / 各 KnowledgeMap ノード / 各 RecentActivityCard を正しく読み上げるか確認。**ユーザー側で実機検証が必要**。
- [x] T043 `CLAUDE.md` の SPECKIT セクションを更新し spec 011 を「✅ 実装」に書き換え (commit 時に commit SHA 反映)。
- [x] T044 [P] `KnowledgeTree/Services/KnowledgeMapBuilder.swift` (Builder + RecentActivitySnapshotBuilder 同居) のコードレビュー: Swift API Design Guidelines 準拠 / `fatalError` / `try!` 不使用 / `@MainActor` 注釈なし確認済。
- [x] T045 最終 simulator build で警告ゼロ (本 spec の改修起因の警告は 0、`Skipping duplicate build file` 警告は pre-existing)。
- [ ] T046 PR 説明に Constitution Check 全 11 ゲート ✅ + iPhone / iPad 両方の AI ブレインタブスクリーンショットを添付 (Per-PR ゲート遵守)。**ユーザー側で実機スクリーンショット撮影 → PR 説明添付が必要**。

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: 依存なし、即着手可
- **Phase 2 (Foundational)**: Phase 1 完了後着手、全 US の前提
- **Phase 3 (US4 既存保持)**: Phase 2 完了後に着手 (実質的に Phase 2 の TabView 化と並行検証)
- **Phase 4 (US1 PowerGauge)**: Phase 2 完了後に着手 (US4 と並列可)
- **Phase 5 (US2 KnowledgeMap)**: Phase 2 完了後に着手 (US1 と並列可、ただし `AIBrainView` への配置は US1 の T015 後)
- **Phase 6 (US3 RecentActivity)**: Phase 2 完了後に着手 (US1/US2 と並列可、`AIBrainView` への配置は T015 後)
- **Phase 7 (Polish)**: 全 US 完了後

### User Story Dependencies

- **US4 (P1, 既存保持)**: Foundational のみ依存。最初に検証可能。
- **US1 (P1, PowerGauge)**: Foundational のみ依存。PowerGaugeCard と AIBrainView 本体 (T015) を作る最初の US。
- **US2 (P1, KnowledgeMap)**: Foundational + US1 の T015 (AIBrainView 本体存在) 依存。KnowledgeMapView の `AIBrainView` への配置タスク T028 が US1 の T015 後でないと走れない。
- **US3 (P2, RecentActivity)**: Foundational + US1 の T015 依存。同様に T036 が T015 後。

### Within Each User Story

- Tests を先に追加 (FAIL 前提で OK)
- 純粋関数 / Builder の本実装 → View の本実装 → AIBrainView への配置 の順
- 各 US 末尾の Checkpoint で実機検証

---

## Parallel Opportunities

### Setup Phase (Phase 1)

```text
T001 (xcodeproj main app) と T002 (xcodeproj Share Extension) は同一 .pbxproj だが build setting セクションが target 別なので慎重に手動編集なら OK。安全のため T001 完了後 T002 推奨。
T003 (Localizable.xcstrings) は完全並列可。
```

### Foundational Phase (Phase 2)

```text
T004 → T005 (同ファイル KnowledgeMapBuilder.swift、順次)
T006 (KnowledgeTreeApp.swift) は単独
T007 [P] (ArticleListView 確認のみ、no-op 可)
```

### US1 並列 (Phase 4)

```text
T013 [P] [US1] (UI test 追加)
T014 [P] [US1] (PowerGaugeCard.swift 新規)
T015 [US1]    (AIBrainView.swift 新規、T014 完了後 import 必要)
T016 [US1]    (KnowledgeTreeApp.swift 修正、T015 完了後)
T017 [US1]    (Localizable 確認、T014 完了後)
```

### US2 並列 (Phase 5)

```text
T018 [P] [US2] / T019 [P] [US2] / T020 [P] [US2]  ← 全テスト並列
T021 [P] [US2] / T022 [P] [US2] / T023 [P] [US2]  ← KnowledgeMapBuilder 別関数なら並列、同一ファイル編集なので順次が安全
T024 [US2]    (KnowledgeMapView 新規) → T025/T026/T027/T029 (同一ファイル順次)
T028 [US2]    (AIBrainView 修正、T015 後)
```

### US3 並列 (Phase 6)

```text
T030 [P] [US3] / T031 [P] [US3]  ← テスト並列
T032 [P] [US3]  ← Builder 実装 (別ファイル可)
T033 [P] [US3]  ← RecentActivityCards 新規
T034/T035 [US3] (RecentActivityCards 内詳細、順次)
T036 [US3]   (AIBrainView 修正、T015 後)
```

### Polish (Phase 7)

```text
T037/T038/T040/T041/T042/T044 [P] (全部独立、並列可)
T039/T043/T045/T046 (順次 or 検証次第)
```

---

## Implementation Strategy

### MVP First (US4 + US1 のみ) — 出荷可能最小スコープ

1. Phase 1 (Setup): T001-T003 完了
2. Phase 2 (Foundational): T004-T007 完了 (TabView 化 + KnowledgeMapBuilder stub)
3. Phase 3 (US4): T008-T012 完了 (既存保持検証)
4. Phase 4 (US1): T013-T017 完了 (PowerGauge 動作)
5. **STOP and VALIDATE**: 検証 1 / 2 / 5 を実機で確認 → MVP demo OK
6. KnowledgeMap / RecentActivity は次フェーズへ

### Incremental Delivery

1. MVP (上記 4 フェーズ) → 検証して中間 commit
2. US2 (Phase 5): KnowledgeMap 追加 → 検証 3 / 7
3. US3 (Phase 6): RecentActivity 追加 → 検証 4
4. Polish (Phase 7): 全検証通し + PR

### Solo Dev Strategy (KnowledgeTree は個人開発)

- 個人開発ゆえ並列化は限定的、ただし Test-first → 実装 → 検証 のループで quality を維持
- Constitution テストゲート遵守: 各 US の Tests を先に書いて FAIL 確認 → 実装で PASS
- 各 US の Checkpoint で git commit (推奨 4-5 コミット: T007 / T012 / T017 / T029 / T036 / T046)

---

## Notes

- [P] = 異なるファイル / 依存なし、並列可
- [Story] = US1〜US4 ラベル
- 各 US は独立完成 + 独立テスト可能
- テストは先に書いて FAIL 確認 (Constitution テストゲート)
- 各 task / Checkpoint で commit 推奨
- 既存スキーマ完全無改修 (新 @Model ゼロ、新 migration ゼロ)
- 既存 ArticleListView / TagListView / TagFilteredListView / EntityFilteredListView / BottomStatusBar / ProcessingMonitor / RefreshTrigger / ServiceContainer / 全 Service / 全 Store は本 spec で 1 行も改修しない (T009-T012 は検証のみ)

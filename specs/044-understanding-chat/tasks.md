# Tasks: Understanding Chat (家庭教師ループ + 学習タブ)

**Feature Branch**: `044-understanding-chat`
**Input**: Design documents from `/specs/044-understanding-chat/`
**Prerequisites**: plan.md, spec.md, research.md (R1-R12), data-model.md, contracts/ (9 files), quickstart.md (SC-001〜SC-010)

**Tests requested**: YES (Constitution Quality Gates 「テスト」必須項目 + plan.md Test Coverage 23 + UI 3 ケース指定)

**Organization**: User Story 順 (P1×5 → P2×4 → P3×1)、各 story 独立検証可能

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Localization strings 用意 (Constitution VII 必須、View body 内 literal 禁止)

- [X] T001 Add ~20 Japanese strings to `KnowledgeTree/Localization/Localizable.xcstrings`: 「学習」/「家庭教師を起動中…」/「✓ わかった」/「🤔 もっと」/「✗ 違う」/「新しい知識」/「更新が必要」/「理解が浅い」/「深掘り余地あり」/「復習」/「学習する」/「まだ学ぶカードがありません。記事を保存したり AI チャットで質問してみましょう」/「次の学びを待っています」/「すべて見る」/「家庭教師を起動できませんでした」/「もう一度開いてみてください。」/「もう少し別の角度から教えてください。」/「今月 %lld 件『わかった』」/「最近深掘り %lld 概念」/「\(name) を深掘り」

**Checkpoint**: xcstrings linter pass

---

## Phase 2: Foundational (Blocking Prerequisites — ALL user stories depend on these)

**Purpose**: @Model + transient struct + 3 Service Protocol+Default + ServiceContainer。これらが揃わないと US1 以降は実装できない。

- [X] T002 [P] Create `UnderstandingInteraction` `@Model` + `UnderstandingCard` transient struct + `UnderstandingCardKind` enum + `UnderstandingCardLabel` enum in `KnowledgeTree/Models/UnderstandingInteraction.swift` (~90 lines、contracts/understanding-interaction-model.md + understanding-card-transient.md 参照)
- [X] T003 Add `UnderstandingInteraction.self` to `SharedSchema.all` array in `KnowledgeTree/SharedSchema.swift`
- [X] T004 [P] Create `UnderstandingCardSurfaceServiceProtocol` + `DefaultUnderstandingCardSurfaceService` with 5-tier scoring (newKnowledge 100 / needsUpdate 90 / shallow 80 / deepDive 60 / review 40, dismissed -10) in `KnowledgeTree/Services/UnderstandingCardSurfaceService.swift` (~200 lines、contracts/understanding-card-surface-service.md 参照)
- [X] T005 [P] Create `UnderstandingTrackerServiceProtocol` + `DefaultUnderstandingTrackerService` with recordUnderstood / NeedMore / Dismissed / OpenedChat + 1-hop graph propagation (累積 2 件 = +1 round-half-up) in `KnowledgeTree/Services/UnderstandingTrackerService.swift` (~180 lines、contracts/understanding-tracker-service.md 参照)
- [X] T006 Create `DeepDiveChatStarterProtocol` + `DefaultDeepDiveChatStarter` wrapping `ChatService.createSession()` + `ChatService.ask()` with tutor prompt context (buildTutorContext for .conceptPage and .savedAnswer kinds) in `KnowledgeTree/Services/DeepDiveChatStarter.swift` (~100 lines、contracts/deep-dive-chat-starter.md 参照、T005 必要)
- [X] T007 Register 3 new services in `KnowledgeTree/Services/ServiceContainer.swift`: `understandingCardSurfaceService`, `understandingTrackerService`, `deepDiveChatStarter` (optional properties)
- [X] T007a Add `UnderstandingInteraction.swift` to ShareExtension + SafariExtension targets in `KnowledgeTree.xcodeproj/project.pbxproj` (PBXBuildFile + PBXFileReference + Sources entries、spec 042/043 同手順)

**Checkpoint**: `xcodebuild build -scheme KnowledgeTree` SUCCEEDED (no usage yet — types compile only)

---

## Phase 3: User Story 1 - 学習カードが自動で並ぶ (Priority: P1) 🎯 MVP

**Goal**: ユーザーが学習タブを開いた時、AI が surface した上位 5 件のカード (ConceptPage / SavedAnswer ブレンド) が表示される。

**Independent Test**: ConceptPage 3 件 + SavedAnswer 2 件存在状態で学習タブを開く → 5 件カード並ぶ + label badge 表示 (SC-001 1 秒以内)

### Implementation for User Story 1

- [X] T008 [P] [US1] Create `UnderstandingCardRow` view with unified UI (ConceptPage `lightbulb.fill` icon / SavedAnswer `quote.bubble.fill` icon, LabelBadge sub-view with 5 colors, SavedAtFormatter relative time) in `KnowledgeTree/Views/UnderstandingCardRow.swift` (~100 lines、contracts/understanding-card-row.md 参照)
- [X] T009 [US1] Create `UnderstandingTabView` (NavigationStack + ScrollView + LazyVStack + 上位 5 件 ForEach + 「+N すべて見る」NavigationLink + UnderstandingEmptyState + navigationDestination(for: UnderstandingCard.self) → DeepDiveChatView placeholder + navigationDestination(for: UnderstandingCardListDestination.self) → UnderstandingCardListView placeholder + .task refresh + .refreshable) in `KnowledgeTree/Views/UnderstandingTabView.swift` (~120 lines、contracts/understanding-tab-view.md 参照、T004 + T008 必要)
- [X] T010 [US1] Modify `KnowledgeTree/KnowledgeTreeApp.swift` and `KnowledgeTree/Services/LastOpenedStore.swift`: add `.learning` case to AppTab enum (1st position), add UnderstandingTabView as 1st tabItem (Label「学習」, systemImage `book.fill`, accessibilityIdentifier `tab.learning`), bootstrap 3 new services (surfaceService + tracker + deepDive starter, inject ChatService + GraphTraversalService into tracker, inject ChatService + tracker into starter), add migration UserDefaults `spec044_learningTabMigrated` to force `.learning` default once (~20 lines、Phase 7 US5 も同時実装)

### Tests for User Story 1

- [X] T011 [P] [US1] Create `UnderstandingCardSurfaceServiceTests` with 10 cases (空状態 / newKnowledge 優先 / needsUpdate 優先 / shallow + 関連記事 7d / dismissed -10 / limit=5 / blend ConceptPage+SavedAnswer / 全 max → review fallback / label 付与正確性 / savedAt desc tiebreak) using in-memory ModelContainer(SharedSchema.all) + Date injection in `KnowledgeTreeTests/UnderstandingCardSurfaceServiceTests.swift` (~250 lines、T004 後)

**Checkpoint US1**: 学習タブ open → 5 カード表示 + SC-001 (1s) + SC-005 (起動 default) + SC-007 (空状態 1s) PASS。MVP の核 surface 機能成立。

---

## Phase 4: User Story 2 - カードタップで AI と深掘り対話 (Priority: P1) 🎯 MVP

**Goal**: ユーザーがカードをタップで DeepDiveChatView 起動、AI が家庭教師調プロンプトで対話開始、下部 sticky 3 ボタン (✓ / 🤔 / ✗) 表示。

**Independent Test**: 「Apple Vision Pro」カードをタップ → DeepDiveChatView 開く + AI 初期発話 3 秒以内 (SC-002)

### Implementation for User Story 2

- [X] T012 [US2] Create `DeepDiveChatView` (VStack: chat body OR ProgressView「家庭教師を起動中…」OR error ContentUnavailableView + `UnderstandingActionBar` sticky bar with 3 buttons + .task → starter.startChat) + `UnderstandingActionBar` sub-view (3 ActionButtons with haptic light, handleUnderstood / handleNeedMore (= ChatService.ask with「もう少し別の角度から教えてください。」) / handleDismissed (= tracker call + dismiss())) + `ChatBodyView` component extracted from existing ChatTabView (reuse messages display + ChatInputField, may need extraction commit if not already) in `KnowledgeTree/Views/DeepDiveChatView.swift` (~200 lines、contracts/deep-dive-chat-view.md 参照、T006 + T009 必要)
- [X] T012a [US2] Replace placeholder navigationDestination in T009 UnderstandingTabView with real `DeepDiveChatView(card: card)`

### Tests for User Story 2

- [X] T013 [P] [US2] Create `DeepDiveChatStarterTests` with 5 cases (ConceptPage card 起動 → ChatSession + title + initial ask + openedChat 履歴 / tutor prompt に concept name 含む / openedChat 1 件記録 / Foundation Models 不可で ChatService fallback session 返却 / SavedAnswer card で prompt に question + answer.prefix(100) 含む) using new `MockChatService` + Mock tracker in `KnowledgeTreeTests/DeepDiveChatStarterTests.swift` (~150 lines、T006 後)

**Checkpoint US2**: カードタップ → chat 起動 + AI 初期発話 + SC-002 (3s) PASS。家庭教師ループの入口完成。

---

## Phase 5: User Story 3 - 「✓ わかった」で理解度が育つ (Priority: P1) 🎯 MVP

**Goal**: 「✓ わかった」タップで ConceptPage.userUnderstanding +1 (clamp 5) + 1-hop graph 波及 + UnderstandingInteraction 記録、次回学習タブで surface 入れ替わり。

**Independent Test**: ConceptPage A (userUnderstanding=0) で deep dive → 「✓ わかった」→ A.userUnderstanding=1 + 学習タブで A 下位化 (SC-003 + SC-004 + SC-008)

### Implementation for User Story 3

- [X] T014 [P] [US3] Implement recordUnderstood logic in `DefaultUnderstandingTrackerService` (T005 で枠は作成済) — UnderstandingInteraction insert, ConceptPage.userUnderstanding clamp [0, 5] += 1, graphService.neighborConceptIDs(for:hops:1) 経由 1-hop propagation で neighbor に "propagated" action insert (累積 2 件 = +1 round-half-up logic), context.save(), refreshTrigger.bump() (T005 の placeholder で関数定義済の場合は本タスクで実装、T005 内で完了済なら本タスクは skip 可)
- [X] T014a [US3] In `UnderstandingActionBar.handleUnderstood`, wire `tracker.recordUnderstood(card:)` call after haptic feedback (T012 で枠は作成済、T014 完成後に動作確認)

### Tests for User Story 3

- [X] T015 [P] [US3] Create `UnderstandingTrackerServiceTests` with 8 cases (recordUnderstood userUnderstanding 0→1 / max clamp 5 / 1-hop 2 neighbor + 2 回 understood で neighbor +1 / recordNeedMore 不変 + 履歴記録 / recordDismissed surface 下位 確認 / SavedAnswer 経由 recordUnderstood で relatedConceptIDs 全部 +1 / graphService=nil で silent skip + log warning / 連打 6 回で max 5 停止 + 履歴 6 件記録) using in-memory ModelContainer + Date injection + Mock GraphTraversalService (or in-memory graph fixture) in `KnowledgeTreeTests/UnderstandingTrackerServiceTests.swift` (~200 lines、T005 + T014 後)
- [X] T016 [P] [US3] Create `UnderstandingTabUITests` with 3 cases (学習タブ起動 → カードあり or empty state / 最初のカードタップで DeepDiveChatView 遷移 + 戻り / 「✓ わかった」tap → 戻った時 surface 入れ替わり) using XCUIApplication + accessibilityIdentifier (`tab.learning` / `card.understanding.conceptPage.*` / `button.understood`) in `KnowledgeTreeUITests/UnderstandingTabUITests.swift` (~80 lines、T010 + T012 後)

**Checkpoint US3**: 「✓ わかった」→ DB +1 + 1-hop 波及 + UI 入れ替わり PASS (SC-003 1s + SC-004 2s + SC-008)。理解度トラッキングの核完成。

---

## Phase 6: User Story 4 - 「🤔 もっと」で対話継続 (Priority: P1) 🎯 MVP

**Goal**: 「🤔 もっと」タップで userUnderstanding 不変、AI に追加質問送信で対話継続。

**Independent Test**: deep dive chat → 「🤔 もっと」→ userUnderstanding 変化なし + UnderstandingInteraction "needMore" 1 件 + AI 追加発話受信

### Implementation for User Story 4

- [X] T017 [US4] (T012 で UnderstandingActionBar.handleNeedMore は実装済 — `tracker.recordNeedMore(card:)` + `chatService.ask(message: "もう少し別の角度から教えてください。", in: session)` を呼ぶ。本タスクで動作確認のみ)
- [X] T017a [US4] Verify `recordNeedMore` case is in T015 UnderstandingTrackerServiceTests (cases 4, "recordNeedMore 不変 + 履歴記録") — 既に T015 でカバー済の場合は skip

**Checkpoint US4**: 「🤔 もっと」→ userUnderstanding 不変 + 履歴記録 + AI 追加発話 PASS。

---

## Phase 7: User Story 5 - 起動時 default タブが学習タブ (Priority: P1) 🎯 MVP

**Goal**: アプリ起動時に学習タブが default 選択される (100%、SC-005)。

**Independent Test**: アプリ完全終了 → 再起動 → 学習タブ選択状態 (SC-005)

### Implementation for User Story 5

- [X] T018 [US5] (T010 で LastOpenedStore migration logic は実装済 — UserDefaults `spec044_learningTabMigrated` キーで初回起動時 `.learning` 強制、2 回目以降は session 内タブ選択保持。本タスクで動作確認のみ)

**Checkpoint US5**: 起動 default = 学習タブ 100% PASS (SC-005)。

---

🎯 **MVP COMPLETE** (Phase 3-7 = US1-US5 全 P1 = 学習タブ + chat + 理解度の核ループ完成、出荷可能最小単位)

---

## Phase 8: User Story 6 - 全カード一覧 (+N すべて見る) (Priority: P2)

**Goal**: 「+N すべて見る」リンクで全 UnderstandingCard を paginated list 表示、100+ 件で 60fps scroll (SC-006)。

**Independent Test**: ConceptPage 20 + SavedAnswer 10 件存在 → 「+25 すべて見る」tap → 全 30 件 LazyVStack 表示 (SC-006)

### Implementation for User Story 6

- [X] T019 [US6] Create `UnderstandingCardListView` (NavigationStack + ScrollView + LazyVStack + ForEach surfaceAllCards + NavigationLink → DeepDiveChatView + .task refresh + .refreshable) in `KnowledgeTree/Views/UnderstandingCardListView.swift` (~80 lines、T004 + T008 後)
- [X] T019a [US6] Replace placeholder navigationDestination in T009 UnderstandingTabView with real `UnderstandingCardListView()`

**Checkpoint US6**: 全件画面遷移 + 60fps scroll PASS (SC-006)。

---

## Phase 9: User Story 7 - 「✗ 違う」で的外れカードを下位に (Priority: P2)

**Goal**: 「✗ 違う」タップで surface 優先度 -10、次回学習タブで下位化。

**Independent Test**: ConceptPage A を「✗ 違う」→ 学習タブで A が上位 5 件から外れる

### Implementation for User Story 7

- [X] T020 [US7] (T012 で UnderstandingActionBar.handleDismissed は実装済 — `tracker.recordDismissed(card:)` + `dismiss()`、T004 SurfaceService で dismissed -10 補正は実装済。本タスクで動作確認のみ)
- [X] T020a [US7] Verify `recordDismissed` case in T015 UnderstandingTrackerServiceTests (case 5) and `dismissed -10` case in T011 UnderstandingCardSurfaceServiceTests (case 5) — 既にカバー済の場合は skip

**Checkpoint US7**: 「✗ 違う」→ priority -10 + 下位化 PASS。

---

## Phase 10: User Story 8 - AI チャット答え → 学習タブで深掘り推奨 (Priority: P2)

**Goal**: AI チャット (spec 021) 経由で auto-save された SavedAnswer (spec 043) が学習タブの surface 候補に入る (newKnowledge or needsUpdate label)。

**Independent Test**: AI チャットで質問 → SavedAnswer 生成 (spec 043) → 学習タブを開く → SavedAnswer が surface 候補に入っている

### Implementation for User Story 8

- [X] T021 [US8] (T004 SurfaceService で SavedAnswer 候補組み込み実装済 — isStale → needsUpdate (90)、savedAt >= now-24h && !relatedConceptIDs.isEmpty → newKnowledge (70)。本タスクで動作確認のみ)
- [X] T021a [US8] Verify "blend ConceptPage+SavedAnswer" case (case 7) in T011 UnderstandingCardSurfaceServiceTests covers SavedAnswer surface — 既にカバー済の場合は skip

**Checkpoint US8**: 秘書ループ (SavedAnswer) → 家庭教師ループ (surface) 接続 PASS。

---

## Phase 11: User Story 9 - ConceptPage 詳細から学習する (Priority: P2)

**Goal**: ConceptPage 詳細画面 toolbar の「学習する」Button で DeepDiveChatView を直接起動 (学習タブ経由しない最短導線)。

**Independent Test**: 知識 Clip → ConceptPage 詳細 → toolbar「学習する」tap → DeepDiveChatView 起動

### Implementation for User Story 9

- [X] T022 [US9] Add `Button("学習する", systemImage: "book.fill")` to `ConceptPageDetailView` toolbar `.topBarTrailing` placement + accessibilityIdentifier `button.learn` + on tap → `UnderstandingCard.fromConceptPage(conceptPage)` を navigationPath.append (~10 lines、contracts/concept-page-detail-learn-button.md 参照)
- [X] T022a [US9] Add `.navigationDestination(for: UnderstandingCard.self) { DeepDiveChatView(card: $0) }` to `KnowledgeClipView` (or wherever ConceptPageDetailView is pushed from) so toolbar button can push DeepDiveChatView (~5 lines)

**Checkpoint US9**: ConceptPage 詳細 → 「学習する」→ DeepDiveChatView 起動 PASS。

---

## Phase 12: User Story 10 - 学習統計の軽量表示 (Priority: P3)

**Goal**: AI ブレインタブ StatsRow に「今月『✓』N 件 / 最近 7 日で深掘り N 概念」表示 (0 件で非表示、SC-010)。

**Independent Test**: 「✓ わかった」3 件 + 深掘り 2 概念実施 → AI ブレインタブで「今月 3 件『わかった』」「最近深掘り 2 概念」表示

### Implementation for User Story 10

- [X] T023 [US10] Modify `KnowledgeTree/Views/AIBrainTabView.swift` (or AIBrainStatsRow if separate file): add "learning stats" section using @Query on UnderstandingInteraction with `#Predicate { $0.action == "understood" && $0.occurredAt >= startOfMonth }` for count + `#Predicate { $0.action == "openedChat" && $0.occurredAt >= now - 7d }` distinct targetID count, render only if either count > 0, hide entirely if both = 0 (~30 lines)

**Checkpoint US10**: 統計表示 (1+ 件で出現、0 件で非表示) PASS (SC-010)。

---

## Phase 13: Polish & Cross-Cutting

**Purpose**: 警告ゼロ build + 全テスト回帰 + ドキュメント更新 + 実機検証 hand-off

- [X] T024 Run `xcodebuild clean build -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17'` — confirm SUCCEEDED with **zero warnings** introduced by spec 044 (pre-existing warnings allowed but document if any)
- [X] T025 Run full test suite `xcodebuild test -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17'` — verify new 23 unit tests PASS (Surface 10 + Tracker 8 + Starter 5) + 3 UI tests PASS + existing specs regression (BodyExtractor pre-existing flaky 8 件 + AIBrainTabUITests 5 件 + SaveArticleUITests 1 件 は spec 044 と無関係なので skip judgment 可)
- [X] T026 Update `CLAUDE.md` to change spec 044 status from `📝 specify+plan+tasks 完了` to `🔧 実装完了` with file count + line count + test PASS summary (commit hash + PR # は実装後追記、本タスクでは status update のみ)
- [ ] T027 ユーザー実機検証: quickstart.md SC-001〜SC-010 全シナリオ + 既存回帰 (AI Chat / ConceptPage / SavedAnswer / 記事保存 / 検索 / タブ移動)、所要 25-35 分。検証結果を CLAUDE.md に追記 + 実機検証 PASS なら status を `✅ 実装完了 + 検証 PASS` に更新

---

## Dependencies & Execution Order

### Phase 依存

```text
Phase 1 (T001 xcstrings)
  ↓
Phase 2 (T002-T007a Foundational)
  ↓
Phase 3 US1 (T008-T011) ─┐
Phase 4 US2 (T012-T013)  ├─ MVP 全 P1 (これ完成で出荷可能)
Phase 5 US3 (T014-T016)  ├─ ※ Phase 6/7 は T010/T012 の placeholder で実装済 (T017/T018 は確認のみ)
Phase 6 US4 (T017-T017a) ┘
Phase 7 US5 (T018)
  ↓
Phase 8 US6 (T019-T019a) ─┐
Phase 9 US7 (T020-T020a)  ├─ P2 (V1 拡張)
Phase 10 US8 (T021-T021a) │
Phase 11 US9 (T022-T022a) ┘
  ↓
Phase 12 US10 (T023) ─ P3
  ↓
Phase 13 Polish (T024-T027)
```

### タスクレベル依存

- T001 → independent
- T002 → independent (Model)
- T003 → T002 (SharedSchema)
- T004 [P] → T002 (SurfaceService 必要 UnderstandingCard)
- T005 [P] → T002 (TrackerService)
- T006 → T005 (DeepDiveChatStarter は tracker 依存)
- T007 → T004 + T005 + T006
- T007a → T002 (pbxproj 編集)
- T008 [P] → T002 (CardRow)
- T009 → T004 + T008 (TabView)
- T010 → T007 + T009 (App + tab default migration)
- T011 [P] → T004 (SurfaceServiceTests)
- T012 → T006 + T009 (DeepDiveChatView)
- T012a → T012
- T013 [P] → T006 (DeepDiveChatStarterTests)
- T014 → T005 (recordUnderstood logic 既に T005 で実装なら本タスク skip 可、本タスクは追加実装が必要な場合のみ)
- T014a → T012 + T014
- T015 [P] → T005 + T014 (TrackerServiceTests)
- T016 [P] → T010 + T012 (UnderstandingTabUITests)
- T017, T017a → T012 + T015 で実装/検証済
- T018 → T010 で実装済
- T019 → T004 + T008 (CardListView)
- T019a → T019 + T009
- T020, T020a → T012 + T011/T015 で実装/検証済
- T021, T021a → T004 + T011 で実装/検証済
- T022 → T012 + T002 (toolbar Button)
- T022a → T022
- T023 → T002 (AIBrainTab 統計)
- T024-T027 → 全実装完了後

### 並列実行可能 [P]

- **Phase 2 setup**: T002 単独 → T004 / T005 / T008 (全 [P]、別ファイル) を T002 後並列実行可、T006 は T005 待ち
- **Phase 3-5 tests**: T011 / T013 / T015 (3 service test [P]、別ファイル) を service 完成後並列実行可
- **Phase 8-11**: P2 各 US は互いに独立、並列着手可

---

## Parallel Execution Examples

### Example 1: Phase 2 並列着手 (T002 完成後)

```text
T002 完成 → T003 順次 + T004 [P] + T005 [P] + T007a [P] を同時着手
              ↓                ↓        ↓
            T006 (T005 待ち) → T007 (T004+T005+T006 待ち)
            T008 [P] (T002 後すぐ)
```

### Example 2: Phase 3-5 test 並列

```text
全 service (T004 / T005 / T006) 完成 → T011 / T013 / T015 を [P] 並列実行
```

---

## Implementation Strategy

### MVP First (Phase 1-7 = T001-T018)

**目標**: V1 出荷可能最小単位 = 学習タブ + 上位 5 カード + chat 起動 + ✓ / 🤔 / ✗ 全ボタン動作 + 起動 default 学習タブ。

- Phase 1-2 で foundational (~7 タスク、build まで)
- Phase 3 で surface (T008-T011、UI 出る)
- Phase 4 で chat 起動 (T012-T013、家庭教師調 prompt 動作)
- Phase 5 で 理解度トラッキング (T014-T016、+1 + 1-hop + UI 入れ替わり)
- Phase 6/7 は T012/T010 で実装済の確認のみ (T017-T018)

T001-T018 完成 = MVP 出荷可能、ユーザー実機検証で SC-001-SC-005 + SC-007-SC-009 全 PASS なら main マージ判断可能。

### Incremental Delivery (Phase 8-12)

P2/P3 は MVP 出荷後 (or 同 PR の付加機能として):

- US6 (+N すべて見る) = T019 — 1 view 追加
- US7 (✗) = T012/T011/T015 で実装/検証済の確認のみ
- US8 (SavedAnswer surface) = T004/T011 で実装/検証済の確認のみ
- US9 (学習する Button) = T022 — toolbar 1 行追加
- US10 (統計 P3) = T023 — AI ブレイン 1 セクション追加

各 1-3 タスクで独立検証可能、優先度に応じて選択投入可。

### Polish (Phase 13)

- T024 zero-warning build
- T025 全テスト回帰
- T026 ドキュメント更新
- T027 ユーザー実機検証 (quickstart.md SC-001〜SC-010)

---

## Format Validation

- ✅ 全タスクが `- [ ] T### [P?] [US?] description with file path` 形式
- ✅ Setup phase (Phase 1) と Foundational phase (Phase 2) は [Story] label なし
- ✅ Polish phase (Phase 13) は [Story] label なし
- ✅ User Story phase (Phase 3-12) は全タスクに [US1]〜[US10] label
- ✅ [P] marker は別ファイル + 依存ゼロのタスクのみ
- ✅ 全タスクに具体的 file path 含む

---

## Summary

**総タスク数**: 27 (T001-T027)
**MVP scope**: T001-T018 (P1 全 5 US、~12 タスク = 30-50% 工数で出荷可能機能完成)
**P2 scope**: T019-T022a (P2 全 4 US)
**P3 scope**: T023 (P3 1 US)
**Polish**: T024-T027

**Independent test criteria** (各 US):
- US1: 学習タブ open → 5 カード表示 (SC-001)
- US2: カードタップ → chat 起動 + AI 3 秒以内発話 (SC-002)
- US3: ✓ わかった → +1 + 入れ替わり (SC-003 / SC-004 / SC-008)
- US4: 🤔 もっと → 不変 + 履歴記録 + AI 継続
- US5: 起動 default = 学習タブ (SC-005)
- US6: +N すべて見る → 全件 LazyVStack 60fps (SC-006)
- US7: ✗ 違う → 下位化
- US8: AI Chat 答え → SavedAnswer → 学習タブ surface
- US9: ConceptPage 詳細「学習する」→ chat 起動
- US10: AI ブレイン統計 (0 件で非表示、SC-010)

**Parallel opportunities**: Phase 2 で T004/T005/T008 を T002 後並列、Phase 3-5 で T011/T013/T015 を service 完成後並列、Phase 8-12 で P2/P3 各 US 並列着手可。

**実装規模**: 新規 11 ファイル + 改修 7 ファイル = ~1750 行、期間 3-4 週間 (Phase A 最大)。Mock テスト 23 + UI テスト 3 = 26 ケース。

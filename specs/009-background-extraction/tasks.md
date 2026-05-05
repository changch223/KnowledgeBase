---

description: "Task list for spec 009 - バックグラウンド AI 抽出継続 (BGTaskScheduler + incremental save)"
---

# Tasks: バックグラウンド AI 抽出継続

**Input**: Design documents from `/specs/009-background-extraction/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: 含む。Mock LanguageModelSession + in-memory ModelContainer + BGTask 手動 trigger。

## Path Conventions

- iOS app: `KnowledgeTree/{Models,Services,Views,Localization}/` + `KnowledgeTreeTests/`

---

## Phase 1: Setup

- [X] T001 spec 006-008 が main の最新ビルドに含まれていることを確認
- [X] T002 [P] 既存テスト全 pass を `xcodebuild test` で確認

---

## Phase 2: Foundational (Blocking Prerequisites)

**目的**: 新 @Model + 既存 Generable type の Codable 化 + Schema migration の前提整備

- [X] T003 `KnowledgeTree/Models/KnowledgeChunkProgress.swift` を新規作成 (data-model.md 1.1)
- [X] T004 `KnowledgeTree/Models/BackgroundExtractionQueueEntry.swift` を新規作成 (data-model.md 1.2)
- [X] T005 `KnowledgeTree/Models/ExtractedKnowledge.swift` に `chunkProgress: [KnowledgeChunkProgress]` relationship 追加 (cascade delete inverse)
- [X] T006 [P] `KnowledgeTree/Services/LanguageModelSessionProtocol.swift` の Generable types (`ExtractedKnowledgeOutput` / `KeyFactOutput` / `KnowledgeEntityOutput` / `FactType` / `EntityType`) に Codable 準拠を追加 (research.md R3)
- [X] T007 `KnowledgeTree/SharedSchema.swift` の Schema.all に `KnowledgeChunkProgress.self`, `BackgroundExtractionQueueEntry.self` を追加
- [X] T008 [P] `KnowledgeTreeShareExtension` target に `KnowledgeChunkProgress.swift`, `BackgroundExtractionQueueEntry.swift` の membership を Ruby script で追加 (spec 008 と同パターン)
- [X] T009 `KnowledgeTree/Info.plist` に `BGTaskSchedulerPermittedIdentifiers` 配列追加: `["app.KnowledgeTree.chunkedKnowledgeExtraction"]`

**Checkpoint**: schema migration が走り、新 entity 永続化 + relationship 追加が動作

---

## Phase 3: ChunkProgressStore + incremental save (US1 / US2 基盤)

**Goal**: chunked extraction の各 chunk 完了で `KnowledgeChunkProgress` に保存、リジューム時に既完了 chunks を skip。

### Tests

- [X] T010 [P] `KnowledgeTreeTests/ChunkProgressStoreTests.swift` を新規作成: 7 ケース (add / upsert / fetchAll sort / cleanup / corrupted JSON / addAfterCleanup / 空 knowledge)

### Implementation

- [X] T011 [P] `KnowledgeTree/Services/ChunkProgressStore.swift` を新規作成: `ChunkProgressStoreProtocol` + `SwiftDataChunkProgressStore` + `NoopChunkProgressStore` (contracts/chunk-progress-store.md)
- [X] T012 [US1/US2] `KnowledgeTree/Services/KnowledgeExtractionService.swift` の `performChunkedExtraction` を incremental save / resume 化 (contracts/knowledge-extraction-service.md)
   - init に `chunkProgressStore: ChunkProgressStoreProtocol = NoopChunkProgressStore()` を追加 (default で後方互換)
   - 開始時に `chunkProgressStore.fetchAll(knowledge:)` で既完了 chunks 取得
   - 各 chunk 完了直後に `chunkProgressStore.add` を呼ぶ
   - 完了時 (succeeded / partial / failed) に `chunkProgressStore.cleanup` を呼ぶ
- [X] T013 [P] [US2] `KnowledgeTreeTests/KnowledgeExtractionServiceTests.swift` に incremental resume case を 5 件追加
   - resume 3 chunks completed → chunks 4-N + meta only
   - 各 chunk 完了で chunkProgressStore.add 呼ばれる
   - 完了で cleanup 呼ばれる
   - .failed 完了でも cleanup
   - 中断時は cleanup されない (中間 progress 保持)
- [X] T014 `KnowledgeTreeApp.bootstrap` で `SwiftDataChunkProgressStore` を inject

**Checkpoint**: 中断 → 再起動 → backfill で incremental resume が動作 (BGTask なくても spec 008 fallback で完了する)

---

## Phase 4: Background queue + Scheduler + Runner (US1 / US3 / US4)

**Goal**: BGTask の register / submit / handle で article を順次処理。

### Tests

- [X] T015 [P] `KnowledgeTreeTests/BackgroundExtractionRunnerTests.swift` を新規作成: 6 ケース (deletedArticle / validArticle / succeededReturnsTrue / extractingReturnsFalse / cancelStopsTask / resumeFromIncrementalProgress)

### Implementation

- [X] T016 [P] `KnowledgeTree/Services/BackgroundExtractionQueue.swift` を新規作成: `enqueue / dequeueOldest / fetchOldest / remove(articleID:)` API (data-model.md 1.2 + 不変条件)
- [X] T017 [P] `KnowledgeTree/Services/BackgroundExtractionRunner.swift` を新規作成 (contracts/background-runner.md): `run(articleID:) -> Bool` + `cancelCurrent()`
- [X] T018 `KnowledgeTree/Services/BackgroundExtractionScheduler.swift` を新規作成 (contracts/background-scheduler.md): singleton + `registerHandler` + `scheduleBGTaskIfNeeded` + `handleTask` + `cancelPending`
- [X] T019 `KnowledgeTreeApp.init()` で `BackgroundExtractionScheduler.shared.registerHandler()` を呼ぶ (research.md R7、launch 最早タイミングで register)
- [X] T020 `KnowledgeTreeApp.bootstrap` で scheduler に runnerProvider / queueProvider を inject
- [X] T021 `KnowledgeExtractionService.performChunkedExtraction` の chunked パス開始時に `queue.enqueue(articleID)` を呼ぶ
- [X] T022 [US1] `ArticleListView` / `ArticleDetailView` の `.onChange(of: scenePhase)` で `.background` 検知時に `scheduler.scheduleBGTaskIfNeeded()` を呼ぶ
- [X] T023 [US1] chunked 完了時 (.succeeded / .partiallySucceeded / .failed) に `queue.remove(articleID:)` を呼ぶ

**Checkpoint**: 手動 BGTask trigger (`_simulateLaunchForTaskWithIdentifier:`) で background 経路が動作

---

## Phase 5: Detail UI 「待機中」表示 (US4)

**Goal**: BGTask 予約済 article の Detail に「バックグラウンドで処理待ち (X/N)」 + 「今すぐ実行」ボタン。

- [X] T024 [P] [US4] `KnowledgeTree/Localization/Localizable.xcstrings` に `detail.knowledge.queuedForBackground` (例: "バックグラウンドで処理待ち (%lld/%lld 完了)") 追加
- [X] T025 [US4] `ArticleDetailView` の `knowledgePlaceholder(status:)` で status `.extracting` のとき queue に該当 article がある場合の分岐を追加: 「バックグラウンドで処理待ち (X/N 完了)」表示 + 既存 retry ボタン (= 「今すぐ実行」)
- [X] T026 `ArticleDetailView` から `BackgroundExtractionQueue` を観察するために `Environment` で inject (Service 経由でも可)

**Checkpoint**: Detail 画面で「待機中」表示が出る

---

## Phase 6: Edge Cases

- [X] T027 [P] queue 内の article が削除済の場合の skip ロジック (T018 内で実装、T015 テストで検証)
- [X] T028 [P] Apple Intelligence OFF で BGTask 起動 → `.skipped` 保存 → queue から remove (T012 / T017 内)
- [X] T029 [P] BGTask 時間切れ (expirationHandler) → cancel + reEnqueue + scheduleNext (T018 内)
- [X] T030 spec 008 の stale state 自動回復 (`fetchPendingArticles` での `.extracting` pickup) が引き続き動作することを確認 (回帰テスト)

---

## Phase 7: Polish

- [X] T031 [P] 全 spec 001-009 テスト pass 確認 (`xcodebuild test`)
- [X] T032 [P] specs/009-background-extraction/quickstart.md の S1〜S8 を実機で実行 (BGTask 手動 trigger 含む)
- [X] T033 [P] 実機検証: BGTask 内の Foundation Models 呼び出しが動作することを最優先確認 (research.md R2 risk)
   - 動かない場合は spec を縮小 (BGTask 内では incremental save の reconciliation のみ、LM 呼び出しは前景に戻ったときに実行) に方向転換
- [X] T034 [P] Console ログ確認:
   - 「BGTask handler invoked」「knowledge chunked resume: alreadyCompleted=N」
   - LM 呼び出し回数が完了 chunks 数のみ (重複なし)
- [X] T035 git commit + push + PR description 更新

---

## Dependencies & Execution Order

### Phase 依存

- **Phase 1**: 即着手
- **Phase 2 (Foundational)**: T003 → T005 / T007 (T003 後)、T004 / T006 並列、T008 / T009 独立で並列
- **Phase 3 (US1/US2 incremental)**: Phase 2 完了後。T010 → T011 → T012 → T013 → T014
- **Phase 4 (BGTask 基盤)**: Phase 3 完了後 (T012 の incremental が前提)。T015 → T016, T017 並列 → T018 → T019 → T020 → T021, T022, T023
- **Phase 5 (UI)**: Phase 4 完了後 (queue 実装が前提)
- **Phase 6 (Edge)**: Phase 4-5 完了後
- **Phase 7 (Polish)**: 全完了後

### MVP 路線 (US1+US2 で BGTask 抜きの incremental resume だけリリース)

1. Phase 1-3 → ここまでで spec 008 fallback 経路で incremental resume が動作 (BGTask なしでも記事完成)
2. **STOP & VALIDATE**: 中断 → 再起動 → resume が動くことを確認
3. その後 Phase 4-7 で BGTask 自動化を追加

---

## Parallel Example: Phase 2

```bash
Task: "KnowledgeChunkProgress.swift 新規"            # T003
Task: "BackgroundExtractionQueueEntry.swift 新規"    # T004
Task: "Generable types Codable 化"                   # T006
Task: "Info.plist 更新"                              # T009
```

---

## Notes

- spec 005 の RefreshTrigger / @Bindable パターン継承
- spec 006 chunked パス内部実装は変更だが、外部 API 後方互換
- spec 008 stale state 自動回復はフォールバックとして残す
- BGTask の実機 dispatch は CI で検証不可、quickstart S3-S5 で手動 trigger
- research.md R2 risk: 実機で BGTask 内 Foundation Models が動作しない場合の spec 縮小方針を T033 で確認

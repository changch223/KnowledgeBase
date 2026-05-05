---

description: "Task list for spec 006 - 長文記事の Chunked Summarization"
---

# Tasks: 長文記事の Chunked Summarization

**Input**: Design documents from `/specs/006-chunked-summarize/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: 含む。spec 005 で導入済の Swift Testing パターンを継承。

**Organization**: ユーザーストーリーごとにグループ化。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 別ファイル / 依存なし → 並列可能
- **[Story]**: US1 / US2 / US3 のいずれか
- ファイルパスは絶対指定

## Path Conventions

- iOS app structure: `KnowledgeTree/{Models,Services,Views,Localization}/` + `KnowledgeTreeTests/`
- spec 005 で確立した Apple Foundation Models / SwiftData / SwiftUI パターン継承

---

## Phase 1: Setup (Shared Infrastructure)

**目的**: spec 006 実装に必要な準備。spec 005 が既に main の MVP インフラを整えているため、追加 setup は最小限。

- [X] T0\1 git ブランチ確認 (`006-chunked-summarize` 上で作業) と spec 001-005 の commit が main に取り込まれていることを `git log` で確認
- [X] T0\1 [P] Xcode で `KnowledgeTree.xcodeproj` を開いてビルド成功 (spec 005 の状態)、`xcodebuild test` で既存 56 ケース全 pass を確認

---

## Phase 2: Foundational (Blocking Prerequisites)

**目的**: 全 US が依存する `ExtractedKnowledge` schema 拡張と `ProcessingMonitor` API 拡張。

**⚠️ CRITICAL**: ここを完了させないと US1 / US2 / US3 のいずれも実装できない

- [X] T0\1 `KnowledgeTree/Models/ExtractedKnowledge.swift` に新規列 3 つを追加: `chunkProcessedCount: Int = 1`, `chunkTotalCount: Int = 1`, `skippedTailChars: Int = 0` (init にも引数追加、default 値で既存呼び出し互換)
- [X] T0\1 [P] `KnowledgeTree/Services/ProcessingMonitor.swift` の `ActiveTask` 構造体に optional `progressIndex: Int? = nil` / `progressTotal: Int? = nil` を追加。`start(_:articleID:title:progressIndex:progressTotal:)` overload と `updateProgress(articleID:index:)` メソッドを追加
- [X] T0\1 [P] `KnowledgeTree/Services/ArticleKnowledgeStore.swift` の `upsertSucceeded` / `upsertFailure` に新引数 `chunkProcessedCount: Int = 1, chunkTotalCount: Int = 1, skippedTailChars: Int = 0` を追加。SwiftData `ExtractedKnowledge` への書き込みで新列を反映
- [X] T0\1 schema migration テスト: in-memory ModelContainer で既存 schema のレコードを新 schema で読み込み、default 値が入ることを `KnowledgeTreeTests/SwiftDataArticleKnowledgeStoreTests.swift` の新ケースで確認

**Checkpoint**: Foundation ready - US1 / US2 / US3 を並列着手可能

---

## Phase 3: User Story 1 - 長文記事を context window エラー無しで要約 (P1) 🎯 MVP

**Goal**: 1000 文字超の本文を chunk 分割 → 各 chunk + meta-summary 生成 → 統合保存。短文は従来単発パスを維持。

**Independent Test**: 5000 文字の Mock 本文を持つ Article で `KnowledgeExtractionService.extract(article:)` を呼び、ExtractedKnowledge.essence が後半内容も含むこと、`chunkProcessedCount = 6, chunkTotalCount = 6` が記録されることを Mock LanguageModelSession で確認。

### Tests for User Story 1 ⚠️

> **NOTE: テストファースト。実装前に FAIL を確認**

- [X] T0\1 [P] [US1] `KnowledgeTreeTests/ChunkSplitterTests.swift` を新規作成。10 ケース (空 / 1 文字 / 999 / 1000 / 1001 / 5000 / 10000 / 10001 / 15000 / 句点なし) で contracts/chunk-splitter.md の不変条件を assert
- [X] T0\1 [P] [US1] `KnowledgeTreeTests/ChunkedKnowledgeAggregatorTests.swift` を新規作成。11 ケース (全失敗 / 1 chunk + meta 成功 / 3 chunk + meta 失敗 / keyFacts 重複排除 / 空白違い / case-insensitive entities / salience max / type 多数決 / type 同票 tiebreak / 空 results / meta only)
- [X] T0\1 [P] [US1] `KnowledgeTreeTests/KnowledgeExtractorTests.swift` に 7 ケース追加: extractFromChunk 正常 / extractFromChunk error / extractMetaSummary 正常 / extractMetaSummary 失敗 / extractMetaSummary 空入力 / buildMetaSummaryPrompt 内容 / buildMetaSummaryPrompt は本文を含まない
- [X] T0\1 [US1] `KnowledgeTreeTests/KnowledgeExtractionServiceTests.swift` に 7 chunked 経路ケース追加: long text 分割 / 全 chunk 成功保存 / 1 chunk 失敗 partial / 全 chunk 失敗 .failed / meta 失敗 partial / monitor progress 更新 / 15000 文字 tail truncate

### Implementation for User Story 1

- [X] T0\1 [P] [US1] `KnowledgeTree/Services/ChunkSplitter.swift` を新規作成。contracts/chunk-splitter.md の API + 不変条件を実装。`Chunk` struct も同ファイル内
- [X] T0\1 [P] [US1] `KnowledgeTree/Services/ChunkedKnowledgeAggregator.swift` を新規作成。contracts/chunked-aggregator.md の `merge(results:metaSummary:) -> AggregatedKnowledge` を実装。`AggregatedKnowledge` / `ChunkResult` struct も同ファイル
- [X] T0\1 [US1] `KnowledgeTree/Services/KnowledgeExtractor.swift` を拡張: `defaultMaxBodyChars` を 1200 → 1000 に変更、`extractFromChunk(_:)` / `extractMetaSummary(chunkEssences:)` / `buildMetaSummaryPrompt(chunkEssences:)` を追加。既存 `extract(extractedText:)` の挙動は変更なし (T011, T012 完了後)
- [X] T0\1 [US1] `KnowledgeTree/Services/KnowledgeExtractionService.swift` の `extract(article:)` 内に chunked パス分岐を追加: `text.count <= 1000` なら従来単発、`> 1000` なら ChunkSplitter → 逐次 extractFromChunk → ChunkedKnowledgeAggregator.merge → upsert (T013 + T011 + T012 + T005 完了後)
- [X] T0\1 [US1] chunked パス内で `Task.isCancelled` チェックを各 chunk 開始前に追加 (cancelAll() 呼び出し時に途中 chunk を skip できるように)

**Checkpoint**: US1 単独で動作確認可能。長文記事を context window エラー無しで要約。

---

## Phase 4: User Story 2 - chunk 進捗の可視化 (P2)

**Goal**: BottomStatusBar に N/M 進捗表示、Detail 開きっぱなしで段階的更新。

**Independent Test**: Mock 5000 文字記事の knowledge 抽出を開始し、ProcessingMonitor.current の progressIndex/Total が 0/6 → 1/6 → ... → 6/6 と更新されることを `MockProcessingMonitor` 等で確認。

### Tests for User Story 2 ⚠️

- [X] T0\1 [P] [US2] `KnowledgeTreeTests/KnowledgeExtractionServiceTests.swift` に「extractUpdatesMonitorProgressOnEachChunk」ケースを追加 (Mock monitor の updateProgress 呼び出し回数と引数を verify)
- [X] T0\1 [P] [US2] `KnowledgeTreeTests/ProcessingMonitorTests.swift` を新規作成: ActiveTask の progressIndex/Total optional 動作 / start で初期 progress 設定 / updateProgress で値更新 / finish で削除

### Implementation for User Story 2

- [X] T0\1 [US2] `KnowledgeTree/Services/KnowledgeExtractionService.swift` の chunked パス内で各 chunk 完了後に `monitor.updateProgress(articleID:index:)` を呼ぶ (T014 を拡張)
- [X] T0\1 [P] [US2] `KnowledgeTree/Views/BottomStatusBar.swift` の表示分岐を変更: `current.progressIndex != nil && current.progressTotal != nil` なら "知識抽出中 N/M"、両 nil なら従来 "知識抽出中"
- [X] T0\1 [P] [US2] `KnowledgeTree/Localization/Localizable.xcstrings` に `status.phase.knowledgeProgress` (例: "知識抽出中 %lld/%lld") を追加。BottomStatusBar から `String(localized:)` 経由で参照
- [X] T0\1 [US2] 単発パスの monitor.start 呼び出しは progressIndex/Total を渡さない (デフォルト nil) ことを T014 で保証

**Checkpoint**: US1 + US2 動作。長文記事処理中に N/M 進捗表示。

---

## Phase 5: User Story 3 - chunk の部分的失敗に強い (P3)

**Goal**: 1-2 chunk 失敗時に partial succeeded で保存、UI に表示。

**Independent Test**: Mock LanguageModelSession で 5 chunk 中 chunk 3 のみ throw させ、ExtractedKnowledge.status == `.partiallySucceeded` で残り 4 chunk の情報が保存されることを確認。

### Tests for User Story 3 ⚠️

- [X] T0\1 [P] [US3] `KnowledgeExtractionServiceTests.swift` に「extractWithLongTextOneChunkFailsMarksPartiallySucceeded」「extractWithLongTextAllChunksFailMarksFailed」「extractWithLongTextMetaSummaryFailsMarksPartiallySucceeded」3 ケース追加 (T010 と統合可)

### Implementation for User Story 3

- [X] T0\1 [US3] `ChunkedKnowledgeAggregator.determineStatus()` ロジック実装 (T012 で完成済の場合は確認のみ): successfulChunkCount 0 → .failed、>0 + meta 成功 → .succeeded、>0 + meta 失敗 → .partiallySucceeded
- [X] T0\1 [US3] meta-summary 失敗時の fallback 実装 (T012 で完成済の場合は確認のみ): essence = 最初の成功 chunk の essence、summary = 各成功 chunk の essence の改行連結 (300 文字 truncate)
- [X] T0\1 [US3] Service の chunked パスで全失敗時 `store.upsertFailure(article:reason: "全 N chunk 失敗")` を呼ぶ。partial / 成功時は `store.upsertSucceeded(article:status: aggregated.determineStatus(), output: aggregated.toOutput(), ...)`
- [X] T0\1 [US3] Detail 画面 (`KnowledgeTree/Views/ArticleDetailView.swift`) の knowledge 失敗時表示で、failureReason に「全 N chunk 失敗」のような文字列が出ることを確認 (spec 005 既存 UI 流用、変更不要のはず)

**Checkpoint**: US1 + US2 + US3 動作。長文記事の partial success が UI で確認可能。

---

## Phase 6: Edge Case - 超長文 (10001 文字以上) の tail truncation 表示

**Goal**: skippedTailChars > 0 の Detail 画面に「※ 本文が長いため冒頭 10000 文字のみを要約対象としています」注記表示。

- [X] T0\1 [P] `KnowledgeTree/Localization/Localizable.xcstrings` に `detail.knowledge.truncatedTailNotice` を追加
- [X] T0\1 [P] `KnowledgeTree/Views/ArticleDetailView.swift` の knowledge セクションで `article.extractedKnowledge?.skippedTailChars > 0` なら注記を表示する分岐を追加
- [X] T0\1 `KnowledgeTreeTests/KnowledgeExtractionServiceTests.swift` の T010 に「extractWith15000CharsTruncatesTailAndRecordsSkipped」ケース追加 (skippedTailChars = 5000 を確認)

---

## Phase 7: Polish & Cross-Cutting Concerns

**目的**: コード品質 / ドキュメント / quickstart 検証

- [X] T0\1 [P] `xcodebuild test` で全 spec 001-006 テスト全 pass を確認 (回帰なし、spec 004 既存 9 ケースが無修正で pass する後方互換)
- [X] T0\1 [P] specs/006-chunked-summarize/quickstart.md の S1〜S7 を実機で実行 (Apple Intelligence 対応端末)
- [X] T0\1 [P] Console ログで `truncating body for ...` が同 URL で 1 回のみ出ること (重複抑止確認、spec 005 ガード継承)
- [X] T0\1 spec 005 の live update が chunked パスでも機能することを実機 S7 で確認 (写真切替問題が再発しない)
- [X] T0\1 git commit (`/speckit-git-commit` or 手動) → push → PR description に quickstart 結果と test 結果を記載

---

## Dependencies & Execution Order

### Phase 依存

- **Phase 1 (Setup)**: 即着手可 (依存なし)
- **Phase 2 (Foundational)**: T003 → T004, T005 (並列), T006 は T003 後
- **Phase 3 (US1)**: Phase 2 完了後着手。T007-T010 (テスト並列) → T011, T012 (実装並列) → T013 → T014, T015 (順序依存)
- **Phase 4 (US2)**: Phase 3 完了後着手 (実用上、UI と一緒に実装したいが論理依存はない)。T016, T017 → T018 → T019, T020, T021
- **Phase 5 (US3)**: Phase 3 完了後着手 (US1 の Service 拡張に依存)。T022 → T023, T024 → T025 → T026
- **Phase 6 (Edge case)**: Phase 5 完了後 (skippedTailChars 列が必要)
- **Phase 7 (Polish)**: 全 Phase 完了後

### User Story 並列性

- US1 (P1) は MVP。単独で完結
- US2 (P2) は US1 完了後にプラスの UX 改善
- US3 (P3) は US1 完了後にプラスの partial success 対応
- US2 / US3 は並行で実装可能 (異なる files、Service 内分岐のみ衝突要注意)

---

## Implementation Strategy

### MVP 路線 (US1 Only)

1. Phase 1 → Phase 2 (foundational)
2. Phase 3 (US1) — テスト先 → 実装 → integration
3. **STOP & VALIDATE**: 5000 / 10000 文字記事を実機保存して essence + summary が後半含むこと確認
4. Demo 可能な状態

### Incremental Delivery

1. MVP (US1) merge → 動作確認 → ユーザーリリース
2. US2 (進捗表示) merge → 長時間処理 UX 改善
3. US3 (partial success) merge → 信頼性向上
4. 最後に Phase 6 (tail truncation 注記) と Phase 7 (polish)

### Parallel Team Strategy

- Developer A: Phase 1 + 2
- Developer A: Phase 3 (US1)
- Developer A: Phase 4 (US2) と Developer B: Phase 5 (US3) を並行着手 (Phase 3 完了後)
- 両者 Phase 6 + 7 で合流

---

## Parallel Example: User Story 1 テスト群

```bash
# Phase 3 のテスト群を並列実装可能 (異なるファイル):
Task: "ChunkSplitterTests.swift 新規作成"     # T007
Task: "ChunkedKnowledgeAggregatorTests.swift 新規作成"  # T008
Task: "KnowledgeExtractorTests.swift 拡張"    # T009
```

```bash
# 実装も並列可能:
Task: "ChunkSplitter.swift 実装"               # T011
Task: "ChunkedKnowledgeAggregator.swift 実装"  # T012
```

---

## Notes

- [P] tasks = 別ファイル + 無依存
- spec 004 の既存 KnowledgeExtractor / Service / Store の API 後方互換が大原則 (既存呼び出しを破壊しない)
- spec 005 の RefreshTrigger / ProcessingMonitor / ServiceContainer / 重複抑止ガード はそのまま継承
- chunked パスの session 呼び出しは逐次 (並列禁止、research.md R4)
- spec 006 完了後、長文 zenn / atmarkit / IT メディア記事で動作確認できる
- 実機で `exceededContextWindowSize` が出ないこと、Console ログに「truncating body」が単発パス (1000 文字以下) のみで出ること

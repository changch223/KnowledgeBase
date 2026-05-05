---

description: "Task list for spec 010 - 階層的 chunked summarization (超長文 30000 文字対応)"
---

# Tasks: 階層的 chunked summarization

**Input**: Design documents from `/specs/010-hierarchical-summary/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: 含む。Mock LanguageModelSession で 階層的呼び出し回数 / 集約ロジック / 失敗パスを検証。

## Path Conventions

- iOS app: `KnowledgeTree/{Models,Services,Views,Localization}/` + `KnowledgeTreeTests/`

---

## Phase 1: Setup

- [X] T001 spec 006-009 が main の最新 commit に含まれていることを確認
- [X] T002 [P] 既存テスト全 pass を確認

---

## Phase 2: Foundational (Blocking)

- [X] T003 `KnowledgeTree/Services/KnowledgeExtractionService.swift` の `maxChunks` default を 10 → 30 に変更 (init 引数の default 値のみ、外部 API 不変)
- [X] T004 [P] `KnowledgeTree/Localization/Localizable.xcstrings` の `detail.knowledge.truncatedTailNotice` を「冒頭 10000 文字」→「冒頭 30000 文字」に更新

**Checkpoint**: chunks 上限拡大、注記文言更新

---

## Phase 3: HierarchicalChunkedSummarizer (純粋関数群)

### Tests

- [X] T005 [P] `KnowledgeTreeTests/HierarchicalChunkedSummarizerTests.swift` を新規作成: 8 ケース
  - 空配列は空配列
  - 18 items を 10 ずつ → [10, 8]
  - 30 items を 10 ずつ → [10, 10, 10]
  - groupSize=1 で 5 items → 5 単要素
  - Mock extractor で 2 groups 順次処理
  - 1 group 失敗で result.output == nil
  - 全 intermediate 失敗で final nil
  - Task.isCancelled で中断

### Implementation

- [X] T006 [P] `KnowledgeTree/Services/HierarchicalChunkedSummarizer.swift` を新規作成 (contracts/hierarchical-summarizer.md):
  - `makeGroups(_:groupSize:) -> [[T]]`
  - `runIntermediateMetaSummaries(groups:extractor:progressCallback:) -> [IntermediateMetaResult]`
  - `runFinalMetaSummary(intermediateResults:extractor:) -> ExtractedKnowledgeOutput?`
  - `IntermediateMetaResult` struct も同ファイル

**Checkpoint**: 純粋関数 unit test pass

---

## Phase 4: ChunkedKnowledgeAggregator.mergeHierarchical

### Tests

- [X] T007 [P] `KnowledgeTreeTests/ChunkedKnowledgeAggregatorTests.swift` に階層化 5 ケース追加 (既存 9 ケース無修正で pass を維持):
  - 全成功で .succeeded、essence は lvl3 値
  - lvl3 失敗 + lvl2 1+ 成功 → .partiallySucceeded、lvl2 連結 fallback
  - lvl2 全失敗 → .partiallySucceeded、lvl1 連結 fallback
  - lvl1 全失敗 → .failed
  - keyFacts / entities が lvl1 から重複排除統合される (lvl2/lvl3 から生成しない)

### Implementation

- [X] T008 `KnowledgeTree/Services/ChunkedKnowledgeAggregator.swift` に `mergeHierarchical(lvl1Results:lvl2Results:lvl3Result:) -> AggregatedKnowledge` を追加 (contracts/knowledge-extraction-service.md `mergeHierarchical` セクション)
  - 既存 `merge(results:metaSummary:)` は無変更 (spec 006 後方互換)
  - 内部で既存 `mergeKeyFacts` / `mergeEntities` private helper を流用

**Checkpoint**: 階層集約ロジック単体テスト pass + 既存 9 ケース無修正で pass

---

## Phase 5: Service 階層化分岐

### Tests

- [X] T009 [P] `KnowledgeTreeTests/KnowledgeExtractionServiceTests.swift` に 7 ケース追加 (既存無修正で pass を維持):
  - chunks 5 個は spec 006 単一 meta パス (lvl2 呼ばれない)
  - chunks 18 個は階層パス、lvl2 = 2 groups
  - chunks 30 個は lvl2 = 3 groups
  - lvl2 1 つ失敗 + lvl3 成功 → .succeeded
  - lvl2 全失敗 → .partiallySucceeded
  - lvl3 失敗 + lvl2 partial → .partiallySucceeded
  - incremental: 12 lvl1 完了済 → 残り 6 lvl1 + 2 lvl2 + 1 lvl3 のみ

### Implementation

- [X] T010 `KnowledgeTree/Services/KnowledgeExtractionService.swift` の `performChunkedExtraction` に階層化分岐を追加 (contracts/knowledge-extraction-service.md):
  - `useHierarchical = chunks.count > 10`
  - lvl1 chunks 処理 (spec 009 incremental save 既存)
  - useHierarchical 時のみ HierarchicalChunkedSummarizer.runIntermediateMetaSummaries → runFinalMetaSummary → mergeHierarchical
  - useHierarchical false なら既存パス (merge + extractMetaSummary)
  - chunkTotalCount = lvl1 + lvl2GroupCount + 1 (useHierarchical) or lvl1 + 1 (non-hier)
  - chunkProcessedCount = 全成功 LM 呼び出し数
- [X] T011 progressMonitor の updateProgress を lvl1 / lvl2 / lvl3 ごとに呼ぶ

**Checkpoint**: 階層パス + 後方互換両方 pass、spec 006 / 008 / 009 既存テスト全 pass

---

## Phase 6: Polish

- [X] T012 [P] 全 spec 001-010 テスト pass 確認
- [X] T013 [P] specs/010-hierarchical-summary/quickstart.md の S1〜S6 を実機で実行
- [X] T014 [P] 18,000 文字記事 / 30,000 文字記事の実機ベンチマーク (Console ログで lvl1/lvl2/lvl3 各層の所要時間記録)
- [X] T015 git commit + push + PR description 更新

---

## Dependencies & Execution Order

- Phase 1 (Setup): 即着手
- Phase 2 (Foundational): T003, T004 並列
- Phase 3 (Summarizer): Phase 2 後。T005 → T006
- Phase 4 (Aggregator): Phase 3 後 (Aggregator は Summarizer の result を受け取る)。T007 → T008
- Phase 5 (Service): Phase 4 後。T009 → T010 → T011
- Phase 6 (Polish): 全完了後

## MVP 路線

1. Phase 1-3: HierarchicalChunkedSummarizer 単体実装 + テスト
2. Phase 4: Aggregator 拡張
3. Phase 5: Service 統合 + 既存テスト pass 維持
4. **STOP & VALIDATE**: 18,000 文字記事の実機検証
5. Phase 6 で polish + 30,000 文字テスト

## Notes

- spec 006 の chunked パス挙動は厳密に維持 (chunks ≤ 10 で階層化されない)
- spec 009 の `KnowledgeChunkProgress` は lvl1 chunks のみ対象、lvl2/lvl3 は失敗時再生成
- spec 008 の RefreshTrigger / @Bindable パターンは継承
- 階層 prompt の細かいチューニングは将来 spec 候補

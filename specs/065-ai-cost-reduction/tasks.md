# Tasks: AI 処理削減 (軽さ優先)

**Branch**: `064-wiki-links-discovery` (継続) | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

最小変更 (改修 2 ファイル、新規ゼロ)。@Model 削除なし。

## Phase 1: 記事保存の軽量化 (US1)
- [x] **T001 [US1]** `Services/ConflictDetectionService.swift`: topEntityCount 2→1 / comparisonLimit 5→1 (矛盾検出 AI 最大 10→1 回)
- [x] **T002 [US1]** `KnowledgeTreeApp.swift`: DefaultKnowledgeExtractionService の `graphExtractionService: graphExtractionService` → `nil` (graph 抽出 hook 停止、既存ノード保持)

## Phase 2: 起動の軽量化 (US2)
- [x] **T003 [US2]** `KnowledgeTreeApp.swift` runStartupBackfills: `async let digestRegeneration` / `topicClustering` を削除 + await tuple から除外 (起動時一括生成停止、オンデマンドは維持)

## Phase 3: 検証
- [x] **T004** clean build (iPhone 17 Simulator)
- [x] **T005** 全 unit test serial regression PASS (ConflictDetection / GraphExtraction / 既存全 suite)
- [x] **T006** CLAUDE.md に spec 065 追記
- [ ] **T007** 実機検証 (ユーザー、SC-001〜005: ログで AI 回数減 / 起動軽量 / digest オンデマンド / チャット破綻なし)

## 依存
T001 / T002 / T003 は独立 (別箇所) → T004 → T005 → T006 → T007 (ユーザー)

## 実装戦略
生成停止 = 既存 nil 経路と同一なので新規テスト不要、既存 regression で担保。実機検証はユーザー。最終 commit (spec 064+065 まとめ) はユーザー指示後。

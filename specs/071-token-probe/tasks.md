# Tasks: token 実測基盤 (TokenBudgetProbe)

**Branch**: 未定 (main から新規) | **Spec**: [spec.md](./spec.md)

@Model 変更なし。生成経路無改修。token リスクなし。**未着手 (今日は spec 文書のみ)**。

## Phase 1: 実装
- [ ] **T001** `Services/TokenBudgetProbe.swift` 新規: `try await SystemLanguageModel.default.tokenCount(for:)` で代表 prompt + 各 @Generable schema (ExtractedKnowledgeOutput 等) の実 token、`.contextSize`、所要時間、残余 budget を os.Logger 出力。`model.availability == .available` で guard
- [ ] **T002** `KnowledgeTreeApp.swift` bootstrap の Task 内に `#if DEBUG` で `await TokenBudgetProbe.shared.runDiagnostics()` を 1 回 (await 必要ゆえ init でなく .task / bootstrap 内)

## Phase 2: 検証
- [ ] **T003** clean build (iPhone 17 Simulator)
- [ ] **T004** 全 unit test serial regression PASS
- [ ] **T005** CLAUDE.md に spec 071 追記
- [ ] **T006** 実機検証: デバッグ起動でコンソールに各 prompt/schema の実 token + contextSize が出る (ユーザー)。この実測値が spec 073 (入力緩和) の根拠

## 実装戦略
新規 1 ファイル + bootstrap 1 行。Edit のたび grep 確認 → build 成功確認 → commit (今回の連続ミスの教訓)。

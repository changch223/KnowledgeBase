# Tasks: カテゴリ誤分類修正

**Branch**: `072-category-fix` (main から) | **Spec**: [spec.md](./spec.md)

@Model 変更なし。token リスクなし。

## Phase 1: 実装
- [x] **T001** `CategorySeed.swift`: `promptCandidatesWithDefinitions` 追加 (各カテゴリに定義+例+反例)
- [x] **T002** `AutoCategoryClassifier.swift`: prompt 刷新 (定義付き候補 + 候補外禁止 + 人名/一般語はその他) + `classify(tagName:context:)` に context 引数 + 後方互換 extension
- [x] **T003** `TagStore.addTag`: article のタイトル+essence を context として渡す
- [x] **T004** `AutoCategoryBackfillRunner` / `LintEngine`: tag.articles から文脈を作り渡す
- [x] **T005** `InMemoryAutoCategoryClassifier` を新シグネチャに追従 (mapping 不変)

## Phase 2: 検証
- [x] **T006** clean build + 全 unit test PASS (iPhone 17 Simulator)
- [x] **T007** CLAUDE.md に spec 072 追記
- [ ] **T008** 実機検証: 保存記事のタグ分類ログで誤分類が減る (SC-001/002、ユーザー、帰宅後)

## 実装戦略
prompt + 引数の調整のみ。Edit のたび grep + build 確認 → commit。

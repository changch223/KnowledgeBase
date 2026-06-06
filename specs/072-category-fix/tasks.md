# Tasks: カテゴリ誤分類修正

**Branch**: 未定 (main から) | **Spec**: [spec.md](./spec.md)

@Model 変更なし。token リスクなし。**未着手 (spec 文書のみ)**。

## Phase 1: 実装
- [ ] **T001** `CategorySeed.swift`: `promptCandidatesWithDefinitions` 追加 (各カテゴリに 1 行定義 + 例 + 反例。例「テクノロジー: AI/プログラミング/ガジェット。反例: 一般ニュースは『ニュース』」)
- [ ] **T002** `AutoCategoryClassifier.swift`: prompt 刷新 (定義付き候補 + 「候補外を作るな/完全一致のみ/人名や一般語は文脈優先かその他」) + `classify(tagName:context:)` に context (記事 essence) 引数追加 (default nil で後方互換)
- [ ] **T003** 呼び出し元更新: AutoTagApplier 経路 / AutoCategoryBackfillRunner / KnowledgeExtractionService で記事 essence を context として渡す
- [ ] **T004** `InMemoryAutoCategoryClassifier` を引数追加に追従 (mapping 不変)
- [ ] **T005** `AutoCategoryClassifierTests` 回帰 + prompt 構造の検証ケース追加

## Phase 2: 検証
- [ ] **T006** clean build + 全 unit test PASS
- [ ] **T007** CLAUDE.md に spec 072 追記
- [ ] **T008** 実機検証: 保存記事のタグ分類ログで誤分類が減る (SC-001/002、ユーザー)

## 実装戦略
prompt + 引数の調整のみ。Edit のたび grep + build 確認 → commit。

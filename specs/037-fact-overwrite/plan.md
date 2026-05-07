# Plan: 時系列事実上書き提案

**Spec**: [spec.md](./spec.md)

## Technical Context

- Swift 6 / SwiftUI / SwiftData / Foundation Models
- iOS 26+
- 規模: 中〜大 (~590 行、~12-15 タスク)

## Architecture

```
[KnowledgeExtractionService]
  └── (既存) succeeded → applyAutoTags / markDigestStale / generateEmbedding
       └── 【新】ConflictDetectionService.detect(article:) — fire-and-forget

[ConflictDetectionService] (新)
  ├── 新記事の top 3 entities 抽出
  ├── 各 entity ごとに同 entity 持つ過去 Article fetch (上限 5)
  ├── Foundation Models で 2 記事比較 (1 prompt / 比較ペア)
  └── ConflictProposal 作成

[Models]
  ├── Article (改修)
  │    └── isObsolete: Bool
  └── ConflictProposal (新)
       ├── newArticle / oldArticle relationship
       ├── entityName / conflictDescription / newFact / oldFact
       └── status: pending / overwrite / keepBoth / dismissed

[Views]
  └── KnowledgeClipView
       └── FactConflictsSection (新)
            └── ConflictProposalRow [採用 / 両方残す / 却下]
```

## Implementation Outline

### Phase 1: Foundation
- T001 [P] ConflictProposal @Model 新規 + SharedSchema 追加
- T002 [P] Article.isObsolete 追加 (lightweight migration)
- T003 [P] ConflictDetectionOutput @Generable + LanguageModelSession 拡張

### Phase 2: Detection Logic
- T004 ConflictDetectionService 実装 (entity 抽出 + 過去記事 fetch + AI 判定)
- T005 KnowledgeExtractionService に hook 追加 (succeeded 後 fire-and-forget)
- T006 ConflictDetectionServiceTests 7 ケース

### Phase 3: KnowledgeDigest 改修
- T007 KnowledgeDigestService prompt で isObsolete を考慮
- T008 既存 KnowledgeDigestServiceTests に isObsolete ケース追加

### Phase 4: UI
- T009 FactConflictsSection 新規 (候補リスト)
- T010 ConflictProposalRow 新規 (3 ボタン UI)
- T011 KnowledgeClipView 改修 (section 追加)

### Phase 5: Bootstrap + Polish
- T012 ServiceContainer に conflictDetectionService 追加
- T013 KnowledgeTreeApp で inject
- T014 build 警告ゼロ + 既存テスト全回帰
- T015 CLAUDE.md / ROADMAP 更新
- T016 実機検証 (ユーザー)

## 主要研究項目

1. **AI 判定の精度**: prompt 設計次第。実機で False Positive / Negative を測定
2. **同 entity 検出範囲**: 完全一致 vs Levenshtein 距離 (例: 「Apple」と「アップル」)
3. **batch 処理タイミング**: 記事保存毎の同期 vs 起動時 batch、UX とのトレードオフ
4. **isObsolete UI**: ライブラリでどう表示? archive 風 (薄く) or 普通? 
5. **30 日 dismiss 期間**: spec 036 と整合
6. **entity 1 件あたり 5 件比較で 5 prompt** = 1 記事保存で最大 15 prompt → 性能影響
   - mitigations: salience 上位 1-2 entities のみ / 並列実行 / 1 件分かれば即終了

## MVP 範囲外

- N 件チェイン矛盾解決 (3 件以上)
- AI 自動 merge (両事実を 1 記事に統合)
- 矛盾検出の手動 trigger (UI で「再検出」ボタン)
- entity 名のあいまい一致 (Levenshtein / cosine similarity)
- 矛盾の信頼度スコア表示

## 依存関係

- **spec 035 (機能 X) 出荷後 が望ましい**: 知識 Clip タブの構造を整理してから FactConflictsSection 追加する方が混乱なし
- **spec 036 (機能 Y)** との UI 整合: 候補リスト / 採用済リストのパターンを揃える

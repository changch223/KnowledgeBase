# Implementation Plan: 階層的 chunked summarization

**Branch**: `010-hierarchical-summary` | **Date**: 2026-05-05 | **Spec**: [spec.md](./spec.md)

## Summary

spec 006 (chunks 上限 10) を超える 10,001-30,000 文字記事の全文要約を実現する。chunks > 10 のとき lvl2 中間 meta-summary (10 chunks ごとにグループ化、~3 グループ) → lvl3 最終 meta-summary の 3 階層パイプラインを採用。chunks ≤ 10 は spec 006 そのまま (後方互換)。spec 009 の `KnowledgeChunkProgress` incremental 永続化は lvl1 chunks のみ対象 (lvl2/lvl3 は再生成許容)。

## Technical Context

**Language/Version**: Swift 6.x (Xcode 16+, iOS 26+)
**Primary Dependencies**: SwiftUI, SwiftData, FoundationModels
**Storage**: SwiftData (App Group container)
**Testing**: Swift Testing + XCTest
**Target Platform**: iOS 26+ / iPadOS 26+
**Project Type**: mobile-app
**Performance Goals**: 18,000 文字記事を 6 分以内 (前景) / 1 時間以内 (BGTask 経由)、5,000 文字記事は spec 006 比 +5% 以内
**Constraints**:
- Foundation Models context window 4,096 token に各 LM 呼び出しが収まる
- chunks 数上限 30 (10 → 30 に拡張)
- lvl2 グループサイズ固定 10 chunks
- spec 009 incremental save は lvl1 のみ
- spec 006 chunks ≤ 10 挙動を破壊しない
**Scale/Scope**: 1 記事あたり最大 30 lvl1 + 3 lvl2 + 1 lvl3 = 34 LM 呼び出し

## Constitution Check

### 主要原則

- [x] **I. プライバシーファースト** — 全 LM 呼び出しは on-device、外部送信無し
- [x] **II. MVP ファースト** — 階層数 3 のみ、並列化なし、prompt チューニング将来 spec
- [x] **III. ソース基づく** — lvl2/lvl3 prompt も「明示されている内容のみ」hallucination 抑止 instruction を含む
- [x] **IV. iOS 実現可能性** — Foundation Models 標準、availability チェックは入口で 1 度実施
- [x] **V. calm UX** — 階層化を UI に露出させない、ユーザーには「N/M 進捗」のみで階層構造は見せない
- [x] **VI. 保守しやすい** — 階層ロジックを `HierarchicalChunkedSummarizer` 純粋関数に分離、Service は orchestration のみ
- [x] **VII. 日本語ファースト** — lvl2/lvl3 prompt も日本語

### Quality Gates

- [x] **コード品質** — 階層化アルゴリズムは純粋関数、テスト容易
- [x] **テスト** — chunks=5/10/11/18/30/35 の境界で挙動を網羅、spec 006 既存テストは無修正で pass
- [x] **アクセシビリティ** — 注記文言を「30000 文字」に更新、`Localizable.xcstrings` 経由
- [x] **パフォーマンス** — chunks ≤ 10 のオーバーヘッドは判定 1 回のみ (~10μs)

**結論**: ✓ パス。

## Project Structure

```text
specs/010-hierarchical-summary/
├── plan.md
├── research.md
├── data-model.md
├── contracts/
│   ├── hierarchical-summarizer.md
│   └── knowledge-extraction-service.md
├── quickstart.md
├── checklists/requirements.md
└── tasks.md

KnowledgeTree/
├── Services/
│   ├── KnowledgeExtractionService.swift            # 既存 + 階層化分岐
│   ├── KnowledgeExtractor.swift                    # 既存 + extractIntermediateMetaSummary 追加
│   ├── ChunkedKnowledgeAggregator.swift            # 既存 + mergeHierarchical 追加
│   └── HierarchicalChunkedSummarizer.swift         # 新規 (純粋関数: グループ分け + lvl2/lvl3 orchestration)
└── Localization/Localizable.xcstrings              # 注記文言更新
```

## 設計判断

### #1 階層化判定: chunks > 10

`KnowledgeExtractionService.performChunkedExtraction` の冒頭で `chunks.count > 10` をチェック。`true` なら階層パス、`false` なら spec 006 既存パス。判定オーバーヘッドは無視できる。

### #2 lvl2 グループ分割: 10 chunks ずつ

```swift
let groups: [[ChunkResult]] = stride(from: 0, to: results.count, by: 10).map {
    Array(results[$0..<min($0 + 10, results.count)])
}
```

chunks=18 → groups=[10, 8]、chunks=25 → [10, 10, 5]、chunks=30 → [10, 10, 10]。

### #3 lvl2 中間 meta-summary の prompt

lvl1 chunks の essence を入力に、spec 006 既存 `buildMetaSummaryPrompt` を流用 (記事原文を含まない、essence 統合専用)。

prompt 内容は同じだが、入力が「lvl1 essences (10 個)」と「lvl1 essences 全数 (3-10 個)」で異なるだけ。同じプロンプトテンプレートで OK。

### #4 lvl3 最終 meta-summary の prompt

lvl2 中間 meta の essence を入力に、spec 006 既存 `buildMetaSummaryPrompt` を流用。

lvl2 と lvl3 は同じプロンプトテンプレートを使う。区別は呼び出し回数で決まる (3 lvl2 → 1 lvl3)。

### #5 keyFacts / entities の集約

spec 006 の `ChunkedKnowledgeAggregator.merge` は **lvl1 chunks 全件** から重複排除。lvl2/lvl3 から keyFacts/entities は生成しない (essence と summary のみ)。これで spec 006 と挙動同じ + 30 chunks に対応。

### #6 incremental save との統合

spec 009 の `KnowledgeChunkProgress` は lvl1 chunks のみ保存。lvl2/lvl3 は失敗時に再生成 (~25-50 秒)。

理由:
- lvl2/lvl3 は LM 呼び出し数が少ない (最大 4 個) ので、失敗時の再生成コストが許容範囲
- lvl2/lvl3 を保存する独立スキーマを設計すると複雑度が増す
- spec 009 の resume ロジックは「lvl1 chunks 既完了 → 残り lvl1 + lvl2/lvl3 を実行」で十分

リジューム時:
1. ChunkSplitter.split で同 chunks を再生成
2. KnowledgeChunkProgress から既完了 lvl1 chunkIndex を取得
3. 残り lvl1 chunks を処理 + incremental save
4. 全 lvl1 揃ったら lvl2 グループ分け → lvl2 LM 呼び出し → lvl3 LM 呼び出し
5. 完了で cleanup

### #7 失敗時の partial success

- **lvl2 1 つ失敗 + 残り成功 + lvl3 成功**: `.succeeded` (lvl3 が全 lvl2 をカバーしているため、1 つ失敗 = 該当範囲の本文情報が薄れるが致命的でない)
- **lvl2 全失敗 + lvl3 不可 (入力空)**: `.partiallySucceeded` (lvl1 essence の連結を fallback)
- **lvl3 失敗 + lvl2 1+ 成功**: `.partiallySucceeded` (最初の lvl2 の essence + 全 lvl2 essence の改行連結を summary)
- **lvl1 全失敗**: `.failed` (spec 006 と同じ)

### #8 chunks 数上限 30

`KnowledgeExtractionService.maxChunks` の default を 10 → 30 に変更。spec 006 で chunks ≤ 10 の挙動はこれにより影響なし (10 で打ち切られない、30 まで作る)。10000 文字を超える文書のみ追加 chunks が生成される。

### #9 後方互換テスト

spec 006 の `ChunkedKnowledgeAggregatorTests` 9 ケース と `KnowledgeExtractionServiceTests` chunked 7 ケースは無修正で pass する必要。

key check: `mergeHierarchical` が新規追加で、既存 `merge(results:metaSummary:)` の signature / 挙動は変更しない。Service の chunked パスは「chunks > 10 のみ階層化」分岐で、chunks ≤ 10 は既存コードを通る。

## Complexity Tracking

> ✓ パス、記載不要

## 次フェーズ

1. Phase 0 (research): 階層 prompt 設計のベストプラクティス、 lvl2/lvl3 の partial 失敗時の status 判定
2. Phase 1: data-model + contracts + quickstart
3. Phase 2: tasks

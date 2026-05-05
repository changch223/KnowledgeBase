# Feature Specification: 階層的 chunked summarization (超長文対応)

**Feature Branch**: `010-hierarchical-summary`
**Created**: 2026-05-05
**Status**: Draft

## なぜ (Why)

spec 006 で本文 1000 文字超を最大 10 chunks (10,000 文字) に分割して chunked summarization を実装したが、それを超える超長文記事 (Wikipedia 大型項目、学術論文の解説、書籍試読、一部ニュースの大型特集) は **冒頭 10,000 文字のみ要約** で、後半は `skippedTailChars` として捨てる仕様になっている。

実用上 10,000 文字超の記事は稀だが、知識管理アプリの長期信頼性を考えると「保存はできるが要約は冒頭だけ」は設計的に弱い。ユーザーが「全文を要約してほしい」と期待する場面で破綻する。

階層的 (hierarchical) chunked summarization により、上限を 30,000 文字 (30 chunks 相当) まで引き上げ、メモリ / context window 制約を維持したまま全文要約を可能にする。

## ゴール

- 30,000 文字までの記事を全文要約対象にする
- 階層構造: lvl1 chunks (10 文字単位 × 30 個) → lvl2 中間 meta-summary (3 グループ) → lvl3 最終 meta-summary (1 個) → ExtractedKnowledge.essence/summary
- chunk 数上限 10 → **30** に拡張
- 中間 meta-summary 3 個 + 最終 meta-summary 1 個 = 追加 LM 呼び出し 4 個
- spec 006 の essence/summary 整合性、spec 009 の incremental 永続化、spec 005 の重複抑止ガードはすべて継承
- 30,001 文字超は冒頭 30,000 文字のみ対象 (skippedTailChars > 0)

## 非ゴール

- chunked パスの並列処理 (依然として逐次)
- 階層数 4 以上の超深層 (3 階層で 30,000 文字をカバーするので不要)
- 動的 chunk サイズ調整 (固定 1,000 文字)
- 階層別 prompt の細かいチューニング (将来 spec 候補)
- 100,000 文字超の超長書籍要約 (用途違い、別アプリ向け)

## ユーザストーリー

### US1 (P1) — 30,000 文字までの記事を全文要約

**As a** Wikipedia 大項目や論文解説など 10,000-30,000 文字の記事を保存したユーザー
**I want** 後半の情報も essence / summary に反映された要約が得られる
**So that** 記事全体を理解した状態で振り返りたい

#### 受け入れ基準

- 18,000 文字記事を共有保存
- chunked summarization が 18 lvl1 chunks (1,800 chars 平均) → 2 lvl2 中間 meta (10 + 8 chunks) → 1 lvl3 最終 meta で完了
- ExtractedKnowledge.essence は記事全体 (前半 + 後半) の主題を捉えている
- ExtractedKnowledge.summary は 300 文字以内で記事の論理構造を保持
- skippedTailChars == 0 (全文 cover)

### US2 (P1) — 既存 10,000 文字以下の単純 chunked パス互換

**As a** spec 006 で動いていた 5,000 文字記事を保存したユーザー
**I want** 引き続き同じ処理時間 (約 2 分 30 秒) で要約が完成する
**So that** spec 010 の階層化が短文の処理を遅くしないこと

#### 受け入れ基準

- 5,000 文字記事 → 5 lvl1 chunks → **lvl2 中間 meta はスキップ** (10 chunks 以下なら従来 spec 006 ロジックを使う) → lvl3 最終 meta = spec 006 と同等
- 処理時間が spec 006 と同等 (~2 分 30 秒)
- ExtractedKnowledge.chunkTotalCount == 6 (5 lvl1 + 1 lvl3)
- chunkProcessedCount は spec 006 と同じ意味で動作

### US3 (P2) — 30,001 文字超の tail truncation

**As a** 30,001 文字以上の超超長文記事 (稀ケース) を保存したユーザー
**I want** 冒頭 30,000 文字までは確実に要約され、超過分は注記される
**So that** 何が要約対象かが透明

#### 受け入れ基準

- 35,000 文字記事を共有保存
- 30 lvl1 chunks (30,000 文字) のみ対象、5,000 文字は skippedTailChars に記録
- Detail 画面の注記が「※ 本文が長いため冒頭 30000 文字のみを要約対象としています」(spec 006 の 10,000 文字注記を更新)
- 階層処理は spec 010 ロジックで 30 chunks に対して動作

### Edge Cases

- **chunks == 10**: 従来 spec 006 の単一 meta-summary (lvl2 中間 meta スキップ)
- **chunks == 11-20**: 2 lvl2 中間 meta グループ (10 + N chunks) → 1 lvl3 最終 meta
- **chunks == 21-30**: 3 lvl2 中間 meta グループ (10 + 10 + N chunks) → 1 lvl3 最終 meta
- **lvl2 中間 meta-summary の partial 失敗**: 該当グループは「成功した chunks の essence を簡易連結」で fallback、lvl3 は影響なし
- **lvl3 最終 meta-summary 失敗**: 全 lvl2 中間 meta の essence を改行連結 (spec 006 既存 fallback と同じパターン)
- **chunks == 0 (空 text)**: spec 006 既存挙動 (early return)
- **本文が 1 字でも `chunks >= 1`**: 階層化判定は chunks の数 (>10 で階層化) で行う

## 機能要件

### 階層化ロジック

- **FR-001**: chunked パスは本文 chunks 数で 2 つのモードに分岐
   - `chunks <= 10`: spec 006 既存 (単一 meta-summary)
   - `chunks > 10`: 階層化 (lvl2 中間 meta + lvl3 最終 meta)
- **FR-002**: 階層化時の lvl2 グループ分割は `chunks` を 10 個ずつのバケットに分け、最後のバケットは 1-10 個
   - chunks=18 → [10, 8] = 2 グループ
   - chunks=25 → [10, 10, 5] = 3 グループ
   - chunks=30 → [10, 10, 10] = 3 グループ
- **FR-003**: 各 lvl2 グループは「該当 chunks の essence」を入力に 1 回の LM 呼び出しで中間 meta-summary を生成
- **FR-004**: lvl3 最終 meta-summary は全 lvl2 中間 meta の essence を入力に 1 回の LM 呼び出しで生成
- **FR-005**: chunk 数上限を 10 → **30** に変更 (`KnowledgeExtractionService.maxChunks` default = 30)
- **FR-006**: 1 LM 呼び出しあたりの prompt 文字数上限は 4,096 token 内に収まる前提
   - lvl1 chunks: 1 chunk ~1,000 chars (spec 006 既存)
   - lvl2 中間 meta: 10 essences × 150 chars = 1,500 chars + prompt overhead → 4,096 token 内
   - lvl3 最終 meta: 3 中間 essences × 150 chars = 450 chars + prompt overhead → 余裕

### keyFacts / entities の集約

- **FR-007**: keyFacts は **lvl1 chunks 全件から重複排除して統合** (spec 006 と同じ手順、階層化の影響なし)
- **FR-008**: entities も **lvl1 chunks 全件から重複排除 + salience 最大 + type 多数決** (spec 006 と同じ)
- **FR-009**: lvl2 中間 meta / lvl3 最終 meta から keyFacts / entities は生成しない (essence と summary のみ)

### 状態 / 進捗 / メタデータ

- **FR-010**: `ExtractedKnowledge.chunkTotalCount` = lvl1 chunks 数 + lvl2 中間 meta 数 + 1 (lvl3 最終 meta)
   - chunks=18 → 18 + 2 + 1 = 21
   - chunks=5 → 5 + 0 + 1 = 6 (spec 006 と同じ)
- **FR-011**: `ExtractedKnowledge.chunkProcessedCount` は成功した LM 呼び出し総数 (lvl1 + lvl2 + lvl3)
- **FR-012**: BottomStatusBar の N/M 表示は chunkProcessedCount / chunkTotalCount で進捗を反映
- **FR-013**: Detail 画面の超長文注記は「冒頭 30000 文字のみ」を表示 (spec 006 の 10000 → 30000 に更新)

### incremental 永続化との互換 (spec 009 統合)

- **FR-014**: spec 009 の `KnowledgeChunkProgress` は lvl1 chunks のみ保存 (10-30 件)
- **FR-015**: lvl2 中間 meta / lvl3 最終 meta は incremental 保存しない (失敗時は再生成、~25 秒で許容)
- **FR-016**: リジューム時は lvl1 chunks の既完了を skip → 残り lvl1 chunks 完了 → lvl2 / lvl3 を新規実行

### 後方互換

- **FR-017**: spec 006 の chunked パス挙動 (chunks <= 10) は無変更
- **FR-018**: spec 006-008 の既存テストは無修正で pass
- **FR-019**: spec 009 の incremental save / BGTask resume は引き続き機能

## 主要エンティティ (新規 / 変更)

### ChunkedKnowledgeAggregator (既存、API 変更)

`merge` メソッドの引数に階層情報を追加:

```swift
static func mergeHierarchical(
    chunks: [ChunkResult],
    intermediateMetas: [ExtractedKnowledgeOutput?],  // 各 lvl2 中間 meta (失敗 nil)
    finalMeta: ExtractedKnowledgeOutput?              // lvl3 最終 meta (失敗 nil)
) -> AggregatedKnowledge
```

旧 `merge(results:metaSummary:)` も保持 (spec 006 後方互換)。

### KnowledgeExtractor (既存、メソッド追加)

`extractMetaSummary` 既存 (lvl3 用にもそのまま使う) + `extractIntermediateMetaSummary(chunkEssences:)` 新規 (lvl2 用、prompt は若干違う)

### KnowledgeExtractionService (既存、performChunkedExtraction 修正)

階層化判定 + lvl2 ループ + lvl3 を追加。

## 成功基準 (Success Criteria)

- **SC-001**: 18,000 文字記事を保存して chunked extraction が完了 (.succeeded)、essence は記事の前半 + 後半両方の主題を含む
- **SC-002**: 5,000 文字記事の処理時間が spec 006 比 +5% 以内 (階層化判定のオーバーヘッド最小)
- **SC-003**: 30,000 文字記事の総処理時間 ≤ 8 分 (30 lvl1 chunks × 25s + 3 lvl2 + 1 lvl3 = 850s ≒ 14 分。実際は spec 009 の background で複数 BGTask に分散)
- **SC-004**: 30,001 文字超は skippedTailChars > 0 で記録、Detail 注記表示
- **SC-005**: lvl2 中間 meta が 1 つ失敗しても、残り lvl2 + lvl3 は処理されて `.partiallySucceeded` で保存
- **SC-006**: spec 009 incremental save との統合: 18 chunks のうち 10 chunks 完了状態でアプリ再起動 → 残り 8 chunks + 2 lvl2 + 1 lvl3 のみ実行

## 依存・前提

- **spec 006**: chunked summarization の入口
- **spec 009**: incremental save + BGTask 自動再開 (lvl1 chunks に対してのみ機能)
- **iOS 26+ / Apple Intelligence**: Foundation Models on-device 推論
- **Constitution Principle I / II / V**: ローカル / MVP / calm UX

## アサンプション

- **chunks 数閾値 10 で階層化判定**: spec 006 の互換性維持と、階層化が必要となるサイズの実用判断
- **lvl2 グループサイズ 10 chunks**: lvl2 prompt が 10 essences × 150 chars = 1,500 chars で context window に余裕
- **lvl2 / lvl3 の incremental save なし**: 失敗時の再生成コストが ~25-50 秒で許容、複雑度を避ける
- **30,000 文字上限**: 平均的な日本語記事 + 学術解説の上限。実用上これ以上は別アプリ向け
- **lvl3 prompt は spec 006 既存 buildMetaSummaryPrompt をそのまま使用** (lvl2 と区別しない、入力が中間 essence でも同じロジックで統合)

## ロールアウト

- spec 010 は spec 006 / 009 のコードを変更するため、後方互換テストを優先
- 階層化判定 (chunks > 10) は default で有効、設定 toggle なし
- chunks 上限を 10 → 30 に変更することで spec 006 単体パス使用時にも上限拡張が反映される

## 非機能

- **メモリ**: lvl1 chunks の results 配列 (30 件 × ~5KB) ≒ 150KB、lvl2 / lvl3 結果は微小
- **電池**: 30 chunks × 25s + 4 meta = 約 14 分の Foundation Models 利用、spec 009 の BGTask 経路で許容範囲
- **データ**: KnowledgeChunkProgress は lvl1 のみ → 30 件 × 2KB = 60KB peak、完了で cleanup

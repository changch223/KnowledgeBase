# Research: 階層的 chunked summarization (Phase 0)

**Feature**: spec 010
**Date**: 2026-05-05

## R1: 階層判定の閾値

**Decision**: `chunks.count > 10` で階層化、`<= 10` は spec 006 既存パス。

**Rationale**:
- spec 006 の上限が 10 なので、それを超える時点で「現状の単一 meta では足りない」が明確
- 11 chunks (= 11,000 文字相当) は既に「冒頭 10,000 文字のみ」で 1,000 文字捨てる仕様だった → 階層化で全文 cover
- 閾値判定オーバーヘッドはマイクロ秒オーダーで無視可能

**Alternatives considered**:
- A. chunks > 5 で階層化 → spec 006 互換性破壊
- B. chunks > 10 (採用)
- C. 動的閾値 (token 数で判定) → 複雑、MVP 不要

---

## R2: lvl2 グループサイズ

**Decision**: lvl2 は **10 chunks ごとにグループ化**。最後のバケットは 1-10 個。

**Rationale**:
- 10 essences (各 ~150 chars) = 1,500 chars + prompt overhead 500 chars = 2,000 chars ≒ 3,400 token < 4,096 token
- グループ数 = `ceil(chunks / 10)` で 30 chunks なら最大 3 グループ
- 階層数 3 (lvl1/lvl2/lvl3) で 30,000 文字をカバーできる最小設計

**Alternatives considered**:
- A. 5 chunks ごと → グループ数 6、lvl3 入力が 6 essences、prompt 余裕あるが lvl2 呼び出しが倍増
- B. 10 chunks (採用) → 3 グループ、lvl3 入力 3 essences、context window 余裕大
- C. 可変グループサイズ → 複雑、MVP 不要

---

## R3: lvl2 / lvl3 の prompt は別物にすべきか

**Decision**: spec 006 既存 `buildMetaSummaryPrompt(chunkEssences:)` を **lvl2 / lvl3 共通で再利用**。

**Rationale**:
- lvl2 入力 = lvl1 chunks の essence 群、lvl3 入力 = lvl2 中間 meta の essence 群
- どちらも「essence 群 → 統合 essence + summary」という同じ操作
- prompt instruction (「明示されている内容のみ / 推測禁止 / 整合性」) は両方に必要
- 別 prompt にするメリット薄、保守コスト増加

**Alternatives considered**:
- A. lvl2 / lvl3 別 prompt → メリット薄
- B. 共通 prompt 流用 (採用)

**Implementation note**: `KnowledgeExtractor.extractMetaSummary(chunkEssences:)` を lvl2 と lvl3 両方で呼ぶ。

---

## R4: keyFacts / entities をどの階層で生成するか

**Decision**: **lvl1 chunks のみ** keyFacts / entities を生成、lvl2 / lvl3 は essence + summary のみ。

**Rationale**:
- lvl2/lvl3 は essence 群を統合する操作で、新たに keyFact / entity を生み出す情報源は無い
- lvl1 で全 chunks から keyFacts / entities を取得 + 重複排除 (spec 006 既存) で全文カバー
- lvl2/lvl3 prompt の出力スキーマを「keyFacts / entities は空配列」と明示することで token 節約

**Alternatives considered**:
- A. lvl2 でも keyFacts/entities 生成 → 重複多発、計算コスト増
- B. lvl1 のみ (採用)

**Implementation note**: spec 006 既存 `buildMetaSummaryPrompt` には「keyFacts と entities は空配列で返す」instruction がすでに入っている。これを lvl2/lvl3 でも継承。

---

## R5: lvl2/lvl3 の incremental 永続化

**Decision**: lvl2/lvl3 は **incremental 永続化しない**。失敗時は再生成。

**Rationale**:
- lvl2 = 最大 3 回、lvl3 = 1 回。失敗時の再生成コスト ~25-100 秒
- spec 009 の `KnowledgeChunkProgress` を lvl2/lvl3 用に拡張すると複雑度増 (chunkIndex の意味が変わる、テストも増)
- 階層化記事の総処理時間 (~14 分) に対して再生成 ~2 分は許容範囲

**Alternatives considered**:
- A. lvl2/lvl3 も保存 → 複雑、MVP 不要
- B. lvl2 のみ保存 → 中途半端
- C. 採用案 (lvl1 のみ)

---

## R6: 失敗時の partial success 判定

**Decision** (data-model.md セクション #7 に統合):
- lvl1 全失敗 → `.failed`
- lvl1 1+ 成功 + lvl2 全失敗 + lvl3 不可 → `.partiallySucceeded` (lvl1 essence 連結を fallback)
- lvl1 1+ 成功 + lvl2 1+ 成功 + lvl3 失敗 → `.partiallySucceeded` (lvl2 essence 連結を fallback)
- 全成功 → `.succeeded`
- lvl2 一部失敗 + lvl3 成功 → `.succeeded` (lvl3 が残り lvl2 から meta を生成、1 グループ欠落は許容)

**Rationale**:
- 階層化の各層で fallback ロジックを揃え、ユーザー視点で「得られる情報を最大化」
- spec 006 の partial success ロジック (`.failed` / `.succeeded` / `.partiallySucceeded`) を踏襲

---

## R7: chunks 数上限 30 の根拠

**Decision**: chunks 上限 = 30 (合計 30,000 文字)。

**Rationale**:
- 平均的な日本語 web 記事 1,000-5,000 文字
- 大型特集 / 学術解説 / Wikipedia 大項目 5,000-30,000 文字
- 書籍 / 論文 30,000+ 文字は本アプリ用途外
- lvl2 グループ数 3 で lvl3 入力 3 essences = sweet spot
- 30,001+ は spec 010 でも `skippedTailChars` で記録 (Detail 注記に表示)

---

## R8: 後方互換テスト

**Decision**: spec 006 の `ChunkedKnowledgeAggregatorTests` 9 + `KnowledgeExtractionServiceTests` chunked 7 ケースは **無修正で pass**。

**Rationale**:
- `merge(results:metaSummary:)` 既存 signature は変更しない (新規 `mergeHierarchical` を追加)
- Service の chunked パスは `chunks > 10` の if 分岐で階層パスに振り分ける、`<= 10` は既存コードを通る
- chunks ≤ 10 を扱うテストは挙動同じ

**Implementation note**: `mergeHierarchical` を新規 method として追加するが、既存 `merge` メソッドは何も変えない。Service 内の if 分岐で使い分け。

---

## サマリ

| Topic | Decision |
|---|---|
| R1 階層判定 | chunks > 10 |
| R2 lvl2 グループ | 10 chunks ごと |
| R3 prompt 共通化 | lvl2/lvl3 同じ prompt (spec 006 流用) |
| R4 keyFacts/entities | lvl1 のみ |
| R5 incremental save | lvl1 のみ |
| R6 partial success | 5 通りの fallback (R6 セクション参照) |
| R7 chunks 上限 | 30 (合計 30,000 文字) |
| R8 後方互換 | 既存テスト無修正 |

NEEDS CLARIFICATION 残数: **0**。

# Research: 長文記事の Chunked Summarization (Phase 0)

**Feature**: spec 006
**Date**: 2026-05-05

Phase 0 の目的: NEEDS CLARIFICATION の解消、技術選択の根拠記録、代替案の検討。本 spec は spec 004 / 005 の延長線で、新規技術導入は無いため重い研究は不要。下記 8 トピックで意思決定を文書化する。

---

## R1: chunk 分割アルゴリズムの境界判定

**Decision**: 「冒頭 1000 文字までで最後に出現する `。` または `\n` を境界とする。両方無ければ 1000 文字 hard cut」

**Rationale**:
- 文 (sentence) の途中で切れると意味が壊れて Foundation Models の essence 抽出精度が低下する
- 日本語文末記号は `。` が圧倒的多数。`！` `？` は意味的境界としては弱いことが多い (会話中の途中等)
- 技術記事では `\n\n` 段落区切りが文末より明示的な区切りなので、句点と同列で扱う
- 1000 文字以内に句点も改行も無いケース (極端なベタ書き、コードブロック等) は稀。hard cut で対応

**Alternatives considered**:
- A: hard cut 1000 文字 → 簡単だが文の途中で切れる頻度が高い
- B: 句点優先で次の chunk 開始位置をずらす (オーバーラップ無し) → 採用
- C: Sliding window with overlap (例: 100 文字 overlap) → 重複排除が複雑化、MVP 不要
- D: NLP 形態素解析 (Mecab 等) で文境界を厳密判定 → サードパーティ依存禁止 (Constitution)

**Implementation note**: `ChunkSplitter.split(text:maxChars:maxChunks:)` は純粋関数。境界探索は `String.lastIndex(where: { "。\n".contains($0) })` で linear scan。10 chunk 上限内ならパフォーマンス問題無し。

---

## R2: meta-summary prompt の出力安定性

**Decision**: 全 chunk の essence をリスト化し「これらを統合して 150 字以内の essence と 300 字以内の summary を生成」と Foundation Models に再投入。Generable type で structured output 制約 (spec 004 既存パターン)。

**Rationale**:
- Foundation Models on-device モデルは要約タスクの精度が高い (Apple の同梱用途として最適化)
- 全 chunk の essence (各 150 字) を 10 個並べても 1500 字 ≒ 2550 token、prompt overhead 込で 4096 内に余裕で収まる
- spec 004 既存の `ExtractedKnowledgeOutput` Generable type をそのまま再利用可能。新規 type 追加不要

**Alternatives considered**:
- A: 文字列連結のみ (LM 不使用) → 冗長で読みにくい summary になる、essence は最初の chunk のものを使うしかない
- B: 階層的要約 (10 chunk → 中間 5 chunk × 2 chunks → 最終 1 chunk) → 精度向上余地あるが LM 呼び出し回数 ~22 回に倍増、複雑度大
- C: 採用案 (1 回 meta-summary)

**Implementation note**: meta-summary 用 prompt は per-chunk prompt と別関数 `KnowledgeExtractor.buildMetaSummaryPrompt(chunkEssences:)` で構築。Generable 出力は `ExtractedKnowledgeOutput` (spec 004 と同一型) で受ける。keyFacts / entities は meta-summary 段階では生成しない (per-chunk から既に集約済のため)。

---

## R3: per-chunk vs meta-summary の prompt 制約の違い

**Decision**: per-chunk prompt は spec 004 既存制約 (元記事に明示されている内容のみ / 推測禁止 / 整合性) をそのまま踏襲。meta-summary prompt は「各 chunk の essence は既に元記事から抽出されている。それらを矛盾なく統合せよ」という追加 instruction を加える。

**Rationale**:
- per-chunk prompt は記事原文に対するハルシネーション抑止が必要
- meta-summary prompt は chunk essence (既に元記事に基づいた抽出物) に対する操作なので、「事実の追加」を明示的に禁じる instruction を入れることで一貫性確保
- prompt が長くなると context window 圧迫するので、両 prompt とも 200 字以内 instruction に抑える

**Alternatives considered**:
- A: per-chunk と meta-summary で同じ prompt を流用 → meta-summary 段階で記事原文を参照する誤動作リスク
- B: 専用 instruction を追加 (採用)

---

## R4: chunk 処理の並列化 vs 逐次

**Decision**: MVP では **逐次処理** のみ。並列化は将来の最適化候補。

**Rationale**:
- iOS 26 の FoundationModels framework は `LanguageModelSession` の thread safety について明確な公式文書が現時点で無い
- 単一セッションを並列利用する実装は GenerationError リスク
- 進捗表示 (N/M) が並列だと「2/5 → 4/5 → 3/5」のような視覚的に不自然な遷移になる
- partial success のロジック (どの chunk が失敗したか) が並列だと複雑化
- 5000 文字記事で 5 chunk + meta-summary = 6 × 25 秒 ≒ 2.5 分。許容範囲

**Alternatives considered**:
- A: 並列化 (10 chunk 同時) → 上記リスク、MVP 不要
- B: 部分並列 (2-3 chunk ずつ) → 中途半端
- C: 完全逐次 (採用)

**Future**: Foundation Models の thread safety が Apple ドキュメントで明示されたら spec 010 等で並列化検討。

---

## R5: chunk 進捗の Observable 設計

**Decision**: `ProcessingMonitor.ActiveTask` 構造体に `progressIndex: Int?` / `progressTotal: Int?` を追加。chunked パス開始時に `monitor.start(.knowledge, articleID:, title:, progressIndex: 0, progressTotal: chunks.count)`、各 chunk 完了時に `monitor.updateProgress(articleID:, index: i+1)` を呼ぶ。

**Rationale**:
- 既存 `start` / `finish` API を維持しつつ、optional progress を追加するだけで API 後方互換
- BottomStatusBar は両 fields が non-nil なら "N/M" 表示、nil なら従来 "知識抽出中" 表示
- 単発パス (1000 文字以下) は progress を渡さない → 従来 UX 維持

**Alternatives considered**:
- A: ProcessingMonitor を破壊的変更 (progressIndex / progressTotal 必須) → 既存 enrichment / body service 側も修正必要、MVP 不要な複雑化
- B: 別 Observable `ChunkProgressMonitor` を新設 → BottomStatusBar が 2 つの monitor を持つことになり複雑化
- C: 既存に optional 追加 (採用)

---

## R6: 重複排除アルゴリズムの厳密性

**Decision**:
- **keyFacts**: `statement.trimmingCharacters(in: .whitespacesAndNewlines)` の完全一致で重複判定
- **entities**: `name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)` での一致で重複判定。重複時は `salience` 最大値、`type` は多数決 (同票時は salience 最大の type)

**Rationale**:
- 厳密一致で false negative (本来は同じ意味の fact が別 fact として残る) は出るが、false positive (異なる事実が同一視される) は出ない。MVP は保守的に
- entity の case-insensitive は「Apple」と「apple」を同一視するため自然
- type の多数決は edge case (同 entity が異なる chunk で異なる type 判定) に対する妥当な default

**Alternatives considered**:
- A: 厳密一致のみ (採用 keyFacts)
- B: NLP 類似度 (Levenshtein 等) → サードパーティ依存禁止
- C: case-insensitive (採用 entities)

**Edge case**: `keyFact.type` の差異は重複判定に影響しない (statement のみで判定)。理由: 同じ statement が異なる type で重複出現する可能性は低い + UI 表示は 1 件で十分。

---

## R7: partial success の境界

**Decision**: spec.md FR-014/FR-015 を以下に詳細化:
- 全 chunk 失敗 → `.failed`、`failureReason = "全 N chunk 失敗"`
- 1+ chunk 成功 + meta-summary 成功 → `.succeeded`
- 1+ chunk 成功 + meta-summary 失敗 → `.partiallySucceeded`、最初の成功 chunk の essence を `essence` に、各 chunk essence の改行連結を `summary` に
- chunk 全成功時のみ `.succeeded` を採用するわけではない (1 chunk 失敗くらいは許容)

**Rationale**:
- ユーザー視点で「何も得られない」より「7 割得られた」方が価値あり
- meta-summary 失敗は per-chunk の情報を残せば致命的でない
- 全失敗のみ `.failed` で再試行ボタンを Detail 画面に出す (spec 005 既存)

**Alternatives considered**:
- A: 1 chunk でも失敗したら全体 `.failed` → 厳しすぎる
- B: 採用案 (上記閾値)

---

## R8: 既存テストとの後方互換

**Decision**: `KnowledgeExtractionServiceTests` の既存ケース (短文 / 全成功 / 全失敗 / partially / availability unavailable / short text skip / backfill) は **無修正で pass** すること。chunked パス用は新規ケースを追加。

**Rationale**:
- Service の `extract(article:)` 公開 API は変更しない (内部 if 分岐のみ)
- Mock LanguageModelSession を chunked test では「N 回呼ばれる」前提に拡張 (call count + index 別 return)
- `ChunkSplitter` / `ChunkedKnowledgeAggregator` は新規 test ファイルで網羅

**Alternatives considered**:
- A: 既存テストを修正 → 後方互換破壊、MVP 不要
- B: 採用案 (既存無修正 + 新規ケース追加)

---

## サマリ

| Topic | Decision |
|---|---|
| R1 chunk 境界 | 句点 / 改行 graceful split、なければ hard cut |
| R2 meta-summary | 1 回追加生成 (リスト形式 prompt) |
| R3 prompt 差別化 | per-chunk と meta-summary で別 instruction |
| R4 並列化 | MVP は逐次のみ |
| R5 進捗 Observable | ProcessingMonitor に optional progressIndex/Total 追加 |
| R6 重複排除 | keyFact: trim 完全一致 / entity: lowercased trim |
| R7 partial success | 1+ chunk 成功なら `.succeeded` or `.partiallySucceeded` |
| R8 後方互換 | 既存テスト無修正、新規 ケース追加 |

NEEDS CLARIFICATION 残数: **0**。Phase 1 (data-model + contracts + quickstart) へ進める。

# Quickstart: 長文記事の Chunked Summarization (Phase 1)

**Feature**: spec 006
**Date**: 2026-05-05

実機 (Apple Intelligence 対応端末: iPhone 15 Pro 以降 / M1 以降の iPad) での手動検証手順。

## 前提

- spec 001-005 が main app に取り込まれビルド成功
- App Group entitlement が provisioning profile で有効
- Apple Intelligence 設定が有効化されている (Settings → Apple Intelligence → ON)
- `KnowledgeTreeTests` と `KnowledgeExtractionServiceTests` が `xcodebuild test` で pass

## 検証シナリオ

### S1: 単発パス互換性 (本文 ≤ 1000 文字)

**目的**: 1000 文字以下の記事は spec 004 既存の単発生成パスをそのまま使うことを確認 (chunked オーバーヘッド 0)。

1. Safari で短いブログ記事 (例: 800 文字程度の Tweet 解説、ミニコラム) を共有 → KnowledgeTree → 投稿
2. 一覧で行が表示される → タップして Detail 画面
3. BottomStatusBar 表示の確認:
   - "メタデータ取得中: <タイトル>" → "本文抽出中: <タイトル>" → "**知識抽出中: <タイトル>**" (N/M 表示**なし**)
4. 数十秒後に knowledge セクション表示
5. ExtractedKnowledge の永続データ確認 (Xcode Console or 開発者向け SwiftData inspector で):
   - `chunkProcessedCount == 1`
   - `chunkTotalCount == 1`
   - `skippedTailChars == 0`

**期待結果**: spec 005 と完全に同じ UX。chunked パスのオーバーヘッドが体感できないこと。

---

### S2: 一般的長文 (本文 5000 文字程度)

**目的**: 標準的な技術記事 / ニュース連載の chunked summarization。

1. zenn.dev / qiita.com / 大手ニュースサイトの中規模記事 (本文 4000-6000 文字目安) を共有保存
2. 一覧で行を表示してすぐタップ → Detail 開きっぱなし
3. BottomStatusBar の進捗表示遷移:
   - "知識抽出中 1/6" (chunk 1 完了)
   - "知識抽出中 2/6"
   - "知識抽出中 3/6"
   - "知識抽出中 4/6"
   - "知識抽出中 5/6"
   - "知識抽出中 6/6" (meta-summary 完了)
   - 完了後 → BottomStatusBar 非表示
4. Detail 画面の段階的更新:
   - chunk 1 完了時点では knowledge 表示まだ
   - 全 chunk + meta-summary 完了 (status `.succeeded`) の瞬間に essence + summary + keyFacts + entities が表示
5. ExtractedKnowledge データ確認:
   - `chunkProcessedCount == 6` (5 chunk + meta)
   - `chunkTotalCount == 6`
   - `skippedTailChars == 0`
6. 総処理時間計測 (Xcode Console の `app.KnowledgeTree` knowledge category ログで確認):
   - per-chunk 処理時間 ~25 秒前後 × 5 = ~125 秒
   - meta-summary ~25 秒
   - 合計 2 分 30 秒以内が期待 (SC-005)

**期待結果**: 後半のセクションも要約に含まれている (前半だけの要約に偏らない)。`exceededContextWindowSize` エラーが出ない。

**失敗時の調査**: ログに `truncating body for ...` が出るのは単発パス (1000 文字以下) のみ。chunked パスでは出ない。

---

### S3: 上限ぎりぎり (本文 9500 文字)

**目的**: 10 chunk 上限に近い記事が `skippedTailChars` 0 でフルカバーされること。

1. ロングフォーム記事 (note.com の長文エッセイ、IT メディアの特集記事 8000-10000 文字目安) を共有保存
2. Detail 画面開きっぱなしで chunk 進捗を確認:
   - "知識抽出中 1/11" → ... → "知識抽出中 11/11"
3. ExtractedKnowledge データ確認:
   - `chunkProcessedCount` ≦ 11 (失敗 chunk があれば減る)
   - `chunkTotalCount == 11`
   - `skippedTailChars == 0` (10000 文字以下に収まっている前提)
4. 総処理時間: ~5 分以内 (10 chunk × 25 秒 + meta = 4 分 35 秒)

**期待結果**: 9500 文字でも全文が要約に反映される。

---

### S4: 超長文の tail truncation (本文 15000 文字)

**目的**: 10 chunk 上限超過時の skippedTailChars 記録 + Detail 画面の注記表示。

1. 非常に長い記事 (e.g., 学術論文の解説、Wikipedia 記事の長い項目、書籍の試し読み) を共有保存
2. Detail 画面で chunk 進捗 `1/11 ... 11/11` と進む (chunk 上限 10 + meta 1)
3. ExtractedKnowledge データ確認:
   - `chunkProcessedCount` ≦ 11
   - `chunkTotalCount == 11`
   - `skippedTailChars > 0` (例: 5000)
4. Detail 画面の knowledge セクション末尾に注記:
   - **「※ 本文が長いため冒頭 10000 文字のみを要約対象としています」** が表示される

**期待結果**: 冒頭 10000 文字の要約が得られる。後半 5000 文字は捨てられる旨が UI で明示される。

**失敗時の調査**: 注記が出ない場合は `ArticleDetailView` の `skippedTailChars > 0` 条件分岐が正しく実装されているか確認。

---

### S5: partial success (1 chunk 失敗時)

**目的**: 一部 chunk が失敗しても残り chunk から得た情報が `.partiallySucceeded` で保存される。

実機での自然再現は難しいので、ユニットテストで担保:
```bash
xcodebuild test -only-testing:KnowledgeTreeTests/KnowledgeExtractionServiceTests/extractWithLongTextOneChunkFailsMarksPartiallySucceeded
```

実機で擬似的に確認するなら:
1. Foundation Models のキャッシュをクリアする (Settings → Apple Intelligence → ストレージ管理 → Reset)
2. 長文記事を共有して chunked 処理中に **意図的に Apple Intelligence をオフ** にする
3. 残り chunk が `error` になり、それまでの chunk 成功分が aggregator で統合される
4. ExtractedKnowledge.status == `.partiallySucceeded`、`failureReason` に "N/M chunk 失敗" 記録

**期待結果**: 全失敗ではなく、得られた情報を最大限活用。Detail 画面の knowledge セクションは表示される (essence + summary + 部分的な keyFacts/entities)。

---

### S6: 単発と chunked の混在 backfill

**目的**: 短文と長文が混在した backfill ですべて適切に処理されること。

1. アプリを完全終了
2. backfill 対象として:
   - 短文記事 1 件 (~500 文字)
   - 中文記事 1 件 (~3000 文字)
   - 長文記事 1 件 (~8000 文字)
   を保存しておく (SwiftData に enrichment / body succeeded で knowledge は pending 状態)
3. アプリ起動 → bootstrap が走る
4. BottomStatusBar の進捗表示:
   - 短文: "知識抽出中: <短文タイトル>" (N/M なし)
   - 中文: "知識抽出中 1/4" → "...3/4" → "4/4" (3 chunk + meta)
   - 長文: "知識抽出中 1/9" → "...9/9" (8 chunk + meta)
5. 各記事の Detail を順次開いて knowledge が正しく表示

**期待結果**: 単発パスと chunked パスが backfill 内で混在しても問題なく動作する。

---

### S7: chunked 処理中の Detail 画面 live update

**目的**: spec 005 の live update 改善が chunked パスでも継続して機能する。

1. 5000 文字記事を共有保存 → 一覧でタップして Detail 開く
2. **アプリを閉じない**
3. BottomStatusBar が 1/6, 2/6, ... と進む
4. Detail 画面では:
   - chunk 進行中も画面が flicker しない (写真表示が消えたり戻ったりしない)
   - 全 chunk + meta 完了の瞬間に knowledge が一気に表示される
5. ScrollView の scroll 位置は維持される

**期待結果**: spec 005 で実装した「写真切替問題」修正が chunked パスでも有効。Detail 画面の `headerSection` は `.id(refreshTick)` の影響を受けない。

---

## 自動テスト

```bash
# ChunkSplitter 単体
xcodebuild test -only-testing:KnowledgeTreeTests/ChunkSplitterTests

# ChunkedKnowledgeAggregator 単体
xcodebuild test -only-testing:KnowledgeTreeTests/ChunkedKnowledgeAggregatorTests

# Service の chunked 経路 integration
xcodebuild test -only-testing:KnowledgeTreeTests/KnowledgeExtractionServiceTests

# 既存 spec 004/005 互換性 (回帰なし確認)
xcodebuild test -only-testing:KnowledgeTreeTests/KnowledgeExtractorTests
```

すべて pass することが PR merge 条件。

---

## 受け入れ基準サマリ

| Spec ID | シナリオ | 期待 |
|---|---|---|
| SC-001 | S2 (5000 文字) | context window エラー無し、100% 成功 |
| SC-002 | S3 (10000 文字) | 100% 成功 |
| SC-003 | S2/S3/S4 | 各 chunk 完了から 0.5 秒以内に N/M 更新 |
| SC-004 | S1 (800 文字) | spec 004 と同等処理時間 (chunked overhead 0) |
| SC-005 | S2 (5000 文字) | 総処理時間 ≦ 3 分 |
| SC-006 | 自動テスト ChunkedKnowledgeAggregatorTests | 重複 1 件以下 |
| SC-007 | S5 (partial success) | 残り chunk から情報保存 |
| SC-008 | S7 (live update) | Detail 画面で段階的に情報追加表示 |

すべて pass で spec 006 完了 → PR merge → main へ。

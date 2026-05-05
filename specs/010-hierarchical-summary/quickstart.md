# Quickstart: 階層的 chunked summarization

**Feature**: spec 010

実機検証手順 (Apple Intelligence 対応端末)。

## 前提

- spec 001-009 を含むビルドがインストール済
- Apple Intelligence 利用可

## S1: 既存 spec 006 互換 (chunks ≤ 10)

1. 5,000 文字記事を共有保存
2. BottomStatusBar 「知識抽出中 1/6 → 6/6」 (5 lvl1 + 1 lvl3)
3. 完了で `.succeeded`、`chunkTotalCount == 6`
4. 処理時間が spec 006 と同等 (~2.5 分)

**期待**: spec 006 の挙動と同じ。階層化判定オーバーヘッド体感ゼロ。

## S2: 階層パス (18,000 文字記事)

1. Wikipedia 大項目 / 学術解説など 18,000 文字相当を共有保存
2. BottomStatusBar 「知識抽出中 1/21 → 21/21」(18 lvl1 + 2 lvl2 + 1 lvl3)
3. 完了で `.succeeded`、`chunkTotalCount == 21`
4. essence は記事の前半 + 後半両方を含む内容
5. 総処理時間 ~9 分

**期待**: 後半内容が essence に反映されている (spec 006 では捨てられていた範囲)。

## S3: chunks 上限到達 (30,000 文字)

1. 30,000 文字相当の超長文記事を保存
2. BottomStatusBar 「知識抽出中 1/34 → 34/34」(30 lvl1 + 3 lvl2 + 1 lvl3)
3. 完了で `.succeeded`、`skippedTailChars == 0`
4. 処理時間 ~14 分 (spec 009 BGTask 経路で複数 BGTask に分散される想定)

## S4: 30,001 文字超 tail truncation

1. 35,000 文字記事を保存
2. lvl1 chunks 30 個 (30,000 文字)、`skippedTailChars == 5,000`
3. Detail 画面注記が「※ 本文が長いため冒頭 30000 文字のみを要約対象としています」(spec 006 の 10000 → 30000)

## S5: lvl2 一部失敗 + lvl3 成功

実機での自然再現は難しい。Mock LM テストで担保:
```bash
xcodebuild test -only-testing:KnowledgeTreeTests/HierarchicalChunkedSummarizerTests
xcodebuild test -only-testing:KnowledgeTreeTests/KnowledgeExtractionServiceTests/partialLvl2WithLvl3Success
```

## S6: spec 009 incremental との統合

1. 18,000 文字記事を保存して chunked extraction 開始
2. lvl1 chunks 12 個完了で中断 (デバイスロック / 完全終了)
3. アプリ再起動 → spec 008 backfill or spec 009 BGTask で resume
4. 残り lvl1 chunks 6 個 + lvl2 2 groups + lvl3 1 のみ実行
5. 既完了 lvl1 12 個は LM 呼び出しなし

**期待**: 重複生成なし、spec 009 incremental の効果が階層パスでも機能。

## 自動テスト

```bash
xcodebuild test -only-testing:KnowledgeTreeTests/HierarchicalChunkedSummarizerTests
xcodebuild test -only-testing:KnowledgeTreeTests/ChunkedKnowledgeAggregatorTests   # 既存 + spec 010 新規ケース
xcodebuild test -only-testing:KnowledgeTreeTests/KnowledgeExtractionServiceTests   # 既存 + 階層化 case
```

spec 006 既存テストは無修正で pass。

## 受け入れ基準

| Spec ID | シナリオ | 期待 |
|---|---|---|
| SC-001 | S2 | 18,000 文字記事の essence に後半内容が含まれる |
| SC-002 | S1 | 5,000 文字記事の処理時間 spec 006 比 +5% 以内 |
| SC-003 | S3 | 30,000 文字 ≤ 8 分 (前景) / ≤ 1 時間 (BGTask 含む) |
| SC-004 | S4 | skippedTailChars > 0 + Detail 注記更新 |
| SC-005 | S5 | partial 失敗を吸収して `.succeeded` または `.partiallySucceeded` |
| SC-006 | S6 | spec 009 incremental save が階層パスでも機能 |

# Quickstart: バックグラウンド AI 抽出継続 (Phase 1)

**Feature**: spec 009
**Date**: 2026-05-05

実機 (iPhone 15 Pro 以降 / Apple Intelligence 対応) での手動検証手順。シミュレータでは BGTask 実行 + Foundation Models が制限的なため、実機が必須。

## 前提

- spec 001-008 を含むビルドがインストール済 (commit `fbcde69` 以降)
- アプリ初回起動を済ませて App Group container 初期化済
- デバイスを **充電器に接続** (BGTask の dispatch 確率が大幅向上)
- iOS 設定 → 一般 → Background App Refresh = ON

## 実機での BGTask 手動 trigger

実装フェーズ最重要: BGTask の dispatch を待つと数時間かかるので、Xcode debugger で手動 trigger。

```text
# Xcode で実機にアタッチして実行中の状態で:
(lldb) e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"app.KnowledgeTree.chunkedKnowledgeExtraction"]
```

これで queue にエントリがあれば BackgroundExtractionScheduler.handleTask が起動する。

時間切れシミュレートも可能:

```text
(lldb) e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"app.KnowledgeTree.chunkedKnowledgeExtraction"]
```

---

## S1: incremental save の正常動作

**目的**: 各 chunk 完了で `KnowledgeChunkProgress` が永続化されることを確認。

1. zenn / qiita の中規模記事 (3000-5000 文字、3-5 chunks) を共有保存
2. アプリ前景で knowledge 抽出が始まる
3. BottomStatusBar に「知識抽出中 1/4」が出た時点で **アプリを完全終了** (App Switcher swipe up)
4. SwiftData inspector or LLDB で `KnowledgeChunkProgress` を確認:
   - `SELECT * FROM ZKNOWLEDGECHUNKPROGRESS WHERE ZKNOWLEDGE = ?` (該当 knowledge.id)
   - `chunkIndex` が 0 (1 chunk 完了済) の行が 1 件存在

**期待**: 中断時点で chunks 0-N の進捗が永続化されている。

---

## S2: アプリ再起動でリジューム (spec 008 fallback)

**目的**: BGTask が走らなくても、再起動 → backfill で incremental resume が動作。

1. S1 の中断状態
2. アプリを再起動
3. bootstrap で `knowledgeService.backfillAll()` が走る
4. spec 008 の `fetchPendingArticles` が `.extracting` 残骸を pickup
5. 残り chunks (chunks N+1 以降) と meta-summary のみ処理
6. BottomStatusBar に「知識抽出中 N+1/total」と表示 (initial progress に completedIndices.count が反映)
7. 完了で `.succeeded` + KnowledgeChunkProgress が cleanup される

**期待**: chunks 0-N は再生成されない (Mock LM テストで確認、実機は Console ログで「knowledge chunked start (or resume): chunks=4 alreadyCompleted=2」を確認)。

---

## S3: BGTask での自動再開 (核心)

**目的**: ユーザーがデバイスをロックして放置すると、BGTask が dispatch されて自動完了する。

1. zenn の長文記事 (8000-10000 文字、9-11 chunks) を共有保存
2. knowledge 抽出が始まる (BottomStatusBar 表示)
3. 数 chunks 完了したところで **デバイスをロック** (画面消灯)
4. **充電器接続のまま放置** 1-2 時間
5. iOS が BGTask を dispatch (system 判断)
6. BackgroundExtractionRunner.run が起動 → 残り chunks を処理
7. 1 BGTask あたり 1-2 chunks 進捗 → 時間切れ → 次回 BGTask 予約 → 繰り返し
8. 数時間後にアプリを開く → ExtractedKnowledge.status == `.succeeded`

**手動 trigger 版** (実機検証):
- 上記 step 4 で待つ代わりに `_simulateLaunchForTaskWithIdentifier:` で手動 dispatch
- Console ログで「BGTask handler invoked: articleID=...」「knowledge chunked resume: alreadyCompleted=N」を確認

---

## S4: BGTask 時間切れ → 中断 → 次回再開

**目的**: 時間切れで現在 chunk が中断されても、incremental save で進捗保持 + 次回 BGTask で残りから再開。

1. S3 の状態で BGTask 起動中
2. `_simulateExpirationForTaskWithIdentifier:` で時間切れシミュレート
3. expirationHandler が起動:
   - currentTask.cancel()
   - queue.enqueue(articleID) で再 enqueue
   - scheduler.scheduleNext()
   - task.setTaskCompleted(success: false)
4. KnowledgeChunkProgress が中断時点まで保存済
5. 次回 BGTask trigger → resume で残り chunks のみ処理

**期待**: 重複生成なし (Mock テストで Foundation Models 呼び出し回数 = 残り chunks 数)。

---

## S5: queue の永続化 (アプリ完全終了 → BGTask)

**目的**: アプリが完全終了している状態で BGTask が dispatch されても、queue から復元できる。

1. 長文記事を保存して chunked extraction 開始
2. アプリを完全終了 (App Switcher swipe up)
3. `_simulateLaunchForTaskWithIdentifier:` で BGTask trigger
4. BackgroundExtractionScheduler.handleTask が起動
5. queue.dequeueOldest() で article ID を取得
6. articleStore.fetchByID で Article 取得 → resume

**期待**: 完全終了状態でも queue が永続化されているので BGTask が空回りしない。

---

## S6: 削除済 article への BGTask 起動

**目的**: queue 内の article が削除されていれば skip される。

1. 長文記事を保存して chunked extraction 開始 → 中断
2. 一覧で記事をスワイプ削除
3. BGTask trigger → queue から article ID 取り出し
4. articleStore.fetchByID で 0 件 → entry 削除 + 次の article へ

**期待**: クラッシュなし、ログで「article deleted, skipping」確認。

---

## S7: Apple Intelligence OFF での BGTask

**目的**: BGTask 内も availability チェックが効く。

1. iOS 設定 → Apple Intelligence → OFF
2. 長文記事を保存
3. extract(article:) 内で `SystemLanguageModel.availability != .available` → `.skipped` 保存 → BGTask 起動しない (queue にも入らない)
4. iOS 設定 → Apple Intelligence → ON
5. アプリ再起動 → backfill で `.skipped` 状態の knowledge は対象外 (既存仕様)
6. ユーザーが Detail 画面で再試行ボタンを押すと extract 再実行 → 今度は AI 利用可 → 成功

**期待**: Constitution Principle IV (iOS 実現可能性) に整合、ユーザーへの説明文表示。

---

## S8: Detail 画面の「待機中」表示

**目的**: BGTask 予約済 article の Detail に静かな状態表示。

1. S3 の中断状態 (`.extracting` + queue 在り)
2. Detail 画面を開く
3. knowledge セクションに **「バックグラウンドで処理待ち (3/11 完了)」** 表示
4. **「今すぐ実行」** ボタンも併存
5. ボタンタップ → 前景で残り chunks を処理 (BGTask 待たず即時)

**期待**: ユーザーは「失敗したのか / 待つのか」を判断できる。

---

## 自動テスト

```bash
# 単体テスト
xcodebuild test -only-testing:KnowledgeTreeTests/ChunkProgressStoreTests
xcodebuild test -only-testing:KnowledgeTreeTests/BackgroundExtractionRunnerTests

# spec 009 incremental resume 経路の integration test
xcodebuild test -only-testing:KnowledgeTreeTests/KnowledgeExtractionServiceTests

# 既存 spec 006 chunked tests 9 ケースは無修正で pass (後方互換)
xcodebuild test -only-testing:KnowledgeTreeTests
```

---

## 受け入れ基準サマリ

| Spec ID | シナリオ | 期待 |
|---|---|---|
| SC-001 | S3 (10000 文字 + ロック放置 + 充電器) | 1 時間以内に .succeeded |
| SC-002 | S2 (中断 → 再起動 resume) | 完了済 chunks の LM 呼び出しが行われない |
| SC-003 | S2 + S4 (中断 → 再開繰り返し) | chunkProcessedCount が monotonically 増加 |
| SC-004 | S2 (BGTask 不実行 + 再起動) | 10 秒以内に backfill が pickup |
| SC-005 | S4 (expiration → 次回再開) | 進捗ロスト 0 |
| SC-006 | S8 (Detail 待機中表示) | 0.5 秒以内 |
| SC-007 | S2 + S4 を 11 chunks 分繰り返し | LM 呼び出し合計 11 回 (重複なし) |

すべて pass で spec 009 完了。

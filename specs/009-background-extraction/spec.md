# Feature Specification: バックグラウンドでの長時間 AI 抽出継続

**Feature Branch**: `009-background-extraction`
**Created**: 2026-05-05
**Status**: Draft
**Input**: User description: "デバイスロック中も chunked knowledge extraction を継続するバックグラウンド実行。BGProcessingTask + BGTaskScheduler。各 chunk 完了で incremental 永続化。MVP は knowledge のみ対象。"

## なぜ (Why)

spec 006 で chunked summarization を実装したことで、長文記事 (10,000 文字超まで対応、最大 11 回の Foundation Models 呼び出し ≒ 5 分弱) を要約できるようになった。

しかし iOS の前景アプリ実行モデルは「画面 ON + アプリ前景」を前提としており、ユーザーが処理中にデバイスをロックすると以下が発生する:

1. アプリは数秒〜30 秒以内にバックグラウンドで suspend される
2. 進行中の Foundation Models 呼び出しが中断される
3. ExtractedKnowledge.status が `.extracting` のまま固定される
4. spec 008 (commit `fbcde69`) の hot-fix で「アプリ再起動 / 手動再試行ボタン」での再開は可能になったが、**ユーザー操作必須**

これは「電源 ON のまま放置すれば勝手に完成している」という calm UX (Constitution Principle V) に反する。実用上、ユーザーは長文記事を保存して別の作業に戻り、しばらく後に開いて完成しているのが望ましい。

iOS の `BGProcessingTask` は最大数分のバックグラウンド実行枠を提供する。Apple Intelligence の on-device Foundation Models 推論はネットワーク不要なので、システムが「最適タイミング」(充電中・通信閑散時間) と判断したときに実行される枠で chunk 抽出を継続できる。

## ゴール

- ユーザーが長文記事を保存 → 知識抽出が始まったら、デバイスをロックして放置するだけで、システムの最適タイミングで残りの chunks が処理されて完成する。
- 各 chunk 完了ごとに状態が永続化され、中断時はその時点までの結果を保持。次回の BGTask で残り chunks から再開できる (incremental resume)。
- BGTask が一向に実行されない (端末未充電・低電力モード等) ケースでも、spec 008 の自動回復 (アプリ再起動 → backfill) と Detail 画面の手動再試行ボタンで救済。
- ユーザー操作不要。設定画面・トグル無し (将来 spec で導入余地あり)。
- 外部送信なし (Foundation Models on-device 推論を継続使用、Constitution Principle I)。

## 非ゴール

- enrichment / body extraction の background 化 (それぞれ短時間で完了するため不要)
- BGAppRefreshTask 経由のミニジョブ (BGProcessingTask に絞る)
- ユーザー設定 UI (充電中限定 / Wi-Fi 限定 / オフトグル) — 将来 spec
- 知識抽出のリアルタイム push 通知 (iOS 上ではバックグラウンド通知が複雑、calm UX に反する)
- Watch / Mac 連携での処理委譲

## ユーザストーリー

### US1 (P1) — デバイスロックして放置で長文記事の要約が完成する

**As a** 長文の連載記事や技術ブログを保存した直後のユーザー
**I want** デバイスをロックして別の作業に戻った後で、再びアプリを開いたときに知識サマリが完成している
**So that** 5 分間アプリを前景に保ち続ける必要がなく、calm UX を享受できる

#### 受け入れ基準

- 10,000 文字の連載記事を共有保存
- knowledge 抽出が開始 (BottomStatusBar に「知識抽出中 1/11」が出る)
- 数 chunk 完了したところでデバイスをロック (画面消灯)
- 充電器に接続したまま放置 (1〜数時間)
- アプリを再度開く → ExtractedKnowledge.status == `.succeeded`、essence / summary / keyFacts / entities が完成している
- BottomStatusBar は idle 状態に戻っている

### US2 (P1) — 中断した chunk から再開する (incremental resume)

**As a** chunked 処理の途中でデバイスがロックされたユーザー
**I want** ロック解除 → アプリ再起動 → BGTask 起動 のいずれかのタイミングで「途中から」再開してほしい
**So that** すでに成功した chunks の結果が無駄にならない

#### 受け入れ基準

- 11 chunks (10 chunks + meta) のうち 4 chunks 完了したところで中断
- ExtractedKnowledge.chunkProcessedCount == 4 が永続化されている
- 再開時は chunk 5 から処理 (chunks 1-4 の essence / keyFacts / entities は中間保持データから復元)
- 全 chunks + meta-summary 完了で `.succeeded` 保存
- 全体の総処理時間が約 5 分 (chunk 1 から再実行する場合の 10 分から半減)

### US3 (P2) — BGTask が走らない場合のフォールバック確認

**As a** デバイスを充電せずバッテリー駆動のまま長時間放置したユーザー
**I want** BGTask が iOS から実行されなくても、次回アプリ起動時に自動で残作業が再開される
**So that** BGTask への過度の依存で永久 stuck にならない

#### 受け入れ基準

- BGTask を skip するシミュレーション (iOS 設定 > Background App Refresh OFF 等)
- 中断 → 数時間放置 → アプリ起動
- spec 008 の `fetchPendingArticles` が `.extracting` 残骸を pickup → backfill で chunk N から再開
- ユーザー操作不要

### US4 (P3) — Detail 画面で「待機中」状態が見える

**As a** 中断した記事の Detail 画面を開いたユーザー
**I want** 「バックグラウンドで処理待ち」のような状態表示で、放置していれば終わると分かる
**So that** 「失敗したのか?」と不安にならず、再試行ボタンを押すか待つかを選べる

#### 受け入れ基準

- ExtractedKnowledge.status == `.extracting` で BGTask が予約されているとき: knowledge セクションに「バックグラウンドで処理待ち (X/N 完了)」表示
- 「再試行 (今すぐ実行)」ボタンも併存 (前景で chunk 5 から手動再開できる)
- BGTask 予約なし + .extracting なら従来の「AI が記事を解析中...」表示 (進行中扱い)

---

### Edge Cases

- **アプリが完全終了 (App Switcher で swipe up)**: BGTaskScheduler は予約を保持。次回の最適タイミングで起動。
- **BGTask 実行枠の途中で時間切れ (~30 秒)**: expirationHandler で現在 chunk を中断 → 既存の incremental 保存はそのまま → 新しい BGTaskRequest を再 submit
- **Foundation Models が unavailable (Apple Intelligence OFF)**: BGTask 実行時に availability チェック → `.skipped` 状態に変更 → BGTask は終了
- **Article が削除された後に BGTask 起動**: queue から該当 article ID を取り出した時点で存在しない → skip
- **複数 article が同時に待ち**: BGTaskRequest は 1 件ずつ予約 (system が複数 task を並行で扱うかは iOS 任せ)。実装では 1 BGTask あたり 1 article を処理
- **chunked パスではなく単発パス (≤1000 文字)**: BGTask は不要。前景のみで完結 (spec 006 既存挙動維持)
- **BGTask 実行時に他の article の Foundation Models 呼び出しが前景で進行中**: 前景優先、BGTask 側は次回延期 (LM session 競合を避ける)
- **デバイス再起動**: BGTaskScheduler の予約は再起動を超えて保持される (iOS 標準挙動)
- **iOS 設定 > Background App Refresh = OFF**: BGTask は実行されない → US3 のフォールバック経路で対応
- **電池残量 20% 未満 / Low Power Mode**: BGTask が iOS によって延期される可能性高 → 充電後に実行

## 機能要件

### 1. バックグラウンド実行基盤

- **FR-001**: アプリは BGTaskScheduler に永続的タスク識別子を 1 つ登録する (例: `app.KnowledgeTree.chunkedKnowledgeExtraction`)
- **FR-002**: 識別子は Info.plist の `BGTaskSchedulerPermittedIdentifiers` 配列に追加される
- **FR-003**: アプリ起動時の bootstrap で `BGTaskScheduler.shared.register(forTaskWithIdentifier:)` でハンドラを登録する
- **FR-004**: chunked extraction が開始された article ID は `BackgroundExtractionQueue` (新規 in-memory + 永続化) に積まれる
- **FR-005**: アプリが background 移行 (`scenePhase != .active`) または backfill で stale articles を pickup したとき、queue に未完了 article があれば `BGTaskScheduler.shared.submit(BGProcessingTaskRequest)` で予約する
- **FR-006**: BGProcessingTaskRequest の earliestBeginDate は nil (即時実行可能)、`requiresExternalPower = false` (充電中限定 OFF、MVP)、`requiresNetworkConnectivity = false` (Foundation Models は on-device)
- **FR-007**: BGTask 起動時、queue から **1 article を取り出して** chunked extraction を再開する (1 BGTask あたり 1 article を最後まで処理する努力をする、時間切れなら incremental 保存して次回繰越)

### 2. Incremental 永続化 + 再開ロジック

- **FR-008**: chunked extraction の各 chunk 完了直後に、その時点の chunk 結果 (essence / keyFacts / entities) を永続化する
- **FR-009**: 永続化先は新規 entity `KnowledgeChunkProgress` (Article ↔ ExtractedKnowledge ↔ KnowledgeChunkProgress) を採用。各 chunk の output (Generable raw) を JSON 文字列で 1 行ずつ保持する
- **FR-010**: ExtractedKnowledge.chunkProcessedCount を「成功した chunks 数」(meta-summary 抜き) として正確に保ち、リジューム時の開始 index に使う
- **FR-011**: リジューム時は `KnowledgeChunkProgress` の既存行を読み出し、ChunkSplitter は同じ本文に対して deterministic に同じ chunks を生成する → 完了済 chunks を skip して chunk N から処理
- **FR-012**: 全 chunks 完了後、最終 meta-summary を生成 → status を `.succeeded` (or partial) に変更 → KnowledgeChunkProgress の中間データは削除 (cleanup)

### 3. UI 表示

- **FR-013**: Detail 画面の knowledge セクションは status `.extracting` で BGTask 予約済 (queue に該当 article がある) のとき、「バックグラウンドで処理待ち (X / N 完了)」と表示
- **FR-014**: 同じ画面に「今すぐ実行」ボタンを表示 (= 既存の knowledgeRetryButton を流用)。タップで前景で残り chunks を再開
- **FR-015**: BottomStatusBar の表示は前景処理が走っているときのみ「知識抽出中 N/M」(spec 006 既存)。BGTask 実行は静かに進む (BottomStatusBar には表示しない、calm UX)

### 4. フォールバック / 互換性

- **FR-016**: spec 008 の stale state 自動回復メカニズム (`fetchPendingArticles` が `.extracting` 残骸を pickup) は引き続き機能する。BGTask が走らないケースのフォールバックパス
- **FR-017**: spec 008 の手動再試行ボタンは引き続き有効
- **FR-018**: 単発パス (本文 ≤1000 文字) は spec 006 既存挙動を維持。BGTask は予約しない
- **FR-019**: enrichment / body extraction は本 spec の対象外。前景のみで実行する spec 002 / 003 の挙動を維持

### 5. プライバシー / Constitution 整合

- **FR-020**: BGTask 内の処理は外部ネットワーク送信を行わない (Foundation Models on-device + SwiftData ローカル永続化のみ)
- **FR-021**: BGTask 内のログは `app.KnowledgeTree` subsystem の `background` カテゴリに分離する

## 主要エンティティ (新規)

### KnowledgeChunkProgress (新規 @Model)

```text
- id: UUID (主キー)
- knowledge: ExtractedKnowledge (relationship、cascade delete inverse)
- chunkIndex: Int                  // 0..<10
- chunkOutputJSON: String          // ChunkResult.output を JSON エンコード
- savedAt: Date
```

ExtractedKnowledge に新 relationship `chunkProgress: [KnowledgeChunkProgress]` を追加 (cascade delete)。

### BackgroundExtractionQueue (transient + 軽量永続化)

```text
- pendingArticleIDs: Set<UUID>
- 永続化: UserDefaults (App Group container 経由) または専用 @Model
```

実装上は @Model で `BackgroundExtractionQueueEntry { articleID: UUID, queuedAt: Date }` として保持し、BGTask 起動時に最古を取り出す。

## 成功基準 (Success Criteria)

- **SC-001**: 10,000 文字記事を保存 → デバイスロック → 充電器接続のまま放置 → 1 時間以内に knowledge.status == .succeeded になっている (BGTask が実行された前提)
- **SC-002**: 中断時の chunk 5 完了状態から再開した場合、再実行は chunk 6 から始まる (chunks 1-5 の Foundation Models 呼び出しは行われない)
- **SC-003**: chunkProcessedCount は中断 → 再開 → 完了の流れで monotonically 増加し、決して減少しない (incremental 永続化の証明)
- **SC-004**: BGTask が実行されない環境でも、アプリ再起動から 10 秒以内に backfill が stale article を pickup して再開する (US3 のフォールバック)
- **SC-005**: BGTask の expirationHandler が呼ばれた時点で、現在 chunk が完了済なら最新進捗が永続化されている (中断による進捗ロスト 0)
- **SC-006**: Detail 画面で BGTask 予約済 article を開くと「バックグラウンドで処理待ち」表示が 0.5 秒以内に出る
- **SC-007**: BGTask 起動 → 1 chunk 処理 → 時間切れ → 次回 BGTask で次 chunk 処理 を 11 chunks 分繰り返した場合、総合計の Foundation Models 呼び出し回数は 11 回 (重複生成なし)

## 依存・前提

- **spec 006**: chunked summarization の入口。本 spec はその incremental 化と background 化
- **spec 008**: stale state 自動回復 (fbcde69) はフォールバックとして残す
- **iOS 26+ / iPadOS 26+**: BGTaskScheduler iOS 13+、Apple Intelligence iOS 26+
- **Constitution Principle I**: 外部送信なし、Foundation Models on-device 推論のみ
- **Constitution Principle V**: calm UX、push 通知やプログレスバーで急かさない
- **対応端末**: Apple Intelligence 対応端末 (iPhone 15 Pro 以降 / M1 以降の iPad)

## アサンプション

- **BGTask の実行頻度**: iOS が決定。最低 1 時間に 1 回程度の実行を期待 (実測ベース)。即時実行は保証されない
- **BGTask の最大実行時間**: 約 30 秒〜数分 (iOS 状態次第)。Foundation Models の chunk 1 回 ~25 秒なので、1 BGTask あたり 1-2 chunks が現実的
- **充電中限定**: MVP では `requiresExternalPower = false` (充電なしでも実行可)。バッテリー消費はあるが Foundation Models は省電力寄りなので許容。設定で切替可能化は将来 spec
- **deterministic な chunk 分割**: 同じ本文 + 同じ chunkSizeChars で同じ chunks が生成される前提 (`ChunkSplitter.split` は純粋関数、spec 006 で保証)
- **複数 article の優先順位**: queue は FIFO (queuedAt 昇順)。最古の article から処理
- **失敗 chunk の扱い**: BGTask 内でも spec 008 の partial success ロジックを維持 (1+ chunk 成功 + meta 失敗 → `.partiallySucceeded`、全 chunk 失敗 → `.failed`)
- **Foundation Models のセッション**: BGTask 内で新規 `LanguageModelSession` を作成 (前景セッションとは独立、競合回避)
- **chunked 処理の deterministic re-replay**: 既に成功した chunk の output を再生成しない (KnowledgeChunkProgress に保存済の JSON を読み出して使う)
- **Tag 自動提案 (spec 008 US4)**: BGTask で knowledge 完成後、Detail 画面を開いた時点で salience >= 4 entities が表示される (新規実装不要)

## ロールアウト

- 本 spec は spec 006 / 008 のコードを変更するため、既存の動作を破壊しないよう後方互換テストを優先
- BGTask の挙動は実機検証必須 (シミュレータでは BGTask の dispatch は手動 trigger でしか確認できない)
- Xcode の `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"app.KnowledgeTree.chunkedKnowledgeExtraction"]` で手動 trigger 可能 (debugger console)

## 非機能

- **メモリ**: BGTask 内の Foundation Models 推論メモリは前景と同等 (~数百 MB)。1 chunk あたりの追加メモリは小
- **電池**: chunk 1 回あたりの電力消費は前景と同等。BGTask は iOS が電池状態を考慮して dispatch するため、低残量時は実行されない
- **データ**: KnowledgeChunkProgress 1 chunk あたり ~2KB (JSON エンコード済 entities + keyFacts + essence)。10 chunks で ~20KB → 完了後 cleanup
- **App Group container**: BGTask 実行コンテキストでも main app と同じ SwiftData ModelContainer を使用 (App Group 経由)

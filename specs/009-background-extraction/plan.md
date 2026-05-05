# Implementation Plan: バックグラウンドでの長時間 AI 抽出継続

**Branch**: `009-background-extraction` | **Date**: 2026-05-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/009-background-extraction/spec.md`

## Summary

spec 006 で実装した chunked summarization は、デバイスロックや app suspend で中断され `.extracting` stale state に陥る (spec 008 fbcde69 で再開可能化したがユーザー操作必須)。本 spec では:

1. **incremental 永続化**: 各 chunk 完了直後に `KnowledgeChunkProgress` (新 @Model) として JSON で保存。中断時はその時点までの結果を保持。
2. **`BackgroundExtractionScheduler`**: `BGTaskScheduler.shared.register/submit` で `BGProcessingTask` を予約。アプリが background 移行 / lock 時に未完了 article の処理を継続。
3. **`BackgroundExtractionRunner`**: BGTask 実行コンテキストで queue から 1 article を取り出し、incremental progress を読んで残り chunks のみ処理。expirationHandler で時間切れ時に現在 chunk を中断し次回 BGTask に持ち越す。
4. **Detail UI 更新**: BGTask 予約済 article は「バックグラウンドで処理待ち (X/N 完了)」表示 + 「今すぐ実行」ボタン。
5. **フォールバック**: spec 008 の `fetchPendingArticles` stale 自動回復は引き続き有効 (BGTask 不実行時の保険)。

技術アプローチ: 新規 entity 2 つ + 新 actor / class 2 つを追加。既存 `KnowledgeExtractionService.performChunkedExtraction` を incremental パスに書き換え。既存 spec 006 chunked tests は無修正で pass する後方互換。

## Technical Context

**Language/Version**: Swift 6.x (Xcode 16+, iOS 26+)
**Primary Dependencies**: SwiftUI, SwiftData, FoundationModels, **BackgroundTasks framework** (新規)
**Storage**: SwiftData (App Group group container)
**Testing**: Swift Testing (`#expect`) + XCTest UI testing
**Target Platform**: iOS 26+ / iPadOS 26+ (Apple Intelligence 対応端末のみ)
**Project Type**: mobile-app
**Performance Goals**:
- 10,000 文字記事 (11 chunks) を BGTask 経由で 1 時間以内に完了 (system が複数 BGTask を dispatch する前提)
- 1 BGTask あたり 1-2 chunks (時間残量次第) を完了
- chunk 完了後の incremental save は 50ms 以内
- Detail 画面の「待機中」表示は 0.5 秒以内
**Constraints**:
- BGTask 実行時間は iOS が決定 (~30 秒〜数分)
- BGTask は最低 1 時間に 1 回程度の頻度で実行 (実測ベース、保証なし)
- 充電中限定 OFF (MVP)、ネットワーク必須 OFF
- Foundation Models on-device 推論のみ (外部送信無し、Constitution Principle I)
- BGTask 内も @MainActor で SwiftData ModelContext を扱う (App Group 同一 container)
**Scale/Scope**: 1 BGTask あたり 1 article を処理。queue は通常 0-3 件 (ユーザーが連続保存するピーク時)

## Constitution Check

Reference: `.specify/memory/constitution.md` (v1.0.0)

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — BGTask 内も Foundation Models on-device 推論のみ、SwiftData ローカル永続化のみ。外部送信無し。FR-020 で明示。
- [x] **II. MVP ファースト開発** — 充電中限定 / Wi-Fi 限定 / 設定 UI / push 通知 / Watch 連携 / enrichment / body の background 化 はすべて MVP 範囲外として spec.md / plan で明記。MVP は「knowledge chunked のみ、設定無し、calm UX」に限定。
- [x] **III. ソースに基づいた知識生成** — KnowledgeChunkProgress は ExtractedKnowledge → Article への非 optional 参照を継承 (cascade delete)。各 chunk の出力は元記事本文の連続部分から生成、ハルシネーション抑止 prompt (spec 006 既存) は BGTask 実行時も適用。
- [x] **IV. iOS の実現可能性を重視する** — `BGTaskScheduler` / `BGProcessingTaskRequest` は iOS 13+ 標準 API、iOS 26 で安定。`SystemLanguageModel.availability` チェックは BGTask 実行時にも適用。Apple Intelligence 利用不可なら `.skipped` で終了。
- [x] **V. シンプルで落ち着いた UX** — BottomStatusBar には BGTask 進行を表示しない (FR-015、calm UX)。push 通知無し (Edge Cases 非ゴールで明示)。Detail 画面の「待機中」表示も静かなテキストのみ。
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — 新規 `BackgroundExtractionScheduler` (actor) と `BackgroundExtractionRunner` (class) は既存 `KnowledgeExtractionService` から分離。`KnowledgeChunkProgress` 関連の JSON encode/decode は専用 helper に切り出し。Foundation Models 呼び出しは既存 `KnowledgeExtractor` を再利用 (BGTask 経路でも変更なし)。
- [x] **VII. 日本語ファースト** — UI 文言 (待機中 / 今すぐ実行) は日本語、Localizable.xcstrings 経由。spec / plan / research / contracts すべて日本語。

### Quality Gates (二次ゲート)

- [x] **コード品質** — `BackgroundExtractionScheduler` は actor で thread safety 担保。`BackgroundExtractionRunner` は @MainActor (SwiftData アクセスのため)。`KnowledgeChunkProgress` は spec 005-008 と同じ @Model パターン。`fatalError` 不使用。新規抽象化 2 つは spec 009 + 将来 spec (BGAppRefreshTask 経由のミニジョブ等) で再利用見込み。
- [x] **テスト** — `KnowledgeChunkProgress` の JSON encode/decode テスト、`BackgroundExtractionRunner` の resume ロジック単体テスト (Mock LanguageModelSession + in-memory ModelContainer)、incremental save 後の restart で重複生成しない検証、expiration ハンドラの中断保存テスト。BGTask の実機 dispatch は `_simulateLaunchForTaskWithIdentifier:` で手動 trigger、UI テストはシミュレータ + Xcode Background Fetch trigger で確認。既存 spec 006 chunked tests 9 ケースは無修正で pass。
- [x] **アクセシビリティ・UX 一貫性** — Detail 画面の「待機中」テキストは `Localizable.xcstrings` 経由 (`detail.knowledge.queuedForBackground`)、`accessibilityIdentifier` 付与 (`knowledgeBackgroundQueuedNotice`)。「今すぐ実行」ボタンは既存 `knowledgeRetryButton` を流用。
- [x] **パフォーマンス** — chunk 完了後 incremental save は SwiftData 1 行 insert (~10ms)。BGTask 起動時の queue 取得 + KnowledgeChunkProgress fetch は 1000 article scale でも < 100ms。BGTask 内のメモリは Foundation Models 推論時 ~数百 MB (前景同等、iOS が許容)。

**結論**: Constitution Check 全項目 ✓ パス。Complexity Tracking 記載不要。

## Project Structure

### Documentation (this feature)

```text
specs/009-background-extraction/
├── plan.md
├── research.md
├── data-model.md
├── contracts/
│   ├── background-scheduler.md
│   ├── background-runner.md
│   ├── chunk-progress-store.md
│   └── knowledge-extraction-service.md  # incremental パスへの修正
├── quickstart.md
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks で生成
```

### Source Code (repository root)

```text
KnowledgeTree/
├── Models/
│   ├── ExtractedKnowledge.swift              # 既存 + chunkProgress relationship 追加
│   ├── KnowledgeChunkProgress.swift          # 新規 @Model
│   └── BackgroundExtractionQueueEntry.swift  # 新規 @Model
├── Services/
│   ├── KnowledgeExtractionService.swift      # 既存 + incremental save / resume ロジック
│   ├── KnowledgeExtractor.swift              # 既存 (変更なし)
│   ├── ChunkSplitter.swift                   # 既存 (変更なし、deterministic 前提)
│   ├── ChunkedKnowledgeAggregator.swift      # 既存 (変更なし)
│   ├── ArticleKnowledgeStore.swift           # 既存 + chunkProgress 永続化メソッド
│   ├── ChunkProgressStore.swift              # 新規 (CRUD + JSON encode/decode)
│   ├── BackgroundExtractionScheduler.swift   # 新規 (actor: BGTaskScheduler 配線)
│   ├── BackgroundExtractionRunner.swift      # 新規 (BGTask 実行コンテキスト)
│   └── BackgroundExtractionQueue.swift       # 新規 (article ID queue + 永続化)
├── Views/
│   └── ArticleDetailView.swift               # 既存 + 「待機中 (X/N)」表示分岐
├── Localization/
│   └── Localizable.xcstrings                 # 新規キー
└── Info.plist                                # BGTaskSchedulerPermittedIdentifiers 配列追加

KnowledgeTreeShareExtension/
└── (変更なし、Share Extension は Article 保存のみで knowledge 抽出には関与しない)

KnowledgeTreeTests/
├── ChunkProgressStoreTests.swift             # 新規
├── BackgroundExtractionRunnerTests.swift     # 新規 (Mock LM + in-memory)
└── KnowledgeExtractionServiceTests.swift     # 既存 + incremental resume case 追加
```

**Structure Decision**: 既存 Services / Models / Views 配置を踏襲。BGTask 関連は 4 つの新規ファイル (Scheduler / Runner / Queue / ChunkProgressStore) に責務分離。`KnowledgeExtractionService` の chunked パスは incremental 化のため大幅修正だが、外部 API は変更せず後方互換維持。

## 設計判断 (Phase 0 → Phase 1 への橋渡し)

### #1 BGTask 識別子は 1 つに集約

`app.KnowledgeTree.chunkedKnowledgeExtraction` 1 つで全 article を処理する。BGTask 起動ごとに 1 article を queue から FIFO で取り出し、可能な限り chunk を進めて時間切れで次回繰越。

代替案 (article ごとに識別子分離) は識別子上限 (10) と Info.plist 管理が複雑化するため不採用。

### #2 incremental 永続化は新規 @Model `KnowledgeChunkProgress`

各 chunk 完了直後に `chunkIndex / chunkOutputJSON / savedAt` を 1 行 insert。完了 chunk の output (Generable raw) を Codable で JSON 化して保存することで、リジューム時に LM 呼び出しを省略できる。

代替案:
- A. ExtractedKnowledge.essence / summary / keyFacts / entities を逐次 update → 中間状態と `.succeeded` の区別困難
- B. `KnowledgeChunkProgress` 別テーブル (採用) → 中間状態を完全分離、cleanup も cascade delete で安全
- C. JSON ファイルとして File system に書く → SwiftData 一元管理に反する

### #3 リジュームは ChunkSplitter の deterministic 性に依存

`ChunkSplitter.split(text:maxChars:maxChunks:)` は純粋関数 (spec 006 R1)。同じ本文 + 同じ chunkSizeChars / maxChunks で同じ Chunk 配列を生成する。

リジューム時:
1. ExtractedKnowledge.article.body.extractedText を再取得
2. ChunkSplitter で chunks を再生成
3. KnowledgeChunkProgress に存在する chunkIndex は skip
4. 残り chunkIndex に対して LM 呼び出し → 完了で chunkProgress を insert
5. 全 chunks 揃ったら meta-summary を生成 → ExtractedKnowledge.essence/summary 等を保存 → chunkProgress を cleanup (cascade delete)

注意: 本文が編集される機能は MVP に無いので「本文不変前提」が成立。将来の手動編集 spec (012 候補) では再生成戦略を見直し必要。

### #4 BGTask 1 回の処理単位

BGTask 起動時の残り時間 (~30 秒前提) を考慮:

- chunk 1 回 ~25 秒 → 1 BGTask あたり **1 chunk** が現実的
- meta-summary も 1 chunk と同等の負荷
- 11 chunks 完了に必要な BGTask 起動: 11 + meta 1 = 最大 12 回
- iOS が 1 時間に 1 回 dispatch した場合、12 時間以内に完了する想定

実装上は while ループで「次 chunk が時間内に終わりそうか」を判定:
```text
while (queue 内の article で chunks 残ある) {
    if Task.isCancelled { break (expirationHandler から呼ばれた) }
    chunk = 次の未処理 chunk
    output = await extractor.extractFromChunk(chunk)  // ~25 秒
    KnowledgeChunkProgress に insert
}
```

時間切れに陥った場合、進行中の chunk は LM session が cancellation を受け取る前提で破棄 (output が完成していなければ insert しない)。次回 BGTask で同じ chunk から再試行。

### #5 expirationHandler の挙動

```text
backgroundTask.expirationHandler = {
    Task { @MainActor in
        currentTask?.cancel()
        await scheduler.reEnqueueIfNeeded(articleID)  // 残 chunks あれば
        await scheduler.scheduleNext()  // 次回 BGTask 予約
        backgroundTask.setTaskCompleted(success: false)
    }
}
```

success: false で iOS に「未完了」と伝えるが、再 submit するので継続される。

### #6 queue の永続化と article 削除対応

`BackgroundExtractionQueueEntry` (新 @Model):
- articleID: UUID (Article.id への soft reference、@Relationship ではなく単純 UUID)
- queuedAt: Date

soft reference の理由: Article が削除された後に BGTask が起動して queue を取り出した時、不在を検知して skip できる (cascade で queue が消える方が確実だが、Article 側にも逆参照を持たせる必要が生じる)。

実装:
1. queue.dequeue() で最古エントリを取り出す
2. 該当 articleID で `FetchDescriptor<Article>(predicate: $0.id == articleID)` を実行
3. 0 件 → エントリを削除して次の article へ
4. 1 件 → BackgroundExtractionRunner にディスパッチ

### #7 ProcessingMonitor との関係

BGTask 実行時の進捗は ProcessingMonitor に表示しない (calm UX、FR-015)。アプリが foreground に戻ったときに spec 008 の自動回復で前景処理に切り替わるなら、その時に ProcessingMonitor.start を呼ぶ (spec 006 既存挙動)。

つまり ProcessingMonitor は **前景処理のみを表示** する責務に保つ。BGTask は完全に静かに進む。

### #8 既存 spec 006 テストとの互換性

spec 006 の `KnowledgeExtractionServiceTests` (chunked パス 7 ケース) は **無修正で pass** すること。

- chunked パスの外部 API (`extract(article:)` の挙動) は変わらない
- 内部実装が incremental save に変わるが、Mock store の呼び出し回数 / 引数は同等になるよう調整 (1 chunk 完了ごとに `chunkProgress.add` が呼ばれる新挙動を Mock 側で受ける = ChunkProgressStoreProtocol を Mock 化)

### #9 schema migration

ExtractedKnowledge に `@Relationship var chunkProgress: [KnowledgeChunkProgress] = []` を追加 (cascade delete inverse)。SwiftData lightweight migration (default 値 `[]` で既存レコードに自動入る、spec 005-008 と同じパターン)。

新規 `KnowledgeChunkProgress` と `BackgroundExtractionQueueEntry` は SharedSchema.all に追加 (Share Extension のスキーマ統一を維持、spec 005 既存パターン)。

### #10 BGTask の Info.plist と権限

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>app.KnowledgeTree.chunkedKnowledgeExtraction</string>
</array>
```

`UIBackgroundModes` には特に追加不要 (BGProcessingTask は permitted identifier のみで動作)。

## Complexity Tracking

> Constitution Check 全項目 ✓ のため記載不要

## 次フェーズ

1. **Phase 0** (research.md): BGTask iOS 仕様の確認 (実行頻度・時間枠・権限要件) / Foundation Models の BGTask 内動作確認 / Codable JSON encode/decode の Generable サポート / 並行処理リスク
2. **Phase 1** (data-model + contracts + quickstart): KnowledgeChunkProgress / BackgroundExtractionQueueEntry スキーマ、4 つの contracts、実機検証手順 (BGTask 手動 trigger 含む)
3. **Phase 2** (`/speckit-tasks`): 実装タスク分解

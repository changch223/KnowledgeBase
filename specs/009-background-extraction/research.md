# Research: バックグラウンド AI 抽出継続 (Phase 0)

**Feature**: spec 009
**Date**: 2026-05-05

## R1: BGProcessingTask vs BGAppRefreshTask

**Decision**: `BGProcessingTask` を採用 (`BGAppRefreshTask` は不採用)

**Rationale**:
- `BGAppRefreshTask` は最大 ~30 秒、頻繁 (15 分〜数時間) 実行向け。短時間タスクに最適化
- `BGProcessingTask` は最大数分、低頻度 (1 時間以上間隔) 実行向け。長時間処理に最適化
- chunk 1 回 ~25 秒 + LM session 起動オーバーヘッドを考えると、BGAppRefreshTask の 30 秒では「1 chunk 完了せずタイムアウト」のリスクが高い
- BGProcessingTask の数分枠なら 1 BGTask で 5-10 chunks の進捗が現実的

**Alternatives considered**:
- A. BGAppRefreshTask のみ → 30 秒では不足、頻繁起動でも継続は困難
- B. BGProcessingTask のみ (採用) → 長時間処理に最適、頻度は iOS 任せだが必要十分
- C. 両方併用 → 複雑、MVP 不要

**Implementation note**: identifier は 1 つ (`app.KnowledgeTree.chunkedKnowledgeExtraction`)、`BGProcessingTaskRequest` を使用。

---

## R2: BGTask 内での Foundation Models 動作

**Decision**: BGTask 内でも `LanguageModelSession` を新規作成して同様に呼び出せる前提で進める。

**Rationale**:
- Foundation Models (`SystemLanguageModel`) は on-device 推論で、ネットワーク不要
- BGProcessingTask は backgroundModes の network 要件と独立に動作
- Apple 公式ドキュメント上、Foundation Models が BG 実行できないという制約は明示されていない (iOS 26 仕様)
- 実機検証で確認必要 (シミュレータでは Apple Intelligence の availability が限定的)

**Alternatives considered**:
- A. BGTask 内でも前景と同じ extractor 呼び出し (採用)
- B. BGTask 専用の lightweight LM 呼び出しパス → 不要、外部 API も同じ

**Implementation note**: BackgroundExtractionRunner 内で `KnowledgeExtractor(session: FoundationModelLanguageModelSession())` を新規生成。前景の extractor と独立 session でも、on-device モデルは同じ。

**Risk**: 実機で BGTask 内 LM 呼び出しが許可されない場合、本 spec は MVP として動作しない。Phase 2 (実装) 段階で実機検証を最優先で実施し、不可なら spec を縮小 (BGTask 内では incremental save の reconciliation のみ、LM 呼び出し自体はアプリ前景に戻ったときに実行) に切り替える。

---

## R3: Codable + Generable 型の JSON encode/decode

**Decision**: `ExtractedKnowledgeOutput` / `KeyFactOutput` / `KnowledgeEntityOutput` / `FactType` / `EntityType` を `Codable` 準拠にして JSON 文字列として保存。

**Rationale**:
- Generable type は Foundation Models の出力スキーマだが、Codable も同時に準拠可能 (構造体なので)
- JSON 1 行で 1 chunk の output を保持 (~2KB)
- リジューム時に JSON decode で復元 → ChunkResult として再利用

**Alternatives considered**:
- A. Generable type を Codable 準拠 (採用) → 簡潔
- B. 別の DTO struct を作成 (例: ChunkOutputDTO) → 重複定義、変換コスト
- C. Property list (NSCoding) → 古い API、Swift 6 で非推奨

**Implementation note**:
```swift
@Generable
struct ExtractedKnowledgeOutput: Codable {  // Codable 追加
    let essence: String
    ...
}
```

`@Generable` macro と `Codable` 準拠は Swift 上で両立可能 (Generable は protocol、Codable も protocol、衝突しない)。実装フェーズで動作確認。

---

## R4: BGTask の expirationHandler ベストプラクティス

**Decision**: expirationHandler 内で:
1. `Task.cancel()` で進行中の処理を即停止
2. 該当 article ID を queue に再 enqueue (まだ chunks 残あり)
3. 新しい BGProcessingTaskRequest を submit
4. `setTaskCompleted(success: false)` を呼ぶ

**Rationale**:
- expirationHandler は ~5 秒以内に完了する必要 (iOS 仕様)
- 進行中の LM 呼び出しを cancel しないと iOS が強制終了する
- success: false でも iOS は再 submit を許可
- 再 submit しないと iOS は次回起動を遅らせる

**Alternatives considered**:
- A. expirationHandler で setTaskCompleted(success: true) → iOS は「完了」と認識、次回頻度が下がる可能性
- B. 採用案 (success: false + 再 submit)

**Implementation note**:
```swift
backgroundTask.expirationHandler = { [weak self] in
    Task { @MainActor [weak self] in
        await self?.cleanupAndReschedule(articleID: ...)
        backgroundTask.setTaskCompleted(success: false)
    }
}
```

---

## R5: queue の永続化 vs in-memory only

**Decision**: SwiftData @Model `BackgroundExtractionQueueEntry` で永続化する。

**Rationale**:
- アプリが完全終了 (App Switcher で swipe up) してから BGTask が起動する場合、in-memory queue は失われる
- BGTask 起動時にゼロから queue を構築する必要がある
- 永続化しておけば BGTask handler 内で `FetchDescriptor<BackgroundExtractionQueueEntry>` で復元可能

**Alternatives considered**:
- A. UserDefaults (App Group) → 単純な配列なら可能だが、SwiftData 一元管理に反する
- B. @Model 永続化 (採用) → SwiftData 統一
- C. in-memory のみ → 完全終了時に queue 失われる、BGTask が空回り

**Implementation note**: spec 008 の SharedSchema.all に `BackgroundExtractionQueueEntry.self` を追加 (Share Extension とのスキーマ統一を維持)。

---

## R6: chunked extraction の incremental save タイミング

**Decision**: 各 chunk の `extractor.extractFromChunk()` 完了直後に `KnowledgeChunkProgress` を 1 行 insert + `context.save()`。

**Rationale**:
- 中断時の進捗ロストを最小化 (最悪でも進行中の 1 chunk のみロスト)
- SwiftData の context.save() は同期で ~10ms (実測)、UX 影響なし
- spec 006 の現状実装は「全 chunks + meta 完了後に一括 upsertSucceeded」で中断時に全消失

**Alternatives considered**:
- A. 各 chunk 完了後に save (採用) → 中断耐性最大
- B. 5 chunks ごとに save → 中断時に最大 4 chunks ロスト
- C. 既存の最終一括 save (中断耐性なし)

**Implementation note**: `ChunkProgressStore.add(knowledge:chunkIndex:output:)` メソッドを新設。Service の chunked ループ内で chunk 完了直後に呼ぶ。

---

## R7: BGTask register のタイミング

**Decision**: アプリ launch の最初 (App init or AppDelegate.didFinishLaunchingWithOptions 相当) で `BGTaskScheduler.shared.register(forTaskWithIdentifier:using:launchHandler:)` を呼ぶ。

**Rationale**:
- iOS は launch 時点で register されていない identifier を未知扱いし、submit が失敗する
- SwiftUI App lifecycle では `init()` が AppDelegate の launch と等価のタイミング
- bootstrap (`.task { await bootstrap() }`) は遅すぎる (View が render された後なので、launch 時点で BGTask 通知が来た場合に間に合わない)

**Alternatives considered**:
- A. App.init() で register (採用)
- B. bootstrap() で register → launch 時点の BGTask 通知に間に合わない可能性
- C. AppDelegate adaptor を導入 → SwiftUI 公式パターンと乖離

**Implementation note**:
```swift
@main
struct KnowledgeTreeApp: App {
    init() {
        BackgroundExtractionScheduler.shared.registerHandler()
    }
    ...
}
```

`BackgroundExtractionScheduler.shared` (singleton) でアプリ起動の最早段階で register 完了。

---

## R8: テスト戦略

**Decision**:
- `KnowledgeChunkProgress` の JSON encode/decode は純粋関数テスト
- `ChunkProgressStore` は in-memory ModelContainer で CRUD テスト
- `BackgroundExtractionRunner` は Mock LanguageModelSession + in-memory ModelContainer で resume ロジックを検証
- `BackgroundExtractionScheduler` の BGTask register / submit はシミュレータで `_simulateLaunchForTaskWithIdentifier:` 経由 (UI test または手動 debugger trigger)

**Rationale**:
- BGTask の本物の dispatch を unit test で検証する方法は無い (iOS が dispatch を制御)
- resume ロジックは Service レイヤーで純関数化されているのでテスト容易
- expirationHandler の挙動は手動 trigger で確認 (実機 + シミュレータ両方)

**Alternatives considered**:
- A. BGTask の実機 dispatch を CI でテスト → 技術的に不可能
- B. 採用案 (resume / save / restart の単体テスト + 手動 dispatch trigger)

**Implementation note**: `BackgroundExtractionRunnerTests` で「3 chunks 完了済の状態から start → chunks 4-11 を処理 → 全完了で chunkProgress cleanup」を Mock LM (各 chunkIndex で異なる output を返す) で検証。

---

## R9: spec 006 chunked tests との後方互換

**Decision**: spec 006 の `KnowledgeExtractionServiceTests` 9 ケースは無修正で pass する。

**Rationale**:
- chunked パスの外部 API (`extract(article:)` の挙動・status 遷移) は変わらない
- Mock store (`MockArticleKnowledgeStore`) の呼び出し回数 / 引数は変化するが、新規 `chunkProgress.add` は別 protocol (`ChunkProgressStoreProtocol`) で受けるので Mock store には影響しない
- ただし新たに `ChunkProgressStoreProtocol` の Mock も DefaultKnowledgeExtractionService の init に inject する必要 → init 引数に default 実装を提供することで既存テストは変更不要

**Alternatives considered**:
- A. 採用案 (init に default 引数追加で後方互換)
- B. テスト全部修正 → 後方互換破壊、spec 006 の安定性低下

**Implementation note**:
```swift
init(
    extractor: KnowledgeExtractor,
    store: ArticleKnowledgeStoreProtocol,
    chunkProgressStore: ChunkProgressStoreProtocol = NoopChunkProgressStore(),  // 新規 default
    ...
)
```

`NoopChunkProgressStore` は何もしない実装 (テストの Mock 互換)。本番では `SwiftDataChunkProgressStore` を inject。

---

## R10: 並行処理のリスク

**Decision**: 同 article への BGTask 処理と前景 `extract(article:)` 呼び出しが衝突するリスクを `KnowledgeExtractionService.activeTasks` (spec 005 既存) で吸収。

**Rationale**:
- BGTask 内も前景でも `KnowledgeExtractionService.extract(article:)` を経由する設計にすれば、spec 005 の重複抑止ガードがそのまま機能
- `activeTasks[articleID]` に in-flight があれば待機する仕様

**Alternatives considered**:
- A. BGTask 内は別 path (extract メソッドを bypass) → 競合管理が複雑化
- B. 採用案 (BGTask も extract 経由) → 既存ガードが効く

**Implementation note**: `BackgroundExtractionRunner.run(articleID:)` 内で:
```swift
guard let article = try? store.fetchArticle(id: articleID) else { return }
await knowledgeService.extract(article: article)  // 既存 API、incremental パスは内部で resume 判定
```

この設計だと前景 extract と BGTask 内 extract が同じパスで動き、activeTasks dedup と incremental resume が両立する。

---

## サマリ

| Topic | Decision |
|---|---|
| R1 BGTask タイプ | BGProcessingTask 1 つ |
| R2 LM in BGTask | 新規 LanguageModelSession (前景独立)、実機検証必須 |
| R3 JSON encode | Generable type に Codable 追加 |
| R4 expirationHandler | cancel + reEnqueue + reSubmit + success:false |
| R5 queue 永続化 | SwiftData @Model |
| R6 incremental save | 各 chunk 完了直後に save |
| R7 register タイミング | App.init() で singleton 登録 |
| R8 テスト戦略 | 単体 + Mock + 手動 dispatch trigger |
| R9 後方互換 | init に default 引数で既存テスト無修正 |
| R10 並行処理 | extract(article:) 経由で activeTasks dedup を継承 |

NEEDS CLARIFICATION 残数: **0**。Phase 1 へ進める。

**Risk acknowledgement**: R2 (BGTask 内 Foundation Models) は実機検証が必須。動かない場合は MVP scope を縮小する。Phase 2 (実装) で最優先確認。

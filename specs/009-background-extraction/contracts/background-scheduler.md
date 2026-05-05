# Contract: BackgroundExtractionScheduler

**File**: `KnowledgeTree/Services/BackgroundExtractionScheduler.swift` (新規)

## 責務

iOS の `BGTaskScheduler` との配線。アプリ起動時の `register`、queue にエントリがある時の `submit`、BGTask handler 起動時の dispatch を担う。Singleton として App.init() で生成。

## API

```swift
@MainActor
final class BackgroundExtractionScheduler {
    static let shared = BackgroundExtractionScheduler()

    static let taskIdentifier = "app.KnowledgeTree.chunkedKnowledgeExtraction"

    /// App.init() で必ず呼ぶ。BGTaskScheduler に handler を登録する。
    func registerHandler()

    /// queue にエントリがある場合に BGProcessingTaskRequest を submit。
    /// 既に submit 済の場合は no-op (BGTaskScheduler は同 identifier の重複 submit を上書き)。
    func scheduleBGTaskIfNeeded() async

    /// 現在の BGTaskRequest を pending list から削除。
    /// テスト用 + ユーザーが手動再試行を選んだ時の cleanup 用。
    func cancelPending() async

    // Service 層から DI で注入される
    var runnerProvider: (() -> BackgroundExtractionRunner?)?
    var queueProvider: (() -> BackgroundExtractionQueue?)?
}
```

## 動作詳細

### registerHandler

```swift
func registerHandler() {
    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: Self.taskIdentifier,
        using: nil   // main queue で実行
    ) { [weak self] task in
        guard let processingTask = task as? BGProcessingTask else {
            task.setTaskCompleted(success: false)
            return
        }
        Task { @MainActor [weak self] in
            await self?.handleTask(processingTask)
        }
    }
}
```

App.init() で 1 回だけ呼ぶ。複数回呼ぶと iOS が precondition failure を起こすため。

### handleTask(_:)

```swift
private func handleTask(_ task: BGProcessingTask) async {
    guard let queue = queueProvider?(), let runner = runnerProvider?() else {
        task.setTaskCompleted(success: false)
        return
    }

    // 次の article を取り出し
    guard let articleID = try? queue.dequeueOldest() else {
        task.setTaskCompleted(success: true)  // queue 空、完了扱い
        return
    }

    // expirationHandler 設定
    task.expirationHandler = {
        Task { @MainActor in
            // 進行中の処理を cancel + 再 enqueue + 次回予約
            runner.cancelCurrent()
            try? queue.enqueue(articleID: articleID)  // 再 enqueue
            await self.scheduleBGTaskIfNeeded()
            task.setTaskCompleted(success: false)
        }
    }

    // 実処理
    let succeeded = await runner.run(articleID: articleID)
    task.setTaskCompleted(success: succeeded)

    // 次の article がまだ queue にあれば次回予約
    if (try? queue.fetchOldest()) != nil {
        await scheduleBGTaskIfNeeded()
    }
}
```

### scheduleBGTaskIfNeeded

```swift
func scheduleBGTaskIfNeeded() async {
    let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
    request.requiresExternalPower = false       // MVP: 充電中限定 OFF
    request.requiresNetworkConnectivity = false // Foundation Models on-device
    request.earliestBeginDate = nil             // 即時可能 (system が決定)

    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        // submit 失敗は通常 simulator 環境 / permitted identifier 未登録 / queue 上限
        // log するが silent fail (アプリ動作には致命的でない)
    }
}
```

### cancelPending

```swift
func cancelPending() async {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
}
```

## 不変条件

1. `registerHandler()` は `App.init()` で **1 回のみ** 呼ばれる (複数回でアプリクラッシュ)
2. `scheduleBGTaskIfNeeded()` は冪等 (重複 submit は iOS が上書き)
3. `handleTask` 内で `task.setTaskCompleted` は必ず 1 回呼ばれる (expirationHandler 含む)
4. expirationHandler 内も MainActor で実行 (SwiftData 操作のため)

## テストケース

BGTaskScheduler の dispatch は CI で検証不可 (iOS 仕様)。手動 trigger とロジック単体テストで担保:

```swift
@Test("registerHandler 重複呼び出しでもクラッシュしない (iOS が precondition failure を出すケースは E2E で確認)")
func registerHandlerOnce()

@Test("scheduleBGTaskIfNeeded で submit が呼ばれる")
func scheduleSubmits()

@Test("queue が空なら handleTask は task.setTaskCompleted(success:true) で終了")
func emptyQueueCompletes()

@Test("expirationHandler が runner.cancelCurrent を呼ぶ")
func expirationCallsCancel()
```

実機検証は quickstart.md の S4 / S5 で:
- LLDB console: `(lldb) e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"app.KnowledgeTree.chunkedKnowledgeExtraction"]`
- 上記で BGTask が dispatch される → ログで handleTask 実行を確認

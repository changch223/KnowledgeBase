# Research: Sprint 2 信頼性改善 4 件

行番号は 2026-05-30 main @ `9e43f2f` 時点。

---

## R1: P1-2 iCloud Toggle バウンス

**Decision**: `@State pendingICloudToggle: Bool?` を追加。Toggle binding を pending 優先表示にし、confirm alert の結果で確定。

**現状 (verified)**: `SettingsView.swift:71-94` の Toggle set closure が `newValue` を保存せず `showICloudEnableConfirm/showICloudDisableConfirm = true` のみ → SwiftUI が `iCloudSyncEnabled` (未変更) を再描画 → スイッチが元位置に弾き返る。confirm alert の `:312-329` で初めて `iCloudSyncEnabled = true/false`。

**実装**:
```swift
@State private var pendingICloudToggle: Bool?
// Toggle
Toggle(isOn: Binding(
    get: { pendingICloudToggle ?? iCloudSyncEnabled },
    set: { newValue in
        pendingICloudToggle = newValue          // ← 楽観表示
        if newValue { showICloudEnableConfirm = true }
        else { showICloudDisableConfirm = true }
    }
))
// enable alert OK
Button("...") { iCloudSyncEnabled = true; pendingICloudToggle = nil; showRestartBanner = true }
// enable alert Cancel
Button(role: .cancel) { pendingICloudToggle = nil }   // ← 元位置に戻る
// disable も同様
```

**Rationale**: pending で楽観表示するとタップ直後に新位置を保ち、cancel で nil → 元位置、OK で確定。バウンスが消える。restartBanner / 確認文言は維持 (FR-003)。

**Alternatives considered**: Toggle を Button + chevron + sheet に変更 (Apple 設定アプリ風) → 変更が大きい。pending state が最小。

---

## R2: P1-3 try? サイレント失敗 surface

**Decision**: `AppErrorReporter` (Protocol + os.Logger Default) を新設。ユーザー操作 7 箇所を do/catch 化、削除系は軽い error 表示。

**対象 (verified、ユーザー能動操作のみ。fetch の try? は読取で対象外)**:
| ファイル:行 | 操作 | feedback |
|---|---|---|
| ChatHistorySidebar:99 | セッション削除 | 削除 → error 表示 |
| SettingsView:288 | チャット履歴全削除 | 削除 → error 表示 |
| SavedAnswerDetailView:40 | ピン切替 | log + 失敗時 state 復元 |
| SavedAnswerDetailView:106 | markFresh | log + 失敗時 state 復元 |
| SavedAnswerDetailView:126 | 削除 | 削除 → error 表示 |
| ArticleDetailView:243 | タグ追加 | log + 失敗時 state 復元 |
| ArticleDetailView:248 | タグ削除 | log + 失敗時 state 復元 |
| ConceptPageDetailView:53 | フォロー切替 | log + 失敗時 state 復元 |

**AppErrorReporter**:
```swift
@MainActor protocol AppErrorReporting {
    func report(_ error: Error, operation: String)
}
@MainActor final class AppErrorReporter: AppErrorReporting {
    static let shared = AppErrorReporter()
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "user-action-error")
    func report(_ error: Error, operation: String) {
        logger.error("user action failed [\(operation, privacy: .public)]: \(String(describing: error), privacy: .public)")
    }
}
```

**Rationale**: report の os.Logger は端末内・低コスト。削除のみ `@State errorMessage` + 軽い alert/banner (取り返しがつかない操作)。トグル系は log + 失敗時に UI を元の値へ戻す (calm UX、強い alert 濫用しない、FR-005 は削除に限定)。裏処理 try? は無改修 (FR-006)。

**テスト**: `AppErrorReporterTests` — MockAppErrorReporting で report 呼び出しを記録、operation 文字列を検証 (~3 ケース)。各 view は @State でロジック薄いため unit より統合/手動。

**Alternatives considered**: 全箇所に強い alert → calm UX 違反。toast framework 新規 → 過剰。log + 削除のみ表示が最小で原則準拠。

---

## R3: P1-6 ModelContainer fatalError 回避

**Decision**: `sharedModelContainer` クロージャの fatalError 2 箇所 (`:76` / `:79`) を in-memory ModelContainer fallback に置換 + `storeLoadFailed` フラグ。

**現状 (verified)**: `KnowledgeTreeApp.swift:57-81` stored property 即時クロージャ。CloudKit 失敗 → local fallback → それも失敗で `fatalError`、非 CloudKit でも `fatalError`。

**実装**:
```swift
// 最終 fallback (両 fatalError を置換)
NSLog("⚠️ ModelContainer init failed entirely, using in-memory store: \(error)")
#if DEBUG
assertionFailure("ModelContainer init failed: \(error)")
#endif
do {
    let inMemory = ModelConfiguration(isStoredInMemoryOnly: true)
    let c = try ModelContainer(for: SharedSchema.all, configurations: [inMemory])
    // storeLoadFailed フラグを立てる手段: クロージャ内で外部 @State は触れないため、
    // 別 static flag or UserDefaults に記録 → body で読んで banner 表示
    UserDefaults.standard.set(true, forKey: "spec061_storeLoadFailed")
    return c
} catch {
    // in-memory すら失敗は本当に異常 → ここだけ fatalError 残置 (理論上ほぼ起きない)
    fatalError("Even in-memory ModelContainer failed: \(error)")
}
```
+ body 側で `storeLoadFailed` を読んで軽い警告 banner (「データの読み込みに問題が発生しました。設定を確認してください」)。

**Rationale**: in-memory なら crash せず起動できる (データ永続化は失われるが再インストール強制を回避、FR-007)。通常時は無影響 (FR-008)。debug は assertionFailure で検知。MVP は banner のみ、フル StoreRecoveryView (retry/local 切替) は最小に留める (Assumptions)。

**Alternatives considered**: フル StoreRecoveryView を最初から → スコープ過大。in-memory fallback + banner が最小で crash 回避を達成。

---

## R4: P1-7 起動 backfill 並列化

**Decision**: bootstrap 末尾 (`:388-427`) の独立 backfill を `async let` で並列化。依存 chain は直列維持。

**現状 (verified)**: `KnowledgeTreeApp.swift:388-427` で全 backfill を直列 await。
- 直列必須: `enrichmentService.backfillAll()` → `bodyService.backfillAll()` → `knowledgeService.backfillAll()` (chain)
- 独立 (knowledge 後): `tagStore.cleanupOrphans()` / `AutoTagBackfillRunner.run()` / `AutoCategoryBackfillRunner.run()` / `digestService.regenerateAllStale()` / `chatService.backfillEmbeddings()` / `topicClusteringService.runIfDue()` / `conceptSynthesisService.backfillFromExistingArticles()→resynthesizeAllStale()`

**実装**:
```swift
// 直列 chain (依存あり)
await enrichmentService.backfillAll()
await bodyService.backfillAll()
await knowledgeService.backfillAll()

// 独立 backfill を並列化 (async let で同時進行、全完了を待つ)
async let tagCleanup: Void = { try? tagStore.cleanupOrphans() }()
async let autoTag: Void = backfillRunner.run()
async let categoryBackfill: Void = categoryBackfillRunner.run()
async let digest: Void = { try? await digestService.regenerateAllStale() }()
async let embeddings: Void = chatService.backfillEmbeddings()
async let topics: Void = topicClusteringService.runIfDue(force: false)
async let concepts: Void = {
    await conceptSynthesisService.backfillFromExistingArticles()
    await conceptSynthesisService.resynthesizeAllStale()
}()
_ = await (tagCleanup, autoTag, categoryBackfill, digest, embeddings, topics, concepts)

// BGTask 予約は最後 (全 backfill 後)
await BackgroundExtractionScheduler.shared.scheduleNextConceptResynthesis()
await BackgroundExtractionScheduler.shared.scheduleNextWeeklyLint()
```

**Rationale**: 全 @MainActor のため真の並列計算ではないが、各 service の await suspend (I/O / Foundation Models 呼び出し) が重なり cold start の待ち時間が短縮。依存 chain は直列維持 (FR-010)。AutoTagBackfillRunner 等が同一 context を触るが、@MainActor 上で交互実行されるためデータ競合なし。

**注意点**: backfillRunner / categoryBackfillRunner は元コードでローカル生成 (`:396` / `:404`) → async let に渡す前に生成。runner が ProcessingMonitor.Phase を共有するため、同時更新で phase が飛ぶ可能性 → ProcessingMonitor は @MainActor で逐次反映されるので表示が乱れる程度 (機能影響なし)。気になれば phase 競合は別途。MVP は並列化優先。

**Alternatives considered**: `withTaskGroup` → async let の方が固定数で読みやすい。真の並列 (Task.detached) → @MainActor service なので不可、P1-8 別 spec。

**検証**: 起動が完了し既存テストが通ること (構造 regression)。Instruments TTI はユーザー後追い。

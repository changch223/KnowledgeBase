# Tasks: Sprint 2 信頼性改善 4 件 + ForEach 重複 ID

**Branch**: `061-sprint2-reliability` | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

信頼性 4 件 (全 P1) + 実機ログで判明した ForEach 重複 ID 修正。パス: `KnowledgeTree/KnowledgeTree/` 配下。

凡例: `[P]` = 別ファイル並列可

---

## Phase 1: Setup

- [x] **T001** `KnowledgeTree/Localization/Localizable.xcstrings` に文言追加 (~6 文言)
  - P1-3 error: `error.action.deleteFailed` 等 (削除失敗の軽い表示)
  - P1-6 recovery: `error.store.loadFailed.title` / `.body` (banner)

---

## Phase 2: Foundational

- [x] **T002** `KnowledgeTree/Services/AppErrorReporter.swift` 新規
  - `@MainActor protocol AppErrorReporting { func report(_ error: Error, operation: String) }`
  - `final class AppErrorReporter: AppErrorReporting` (os.Logger、`shared` singleton)
  - contract: contracts/error-reporting.md
- [x] **T003** `KnowledgeTreeTests/AppErrorReporterTests.swift` 新規 (3 ケース)
  - Mock AppErrorReporting で report 呼び出し記録 + operation 文字列検証

**Checkpoint**: AppErrorReporter compile + テスト PASS。

---

## Phase 3: US1 (P1-2) iCloud Toggle バウンス

**Goal**: トグルが弾き返らず、確認で確定/復元。

- [x] **T004 [P] [US1]** `KnowledgeTree/Views/SettingsView.swift` toggle pending 化
  - `@State private var pendingICloudToggle: Bool?`
  - Toggle.get = `pendingICloudToggle ?? iCloudSyncEnabled`、set で pending 保持 + alert
  - enable/disable alert OK で apply + pending=nil、Cancel で pending=nil
  - contract: contracts/icloud-toggle.md

**Checkpoint**: tap でバウンスなし、cancel 復元 / OK 反転。

---

## Phase 4: US2 (P1-3) try? サイレント失敗 surface

**Goal**: ユーザー操作失敗を log + 削除系は表示。

- [x] **T005 [US2]** `KnowledgeTree/Views/SettingsView.swift:288` チャット履歴全削除 → do/catch + AppErrorReporter + error 表示 (T002 後)
- [x] **T006 [P] [US2]** `KnowledgeTree/Views/ChatHistorySidebar.swift:99` セッション削除 → do/catch + error 表示 (T002 後)
- [x] **T007 [P] [US2]** `KnowledgeTree/Views/SavedAnswerDetailView.swift:40/106/126` ピン/markFresh/削除 → do/catch + log、削除は error 表示 (T002 後)
- [x] **T008 [P] [US2]** `KnowledgeTree/Views/ArticleDetailView.swift:243/248` タグ追加/削除 → do/catch + log + 失敗時 state 復元 (T002 後)
- [x] **T009 [P] [US2]** `KnowledgeTree/Views/ConceptPageDetailView.swift:53` フォロー切替 → do/catch + log + 失敗時 state 復元 (T002 後)

**Checkpoint**: 7 箇所が do/catch + AppErrorReporter 経由。

---

## Phase 5: US3 (P1-6) ModelContainer crash 回避

**Goal**: store 構築失敗で crash せず起動。

- [x] **T010 [US3]** `KnowledgeTree/KnowledgeTreeApp.swift:76/79` fatalError → in-memory ModelContainer fallback + UserDefaults `spec061_storeLoadFailed` + `#if DEBUG assertionFailure`
  - contract: contracts/store-recovery.md
- [x] **T011 [US3]** `KnowledgeTreeApp` body に `storeLoadFailed` banner (「データ読み込みに問題」) (T010 後)

**Checkpoint**: build SUCCEEDED、通常起動は無影響。

---

## Phase 6: US4 (P1-7) backfill 並列化

**Goal**: 独立 backfill を同時進行。

- [x] **T012 [US4]** `KnowledgeTree/KnowledgeTreeApp.swift:388-427` bootstrap 末尾
  - enrichment→body→knowledge は直列維持
  - 独立 backfill (tagCleanup / autoTag / category / digest / embeddings / topics / concepts) を `async let` で並列化 + `_ = await (...)`
  - BGTask 予約 (scheduleNext*) は最後
  - contract: contracts/backfill-parallel.md

**Checkpoint**: build SUCCEEDED、起動完了 regression。

---

## Phase 7: 追加 (実機ログ判明) ForEach 重複 ID

**Goal**: AI が同テーマ重複返却時の `ForEach undefined results` 警告を解消。

- [x] **T013 [P]** `RecentArticlesSection.swift:122` + `RecentLearningDetailView.swift:82` の `ForEach(themes, id: \.self)` を index 込み一意 ID に
  - `ForEach(Array(themes.enumerated()), id: \.offset)` パターン (or themes を一意化)
  - accessibilityIdentifier の `theme` 参照は維持

**Checkpoint**: `rg "ForEach\(themes, id" → 0 hit`。

---

## Phase 8: Polish & 検証

- [x] **T014** clean build (iPhone 17 Simulator)、本 spec 由来 warning ゼロ
- [x] **T015** 全 unit test serial regression PASS (AppErrorReporterTests 含む)
- [x] **T016** 静的検証: `rg "AppErrorReporter|pendingICloudToggle|async let|isStoredInMemoryOnly"`
- [x] **T017** `CLAUDE.md` に spec 061 を 🔧 実装完了で追記
- [ ] **T018** 実機検証 (ユーザー、SC-001〜004 + ForEach 警告消失)

---

## 依存グラフ

```
T001 ─┬─ T005 / T007 (error 文言)
T002 ─┴─ T005-T009 (AppErrorReporter)
T004 独立 / T010 → T011 / T012 独立 / T013 独立
全実装 → T014 → T015 → T016 → T017 → T018 (ユーザー)
```

## 並列例

- **T004 / T010 / T012 / T013** 並列 (別ファイル/別箇所)
- T002 後: **T006 / T007 / T008 / T009** 並列

## 実装戦略

- T001+T002 (Foundational) → US1-US4 + Phase 7 を並列着手 → Polish。
- 本セッションは T001-T017 (build + unit test + static)、T018 実機検証はユーザー。
- 最終 commit はユーザー指示後。

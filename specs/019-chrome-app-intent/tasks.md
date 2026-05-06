# Tasks: Chrome 連携 App Intents + iOS Shortcut + 設定画面 Setup Guide (spec 019)

**Input**: Design documents from `/specs/019-chrome-app-intent/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ (5 個), quickstart.md

**Tests**: 静的純関数 `ArticleSavingActor.performSave()` に対する unit test を含める (in-memory ModelContainer)。AppIntent perform() 自体や view rendering は対象外、quickstart 12 シナリオで実機検証代替。

**Organization**: 5 user stories (US1〜US5) ごとに Phase 分け。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 並列可能 (異なるファイル、依存なし)
- **[Story]**: US1〜US5 のいずれか
- 全タスクに project-relative path を記載

---

## Phase 1: Setup

**Purpose**: 文言追加 (新 SwiftData schema なし、新 service 不要)

- [x] T001 `KnowledgeTree/Localization/Localizable.xcstrings` に新規 13 文言を追加: `settings.title` / `settings.section.externalIntegration` / `settings.chromeSetup.entry` / `settings.chromeSetup.title` / `settings.chromeSetup.description` / `settings.chromeSetup.step1.title` / `settings.chromeSetup.step1.description` / `settings.chromeSetup.openShortcutsButton` / `settings.chromeSetup.step2.title` / `settings.chromeSetup.step2.description` / `settings.chromeSetup.step3.title` / `settings.chromeSetup.step3.description` / `settings.chromeSetup.completeButton` / `settings.chromeSetup.resetLink` (research.md R9 仕様、日本語のみ)

---

## Phase 2: Foundational

**Purpose**: 全 User Story 共通の ArticleSavingActor を整備 (App Intent + main app + テスト 3 経路で利用)

- [x] T002 `KnowledgeTree/AppIntents/` ディレクトリを作成し、`KnowledgeTree/AppIntents/ArticleSavingActor.swift` を新規作成。`actor ArticleSavingActor { static let shared = ArticleSavingActor() }` + `func save(url:title:)` (singleton 経由) + lazy `getContainer()` (App Group ModelContainer cache) + `static performSave(url:title:in: ModelContext)` (純関数、testable、http/https scheme チェック + 重複検出 + insert)。contracts/article-saving-actor.md 仕様準拠

**Checkpoint**: T001-T002 完了で全 US が並列着手可能

---

## Phase 3: User Story 1 (P1) — Shortcuts.app に「知積に保存」が自動登録 🎯 MVP

**Goal**: AppShortcutsProvider 経由で Shortcuts.app + Spotlight + Siri に「知積に保存」アクションが自動登録される

**Independent Test**:
- 実機で Shortcuts.app 起動 → Apps 一覧に「知積」アクション表示
- Spotlight 検索で「知積」入力 → 候補表示

- [x] T003 [US1] `KnowledgeTree/AppIntents/SaveURLToKnowledgeTreeIntent.swift` を新規作成。`struct SaveURLToKnowledgeTreeIntent: AppIntent` (`title` / `description` / `openAppWhenRun: false` / `@Parameter url: URL` / `@Parameter title: String?` / `perform() async throws -> some IntentResult` で `ArticleSavingActor.shared.save(url:title:)` 呼び出し → `return .result()`)。contracts/save-url-to-knowledgetree-intent.md 仕様準拠
- [x] T004 [US1] 上記 `SaveURLToKnowledgeTreeIntent.swift` の同ファイル末尾に `struct KnowledgeTreeShortcuts: AppShortcutsProvider` を実装。`appShortcuts: [AppShortcut]` で `AppShortcut(intent: SaveURLToKnowledgeTreeIntent(), phrases: ["知積に保存", "URL を 知積に保存", "Save to \(.applicationName)"], shortTitle: "保存", systemImageName: "square.and.arrow.down")`。contracts/app-shortcuts-provider.md 仕様準拠

**Checkpoint**: T003-T004 完了で US1 完成。実機で Shortcuts.app に自動登録確認 (SC-001)

---

## Phase 4: User Story 2 (P1) — Shortcut から URL を保存

**Goal**: 「知積に保存」アクションを Shortcut で実行 → URL が SwiftData に保存される

**Independent Test**:
- Shortcut から URL 渡す → ライブラリタブに新記事表示
- testSaveValidURLCreatesArticle / testSaveDuplicateURLSilentSkip / testSaveInvalidURLSilentSkip / testSaveWithoutTitleUsesURLAsTitle / testSaveWithTitleStoresTitle PASS

(US2 は T003-T004 で実装済、本 Phase はテスト + 動作確認のみ)

- [x] T005 [US2] `KnowledgeTreeTests/SaveURLToKnowledgeTreeIntentTests.swift` を新規作成 (5 ケース): `testSaveValidURLCreatesArticle` / `testSaveDuplicateURLSilentSkip` / `testSaveInvalidURLSilentSkip` / `testSaveWithoutTitleUsesURLAsTitle` / `testSaveWithTitleStoresTitle`。in-memory ModelContainer (SharedSchema.all) で隔離、`ArticleSavingActor.performSave(url:title:in:)` 静的純関数を直接呼び出し検証。contracts/article-saving-actor.md テスト戦略準拠

**Checkpoint**: T005 完了で US2 完成。`xcodebuild test` で 5 ケース全 PASS、実機で SC-002 / SC-003 / SC-004 確認可能

---

## Phase 5: User Story 4 (P1) — アプリ内 SettingsView で Setup Guide

**Goal**: AI ブレインタブ右上の歯車から SettingsView へ、SettingsView から ChromeShortcutSetupView へ遷移できる

**Independent Test**:
- 歯車タップ → SettingsView 表示
- 「Chrome から自動保存」エントリタップ → ChromeShortcutSetupView 表示
- 「セットアップ完了」ボタンタップ → flag set、戻ると checkmark 表示

- [x] T006 [P] [US4] `KnowledgeTree/Views/SettingsView.swift` を新規作成。Form 形式 + 「外部連携」Section + NavigationLink (`ChromeSetupDestination()`) + safari icon + checkmark (setupCompleted 時) + `@AppStorage("settings.shortcutSetupCompleted")` + `.navigationDestination(for: ChromeSetupDestination.self)` で `ChromeShortcutSetupView()`。`SettingsDestination` / `ChromeSetupDestination` Hashable struct (空) を同ファイル末尾に追加。contracts/settings-view.md 仕様準拠
- [x] T007 [P] [US4] `KnowledgeTree/Views/ChromeShortcutSetupView.swift` を新規作成。ScrollView + VStack + 説明文 + 3 つの stepCard (helper func: number Circle + title + description + optional ActionButton) + Step 1 内の「Shortcuts アプリを開く」ボタン (`UIApplication.shared.open(URL(string: "shortcuts://")!)`) + 「セットアップ完了」/「もう一度見る」ボタン切替 + accessibilityIdentifier 全配置 + dsCardBackground()。contracts/chrome-shortcut-setup-view.md 仕様準拠
- [x] T008 [US4] `KnowledgeTree/Views/AIBrainView.swift` の NavigationStack に `.toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink(value: SettingsDestination()) { Image(systemName: "gearshape").foregroundStyle(DS.Color.actionBlue) }.accessibilityIdentifier("settings.button") } }` を追加 + `.navigationDestination(for: SettingsDestination.self) { _ in SettingsView() }` を追加。research.md R7 仕様準拠

**Checkpoint**: T006-T008 完了で US4 完成。実機で SC-006 / SC-007 / SC-008 / SC-009 / SC-010 確認可能

---

## Phase 6: User Story 3 (P1) — Personal Automation で Chrome 起動時自動保存

**Goal**: ユーザーが Personal Automation を作成 → Chrome 起動時に自動保存

**Independent Test**:
- 実機で Personal Automation 設定 → Chrome 起動 → 知積に新記事保存 (60 秒以内)

(US3 は OS 機能利用、追加実装ゼロ。実機検証のみ)

- [ ] T009 [US3] 実機検証 (quickstart SC-005): Shortcuts.app → 自動化タブ → 「個人用オートメーション」→「アプリ」→ Chrome 選択 →「開く」→ アクション「知積に保存」追加 → URL を「Chrome の現在の URL」に設定 →「実行前に通知」OFF → 保存 → Chrome 起動して自動保存トリガー動作確認。⚠️ Chrome の現在の URL 取得が iOS Shortcuts で動かない場合は固定 URL でテスト、結果を quickstart.md に記録

**Checkpoint**: T009 完了で US3 完成 (ユーザー実機検証、Claude 範囲外)

---

## Phase 7: User Story 5 (P2) — Apple Intelligence 不可端末で動作

**Goal**: App Intent 経路は AI 不要で動作、Simulator / 古い iPhone でも保存自体は完了

**Independent Test**:
- Simulator (Apple Intelligence 不可) で SC-002 と同手順 → 保存成功

(US5 は AI 不要設計、追加実装ゼロ。実機検証のみ)

- [ ] T010 [US5] 実機検証 (quickstart SC-011): Simulator iPhone 17 で Shortcuts.app から「知積に保存」を手動実行 → ライブラリタブで保存確認。AI 抽出は spec 015 Fallback 経由で簡易処理されることも確認

**Checkpoint**: T010 完了で US5 完成 (ユーザー実機検証)

---

## Phase 8: Polish & Cross-Cutting

**Purpose**: 既存テスト回帰確認 + ビルド警告ゼロ + CLAUDE.md + ROADMAP 更新

- [x] T011 [P] `xcodebuild build -scheme KnowledgeTree -destination "platform=iOS Simulator,name=iPhone 17"` でビルド SUCCEEDED + 本 spec 起因 warning ゼロ確認
- [x] T012 [P] `xcodebuild test -scheme KnowledgeTree -destination "platform=iOS Simulator,name=iPhone 17"` で全テスト実行、spec 018 まで 110+ ケース + 新規 5 ケース (SaveURLToKnowledgeTreeIntentTests) 全 PASS 確認 (BodyExtractorTests 2 件は既存 FAIL、本 spec 起因ではない)
- [x] T013 [P] `CLAUDE.md` の spec 019 行を「📝 計画完了」→「✅ 実装」に更新 (commit hash 追記)
- [ ] T014 quickstart 12 シナリオ (SC-001〜SC-012) を実機検証 (ユーザー実施)

---

## Dependencies

```
T001 (Setup: xcstrings)
   ↓
T002 (Foundational: ArticleSavingActor)
   ↓
   ├─→ T003 (US1: SaveURLToKnowledgeTreeIntent) ─┐
   │                                              │
   ├─→ T004 (US1: AppShortcutsProvider) ─────────┤
   │                                              │
   ├─→ T005 (US2: SaveURLToKnowledgeTreeIntentTests) ─┤
   │                                                   │
   ├─→ T006 (US4: SettingsView) ─┬─────────────────────┤
   ├─→ T007 (US4: ChromeShortcutSetupView) ─┤         │
   └─→ T008 (US4: AIBrainView 改修) ─┘                │
                                                       ↓
                                            T009 (US3 実機)
                                            T010 (US5 実機)
                                                       ↓
                                            T011-T013 (Polish 並列)
                                                       ↓
                                            T014 (実機検証)
```

T003 と T004 は同一ファイル (SaveURLToKnowledgeTreeIntent.swift) なので順次実行が安全。T006/T007 は別ファイル、並列可。T008 は AIBrainView 改修なので T006 / T007 と並列可。

## Parallel Opportunities

- T006 (SettingsView) ‖ T007 (ChromeShortcutSetupView) ‖ T008 (AIBrainView): 全部別ファイル、並列実装可
- T011 (build) ‖ T012 (test) ‖ T013 (CLAUDE.md): Polish 段階で並列

## Implementation Strategy

### MVP (US1 + US2 + US4 で価値提供可)

T001-T008 で:
- US1: AppShortcutsProvider 自動登録 (Shortcuts.app に表示)
- US2: Shortcut から URL を保存 (5 ケース PASS)
- US4: SettingsView Setup Guide

US3 (Personal Automation) は OS 機能、ユーザーが Setup Guide を見ながら手動設定。
US5 (fallback 端末) は App Intent 設計上の自動対応、追加実装ゼロ。

### 段階リリース提案

1. **Sprint 1 (MVP)**: Phase 1-5 = T001-T008 (US1 + US2 + US4 完成、Shortcut 経路 + SettingsView deliver)
2. **Sprint 2 (検証)**: Phase 6-7 = T009-T010 (US3 + US5 実機検証)
3. **Sprint 3 (Polish + 検証)**: Phase 8 = T011-T014 (build / test / CLAUDE.md / 実機検証)

実装規模目安: 14 タスク、~540 行 (新規 4 ファイル + 改修 2 ファイル + 新規テスト 1 ファイル)。

## Memo

- AppShortcutsProvider 自動登録は実機で初検証 (本プロジェクト初の AppIntents 統合)
- pbxproj 自動取り込み: KnowledgeTree/AppIntents/ ディレクトリは PBXFileSystemSynchronizedRootGroup で auto-sync 想定、Share Extension target には不要 (App Intent は main app のみ)
- ArticleSavingActor は Share Extension の `ArticleSavingService` (spec 001) と独立、App Group ModelContainer 共有で同 store にアクセス
- Personal Automation の「Chrome 現在の URL」取得は iOS Shortcuts の制約次第、動かなければ将来 spec で改善 (research.md R12)
- 「Hey Siri、知積に保存」音声起動は AppShortcutsProvider phrases で副次的に有効化、本 spec の主目的ではない

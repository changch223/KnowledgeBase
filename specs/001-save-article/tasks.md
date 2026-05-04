---
description: "Task list for spec 001 — 記事保存 (Share Sheet 経由)"
---

# Tasks: 記事保存 (Share Sheet 経由)

**Input**: Design documents from `/specs/001-save-article/`
**Prerequisites**: plan.md (済), spec.md (済), research.md (済), data-model.md (済), contracts/ (済), quickstart.md (済)

**Tests**: 含む。Constitution Quality Gate「テストゲート」が必須化しているため、ユニットテストと UI テストを各 user story に含める。

**Organization**: User story 単位でフェーズ分割。各 user story は独立して実装・テスト可能で、完了時点で **MVP 増分** として動作する。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 並列実行可能 (異なるファイル、未完了タスクへの依存なし)
- **[Story]**: US1 / US2 / US3 — どの user story に属するかを示す
- 各タスクには **絶対ファイルパス** を含める

## Path Conventions

既存の Xcode プロジェクトを拡張する単一プロジェクト構成 (plan.md / Project Structure 参照):

- アプリ本体: `KnowledgeTree/`
- Share Extension target (新規): `KnowledgeTreeShareExtension/`
- ユニットテスト: `KnowledgeTreeTests/`
- UI テスト: `KnowledgeTreeUITests/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 既存 scaffold の整理と新規ディレクトリ・設定の初期化。

- [X] T001 既存の `KnowledgeTree/Item.swift` を削除する (Article モデルに置き換える前提準備)
- [X] T002 既存の `KnowledgeTree/ContentView.swift` を削除する (ArticleListView に置き換える前提準備)
- [X] T003 [P] 新規ディレクトリを作成する: `KnowledgeTree/Models/`、`KnowledgeTree/Services/`、`KnowledgeTree/Views/`、`KnowledgeTree/Localization/`
- [X] T004 [P] App Group ID を確定する。形式は `group.<reverse-domain>.knowledgetree.shared`。値を `KnowledgeTree/Config.xcconfig` (新規) に `APP_GROUP_ID = group.<...>.shared` として記入し、両 target の Build Settings から参照可能にする
- [X] T005 [P] `KnowledgeTree/Localization/Localizable.xcstrings` を作成し、初期言語を「ja」に設定。research.md / R5 のキー一覧 (`share.duplicateMessage`、`share.errorNoURL`、`share.errorUnsupportedScheme`、`share.errorStorage`、`share.savedConfirmation`、`list.empty.title`、`list.deleteAction`) を日本語値で登録

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: すべての user story が依存する基盤コード。Phase 3 以降の着手前に完了必須。

**⚠️ CRITICAL**: このフェーズ完了前は user story 着手不可。

- [X] T006 [P] `KnowledgeTree/Models/Article.swift` を実装する。SwiftData `@Model` クラス、attributes は `id: UUID` (主キー、`@Attribute(.unique)`)、`url: String`、`title: String`、`savedAt: Date`。data-model.md の SwiftData macro 構成セクションに従う
- [X] T007 `KnowledgeTree/Services/ArticleStore.swift` を実装する。`ArticleStoreProtocol` (Sendable) と `SwiftDataArticleStore` 実装を定義。`exists(url:)` は `FetchDescriptor<Article>` + `#Predicate { $0.url == url }` + `fetchLimit = 1`。`insert` / `delete` / `fetchAllSortedBySavedAt` を実装。`ArticleStoreError.persistenceFailure(underlying:)` enum も定義 (contracts/article-store.md)
- [ ] T008 `KnowledgeTree.xcodeproj` に新規 target `KnowledgeTreeShareExtension` (Share Extension テンプレート) を追加する。Bundle ID は app の `<bundle-id>.ShareExtension` 形式
- [ ] T009 `KnowledgeTreeShareExtension/KnowledgeTreeShareExtension.entitlements` を作成し、App Group capability を T004 で決めた ID で有効化する
- [ ] T010 既存 app target (`KnowledgeTree`) に App Group capability を追加し、entitlements file を生成・T004 の ID を登録する
- [ ] T011 Xcode File Inspector で `KnowledgeTree/Models/Article.swift` と `KnowledgeTree/Services/ArticleStore.swift` の Target Membership を **`KnowledgeTree` と `KnowledgeTreeShareExtension` の両方** で ON にする
- [X] T012 `KnowledgeTree/KnowledgeTreeApp.swift` を更新する: `ModelConfiguration(schema:, groupContainer: .identifier(<APP_GROUP_ID>))` を使い、schema を `[Article.self]` に変更。失敗時の `fatalError` は許容範囲 (Constitution Code Quality Gate の例外)

**Checkpoint**: 基盤完成。User story 着手可能。

---

## Phase 3: User Story 1 — 共有から保存して一覧で確認できる (Priority: P1) 🎯 MVP

**Goal**: ユーザーが Share Sheet 経由で URL を保存し、アプリ起動時に一覧で確認できる。重複保存は拒否される。

**Independent Test**: 任意のアプリの共有メニューから KnowledgeTree を選び、その後アプリを起動して保存記事のタイトルが一覧の最上段に表示される。同じ URL を再共有すると「既に保存済みです」が表示され、重複は作られない。

### Tests for User Story 1 (Constitution テストゲート: 必須)

> **NOTE: テストは実装前に書き、まず FAIL することを確認してから実装に入る (TDD は spec で必須化されていないが、SwiftData / Share 系は副作用が多いため tests-first を推奨)**

- [X] T013 [P] [US1] `KnowledgeTreeTests/ArticleSavingServiceTests.swift` を作成する。`MockArticleStore` を内部で定義し、contracts/article-saving-service.md の "Tests" 表にある 8 ケース (通常保存 / URL 不在 / 非対応スキーム / Title 空→host fallback / Title 空+host nil→absoluteString fallback / 重複保存 / 重複後 savedAt 不変 / persistence エラー) を全て網羅
- [X] T014 [P] [US1] `KnowledgeTreeTests/SwiftDataArticleStoreTests.swift` を作成する。`ModelContainer(for: Article.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))` で in-memory Container を構築し、`SwiftDataArticleStore` の `insert` → `exists` → `fetchAllSortedBySavedAt` → `delete` の往復を検証

### Implementation for User Story 1

- [X] T015 [US1] `KnowledgeTree/Services/ArticleSavingService.swift` を実装する。`ArticleSavingServiceProtocol` (Sendable) と `DefaultArticleSavingService` 実装、`SaveResult` enum を定義 (contracts/article-saving-service.md)。validation 順序: missingURL → unsupportedScheme → 重複チェック (`store.exists(url:)`) → Title fallback → `Article` 生成 → `store.insert`
- [ ] T016 [US1] `KnowledgeTree/Services/ArticleSavingService.swift` の Target Membership を **`KnowledgeTree` と `KnowledgeTreeShareExtension` の両方** で ON にする
- [X] T017 [P] [US1] `KnowledgeTreeShareExtension/ShareReceivedItem.swift` を実装する。`url: URL?` と `suppliedTitle: String?` を持つ Sendable struct (contracts/share-received-item.md)
- [X] T018 [US1] `KnowledgeTreeShareExtension/ShareViewController.swift` を実装する。`UIViewController` を継承。`viewDidAppear` で `extensionContext.inputItems` から `NSExtensionItem` → `UTType.url` attachment → `loadItem(forTypeIdentifier:)` で URL 抽出 (research.md / R2 のスニペット参照)。`ShareReceivedItem` 経由で `DefaultArticleSavingService.save(...)` を呼び、`SaveResult` をユーザーに 1 秒以内表示してから `extensionContext.completeRequest(returningItems:nil)` で dismiss。表示文言は `Localizable.xcstrings` から取得 (`share.savedConfirmation` / `share.duplicateMessage` / `share.errorNoURL` / `share.errorUnsupportedScheme` / `share.errorStorage`)
- [X] T019 [US1] `KnowledgeTreeShareExtension/Info.plist` を編集し、`NSExtension.NSExtensionAttributes.NSExtensionActivationRule` に `NSExtensionActivationSupportsWebURLWithMaxCount = 1` を設定して URL のみ受理する
- [X] T020 [P] [US1] `KnowledgeTree/Views/EmptyStateView.swift` を実装する。`Localizable.xcstrings` の `list.empty.title` を表示する落ち着いた SwiftUI View。`accessibilityIdentifier("articleListEmpty")` を付与
- [X] T021 [US1] `KnowledgeTree/Views/ArticleListView.swift` を実装する。`@Query<Article>(sort: \.savedAt, order: .reverse)` で取得。0 件時は `EmptyStateView()` を、1 件以上あるときは `List` でタイトル(主)+URL(副) の行を表示。各行に `accessibilityIdentifier("articleListRow")`、行に `accessibilityLabel("\(title), \(url)")` を付与
- [X] T022 [US1] `KnowledgeTree/KnowledgeTreeApp.swift` の `WindowGroup` 内を `ContentView()` から `ArticleListView()` に置換
- [X] T023 [P] [US1] `KnowledgeTreeUITests/SaveArticleUITests.swift` を作成し、以下の UI テストを実装: (a) アプリ起動 → `articleListEmpty` 要素が表示される (空状態)、(b) シード経路で記事 1 件をテスト用 ModelContainer に投入後、`articleListRow` が 1 件表示される、(c) Acceptance Scenario 3 (新しい順並び) を 2 件シードで検証

**Checkpoint**: User Story 1 完成。Share Sheet → 保存 → 一覧表示 → 重複拒否 が動く MVP 状態。

---

## Phase 4: User Story 2 — 元記事をブラウザで再閲覧する (Priority: P2)

**Goal**: 一覧の任意の行をタップして、内蔵ブラウザビュー (Safari View Controller) で元 URL を開ける。

**Independent Test**: シード済みの一覧から行をタップ → SVC が画面を覆い、元 URL がロードされる。「完了」を押すと一覧に戻る。

### Tests for User Story 2

- [ ] T024 [P] [US2] `KnowledgeTreeUITests/SaveArticleUITests.swift` に「行タップ → SVC 表示 → 完了 → 一覧復帰」の UI テストを追加する。SVC 内部の WebKit には触れず、SVC 表示状態の検出 (例: SVC 内の "完了" ボタンの存在) と dismiss 後の元画面復帰のみを assertion

### Implementation for User Story 2

- [X] T025 [US2] `KnowledgeTree/Views/SafariView.swift` を実装する。`UIViewControllerRepresentable` で `SFSafariViewController(url:)` をラップ (research.md / R4 のスニペット参照)。`accessibilityIdentifier("articleSafariView")` を root に付与
- [X] T026 [US2] `KnowledgeTree/Views/ArticleListView.swift` を更新する: `@State private var selectedArticle: Article?` を追加、List 行を `Button(action: { selectedArticle = article })` で wrap し、`.sheet(item: $selectedArticle) { SafariView(url: URL(string: $0.url)!) }` を追加。URL parse 失敗時は `nil` 行は無視 (本 spec ではスキーム validation 済なので発生しない想定)

**Checkpoint**: User Story 2 完成。Acceptance Scenario 1〜2 が成立。

---

## Phase 5: User Story 3 — 不要な記事を削除する (Priority: P3)

**Goal**: 一覧の行を左にスワイプして「削除」を押すと即削除され、再起動後も復活しない。

**Independent Test**: シード済みの一覧から行をスワイプ削除 → 行が即消える → アプリを完全終了して再起動 → 削除済み行は復活しない。

### Tests for User Story 3

- [ ] T027 [P] [US3] `KnowledgeTreeUITests/SaveArticleUITests.swift` に「スワイプ → 削除 → 行消失 → 再起動後も削除済み」の UI テストを追加。`articleDeleteAction` 要素に対するタップを使用

### Implementation for User Story 3

- [X] T028 [US3] `KnowledgeTree/Views/ArticleListView.swift` を更新する: `List` の `ForEach` に `.onDelete { offsets in ... }` を追加し、対象 `Article` を `SwiftDataArticleStore.delete(_:)` 経由で削除。`@Environment(\.modelContext)` を使ってコンテキスト経由で削除すること (Apple HIG 準拠: 確認ダイアログなしの即削除)。スワイプアクションには `accessibilityIdentifier("articleDeleteAction")` と `Localizable.xcstrings` の `list.deleteAction` キーを使用

**Checkpoint**: User Story 3 完成。spec 001 の全 user story が実装済み。

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Quality Gate / Constitution 準拠の最終仕上げ。

- [X] T029 [P] アクセシビリティ確認: 全インタラクティブ要素 (`articleListRow`、`articleListEmpty`、`articleDeleteAction`、`articleSafariViewDoneButton`、`shareExtensionStatusLabel`) に `accessibilityIdentifier` が付与されていることを `grep -rn 'accessibilityIdentifier' KnowledgeTree/ KnowledgeTreeShareExtension/` で確認
- [X] T030 [P] 文言確認: `KnowledgeTree/Localization/Localizable.xcstrings` の全キーが日本語値を持ち、コード内に英語生文字列リテラルが含まれていないことを `grep -rn 'Text("[A-Za-z]' KnowledgeTree/ KnowledgeTreeShareExtension/` で確認 (Principle VII / FR-011 / SC-008)
- [ ] T031 [P] パフォーマンス測定: Debug ビルドで 1000 件の `Article` を seed → Instruments の SwiftUI Time Profiler で 60 fps スクロールを確認 → 結果を `specs/001-save-article/perf-results.md` に保存して PR description に貼付 (SC-003)
- [ ] T032 [P] パフォーマンス測定: 行タップから SVC 表示までの時間を Instruments で計測し 300 ms 以内を確認 → `specs/001-save-article/perf-results.md` に追記 (SC-004)
- [ ] T033 quickstart.md の手動検証 (US1〜US3 + Edge Cases + Accessibility) を実機 / シミュレータで全項目実施し、各「Pass」を埋めた状態で PR description に貼付
- [X] T034 plan.md の Constitution Check 11 項目を最終確認し、すべて [x] のままであることを review (Phase 1 設計時の状態を維持)
- [ ] T035 Constitution の deferred TODO (`TARGETED_DEVICE_FAMILY = "1,2,7"` → `"1,2"` への絞り込み、macOS deployment target 整理) は別 PR で扱う前提で、本 PR description にリンクメモを残す

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: 依存なし、即着手可
- **Phase 2 (Foundational)**: Phase 1 完了後。**全 user story の前提**
- **Phase 3 (US1 / P1)**: Phase 2 完了後。最初に着手して MVP として Stop-and-Validate
- **Phase 4 (US2 / P2)**: Phase 3 完了が望ましい (US2 は ArticleListView の拡張のため)
- **Phase 5 (US3 / P3)**: Phase 3 完了後 (US3 も ArticleListView の拡張)
- **Phase 6 (Polish)**: 全 user story 完了後

### User Story Dependencies (技術的)

- **US1 (P1)**: Phase 2 のみに依存 — 完全独立
- **US2 (P2)**: US1 の `ArticleListView` 存在に依存 (List 行をタップ可能にする)。理論的には US1 と分離可能だが MVP では US1 → US2 順を推奨
- **US3 (P3)**: US1 の `ArticleListView` 存在に依存 (List に `.onDelete` を追加する)。US2 と並列可能

### Within Each User Story

- Tests を先に書き、FAIL 確認後に実装着手 (TDD 推奨、必須ではない)
- Models / Services → Views → 統合の順
- Story 完了 → 次 Priority へ

### Parallel Opportunities

- **Phase 1**: T003 / T004 / T005 は並列可
- **Phase 2**: T006 のみ [P] (他は順序依存大)
- **Phase 3 (US1)**: T013 と T014 は並列。T017 と T020 は並列。T023 は実装後だが他テストと独立で並列可
- **Phase 4 vs Phase 5**: US2 と US3 は実装が異なる ArticleListView 拡張だが、同じファイルを編集するため **直列** (UI テストは並列可能だが、実装は競合)
- **Phase 6**: T029 / T030 / T031 / T032 はすべて並列実行可能

---

## Parallel Example: User Story 1 のテスト並列実行

```bash
# US1 のテストを並列で書く (実装前):
Task: "ArticleSavingServiceTests.swift を作成 (8 ケース)"   # T013 [P]
Task: "SwiftDataArticleStoreTests.swift を作成"             # T014 [P]
```

```bash
# US1 の実装後、独立コンポーネントを並列実装:
Task: "ShareReceivedItem.swift を実装"                       # T017 [P]
Task: "EmptyStateView.swift を実装"                          # T020 [P]
```

---

## Implementation Strategy

### MVP First (User Story 1 のみ)

1. Phase 1 (Setup) を完了
2. Phase 2 (Foundational) を完了 — **CRITICAL**、ブロッキング
3. Phase 3 (US1) を完了
4. **STOP and VALIDATE**: quickstart.md の US1 セクション + 重複検出 (Acceptance Scenario 5) を手動検証
5. ここで Demo 可能 (MVP achieved)

### Incremental Delivery

1. Setup + Foundational → 基盤 ready
2. US1 → 検証 → Demo (MVP)
3. US2 (元記事閲覧) → 検証 → Demo
4. US3 (削除) → 検証 → Demo
5. Polish → PR

### Solo Developer Strategy

ソロ開発者向け推奨ペース (constitution Principle II: MVP first / 個人開発者の resource を集中):

- 1 セッション目: Phase 1 + Phase 2 (基盤)
- 2 セッション目: Phase 3 / US1 のテスト + Service 実装 + Share Extension
- 3 セッション目: Phase 3 / US1 の View 実装 + UI テスト + 手動検証
- 4 セッション目: Phase 4 / US2 (SafariView 統合)
- 5 セッション目: Phase 5 / US3 (削除) + Phase 6 (Polish) + PR

---

## Notes

- [P] タスク = 異なるファイルへの編集、依存なし
- [Story] タグは user story 単位で実装/テスト/デプロイ可能性を担保するためのトレーサビリティ
- 各 user story 完了時点で **Stop-and-Validate** を行うこと
- テスト実装前に必ず FAIL を確認すること (TDD 推奨)
- 各タスクまたは論理グループ完了ごとに commit
- 巨大 SwiftUI View に詰め込まない (Constitution Principle VI / コード品質ゲート)
- 全 UI 文言は `Localizable.xcstrings` 経由 (Constitution Principle VII / FR-011)

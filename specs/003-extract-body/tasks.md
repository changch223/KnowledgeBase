---
description: "Task list for spec 003 — 本文抽出 (Reader View)"
---

# Tasks: 本文抽出 (Reader View)

**Input**: Design documents from `/specs/003-extract-body/`
**Prerequisites**: plan.md (済), spec.md (済), research.md (済), data-model.md (済), contracts/ (済), quickstart.md (済)

**Tests**: 含む。Constitution Quality Gate「テストゲート」が必須化しているため、`BodyExtractor` (純関数) と `BodyExtractionService` (orchestration) と `SwiftDataArticleBodyStore` の各層をユニットテスト + Reader / SVC 切替 UI を UI テストで担保。

**Organization**: User story 単位でフェーズ分割。各 user story は独立して実装・テスト可能。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 並列実行可能 (異なるファイル、未完了タスクへの依存なし)
- **[Story]**: US1 / US2 / US3 — どの user story に属するかを示す
- 各タスクには **絶対ファイルパス** を含める

## Path Conventions

spec 001 / 002 の Xcode project を **拡張する** 単一プロジェクト構成。target 追加なし、ファイル追加のみ。

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Reader View 用日本語キーと test fixture を準備。

- [ ] T001 [P] `KnowledgeTree/Localization/Localizable.xcstrings` に新規キーを追加: `reader.doneButton` (完了)、`reader.openOriginalButton` (元記事を開く)、`reader.navigationTitle` (記事を読む)。値はすべて日本語
- [ ] T002 [P] HTML test fixtures を作成: `KnowledgeTreeTests/Fixtures/body-article-tag.html`、`body-main-tag.html`、`body-no-semantic.html`、`body-boilerplate-heavy.html`、`body-too-short.html`、`body-with-images.html`、`body-with-links.html`、`body-with-lists.html`、`body-japanese.html`、`body-broken.html` (research.md / R7 の 10 種類)。spec 002 の `MetadataParser` 用 fixture と一部共有可能なら流用

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: ArticleBody schema 拡張と Article への relationship 追加。

**⚠️ CRITICAL**: このフェーズ完了前は user story 着手不可。

- [ ] T003 `KnowledgeTree/Models/ArticleBody.swift` を作成する。SwiftData `@Model` クラス、attributes は data-model.md の SwiftData 構成に従う (`id` UUID 主キー、`article: Article` non-optional 参照、`statusRaw: String`、`extractedText: Optional`、`extractionVersion: Int = 1`、`lastExtractedAt: Optional`)。`BodyExtractionStatus` enum + getter/setter extension も同 file に定義
- [ ] T004 `KnowledgeTree/Models/Article.swift` を更新する: `@Relationship(deleteRule: .cascade, inverse: \ArticleBody.article) var body: ArticleBody?` を追加。既存 `enrichment` relationship はそのまま保持
- [ ] T005 `KnowledgeTree/KnowledgeTreeApp.swift` を更新する: `Schema([Article.self, ArticleEnrichment.self])` を `Schema([Article.self, ArticleEnrichment.self, ArticleBody.self])` に拡張。SwiftData lightweight migration で吸収
- [ ] T006 `KnowledgeTree/Models/ArticleBody.swift` の Target Membership を **`KnowledgeTree` のみ** で ON にする (Share Extension 未使用)

**Checkpoint**: 基盤完成。User story 着手可能。

---

## Phase 3: User Story 1 — アプリ内 Reader View で本文を読める (Priority: P1) 🎯 MVP

**Goal**: spec 002 で enrichment 成功した記事の rawHTML から本文を抽出し、一覧タップ時に **アプリ内 Reader View** で plain text 本文を快適に読める。

**Independent Test**: enrichment 成功 & ArticleBody .succeeded 状態の記事を一覧でタップ → アプリ内 Reader View が画面を覆い、本文が読みやすい typography で表示。広告 / nav / サイドバーは含まれない。「完了」で一覧に戻る。

### Tests for User Story 1 (Constitution テストゲート: 必須)

> **NOTE: テスト先行 (TDD 推奨)。BodyExtractor は純関数で fixture テストが容易。**

- [ ] T007 [P] [US1] `KnowledgeTreeTests/BodyExtractorTests.swift` を作成する。Phase 1 で作った fixture HTML 10 種を読み込み、contracts/body-extractor.md の Tests 表にある 11 ケース (`<article>` typical、`<main>` typical、no semantic→density、boilerplate heavy、too short→nil、with images→除去、with links→URL捨て、with lists→箇条書き化、Japanese、broken→parseFailed、空文字列→parseFailed) を全網羅
- [ ] T008 [P] [US1] `KnowledgeTreeTests/SwiftDataArticleBodyStoreTests.swift` を作成する。`isStoredInMemoryOnly: true` で contracts/article-body-store.md の Tests 表 7 ケース (upsert 新規 / 更新 / fetchPendingArticles 空 / rawHTML なし除外 / 混在 / cascade delete / deleteAll) を網羅
- [ ] T009 [P] [US1] `KnowledgeTreeTests/BodyExtractionServiceTests.swift` を作成する。`MockBodyExtractor` + `MockArticleBodyStore` で **成功パス系のみ** テスト (US1 範囲): 通常成功 / rawHTML nil → no-op / 既に .succeeded → no-op / backfill 複数件。失敗系は Phase 4 / US2

### Implementation for User Story 1

- [ ] T010 [US1] `KnowledgeTree/Services/BodyExtractor.swift` を実装する。`struct BodyExtractor` + `static func extract(html:) -> ParsedBody`。research.md / R1 の 2 段階ヒューリスティック (semantic タグ優先 → text-density スコアリング)、研究 R2 の HTML→text 規則 (段落 / 箇条書き / 引用保持、`<img>`/`<video>`/`<iframe>` 完全除去、リンク URL 捨て)。Foundation 標準のみ、サードパーティ禁止
- [ ] T011 [US1] `KnowledgeTree/Services/ArticleBodyStore.swift` を実装する。`ArticleBodyStoreProtocol` + `SwiftDataArticleBodyStore` (`@MainActor`、`ModelContext` 内包)。`upsert` / `fetchPendingArticles` / `deleteAll` を実装 (contracts/article-body-store.md)。`fetchPendingArticles` の predicate は `body == nil AND enrichment != nil AND enrichment.rawHTML != nil`
- [ ] T012 [US1] `KnowledgeTree/Services/BodyExtractionService.swift` を実装する。`BodyExtractionServiceProtocol` + `DefaultBodyExtractionService`。`extract(article:)` は: 既に succeeded/permanentlyFailed なら no-op → rawHTML nil なら no-op → store.upsert(.extracting) → `Task.detached(priority: .utility)` で `BodyExtractor.extract(html:)` 実行 → 結果 100文字未満なら .failed、それ以外 .succeeded で store.upsert (contracts/body-extraction-service.md)
- [ ] T013 [US1] `KnowledgeTree/Services/ArticleEnrichmentService.swift` を更新する: init に optional `bodyExtractionService: BodyExtractionServiceProtocol?` を追加。enrichment .succeeded 時 (store.upsert 直後) に `Task { await bodyExtractionService?.extract(article:) }` を発行 (await せず fire-and-forget)。spec 002 の既存テストを破壊しないよう default は nil
- [ ] T014 [US1] `KnowledgeTree/KnowledgeTreeApp.swift` を更新する: `BodyExtractionService` を bootstrap 時に作成し、`ArticleEnrichmentService` の init に inject。`.task { await bodyExtractionService.backfillAll() }` を `WindowGroup` に追加 (spec 002 の enrichment backfill と並列ではなく直列でも可)
- [ ] T015 [P] [US1] `KnowledgeTree/Views/ReaderView.swift` を実装する。引数に `Article` を取り、`ScrollView` 内に `LazyVStack` + `Text(article.body?.extractedText ?? "")` を段落ごとに描画 (research.md / R3: `.font(.body)` + `.lineSpacing(8)` + `.frame(maxWidth: 680)` + `.padding(.horizontal, 24)`)。`navigationTitle("reader.navigationTitle")`。`.accessibilityIdentifier("readerView")` を root に
- [ ] T016 [P] [US1] `KnowledgeTree/Views/ReaderToolbar.swift` を実装する。SwiftUI `ToolbarContent` を返す struct。最初は **「完了」ボタン (dismiss action) のみ**。`.accessibilityIdentifier("readerDoneButton")`、文言は `Localizable.xcstrings` の `reader.doneButton`。「元記事を開く」ボタンは Phase 5 / US3 で追加
- [ ] T017 [US1] `KnowledgeTree/Views/ArticleListView.swift` を更新する: `selectedRoute: ArticleRoute?` enum state を追加 (`enum ArticleRoute: Identifiable { case reader(Article); case safari(URL) }`)。行タップ時に `article.body?.status == .succeeded` なら `.reader(article)` を、それ以外なら `.safari(URL(string: article.url)!)` を `selectedRoute` に set。`.sheet(item: $selectedRoute) { route in ... }` で 2 種の View を出し分け
- [ ] T018 [P] [US1] `KnowledgeTreeUITests/SaveArticleUITests.swift` に Reader View 表示テストを追加する。launch arg (例 `--ui-test-seed-body-succeeded`) で in-memory mode で Article + ArticleBody(.succeeded, extractedText: "...") を seed → 起動 → 行タップ → `readerView` が表示されることを assert

**Checkpoint**: User Story 1 完成。enrichment 成功記事の Reader View 表示が動く MVP 状態。

---

## Phase 4: User Story 2 — 抽出失敗 / 未抽出時は SVC にフォールバック (Priority: P2)

**Goal**: 抽出失敗・rawHTML 不在・抽出 pending 状態の記事は、行タップ時に Reader View ではなく SafariViewController が起動する。spec 001 / 002 の挙動を維持し、UX 後退ゼロ。

**Independent Test**: ArticleBody .failed の記事をシード → 行タップ → SVC が起動する (Reader は出ない)。ArticleBody 不在の記事も同様。

### Tests for User Story 2

- [ ] T019 [P] [US2] `KnowledgeTreeTests/BodyExtractionServiceTests.swift` に failure ケースを追加 (4 ケース): (a) Mock Extractor が `ParsedBody(extractedText: nil, strategy: .parseFailed)` 返却 → store.upsert(.failed)、(b) Mock Extractor が "短い文字列" (50 文字) 返却 → store.upsert(.failed, text: nil)、(c) rawHTML 有り & body 不在 → backfill が拾う、(d) Mock Store が throw → status `.extracting` のまま (rollback せず、次回 backfill で再試行可能)

### Implementation for User Story 2

- [ ] T020 [US2] `KnowledgeTree/Views/ArticleListView.swift` の遷移先判定 (T017) を明示的にハンドリング: `body?.status` が `.succeeded` 以外 (`.failed` / `.permanentlyFailed` / `.pending` / `.extracting` / nil) は **すべて SVC 直行** (Reader を試みない)。論理は 1 行の switch で書き、test 可能にする
- [ ] T021 [P] [US2] `KnowledgeTreeUITests/SaveArticleUITests.swift` に SVC フォールバックテストを追加する。launch arg で 3 種シード: (a) ArticleBody .failed、(b) ArticleBody 不在、(c) ArticleBody .pending → 各 Article 行タップで SVC が起動 (= `readerView` は表示されない、SVC の標準 toolbar 等で SVC 表示を検出) を assert

**Checkpoint**: User Story 2 完成。失敗 / 未抽出時のフォールバック動作確認。

---

## Phase 5: User Story 3 — Reader View 表示中も元記事に戻れる (Priority: P3)

**Goal**: Reader View 表示中の toolbar に「元記事を開く」ボタンを追加し、タップで SafariViewController を modal で重ねて起動できる。

**Independent Test**: Reader 表示中に「元記事を開く」をタップ → SVC が Reader の上に表示 → SVC の「完了」で SVC 閉じる → Reader 復帰。

### Tests for User Story 3

- [ ] T022 [P] [US3] `KnowledgeTreeUITests/SaveArticleUITests.swift` に「Reader 表示中 → 元記事ボタン → SVC 表示 → 完了 → Reader 復帰」テストを追加する。launch arg で .succeeded body をシード → 行タップで Reader 表示 → `readerOpenOriginalButton` タップ → SVC 表示確認 → SVC 内の「完了」を押して Reader に戻ることを assert

### Implementation for User Story 3

- [ ] T023 [US3] `KnowledgeTree/Views/ReaderToolbar.swift` を更新する: 既存「完了」ボタンに加えて「元記事を開く」ボタンを追加。`.accessibilityIdentifier("readerOpenOriginalButton")`、文言は `reader.openOriginalButton` キー。SF Symbol `safari` 想定。tap action は callback で受け取る (`onOpenOriginal: () -> Void`)
- [ ] T024 [US3] `KnowledgeTree/Views/ReaderView.swift` を更新する: `@State private var presentedSafariURL: URL?` を追加、`ReaderToolbar` の `onOpenOriginal` で `presentedSafariURL = URL(string: article.url)` を set。`.sheet(item:)` で `SafariView(url:)` を Reader の上に modal 重ね表示 (`Identifiable` ラッパが必要)

**Checkpoint**: User Story 3 完成。spec 003 の全 user story 達成。

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Quality Gate 最終仕上げ + Network 非依存の確認。

- [ ] T025 [P] アクセシビリティ確認: `grep -rn 'accessibilityIdentifier' KnowledgeTree/Views/Reader*` で `readerView` / `readerDoneButton` / `readerOpenOriginalButton` の付与を確認
- [ ] T026 [P] 文言確認: `grep -rnE 'Text\("[A-Za-z]' KnowledgeTree/Views/Reader*` で英語生文字列リテラルなし、`reader.*` キーが Localizable.xcstrings に登録されていることを確認 (Principle VII / FR-007 / FR-008)
- [ ] T027 [P] パフォーマンス計測: 1 件 enrichment 完了から ArticleBody .succeeded 到達まで median 1 秒以内 (10 サンプル測定 → `specs/003-extract-body/perf-results.md` に記録、PR description に貼付) (SC-001)
- [ ] T028 [P] パフォーマンス計測: 一覧タップから Reader View 表示まで Instruments で 300 ms 以内を確認 → `perf-results.md` に追記 (SC-002)
- [ ] T029 [P] パフォーマンス計測: 抽出ジョブ実行中に一覧スクロール (100 件) → main thread 占有 ≤ 100 ms → `perf-results.md` に追記 (SC-004)
- [ ] T030 [P] パフォーマンス計測: 100 件 ArticleBody 持ち一覧の 60 fps スクロール → `perf-results.md` に追記 (SC-006)
- [ ] T031 ネットワーク監視: Charles Proxy / Console.app で本 spec 起因のネットワークリクエストが **ゼロ** であることを確認 (spec 002 のリクエストは別、本 spec の起動・抽出・Reader 表示・backfill では network ハンドシェイクすら発生しないこと)。`specs/003-extract-body/network-audit.md` に記録 (Principle I 完全維持の証跡)
- [ ] T032 quickstart.md の手動検証 (US1〜US3 + Edge Cases + Performance + Network 監視 + Accessibility) を実機 / シミュレータで全項目実施し、各「Pass」を埋めた状態で PR description に貼付 (Constitution Per-PR ゲート)
- [ ] T033 plan.md の Constitution Check 11 項目を最終再確認、すべて [x] のままを review (Phase 1 設計時の状態を維持、特に Principle I の「新規ネットワーク非依存」が実装で violate されていないこと)
- [ ] T034 PR description に「本 spec 003 はネットワーク非依存、Principle I を完全維持。spec 002 のキャッシュ rawHTML を再利用して新規送信ゼロ」のメモを記載

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: 依存なし
- **Phase 2 (Foundational)**: Phase 1 完了後。**全 user story の前提** (schema 拡張)
- **Phase 3 (US1 / P1)**: Phase 2 完了後。最初に着手して MVP として Stop-and-Validate
- **Phase 4 (US2 / P2)**: Phase 3 完了が望ましい (US2 は Service 層の failure ハンドリング + ArticleListView の T017 判定をブラッシュアップ)
- **Phase 5 (US3 / P3)**: Phase 3 完了後 (Reader View / ReaderToolbar の存在が前提)
- **Phase 6 (Polish)**: 全 user story 完了後

### User Story Dependencies (技術的)

- **US1 (P1)**: Phase 2 のみに依存 — 完全独立 (成功パスだけで完結する MVP)
- **US2 (P2)**: US1 の Service / Store / ArticleListView に依存
- **US3 (P3)**: US1 の ReaderView / ReaderToolbar に依存。US2 とは独立 (並列可)

### Within Each User Story

- Tests を先に書き FAIL を確認してから実装着手 (TDD 推奨)
- Models / Services → Views → 統合の順
- Story 完了 → Stop-and-Validate (quickstart.md 該当セクション)

### Parallel Opportunities

- **Phase 1**: T001 / T002 並列
- **Phase 2**: T003-T006 はすべて順序依存 (relationship + schema)
- **Phase 3 (US1)**: T007 / T008 / T009 はテスト並列。T010 / T011 / T012 は Service 実装で順序依存 (Service が Extractor + Store を使う)。T013 / T014 は順序依存 (Service injection)。T015 / T016 / T018 は独立 View / test で並列可。T017 のみ ArticleListView の編集なので直列
- **Phase 4 (US2)**: T019 単独。T020 / T021 はリレートして直列気味
- **Phase 5 (US3)**: T023 / T024 は同一 Reader 系ファイル編集で直列。T022 はテスト並列可
- **Phase 6 (Polish)**: T025-T030 すべて並列実行可能

---

## Parallel Example: User Story 1 のテスト並列実行

```bash
# US1 のテスト 3 本を並列で書く (実装前):
Task: "BodyExtractorTests.swift を作成 (11 ケース、フィクスチャベース)"  # T007 [P]
Task: "SwiftDataArticleBodyStoreTests.swift を作成 (7 ケース)"            # T008 [P]
Task: "BodyExtractionServiceTests.swift を作成 (成功パスのみ)"            # T009 [P]
```

```bash
# US1 の独立 View / test を並列実装:
Task: "ReaderView.swift を実装"                                 # T015 [P]
Task: "ReaderToolbar.swift (完了ボタンのみ) を実装"             # T016 [P]
Task: "SaveArticleUITests に Reader 表示テストを追加"           # T018 [P]
```

---

## Implementation Strategy

### MVP First (User Story 1 のみ)

1. Phase 1 (Setup) を完了
2. Phase 2 (Foundational) を完了 — **CRITICAL**、ブロッキング
3. Phase 3 (US1) を完了
4. **STOP and VALIDATE**: quickstart.md の US1 セクションを手動検証 (enrichment 成功記事をタップ → Reader 表示)
5. Demo 可能 (MVP achieved)

### Incremental Delivery

1. Setup + Foundational → 基盤 ready
2. US1 → 検証 → Demo (Reader View が動く MVP)
3. US2 (失敗フォールバック) → 検証 → Demo
4. US3 (元記事を開くボタン) → 検証 → Demo
5. Polish → PR

### Solo Developer Strategy

ソロ開発者向け推奨ペース (Constitution Principle II):

- 1 セッション目: Phase 1 + Phase 2 (基盤) + US1 のテスト 3 本
- 2 セッション目: US1 の Extractor / Store / Service 実装 + Service inject (T013) + backfill bootstrap (T014)
- 3 セッション目: US1 の Reader / ReaderToolbar / ArticleListView 切替実装 + UI テスト
- 4 セッション目: US2 の failure ハンドリング + テスト → US3 の 元記事ボタン + .sheet 統合 + テスト
- 5 セッション目: Polish (Performance 計測 / Network 監査 / quickstart 手動検証) + PR

---

## Notes

- [P] タスク = 異なるファイルへの編集、依存なし
- [Story] タグは user story 単位で実装/テスト/デプロイ可能性を担保するためのトレーサビリティ
- 各 user story 完了時点で **Stop-and-Validate** を行うこと
- テスト実装前に必ず FAIL を確認すること (TDD 推奨)
- 各タスクまたは論理グループ完了ごとに commit
- 巨大 SwiftUI View に詰め込まない (Principle VI、本 spec で `ReaderView` と `ReaderToolbar` を分離した理由)
- 全 UI 文言は `Localizable.xcstrings` 経由 (Principle VII)
- **本 spec はネットワーク非依存** (Principle I 完全維持)。実装中に新規 URLSession / fetch を追加しないこと (T031 の audit で確認)

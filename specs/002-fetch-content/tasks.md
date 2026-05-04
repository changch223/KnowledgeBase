---
description: "Task list for spec 002 — 本文取得・メタデータエンリッチメント"
---

# Tasks: 本文取得・メタデータエンリッチメント

**Input**: Design documents from `/specs/002-fetch-content/`
**Prerequisites**: plan.md (済), spec.md (済), research.md (済), data-model.md (済), contracts/ (済), quickstart.md (済)

**Tests**: 含む。Constitution Quality Gate「テストゲート」が必須化しているため、`MetadataParser` (純関数) と `ArticleEnrichmentService` (retry / backoff 含む) と `SwiftDataArticleEnrichmentStore` の各層をユニットテスト + 一覧 View の状態を UI テスト。

**Organization**: User story 単位でフェーズ分割。各 user story は独立して実装・テスト可能。完了時点で **MVP 増分** として動作する。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 並列実行可能 (異なるファイル、未完了タスクへの依存なし)
- **[Story]**: US1 / US2 — どの user story に属するかを示す
- 各タスクには **絶対ファイルパス** を含める

## Path Conventions

spec 001 の Xcode project を **拡張する** 単一プロジェクト構成 (plan.md / Project Structure 参照):

- アプリ本体: `KnowledgeTree/` (新規 Service 群はここに追加)
- Share Extension: `KnowledgeTreeShareExtension/` (本 spec では変更なし)
- ユニットテスト: `KnowledgeTreeTests/`
- UI テスト: `KnowledgeTreeUITests/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: enrichment に必要な日本語キーと test fixture を準備。

- [ ] T001 [P] `KnowledgeTree/Localization/Localizable.xcstrings` に新規キーを追加: `enrichment.statusFetching` (取得中)、`enrichment.statusUnfetched` (未取得)、`enrichment.statusFailed` (取得失敗)、`enrichment.thumbnailPlaceholderLabel` (サムネイルなし — VoiceOver 用)。値はすべて日本語。
- [ ] T002 [P] HTML test fixtures を作成: `KnowledgeTreeTests/Fixtures/sample-full.html` (title + description + og:image 全有)、`sample-title-only.html`、`sample-empty.html`、`sample-relative-og.html` (相対 OG image)、`sample-broken.html` (壊れた HTML)。固定 string でも可だが file の方が test 可読性が高い

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: User story が依存する SwiftData schema 拡張と URL session 抽象。

**⚠️ CRITICAL**: このフェーズ完了前は user story 着手不可。

- [ ] T003 `KnowledgeTree/Models/ArticleEnrichment.swift` を作成する。SwiftData `@Model` クラス、attributes は data-model.md の SwiftData 構成セクションに従う (`id` UUID 主キー、`article: Article` non-optional 参照、`statusRaw: String`、`canonicalTitle/summary/ogImageURL/rawHTML/lastFetchedAt: Optional`、`retryCount: Int`)。`EnrichmentStatus` enum + getter/setter extension も同 file に定義
- [ ] T004 `KnowledgeTree/Models/Article.swift` を更新する: `@Relationship(deleteRule: .cascade, inverse: \ArticleEnrichment.article) var enrichment: ArticleEnrichment?` を追加。既存 init は変更不要 (新 field は default nil)
- [ ] T005 `KnowledgeTree/KnowledgeTreeApp.swift` を更新する: `Schema([Article.self])` を `Schema([Article.self, ArticleEnrichment.self])` に拡張。SwiftData は backward-compat な lightweight migration で吸収 (research.md / R6)
- [ ] T006 [P] `KnowledgeTree/Services/URLSessionProtocol.swift` を作成する。1 メソッド protocol (`func data(for request: URLRequest) async throws -> (Data, URLResponse)`) を定義し、`extension URLSession: URLSessionProtocol {}` を追加 (research.md / R7)
- [ ] T007 [P] `KnowledgeTree/Models/ArticleEnrichment.swift` の Target Membership を **`KnowledgeTree` のみ** で ON にする (Share Extension では未使用、Constitution Principle V — 共有を止めない設計のため)

**Checkpoint**: 基盤完成。User story 着手可能。

---

## Phase 3: User Story 1 — 自動 enrichment と enriched 一覧表示 (Priority: P1) 🎯 MVP

**Goal**: ユーザーが Share Sheet 経由で記事を保存した直後、バックグラウンドで HTML fetch + メタデータ抽出が走り、一覧画面が enriched カード (サムネイル + canonical タイトル + description) で表示される。

**Independent Test**: 1 件の記事を Share Sheet で保存 → 数秒待つ → アプリを開く → 一覧の最上段にサムネイル + canonical タイトル + description が表示される。元の保存時タイトル (URL ホスト等のフォールバック) は使われていない。

### Tests for User Story 1 (Constitution テストゲート: 必須)

> **NOTE: テスト先行 (TDD 推奨)。fetch / parser ロジックは副作用が多いため fixture-based test で固める。**

- [ ] T008 [P] [US1] `KnowledgeTreeTests/MetadataParserTests.swift` を作成する。Phase 1 で作った fixture HTML を読み込み、contracts/metadata-parser.md の Tests 表にある 13 ケース (完全 / title only / 空 / HTML エンティティ / 切り詰め / 相対 og:image / og:secure_url / http-only og:image / 壊れ HTML / og:description fallback / 大文字 META / シングルクォート / 多重 meta) をすべて網羅
- [ ] T009 [P] [US1] `KnowledgeTreeTests/SwiftDataArticleEnrichmentStoreTests.swift` を作成する。`isStoredInMemoryOnly: true` の `ModelContainer` で contracts/article-enrichment-store.md の Tests 表にある 6 ケース (upsert 新規 / upsert 更新 / fetchPendingArticles 空 / 混在 / cascade delete / deleteAll) を網羅
- [ ] T010 [P] [US1] `KnowledgeTreeTests/ArticleEnrichmentServiceTests.swift` を作成する。`MockURLSession` + `MockArticleEnrichmentStore` で **成功パスのみ** をテスト (US1 範囲): 通常成功 / no-op (succeeded) / no-op (permanentlyFailed) / scheme チェック (http→permanentlyFailed)。retry 系テストは Phase 4 / US2 で追加

### Implementation for User Story 1

- [ ] T011 [US1] `KnowledgeTree/Services/MetadataParser.swift` を実装する。`struct MetadataParser` + `static func parse(html:baseURL:) -> ParsedMetadata`。`<title>` / `<meta name="description">` / `<meta property="og:image">` を case-insensitive 正規表現 + HTML エンティティ decode + 切り詰め (title 200 / summary 300) で抽出。og:image は base URL で絶対化、http→https 置換 (research.md / R5、contracts/metadata-parser.md)
- [ ] T012 [US1] `KnowledgeTree/Services/ArticleEnrichmentStore.swift` を実装する。`ArticleEnrichmentStoreProtocol` + `SwiftDataArticleEnrichmentStore` (内部に `ModelContext`、`@MainActor`)。`upsert(article:status:...)` / `fetchPendingArticles()` / `deleteAll()` を実装 (contracts/article-enrichment-store.md)
- [ ] T013 [US1] `KnowledgeTree/Services/ArticleEnrichmentService.swift` を実装する (成功パスのみ、retry は Phase 4)。`ArticleEnrichmentServiceProtocol` + `DefaultArticleEnrichmentService`。init で `URLSessionProtocol` (background config) と `ArticleEnrichmentStoreProtocol` を受け取る。`enrich(article:)` は: status .succeeded/.permanentlyFailed なら no-op → status .fetching に更新 → URLRequest 構築 (固定 User-Agent `KnowledgeTree/1.0 (iOS)` + 標準 Accept、Cookie/Authorization は付けない / `httpAdditionalHeaders = nil`) → fetch → MetadataParser.parse → 2MB チェック後 store.upsert(.succeeded)。失敗時は status .failed のままにして本 phase では retry しない
- [ ] T014 [P] [US1] `KnowledgeTree/Views/ThumbnailView.swift` を実装する。`AsyncImage(url:)` ラッパ。loading / failure / nil URL すべての場合にプレースホルダ (グレー角丸正方形 72×72pt) を表示し layout shift を起こさない。`accessibilityIdentifier("articleListThumbnail")`、ogImageURL nil 時は body 自体を返さず行高をコンパクトに保つ
- [ ] T015 [P] [US1] `KnowledgeTree/Views/ArticleRow.swift` を新規作成 (既存 `ArticleListView.swift` から行レンダリング部分を抽出 — Principle VI / 単一巨大 View 回避)。enrichment.canonicalTitle があれば優先表示、なければ Article.title。enrichment.summary があれば 2 行で表示。enrichment.ogImageURL があれば左端に ThumbnailView を表示
- [ ] T016 [US1] `KnowledgeTree/Views/ArticleListView.swift` を更新する: 既存 ForEach 内の `ArticleRow(article:)` への置換、行ごとの `accessibilityIdentifier("articleListRow")` は維持、`accessibilityLabel` は enriched 値があれば canonical title + summary に切り替え (なければ既存通り)
- [ ] T017 [US1] `KnowledgeTree/KnowledgeTreeApp.swift` を更新する: `WindowGroup { ArticleListView() ... }` の `.task { ... }` モディファイアで `DefaultArticleEnrichmentService(...).backfillAll()` をキックオフ。`ModelContext` を Service init に渡せるよう、Service の inject を `@Environment(\.modelContext)` 経由で取得する小さな wrapper (`@MainActor func bootstrap(in context: ModelContext)`) を `KnowledgeTreeApp.swift` に置く
- [ ] T018 [P] [US1] `KnowledgeTreeUITests/SaveArticleUITests.swift` に enriched 行表示テストを追加する。launch argument (例 `--ui-test-seed-enriched`) で in-memory モード起動 + ArticleEnrichment 1 件 seed → 起動後に `articleListThumbnail` と canonical title 文字列が表示されることを assert (URLProtocol stub の有無に依らず seed で検証)

**Checkpoint**: User Story 1 完成。Wi-Fi 環境で保存 → 数秒で enriched カード表示の最小フローが動く MVP 状態。

---

## Phase 4: User Story 2 — 取得失敗時のフォールバック (Priority: P2)

**Goal**: ネットワーク失敗・404・タイムアウト等で enrichment に失敗した場合でも、spec 001 の最低表示 (Article.title + URL) は維持され、行に小さな状態インジケータが付く。自動 backoff 再試行で復活する。

**Independent Test**: 機内モードで 1 件保存 → 一覧に Article.title + URL のフォールバック表示 + 「未取得」インジケータ。機内モード解除 → 1〜2 分後に enriched 表示に置き換わる。3 回連続失敗 (404 等) で「取得失敗」インジケータに固定、自動 retry 停止。

### Tests for User Story 2

- [ ] T019 [P] [US2] `KnowledgeTreeTests/ArticleEnrichmentServiceTests.swift` に retry / backoff テストを追加する: (a) 1 回目 404 → 2 回目 200 → succeeded、retryCount=1、(b) 3 回 timeout → permanentlyFailed、retryCount=3、(c) 5MB 超 → failed/permanentlyFailed、(d) 巨大 HTML 部分抽出、(e) Task.cancel で sleep 中の backoff が即解除されること

### Implementation for User Story 2

- [ ] T020 [US2] `KnowledgeTree/Services/ArticleEnrichmentService.swift` を更新する: retry + exponential backoff スケジュール (30s → 2min → 10min) を実装。`Task.sleep(for: .seconds(...))` で待機、cancel respect。retryCount を ArticleEnrichmentStore.upsert で永続化 (将来の再起動後も状態継続)。失敗時 status を `.failed` (retry 余地あり) または `.permanentlyFailed` (上限超) に更新
- [ ] T021 [US2] `KnowledgeTree/Services/ArticleEnrichmentService.swift` を更新する: `Network.NWPathMonitor` を統合。オフライン状態では retry の `Task.sleep` を skip して待機状態に。オンライン復帰時に `failed` ステータスの Article を再度キューイング
- [ ] T022 [P] [US2] `KnowledgeTree/Views/EnrichmentStatusBadge.swift` を新規作成。3 状態のアイコン (例: `arrow.triangle.2.circlepath` 取得中、`cloud.slash` 未取得、`exclamationmark.triangle` 取得失敗)。SF Symbols 使用、サイズ 14pt。それぞれ `accessibilityIdentifier` (`articleEnrichmentStatusFetching` / `articleEnrichmentStatusUnfetched` / `articleEnrichmentStatusFailed`) と日本語 `accessibilityLabel` (Localizable.xcstrings から)
- [ ] T023 [US2] `KnowledgeTree/Views/ArticleRow.swift` を更新する: `Article.enrichment?.status` で出し分けて `EnrichmentStatusBadge` を行末に配置 (succeeded のときは表示しない)
- [ ] T024 [P] [US2] `KnowledgeTreeUITests/SaveArticleUITests.swift` に「取得失敗状態の行表示」テストを追加する。launch argument で seed: status .failed + .permanentlyFailed のレコードを 1 件ずつ → 起動後に対応する `accessibilityIdentifier` が表示されていることを assert

**Checkpoint**: User Story 2 完成。失敗・retry・復帰の全フローが動く。spec 002 の機能スコープ達成。

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Quality Gate 最終仕上げ + Network Access の privacy 監視。

- [ ] T025 [P] アクセシビリティ確認: `grep -rn 'accessibilityIdentifier' KnowledgeTree/Views/` で新規 ID (`articleListThumbnail`、`articleEnrichmentStatusFetching`、`articleEnrichmentStatusUnfetched`、`articleEnrichmentStatusFailed`) すべて付与されていることを確認
- [ ] T026 [P] 文言確認: `grep -rnE 'Text\("[A-Za-z]' KnowledgeTree/Views/` で英語生文字列リテラルが含まれていないこと、`enrichment.*` キーが Localizable.xcstrings に登録されていることを確認 (Principle VII / FR-008 / SC-008)
- [ ] T027 [P] パフォーマンス計測: 1000 件 enriched seed 状態で Instruments の SwiftUI Time Profiler を実行 → 100 件超リストが 60fps スクロール可能を確認 → 結果を `specs/002-fetch-content/perf-results.md` に保存して PR description に貼付 (SC-007 / Constitution パフォーマンスゲート)
- [ ] T028 [P] パフォーマンス計測: enrichment ジョブ実行中に一覧スクロールしても main thread 占有 ≤ 100 ms を Instruments で確認 → `specs/002-fetch-content/perf-results.md` に追記 (SC-004)
- [ ] T029 Network 監視: Charles Proxy (or Console.app) で `xcodebuild test` 実行中の HTTP リクエストを観察し、(a) 第三者ホストへの送信 = 0、(b) Cookie / Authorization / IDFA 等の機微ヘッダ送信 = 0、(c) User-Agent が `KnowledgeTree/1.0 (iOS)` であることを確認 → `specs/002-fetch-content/network-audit.md` を作成して PR に貼付 (FR-003 / Network Access Justification の遵守確認)
- [ ] T030 quickstart.md の手動検証 (US1 + US2 + Edge Cases + Performance + Network 監視 + Accessibility) を実機 / シミュレータで全項目実施し、各「Pass」を埋めた状態で PR description に貼付 (Constitution Per-PR ゲート)
- [ ] T031 plan.md の Constitution Check 11 項目を最終確認し、すべて [x] のままであることを review (Phase 1 設計時の状態を維持、特に Principle I の Network Access Justification が実装で violate されていないこと)
- [ ] T032 PR description に Network Access Justification セクションへのリンク + Privacy Manifest / App Store privacy disclosure との整合性メモを記載 (App submission 段階での再確認用)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: 依存なし、即着手可
- **Phase 2 (Foundational)**: Phase 1 完了後。**全 user story の前提** (schema 拡張、URLSession 抽象)
- **Phase 3 (US1 / P1)**: Phase 2 完了後。最初に着手して MVP として Stop-and-Validate
- **Phase 4 (US2 / P2)**: Phase 3 完了が望ましい。理由: US2 は ArticleEnrichmentService の retry 拡張 + 同 service の使う ArticleRow の status 表示で、US1 の基盤 (Service / Store / ArticleRow) が必要
- **Phase 5 (Polish)**: 全 user story 完了後

### User Story Dependencies (技術的)

- **US1 (P1)**: Phase 2 のみに依存 — 完全独立 (成功パスだけで完結する MVP)
- **US2 (P2)**: US1 の Service / Store / ArticleRow に依存 — US1 完了後に US2 拡張

### Within Each User Story

- Tests を先に書き FAIL を確認してから実装着手 (TDD 推奨)
- Models / Services → Views → 統合の順
- Story 完了 → Stop-and-Validate (quickstart.md 該当セクション)

### Parallel Opportunities

- **Phase 1**: T001 / T002 並列
- **Phase 2**: T006 + T007 のみ並列 (T003-T005 は順序依存)
- **Phase 3 (US1)**: T008 / T009 / T010 はテスト並列。T014 / T015 は実装ファイル並列。T011 / T012 / T013 は順序依存 (Service が Parser + Store を使うため)
- **Phase 4 (US2)**: T019 単独テスト並列。T022 は独立コンポーネント並列。T020 / T021 / T023 は同一 Service / Row への変更なので直列
- **Phase 5 (Polish)**: T025 / T026 / T027 / T028 すべて並列実行可能

---

## Parallel Example: User Story 1 のテスト並列実行

```bash
# US1 のテスト 3 本を並列で書く (実装前):
Task: "MetadataParserTests.swift を作成 (13 ケース)"          # T008 [P]
Task: "SwiftDataArticleEnrichmentStoreTests.swift を作成"     # T009 [P]
Task: "ArticleEnrichmentServiceTests.swift を作成 (成功パス)" # T010 [P]
```

```bash
# US1 のテスト後、独立 View コンポーネントを並列実装:
Task: "ThumbnailView.swift を実装"                            # T014 [P]
Task: "ArticleRow.swift を実装"                               # T015 [P]
```

---

## Implementation Strategy

### MVP First (User Story 1 のみ)

1. Phase 1 (Setup) を完了
2. Phase 2 (Foundational) を完了 — **CRITICAL**、ブロッキング
3. Phase 3 (US1) を完了
4. **STOP and VALIDATE**: quickstart.md の US1 セクション (Wi-Fi で 1 件保存 → enriched 表示) を手動検証
5. ここで Demo 可能 (MVP achieved)

### Incremental Delivery

1. Setup + Foundational → 基盤 ready
2. US1 → 検証 → Demo (最小 enrichment が動く MVP)
3. US2 (失敗フォールバック + retry) → 検証 → Demo
4. Polish → PR

### Solo Developer Strategy

ソロ開発者向け推奨ペース (Constitution Principle II):

- 1 セッション目: Phase 1 + Phase 2 (基盤) + US1 のテスト 3 本
- 2 セッション目: US1 の Service / Store / Parser 実装
- 3 セッション目: US1 の View 実装 (ThumbnailView / ArticleRow / ArticleListView 更新) + UI テスト
- 4 セッション目: US2 の retry / backoff / NWPathMonitor 実装 + テスト + status badge UI
- 5 セッション目: Polish (Performance / Network 監視 / quickstart 手動検証) + PR

---

## Notes

- [P] タスク = 異なるファイルへの編集、依存なし
- [Story] タグは user story 単位で実装/テスト/デプロイ可能性を担保するためのトレーサビリティ
- 各 user story 完了時点で **Stop-and-Validate** を行うこと
- テスト実装前に必ず FAIL を確認すること (TDD 推奨)
- 各タスクまたは論理グループ完了ごとに commit
- 巨大 SwiftUI View に詰め込まない (Principle VI / コード品質ゲート、本 spec で `ArticleRow` を分離した理由)
- 全 UI 文言は `Localizable.xcstrings` 経由 (Principle VII / FR-008)
- Network Access は Principle I の例外要件 (spec.md の Network Access Justification) を満たした実装にすること (T029 で監査)

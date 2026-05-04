---
description: "Task list for spec 004 — 知識抽出 + 要約 (Apple Foundation Models)"
---

# Tasks: 知識抽出 + 要約 (Knowledge Extraction + Summarization)

**Input**: Design documents from `/specs/004-summarize/`
**Prerequisites**: plan.md (済), spec.md (済), research.md (済), data-model.md (済), contracts/ (済), quickstart.md (済)、spec 001-003 が動作する状態。

**Tests**: 含む。Constitution Quality Gate「テストゲート」が必須化。`KnowledgeExtractor` (Mock LanguageModelSession)、`KnowledgeExtractionService` (orchestration + availability)、`SwiftDataArticleKnowledgeStore` (in-memory + cascade delete + Generable→@Model マッピング) の各層をユニットテスト + Reader 知識セクション表示を UI テスト。実 Foundation Models のテストは quickstart 手動検証で担保。

**Organization**: User story 単位でフェーズ分割。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 並列実行可能 (異なるファイル、未完了タスクへの依存なし)
- **[Story]**: US1 / US2 / US3 — どの user story に属するか
- 各タスクには **絶対ファイルパス** を含める

## Path Conventions

spec 001-003 の Xcode project を **拡張する** 単一プロジェクト構成。target 追加なし、ファイル追加のみ。

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 知識抽出に必要な日本語キー追加 + 既存 Article への relationship 拡張 + Schema 拡張。

- [ ] T001 [P] `KnowledgeTree/Localization/Localizable.xcstrings` に新規キーを追加 (約 12 キー):
  - `knowledge.section.title` (知識サマリ)
  - `knowledge.summary.heading` (要約)
  - `knowledge.facts.heading` (重要な事実)
  - `knowledge.entities.heading` (登場するもの)
  - `knowledge.bodyHeading` (本文)
  - `knowledge.aiGeneratedLabel` (AI 生成)
  - `knowledge.factType.event` / `.claim` / `.statistic` / `.definition` / `.quote`
  - `knowledge.entityType.person` / `.organization` / `.location` / `.concept` / `.product` / `.work`
  全て日本語値で登録 (Principle VII)
- [ ] T002 `KnowledgeTree/Models/Article.swift` を更新する: `@Relationship(deleteRule: .cascade, inverse: \ExtractedKnowledge.article) var extractedKnowledge: ExtractedKnowledge?` を追加。既存 `enrichment` / `body` relationship はそのまま保持
- [ ] T003 `KnowledgeTree/KnowledgeTreeApp.swift` を更新する: Schema を `[Article.self, ArticleEnrichment.self, ArticleBody.self]` から `[Article.self, ArticleEnrichment.self, ArticleBody.self, ExtractedKnowledge.self, KeyFact.self, KnowledgeEntity.self]` に拡張。SwiftData lightweight migration で吸収

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: ExtractedKnowledge / KeyFact / KnowledgeEntity の @Model 定義。

**⚠️ CRITICAL**: このフェーズ完了前は user story 着手不可。

- [ ] T004 `KnowledgeTree/Models/ExtractedKnowledge.swift` を作成する。data-model.md / Persistent Types に従い 1 ファイル内に以下を定義:
  - `@Model final class ExtractedKnowledge` (id / article non-optional ref / statusRaw / essence? / summary? / generatedAt? / modelVersion? / extractionVersion / generationDurationMs? + cascade relationship to keyFacts / entities)
  - `@Model final class KeyFact` (id / knowledge non-optional ref / statement / typeRaw / order)
  - `@Model final class KnowledgeEntity` (id / knowledge non-optional ref / name / typeRaw / salience / order)
  - `enum ExtractionStatus: String, Codable, Sendable` (pending/extracting/succeeded/partiallySucceeded/failed/skipped) + getter/setter extension
  - `extension KeyFact` で `var type: FactType` getter (typeRaw → enum)
  - `extension KnowledgeEntity` で `var type: EntityType` getter (typeRaw → enum)
  - `FactType.init?(rawValue:)` と `EntityType.init?(rawValue:)` を spec.md / data-model.md の文字列にマッピング (`@Generable enum` の `String(describing:)` 出力との変換)
- [ ] T005 `KnowledgeTree/Models/ExtractedKnowledge.swift` の Target Membership を **`KnowledgeTree` のみ** で ON にする (Share Extension 未使用)

**Checkpoint**: 基盤完成。User story 着手可能。

---

## Phase 3: User Story 1 — 自動抽出 + 一覧表示 (Priority: P1) 🎯 MVP

**Goal**: ArticleBody .succeeded 時に Apple Foundation Models で 4 出力 (essence + summary + keyFacts + entities) を 1 セッション生成 → SwiftData に保存 → 一覧で essence + entity chips + 「AI 生成」ラベル を表示。

**Independent Test**: spec 003 で本文抽出成功済の記事を 1 件保存 → 数秒待つ → 一覧の該当行に essence (1 行) + entity chips (上位 3 つ) + 「AI 生成」ラベル が表示される。

### Tests for User Story 1 (Constitution テストゲート: 必須)

> **NOTE**: 実 Foundation Models のテストは Mock で代替。実機は quickstart 手動検証。

- [ ] T006 [P] [US1] `KnowledgeTree/Services/LanguageModelSessionProtocol.swift` を作成する。`protocol LanguageModelSessionProtocol: Sendable { func generateKnowledge(prompt: String) async throws -> ExtractedKnowledgeOutput }` を定義 + 本番実装 `FoundationModelLanguageModelSession` (`@MainActor`、`LanguageModelSession.respond(generating:prompt:)` 呼び出し) も同 file に。`ExtractedKnowledgeOutput` / `KeyFactOutput` / `KnowledgeEntityOutput` (@Generable struct) と `FactType` / `EntityType` (@Generable enum) も同 file に定義 (data-model.md / Generable Types に従う、`@Guide(description:)` で日本語制約)
- [ ] T007 [P] [US1] `KnowledgeTreeTests/KnowledgeExtractorTests.swift` を作成する。`MockLanguageModelSession` (contracts/knowledge-extractor.md の Mock 実装、`nextResult: Result<ExtractedKnowledgeOutput, Error>`) と `ExtractedKnowledgeOutput.fixture()` を定義し、6 ケース網羅: 通常成功 / safety filter blocked / context exceeded / timeout / empty output / partial output
- [ ] T008 [P] [US1] `KnowledgeTreeTests/SwiftDataArticleKnowledgeStoreTests.swift` を作成する。`isStoredInMemoryOnly: true` の `ModelContainer` で contracts/article-knowledge-store.md の Tests 表 8 ケース網羅: upsertStatus 新規 / 更新 / upsertSucceeded 新規 / 更新 (旧 children 削除確認) / fetchPendingArticles 空 / 混在 / cascade delete / deleteAll
- [ ] T009 [P] [US1] `KnowledgeTreeTests/KnowledgeExtractionServiceTests.swift` を作成する。`MockLanguageModelSession` + `MockArticleKnowledgeStore` で 9 ケース網羅: 通常成功 / extractedText 短すぎ → no-op / Apple Intelligence 不可能 → .skipped / 既に成功 → no-op / safety filter blocked → .failed / 部分成功 (essence + summary のみ) → .partiallySucceeded / 完全空出力 → .failed / backfill 複数件 / cancel

### Implementation for User Story 1

- [ ] T010 [US1] `KnowledgeTree/Services/KnowledgeExtractor.swift` を実装する。`@MainActor struct KnowledgeExtractor`、init で `LanguageModelSessionProtocol` 受け取り。`func extract(extractedText: String) async throws -> ExtractedKnowledgeOutput` を実装 (contracts/knowledge-extractor.md)。`buildPrompt(text:)` で research.md / R3 の strict instructions を含む日本語 prompt を構築 (FR-020、「元記事に明示されている内容のみ」「推測・補完禁止」「essence / summary / key facts は矛盾しない」「日本語で出力」を必ず含める)
- [ ] T011 [US1] `KnowledgeTree/Services/ArticleKnowledgeStore.swift` を実装する。`ArticleKnowledgeStoreProtocol` + `SwiftDataArticleKnowledgeStore` (`@MainActor`、`ModelContext` 内包)。`upsertStatus(article:status:)` と `upsertSucceeded(article:status:output:modelVersion:durationMs:)` の 2 メソッド + `fetchPendingArticles()` + `deleteAll()`。Generable→@Model マッピングで FactType / EntityType を `String(describing:)` で statusRaw に保存、長さ制限 (essence 150 / summary 300 / fact 200 / entity 30) を適用、salience を 1〜5 に clamp (contracts/article-knowledge-store.md)
- [ ] T012 [US1] `KnowledgeTree/Services/KnowledgeExtractionService.swift` を実装する。`KnowledgeExtractionServiceProtocol` + `DefaultKnowledgeExtractionService` (`@MainActor`)。init で `KnowledgeExtractor` と `ArticleKnowledgeStoreProtocol` を受け取り。`extract(article:)` は: 既に succeeded/partiallySucceeded なら no-op → extractedText nil/200字未満なら no-op → `SystemLanguageModel.availability` チェック (`.available` 以外なら `store.upsertStatus(.skipped)` で return) → `store.upsertStatus(.extracting)` → `Task.detached(priority: .utility)` で `extractor.extract(extractedText:)` 実行 → 結果の partial/full 判定 (essence/summary/keyFacts/entities の有無で .succeeded / .partiallySucceeded / .failed) → `store.upsertSucceeded(...)` (contracts/knowledge-extraction-service.md)
- [ ] T013 [US1] `KnowledgeTree/Services/BodyExtractionService.swift` を更新する: `init(store:knowledgeExtractionService:minimumBodyLength:extractionVersion:)` に optional `knowledgeExtractionService: KnowledgeExtractionServiceProtocol?` を追加 (default nil で spec 003 既存テストを破壊しない)。`performExtraction` の最後で body status を .succeeded で永続化した直後に `Task { await knowledgeExtractionService?.extract(article:) }` を fire-and-forget で発行
- [ ] T014 [US1] `KnowledgeTree/KnowledgeTreeApp.swift` を更新する: `bootstrap()` 内で `SwiftDataArticleKnowledgeStore` + `KnowledgeExtractor(session: FoundationModelLanguageModelSession())` + `DefaultKnowledgeExtractionService` を作成し、`DefaultBodyExtractionService` の init に `knowledgeExtractionService:` で inject。backfill 順序を `enrichmentService.backfillAll() → bodyService.backfillAll() → knowledgeService.backfillAll()` に拡張
- [ ] T015 [P] [US1] `KnowledgeTree/Views/EntityChip.swift` を実装する。引数 `KnowledgeEntity` を取り、SF Symbol アイコン (person→`person.fill`、organization→`building.2.fill`、location→`mappin.circle.fill`、concept→`lightbulb.fill`、product→`shippingbox.fill`、work→`book.fill`) + entity.name の chip 表示。`accessibilityIdentifier("knowledgeEntityChip")`、`accessibilityLabel` で type + name を日本語で
- [ ] T016 [US1] `KnowledgeTree/Views/ArticleRow.swift` を更新する: `article.extractedKnowledge?.status` が `.succeeded` または `.partiallySucceeded` の場合、既存表示 (タイトル / URL / サムネイル) の下に: (a) essence の 1 行 (line limit 2)、(b) entity chips の HStack (上位 3 つ、salience 順 sort)、(c) 「AI 生成」ラベル (caption フォント、グレー、`accessibilityIdentifier("knowledgeAIGeneratedLabel")`) を追加。enrichment status badge と並ばないように layout 調整
- [ ] T017 [P] [US1] `KnowledgeTreeUITests/SaveArticleUITests.swift` に knowledge 表示テストを追加する。launch arg (例 `--ui-test-seed-knowledge-succeeded`) で in-memory mode で Article + ArticleEnrichment(.succeeded) + ArticleBody(.succeeded) + ExtractedKnowledge(.succeeded、essence/summary、3 KeyFact、5 KnowledgeEntity) を seed → 起動 → 一覧の該当行に essence 文字列と entity chip と 「AI 生成」ラベルが表示されることを assert

**Checkpoint**: User Story 1 完成。ArticleBody .succeeded → 自動抽出 → 一覧表示の MVP フローが動く状態。

---

## Phase 4: User Story 2 — Reader View で構造表示 (Priority: P2)

**Goal**: spec 003 の Reader View で本文の上に「知識サマリ」セクションが構造的に表示される (essence 太字 → summary 段落 → key facts list → entity chips → 区切り → 本文)。

**Independent Test**: ExtractedKnowledge .succeeded の記事を一覧でタップ → Reader View 開く → 本文の上に知識サマリセクションが表示される。

### Tests for User Story 2

- [ ] T018 [P] [US2] `KnowledgeTreeUITests/SaveArticleUITests.swift` に Reader 知識セクション表示テストを追加する。launch arg seed で knowledge 持ち Article → 行タップ → `readerView` 内に `knowledgeSummarySection` が表示される、essence / summary / key facts / entity chips の identifier がすべて存在することを assert

### Implementation for User Story 2

- [ ] T019 [P] [US2] `KnowledgeTree/Views/KeyFactRow.swift` を実装する。引数 `KeyFact` を取り、SF Symbol 種別アイコン (event→`calendar`、claim→`bubble.left`、statistic→`chart.bar`、definition→`text.book.closed`、quote→`quote.bubble`) + statement の HStack。`accessibilityIdentifier("knowledgeFactRow")`、`accessibilityLabel` で type + statement を日本語
- [ ] T020 [US2] `KnowledgeTree/Views/KnowledgeSummaryView.swift` を実装する。引数 `ExtractedKnowledge` を取り、以下構造:
  - 「AI 生成」ラベル (`knowledgeAIGeneratedLabel`)
  - essence 太字 (`Text(essence).font(.headline).accessibilityIdentifier("knowledgeEssence")`、knowledge.essence が nil なら表示しない)
  - summary 段落 (`Text(summary).font(.body).accessibilityIdentifier("knowledgeSummaryText")`、knowledge.summary が nil なら表示しない)
  - 「重要な事実」見出し + KeyFactRow の VStack (knowledge.keyFacts が空なら見出しごと非表示)
  - 「登場するもの」見出し + EntityChip の FlowLayout または HStack (knowledge.entities が空なら見出しごと非表示。salience 降順で sort)
  - 区切り線 (`Divider()`)
  - root に `accessibilityIdentifier("knowledgeSummarySection")`、`@ScaledMetric` 等で Dynamic Type 対応
- [ ] T021 [US2] `KnowledgeTree/Views/ReaderView.swift` を更新する: 既存 `ScrollView { LazyVStack { ... 本文段落 ... } }` の冒頭に、knowledge .succeeded/.partiallySucceeded のときのみ `KnowledgeSummaryView(knowledge: article.extractedKnowledge!)` を配置 + 「本文」見出し (`Text("knowledge.bodyHeading").font(.title3)`) を本文の前に置く

**Checkpoint**: User Story 2 完成。Reader View で知識セクション表示が動く。

---

## Phase 5: User Story 3 — Apple Intelligence 不可能時のフォールバック (Priority: P3)

**Goal**: Apple Intelligence 非対応端末 / 設定 OFF / モデル未ダウンロード のとき、知識抽出はサイレントに skip され、UI 上は知識セクション全体が表示されない。spec 001-003 の全機能は完全動作。

**Independent Test**: シミュレータで Apple Intelligence をオフ → 記事を保存 → 知識セクションが出ない、spec 001-003 機能は完全動作。

### Tests for User Story 3

- [ ] T022 [P] [US3] `KnowledgeTreeTests/KnowledgeExtractionServiceTests.swift` に availability skip ケースを 3 種追加: (a) `.unavailable(.deviceNotEligible)`、(b) `.unavailable(.appleIntelligenceNotEnabled)`、(c) `.unavailable(.modelNotReady)` のそれぞれで `store.upsertStatus(.skipped)` が呼ばれ、`extractor` (Mock) は呼ばれないこと

### Implementation for User Story 3

- [ ] T023 [US3] `KnowledgeTree/Services/KnowledgeExtractionService.swift` の availability チェックを実装で徹底する: `extract(article:)` の冒頭で `SystemLanguageModel.default.availability` を取得し、`.available` 以外なら以下を実行:
  - `store.upsertStatus(article:, status: .skipped)` で永続化
  - return (extractor は呼ばない)
  T012 と統合だが、本タスクで明示的に test 駆動で確認

**Checkpoint**: User Story 3 完成。spec 004 の全 user story 達成。

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Quality Gate 最終仕上げ + ハルシネーション率 / 一貫性 sampling + Network 監査。

- [ ] T024 [P] アクセシビリティ確認: `grep -rn 'accessibilityIdentifier' KnowledgeTree/Views/Knowledge*` および `KnowledgeTree/Views/EntityChip.swift` / `KnowledgeTree/Views/KeyFactRow.swift` / `ArticleRow.swift` で `knowledgeSummarySection`、`knowledgeEssence`、`knowledgeSummaryText`、`knowledgeFactRow`、`knowledgeEntityChip`、`knowledgeAIGeneratedLabel` が全て付与されていることを確認
- [ ] T025 [P] 文言確認: `grep -rnE 'Text\("[A-Za-z]' KnowledgeTree/Views/Knowledge*` で英語生文字列リテラルが含まれていないこと、`knowledge.*` キー約 12 件が `Localizable.xcstrings` に登録されていることを確認 (Principle VII / FR-017 / SC-008)
- [ ] T026 [P] パフォーマンス計測: ArticleBody .succeeded から ExtractedKnowledge .succeeded まで Apple Intelligence 対応端末で median 6 秒以内 (10 サンプル測定 → `specs/004-summarize/perf-results.md` に記録、PR 添付、SC-001)
- [ ] T027 [P] パフォーマンス計測: 100 件 ExtractedKnowledge 持ち一覧で 60fps スクロール (Instruments → `perf-results.md`、SC-005)
- [ ] T028 [P] パフォーマンス計測: 抽出ジョブ実行中の一覧スクロール → main thread 占有 ≤ 100ms (Instruments → `perf-results.md`、SC-004)
- [ ] T029 [P] パフォーマンス計測: 一覧タップから Reader View 表示まで 300ms 以内 (知識セクション追加でも spec 003 と同等、Instruments → `perf-results.md`、SC-006)
- [ ] T030 ハルシネーション率 sampling: 任意 20 記事をサンプリング、各記事の key facts (3-5 件 × 20 = 60-100 件) を本文と見比べ、80% 以上が本文に存在 (literal または semantic match) する → `specs/004-summarize/hallucination-sampling.md` に記録 (SC-009、quickstart.md 参照)
- [ ] T031 一貫性 sampling: 任意 20 記事の essence と summary を見比べ、95% 以上で主題が一致/矛盾しない → `specs/004-summarize/hallucination-sampling.md` に追記 (SC-010)
- [ ] T032 Network 監視: Charles Proxy / Console.app で本 spec 起因のネットワークリクエストが **ゼロ** であることを確認 (Foundation Models on-device、第三者 AI サーバーへの接続ゼロ) → `specs/004-summarize/network-audit.md` に記録 (Principle I 完全維持の証跡)
- [ ] T033 quickstart.md の手動検証 (US1〜US3 + Edge Cases + Performance + Network 監視 + ハルシネーション + 一貫性 + Accessibility) を Apple Intelligence 対応端末で全項目実施し、各「Pass」を埋めた状態で PR description に貼付 (Constitution Per-PR ゲート)
- [ ] T034 plan.md の Constitution Check 11 項目を最終再確認、すべて [x] のままを review (Phase 1 設計時の状態を維持、特に Principle I の「新規ネットワーク非依存」+ Principle III の「データモデル non-optional 参照」が実装で violate されていないこと)
- [ ] T035 PR description に以下を記載:
  - 「本 spec 004 はネットワーク非依存、Apple Foundation Models on-device、Constitution Principle I 完全維持」
  - Generable 型 (transient) と @Model 型 (persistent) の分離設計の意図 (Plan 設計判断 #1)
  - ハルシネーション抑止の 3 層対策 (Guide / prompt / UI)
  - Apple Intelligence 不可能時の graceful degradation 動作

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: 依存なし
- **Phase 2 (Foundational)**: Phase 1 完了後。**全 user story の前提** (schema 拡張 + ExtractedKnowledge model 定義)
- **Phase 3 (US1 / P1)**: Phase 2 完了後。最初に着手して MVP として Stop-and-Validate
- **Phase 4 (US2 / P2)**: Phase 3 完了後 (KnowledgeSummaryView は ArticleListView の knowledge データに依存)
- **Phase 5 (US3 / P3)**: Phase 3 完了後 (KnowledgeExtractionService の availability ロジックを test driven で固める)
- **Phase 6 (Polish)**: 全 user story 完了後

### User Story Dependencies (技術的)

- **US1 (P1)**: Phase 2 のみに依存 — 完全独立 (4 出力生成 + 一覧表示の MVP)
- **US2 (P2)**: US1 の Service / Store / ArticleListView に依存
- **US3 (P3)**: US1 の Service の availability ロジックを test driven で深掘り。US1 完了後に並列可

### Within Each User Story

- Tests を先に書き FAIL を確認してから実装 (TDD 推奨)
- Models / Services → Views → 統合の順
- Story 完了 → Stop-and-Validate

### Parallel Opportunities

- **Phase 1**: T001 単独 (T002 / T003 は同一スキーマ変更で順序依存)
- **Phase 2**: T004 が中心、T005 は完了後
- **Phase 3 (US1)**: T006 / T007 / T008 / T009 はテスト並列。T010 / T011 / T012 は順序依存 (Service が Extractor + Store を使う)。T013 / T014 は順序依存 (BodyExtractionService 修正 → KnowledgeTreeApp wire)。T015 / T017 は独立 View / test で並列可。T016 は ArticleRow 単独編集で直列
- **Phase 4 (US2)**: T018 単独テスト並列。T019 / T020 / T021 は同一系統で順序依存
- **Phase 5 (US3)**: T022 / T023 並列可
- **Phase 6 (Polish)**: T024-T029 すべて並列実行可能

---

## Parallel Example: User Story 1 のテスト並列実行

```bash
# US1 のテスト 4 本を並列で書く (実装前):
Task: "LanguageModelSessionProtocol + Generable 型を作成"     # T006 [P]
Task: "KnowledgeExtractorTests を作成 (6 ケース)"             # T007 [P]
Task: "SwiftDataArticleKnowledgeStoreTests を作成 (8 ケース)" # T008 [P]
Task: "KnowledgeExtractionServiceTests を作成 (9 ケース)"     # T009 [P]
```

```bash
# US1 の独立 View / test を並列実装:
Task: "EntityChip.swift を実装"                                # T015 [P]
Task: "SaveArticleUITests に knowledge 表示テスト追加"         # T017 [P]
```

---

## Implementation Strategy

### MVP First (User Story 1 のみ)

1. Phase 1 (Setup) を完了
2. Phase 2 (Foundational) を完了 — **CRITICAL**、ブロッキング
3. Phase 3 (US1) を完了
4. **STOP and VALIDATE**: quickstart.md の US1 セクションを Apple Intelligence 対応端末で手動検証
5. Demo 可能 (4 出力 1 セッション生成 + 一覧表示の MVP)

### Incremental Delivery

1. Setup + Foundational → 基盤 ready
2. US1 → 検証 → Demo (一覧の essence + entity chip が動く MVP)
3. US2 (Reader 知識セクション) → 検証 → Demo
4. US3 (Apple Intelligence 不可能時) → 検証 → Demo
5. Polish → PR

### Solo Developer Strategy

ソロ開発者向け推奨ペース (Constitution Principle II):

- 1 セッション目: Phase 1 + Phase 2 (基盤) + US1 のテスト 4 本
- 2 セッション目: US1 の Extractor / Store / Service 実装 + BodyExtractionService inject (T013) + KnowledgeTreeApp bootstrap (T014)
- 3 セッション目: US1 の EntityChip / ArticleRow 更新 + UI テスト
- 4 セッション目: US2 の KeyFactRow / KnowledgeSummaryView / ReaderView 更新 + UI テスト
- 5 セッション目: US3 の availability test 強化 + Polish (Performance / Network / ハルシネーション sampling / quickstart) + PR

---

## Notes

- [P] タスク = 異なるファイル、依存なし
- [Story] タグはトレーサビリティ
- 各 user story 完了時点で **Stop-and-Validate**
- テスト実装前に必ず FAIL を確認 (TDD 推奨)
- 各タスクまたは論理グループ完了ごとに commit
- 巨大 SwiftUI View に詰め込まない (Principle VI、本 spec で `KnowledgeSummaryView` / `KeyFactRow` / `EntityChip` を分離した理由)
- 全 UI 文言は `Localizable.xcstrings` 経由 (Principle VII)
- **本 spec はネットワーク非依存** (Apple Foundation Models on-device、Principle I 完全維持)。実装中に新規 URLSession / 第三者 AI 呼び出しを追加しないこと (T032 の audit で確認)
- **ハルシネーション抑止 3 層**: Guide / prompt / UI ラベル。自動検証は MVP 外、T030 の sampling のみ
- **Generable 型 (transient) と @Model 型 (persistent) の分離** を厳守 — Generable 出力を直接保存せず、必ず Store 層でマッピング (Plan 設計判断 #1、将来モデル更新時の互換性確保)

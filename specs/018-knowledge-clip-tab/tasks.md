# Tasks: 知識 Clip タブ + Category 統合 AI ダイジェスト + Category 知識総まとめ詳細画面 (spec 018)

**Input**: Design documents from `/specs/018-knowledge-clip-tab/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ (5 個), quickstart.md

**Tests**: 純関数 / Service ロジック / @Model schema に対する unit test を含める (in-memory ModelContainer + Mock LanguageModelSession)。view rendering / NavigationStack 標準挙動は除外、quickstart 12 シナリオで実機検証代替。

**Organization**: 5 user stories (US1〜US5) ごとに Phase を分けて独立 deliver 可能。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 並列可能 (異なるファイル、依存なし)
- **[Story]**: US1〜US5 のいずれか
- 全タスクに project-relative path を記載

---

## Phase 1: Setup

**Purpose**: 文言追加 + SwiftData schema 拡張

- [x] T001 `KnowledgeTree/Localization/Localizable.xcstrings` に新規 10 文言追加 (`clip.tab.title` / `clip.empty.title` / `clip.empty.description` / `clip.filter.all` / `clip.filter.days7` / `clip.filter.days30` / `clip.card.staleLabel` / `clip.detail.summary.title` / `clip.detail.keyFacts.title` / `clip.detail.entities.title` / `clip.detail.articles.title` 等、必要なもの全部)、日本語のみ
- [x] T002 `KnowledgeTree/SharedSchema.swift` の `static var all` 配列末尾に `KnowledgeDigest.self` を追加 (lightweight migration、既存無傷)

---

## Phase 2: Foundational

**Purpose**: 全 User Story 共通の @Model + Service + Article inverse relationship 整備

- [x] T003 `KnowledgeTree/Models/KnowledgeDigest.swift` を新規作成 (data-model.md / contracts/knowledge-digest-model.md 仕様)。`@Model final class KnowledgeDigest` + 9 フィールド + `@Relationship(deleteRule: .nullify, inverse: \Article.digests) var sourceArticles: [Article]` + init
- [x] T004 `KnowledgeTree/Models/Article.swift` に `@Relationship var digests: [KnowledgeDigest] = []` を追加 (KnowledgeDigest.sourceArticles の inverse)
- [x] T005 `KnowledgeTree/Services/KnowledgeDigestService.swift` を新規作成。protocol `KnowledgeDigestService` + `FoundationModelsKnowledgeDigestService` + `FallbackKnowledgeDigestService` + transient struct `DigestOutput` / `DigestCardOutput` (`@Generable` macro)。contracts/knowledge-digest-service.md 仕様 + research.md R2/R3/R11/R12

**Checkpoint**: T001-T005 完了で全 US が並列着手可能

---

## Phase 3: User Story 1 (P1) — 知識 Clip タブで Category 別 AI ダイジェスト閲覧 🎯 MVP

**Goal**: 新タブ「知識 Clip」を TabView 中央に追加、Category 別 AI 統合カードを LazyVStack 縦並び表示

**Independent Test**:
- AI ブレインタブの隣に「知識 Clip」タブが表示される
- タブ open → カード一覧表示 (LazyVStack)
- KnowledgeDigestServiceTests / KnowledgeDigestModelTests PASS

- [x] T006 [P] [US1] `KnowledgeTreeTests/KnowledgeDigestModelTests.swift` を新規作成 (3 ケース): testRelationshipNullifyOnArticleDelete / testIsStaleDefaultsFalse / testCardIndexOrdering。in-memory ModelContainer + SharedSchema.all で隔離
- [x] T007 [P] [US1] `KnowledgeTreeTests/KnowledgeDigestServiceTests.swift` を新規作成 (7 ケース): testRegenerateProducesDigestWithSourceArticles / testRegenerateAllStaleSkipsNonStale / testMarkStaleSetsFlag / testFallbackWhenAvailabilityUnavailable / testMultiCardSplitWhenAIReturnsMultipleCards / testIdempotentMultipleRegenerate / testEmptyCategoryReturnsEmpty。MockLanguageModelSession + MockAvailabilityChecker で AI mock。`private typealias Tag = KnowledgeTree.Tag`
- [x] T008 [US1] `KnowledgeTree/Views/KnowledgeClipCard.swift` を新規作成 (~120 行)。contracts/knowledge-clip-card.md 仕様: headerSection (Category 名 + 元記事数 + savedAt + stale + 小 OG) + summarySection + keyFactsSection (・bullet) + entityChipsSection (横スクロール Capsule) + accessibilityIdentifier "clip.card.<categoryRaw>.<cardIndex>" + combinedAccessibilityLabel
- [x] T009 [US1] `KnowledgeTree/Views/KnowledgeClipView.swift` を新規作成 (~120 行)。contracts/knowledge-clip-view.md 仕様: NavigationStack + ScrollView + LazyVStack + timeFilterChips + digestsContent + `@Query allDigests` + `@State period` + computed `digestsByCategory` + `.navigationDestination(for: CategoryDigestDetailDestination.self)` (CategoryKnowledgeDetailView は T012 で実装、まず stub view で繋ぐ)
- [x] T010 [US1] `KnowledgeTree/KnowledgeTreeApp.swift` を改修。TabView の 2nd と 3rd の間 (Library と AI ブレインの間) に `KnowledgeClipView` を `.tabItem { Label("clip.tab.title", systemImage: "lightbulb.fill") }` で追加 + `accessibilityIdentifier("tab.knowledgeClip")`
- [x] T011 [US1] `KnowledgeTree/KnowledgeTreeApp.swift` の bootstrap で `KnowledgeDigestService` を初期化、`ServiceContainer.digestService` に inject (ServiceContainer に `var digestService: KnowledgeDigestService?` プロパティ追加が必要、または既存 services と並列で `@State` に保持)、bootstrap 末尾で `await digestService.regenerateAllStale()` 実行 (初回起動時の全集約)

**Checkpoint**: T006-T011 完了で US1 完成。`xcodebuild test` で 10 ケース全 PASS、Simulator で「知識 Clip」タブが表示され、Category 別カード一覧確認可能

---

## Phase 4: User Story 2 (P1) — マルチカード分割

**Goal**: 散らかった内容の Category を AI が自動で複数カードに分割

**Independent Test**:
- Mock AI が `cards: [Card1, Card2]` 返すと Digest が cardIndex 0/1 で 2 個生成
- testMultiCardSplitWhenAIReturnsMultipleCards (T007 内) PASS

(US2 は T005 で `DigestOutput { cards: [Card] }` 設計 + T007 で test 完備、追加実装ゼロ。Phase 3 完了で自動的に US2 も完了)

- [x] T012 [US2] T005 の `FoundationModelsKnowledgeDigestService.persistDigests(...)` 内のロジックを再確認: AI が `cards.count == 2` を返した時、cardIndex 0 と 1 で 2 個の `KnowledgeDigest` を insert することを確認 (要なら追加バリデーション)

**Checkpoint**: T012 完了で US2 確認終了 (実装は Phase 2/3 で完了済)

---

## Phase 5: User Story 3 (P1) — pull-to-refresh で再集約

**Goal**: 新記事追加時に該当 Category の Digest を stale 化、pull-to-refresh で AI 再集約

**Independent Test**:
- 新記事保存後、KnowledgeExtractionService 完了 hook で markStale 呼ばれる
- 知識 Clip タブで pull-down → ProgressView → 再集約完了 → stale フラグ解除
- testRegenerateAllStaleSkipsNonStale (T007 内) PASS

- [x] T013 [US3] `KnowledgeTree/Services/KnowledgeExtractionService.swift` の `extract(article:)` 関数の最後に `digestService?.markStale(for:)` hook を追加 (research R4 仕様)。`KnowledgeExtractionService` の init に `digestService: KnowledgeDigestService?` を inject (optional、test 時 nil 可)
- [x] T014 [US3] `KnowledgeTree/KnowledgeTreeApp.swift` の bootstrap で `KnowledgeExtractionService` を構築する箇所に `digestService` を inject
- [x] T015 [US3] `KnowledgeTree/Views/KnowledgeClipView.swift` の ScrollView に `.refreshable { try? await services.digestService?.regenerateAllStale() }` modifier を追加 (research R5 仕様)

**Checkpoint**: T013-T015 完了で US3 完成。実機で新記事保存 → 知識 Clip タブ → 「更新あり」マーク → pull-down → 再集約確認可能

---

## Phase 6: User Story 4 (P1) — Category 知識総まとめ詳細画面

**Goal**: KnowledgeClipCard タップ → CategoryKnowledgeDetailView 遷移、包括サマリ + Top KeyFact 10 + Top Entity 5 + 元記事一覧

**Independent Test**:
- カードタップ → CategoryKnowledgeDetailView 表示
- 4 セクション (総まとめ / 重要ポイント / 関連する概念 / 元記事) すべて表示
- 元記事タップで ArticleDetailView シート起動

- [x] T016 [US4] `KnowledgeTree/Views/CategoryKnowledgeDetailView.swift` を新規作成 (~110 行)。contracts/category-knowledge-detail-view.md 仕様: NavigationTitle + ScrollView + LazyVStack + 4 sections (aggregatedSummary / topKeyFacts / topEntities / articlesList) + computed properties (digestsForCategory / articlesForCategory / aggregatedSummary / topKeyFactsAggregated / topEntitiesAggregated) + sheet `presentedArticle` で ArticleDetailView 起動 + `.refreshable { try? await services.digestService?.regenerate(for: category) }`
- [x] T017 [US4] `KnowledgeTree/Views/KnowledgeClipView.swift` の `CategoryDigestDetailDestination` Hashable struct (transient) を file 末尾に追加し、`.navigationDestination(for: CategoryDigestDetailDestination.self)` で `CategoryKnowledgeDetailView(category: dest.category)` に遷移するように接続 (T009 で stub だった部分を本実装に)

**Checkpoint**: T016-T017 完了で US4 完成。実機でカードタップ → 詳細画面遷移 + 4 セクション表示 + pull-to-refresh 再集約 確認可能

---

## Phase 7: User Story 5 (P2) — Empty / 抽出中表示

**Goal**: 記事 0 件 / AI 抽出中 で適切な Empty / Loading 表示

**Independent Test**:
- 記事 0 件 → ContentUnavailableView「Safari から記事を保存しましょう」
- 記事はあるが essence 0 件 → 「AI が知識を集約中です...」+ ProgressView

- [x] T018 [US5] `KnowledgeTree/Views/KnowledgeClipView.swift` の `digestsContent` ロジックを Empty/Loading 場面別出し分けに改修: 記事 0 件 = ContentUnavailableView (clip.empty.title + clip.empty.description) / 記事あり essence 0 件 = カスタムプレースホルダ (「AI が知識を集約中です...」+ ProgressView) / それ以外 = カード一覧 (T009 既実装)

**Checkpoint**: T018 完了で US5 完成 (実機検証は Phase 8 で確認)

---

## Phase 8: Polish & Cross-Cutting

**Purpose**: 既存テスト回帰 + ビルド警告ゼロ + CLAUDE.md 更新 + 実機検証 backlog

- [x] T019 [P] `xcodebuild build -scheme KnowledgeTree -destination "platform=iOS Simulator,name=iPhone 17"` でビルド SUCCEEDED + 本 spec 起因 warning ゼロ確認
- [x] T020 [P] `xcodebuild test -scheme KnowledgeTree -destination "platform=iOS Simulator,name=iPhone 17"` で全テスト実行、spec 017 まで 100+ ケース + 新規 10 ケース (KnowledgeDigestServiceTests 7 + KnowledgeDigestModelTests 3) 全 PASS 確認 (BodyExtractorTests 2 件は spec 016 から既存 FAIL、本 spec 起因ではない)
- [x] T021 [P] `CLAUDE.md` の spec 018 行を「📝 計画完了」→「✅ 実装」に更新 (commit hash 追記)
- [ ] T022 quickstart 12 シナリオ (SC-001〜SC-012) を実機検証 (ユーザー実施)

---

## Dependencies

```
T001, T002 (Setup)
   ↓
T003 (KnowledgeDigest @Model)
   ↓
T004 (Article inverse) ─┐
   ↓                     │
T005 (Service protocol + Foundation + Fallback)
   ↓
   ├─→ T006 (US1 model test) ─┐
   ├─→ T007 (US1 service test) ─┤
   ├─→ T008 (US1 KnowledgeClipCard) ─┐
   │                                  │
   ├─→ T009 (US1 KnowledgeClipView, stub destination) ─┤
   │                                                    │
   ├─→ T010 (US1 TabView 改修) ─┤                       │
   ├─→ T011 (US1 bootstrap inject) ─┤                  │
   │                                  │                  │
   ├─→ T012 (US2 確認、追加実装なし) ─┤                  │
   │                                  │                  │
   ├─→ T013 (US3 hook 追加) ─┤        │                  │
   ├─→ T014 (US3 bootstrap inject) ─┤ │                  │
   ├─→ T015 (US3 .refreshable) ─┤    │                  │
   │                              │    │                  │
   ├─→ T016 (US4 CategoryKnowledgeDetailView) ─┐         │
   ├─→ T017 (US4 destination 接続) ─┤          │         │
   │                                            │         │
   └─→ T018 (US5 Empty/Loading 分岐) ─┤        │         │
                                       ↓        ↓         ↓
                                       T019-T022 (Polish)
```

T009 は T016 の実装より先に完了するが destination は stub 状態、T016+T017 で本実装に切替。

## Parallel Opportunities

- T006 (model test) ‖ T007 (service test) ‖ T008 (Card view): 全部別ファイル、並列可能
- T013-T015 は同一ファイル KnowledgeTreeApp / KnowledgeExtractionService / KnowledgeClipView だが、影響部分が分離しているので順次実行が安全
- T019-T021 は別ファイル、Polish 段階で並列

## Implementation Strategy

### MVP (US1 + US4 のみで価値提供可)

T001-T011 + T016-T017 で:
- US1: 知識 Clip タブ + カード表示
- US4: Category 詳細画面

US2 (T012) は US1 と一体、追加実装ゼロで完了。US3 (refresh) と US5 (Empty) は P1/P2 で後追い可。

### 段階リリース提案

1. **Sprint 1 (MVP)**: Phase 1 + 2 + 3 + 6 = T001-T011 + T016-T017 (US1 + US4 完成、タブ + カード + 詳細画面 deliver)
2. **Sprint 2 (Refresh + Empty)**: Phase 5 + 7 = T013-T015 + T018 (US3 + US5 完成)
3. **Sprint 3 (Polish + 検証)**: Phase 8 = T019-T022 (build / test / 実機検証)

実装規模目安: 22 タスク、~930 行 (新規 6 ファイル + 改修 5 ファイル + 新規テスト 2 ファイル)。

## Memo

- spec 017 が同 work tree に未 commit、spec 018 commit 時に統合する想定 (1 PR で spec 017 + 018)
- Foundation Models の実機テストは Apple Intelligence 対応端末必須、Simulator では fallback 経路を確認
- KnowledgeExtractionService への hook 追加 (T013) は spec 012/013/015 の hook 拡張パターン同様、既存挙動を壊さない
- マルチカード分割 (US2) は AI 任せの自由判断、`@Guide` description で意図を伝達、必ず分割される保証はない (1 カードでも OK)

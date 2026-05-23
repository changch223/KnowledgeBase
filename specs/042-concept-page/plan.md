# Implementation Plan: ConceptPage (概念ページ)

**Branch**: `042-concept-page` | **Date**: 2026-05-23 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/042-concept-page/spec.md`

## Summary

`ConceptPage` は iKnow V1 (旧 知積、Bundle ID 継承) の **Phase A 第一弾 spec** であり、Karpathy LLM Wiki 思想の中核 "compounding artifact" を SwiftData で実体化する最重要 spec。

複数の保存記事に登場する同名 entity (人物 / モノ / 概念) を 1 つの **ConceptPage** に統合し、Apple Foundation Models で複数ソースを横断した「今わかっていること」(summary 200-400 字) と「横断的知見」(crossSourceInsights 最大 7 件) を AI が自動合成。新記事 ingest 時に既存 ConceptPage は `isStale = true` でマークされ、BGTask で順次再合成される。ユーザーは知識 Clip タブの新セクション「あなたが追っている人物・モノ」からカード一覧でアクセスし、詳細画面で 4 セクション (今わかっていること / 横断的知見 / 関連記事 / つながる人物・モノ) を閲覧、必要に応じて rename / merge / delete / pin で補正できる。

技術アプローチは **既存パターンの最大流用**: spec 040 (GraphExtractionService) の `@Generable` + `Mock` パターン、spec 018 (KnowledgeDigestService) の Foundation + Fallback 2 経路、spec 010 (chunked + meta-summary) の context window 対策、spec 024 (TagStore) / spec 041 (GraphNodeStore) の rename/merge/delete UI、spec 009 (BGTaskScheduler) の background 経路、spec 021 (EmbeddingService) の vector 統合。新規 8 ファイル + 改修 8 ファイル = ~1500 行、Mock LM で決定論的に 18 + 8 = ~26 テストケース。Foundation Models 不可端末では Fallback service が essence 並べた簡易 summary を silent に生成。

## Technical Context

**Language/Version**: Swift 6 (Swift 5.9+ 既存基盤に準拠)
**Primary Dependencies**: SwiftUI / SwiftData / FoundationModels (`SystemLanguageModel`, `@Generable`, `@Guide`) / NaturalLanguage (NLEmbedding 日本語 sentence embedding) / Accelerate (vDSP_dotpr / cosine similarity) / BackgroundTasks (BGTaskScheduler)
**Storage**: SwiftData (`@Model ConceptPage` を `SharedSchema.all` に追加、lightweight migration で自動付与、`@Attribute(.externalStorage) Data?` で embedding を blob 化)
**Testing**: XCTest (`KnowledgeTreeTests` — `MockLanguageModelSession` + in-memory `ModelContainer(isStoredInMemoryOnly: true)` の既存 fixture 流用、`SharedSchema.all` で構築)
**Target Platform**: iOS 26+ / iPadOS 26+ (Apple Intelligence 対応端末)
**Project Type**: iOS mobile app (Xcode project `KnowledgeTree.xcodeproj`、main target `KnowledgeTree` + share extension + safari extension の既存 multi-target 構成)
**Performance Goals**:
- 知識 Clip タブ scroll で 60 fps 維持 (ConceptPage 100+ 件想定、SC-007)
- ConceptPage 自動生成は 2 件目記事保存から 30 秒以内 (SC-001)
- 新記事 ingest 完了から isStale 反映まで 5 分以内 (SC-004)
- rename / merge / delete は 1 秒以内に UI 反映 (SC-006)
- 「関連記事」タップから ArticleDetailView 表示まで 1 秒以内 (SC-010)

**Constraints**:
- 完全 on-device、クラウド API ゼロ (Constitution I)
- AI 失敗時 silent fallback、ユーザーに「AI 失敗」表示しない (SC-008, V calm UX)
- Foundation Models context window 制約: 5+ 関連記事は hierarchical + meta-summary パターン必須 (SC-005)
- summary 200-400 字日本語、推測なし (Constitution III + VII)
- ConceptPage @Relationship `deleteRule: .nullify` で Article 側を保護 (FR-016)
- 同 entity でも categoryRaw 別に ConceptPage 1 つずつ (assumption: 同 categoryRaw + name で unique)
- BGTask 1 回あたり 3-5 件再合成 (BGAppRefreshTask の時間制限内)

**Scale/Scope**:
- 初期想定 ConceptPage 数: 50-200 件 (1 ユーザー、6 ヶ月利用想定)
- 関連記事数: ConceptPage あたり 2-20 件想定 (5+ で chunked パス)
- 新規ファイル 8 / 改修ファイル 8 / 新規テストファイル 2 / 既存テスト改修 1
- 規模 ~1500 行 (実装 ~1100 + テスト ~400)
- Mock テストケース 18 + 8 = ~26 ケース
- 期間 3 週間 (Phase A)
- タスク数見込み: 16-20 (US1-P1 / US2-P1 / US3-P1 / US4-P2 / US5-P2 / US6-P3 の 6 user story)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Reference: `.specify/memory/constitution.md` (v1.0.0). Each item below MUST be
checked or explicitly justified in **Complexity Tracking**.

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — ConceptPage / summary / crossSourceInsights / embedding は全て SwiftData (ローカル) に保存。Foundation Models は完全 on-device。外部送信ゼロ。spec.md FR-007/010 + assumption「完全 on-device、クラウド API 一切使用しない」で明記。
- [x] **II. MVP ファースト開発** — 本 spec は VISION.md v2.0 で確定した iKnow V1 必須機能 (Phase A 第一弾)。スコープは User Story 6 個に厳密に限定、Out of Scope (SavedAnswer / WikiLint / Community / Understanding Chat / Widget) を spec.md と本 plan で明示分離。
- [x] **III. ソースに基づいた知識生成** — ConceptPage.relatedArticles は `@Relationship` で Article への非 optional 参照を保持 (FR-006/030)。summary 生成 prompt で「原文に明示された内容のみ、推測なし」を強制 (FR-031、R4 @Guide 文言)。詳細画面の「関連記事」セクションから Article Detail へ jump 可能 (FR-023, SC-010)。
- [x] **IV. iOS の実現可能性を重視する** — 本 spec は記事取り込み手段を追加せず既存 Share Sheet ルートに乗る。`SystemLanguageModel.availability` チェックは ConceptSynthesisService 内で Foundation 経路 / Fallback 経路を切替 (R3、既存 AvailabilityChecker 流用)。iOS 26+ / Apple Intelligence 端末前提、Fallback は `.unavailable` でも silent に動作 (assumption + SC-008)。macOS 対象外、本 spec はモバイル UI 限定。
- [x] **V. シンプルで落ち着いた UX** — 自動生成は silent fire-and-forget (FR-012)、進捗バー / 通知 / バッジゼロ、AI 失敗を「整理中…」placeholder で隠す (FR-025)、Stale 再合成も BGTask で静か。詳細画面は片手操作前提の縦 scroll、4 セクションは折りたたみではなく順次表示で短時間確認可能。
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — 層分離: Model (ConceptPage) / Service (ConceptSynthesisServiceProtocol + Foundation 実装 + Fallback 実装) / Store (ConceptPageStore) / View (Card / DetailView / EditSheet)。AI 経路は `ConceptSynthesisServiceProtocol` + `LanguageModelSessionProtocol` の 2 段 protocol 境界で隔離、Mock 注入可能 (R3, R4)。既存 ServiceContainer + RefreshTrigger + ProcessingMonitor パターン踏襲。
- [x] **VII. 日本語ファースト** — summary / crossSourceInsights / セクションタイトル / Edit Sheet 文言は全て日本語。固有名詞は原文維持 (英語 entity 名は英語のまま、例: "Apple")。Localizable.xcstrings に ~15 文言追加 (View body 内 literal 禁止、既存パターン)。

### Quality Gates (二次ゲート)

- [x] **コード品質** — `fatalError` / `try!` / `!` は使用しない (既存 service 同パターン)。新規 protocol (`ConceptSynthesisServiceProtocol`) は 2 実装 (Foundation + Fallback) + Mock テスト の合計 3 箇所で使用 (新規抽象化 2 箇所以上ルール充足)。
- [x] **テスト** — 新規 `ConceptSynthesisServiceTests` 8-10 ケース + `ConceptPageStoreTests` 7-8 ケース、in-memory ModelContainer + SharedSchema.all + MockLanguageModelSession で決定論的。実ネットワーク使用ゼロ。既存 `KnowledgeExtractionServiceTests` に hook 追加検証 1-2 ケース。UI テストは V1 全体で別途検討 (本 spec ではユーザー実機検証で代替、quickstart.md 10 シナリオ)。
- [x] **アクセシビリティ・UX 一貫性** — 全インタラクティブ要素 (Card / Edit Sheet ボタン / ピン toggle) に `accessibilityIdentifier` 付与 (例: `conceptPageCard_<id>`, `conceptPageEditSheet_renameButton`)。Dynamic Type / Dark Mode (spec 017 DesignSystem `Color.adaptive` 流用) / VoiceOver 対応。SF Symbols (`person.fill`, `lightbulb.fill`, `link`, `pin.fill`) を活用。全文字列 `LocalizedStringKey` 経由。
- [x] **パフォーマンス** — KnowledgeClipView の ConceptPage `@Query` は `#Predicate { $0.relatedArticles.count >= 2 }` + `FetchDescriptor.fetchLimit = 5` で境界付け (上位 5 のみ、「すべて見る」遷移後は paginated)。100 件超の表示は別画面 (NavigationLink 遷移先) で `LazyVStack`。BGTask 1 回 3-5 件で時間制限内。escaping closure は `[weak self]` (Service 内)。

## Project Structure

### Documentation (this feature)

```text
specs/042-concept-page/
├── plan.md                                      # This file (/speckit-plan output)
├── research.md                                  # Phase 0 output (R1-R10)
├── data-model.md                                # Phase 1 output (ConceptPage @Model + 関連 transient)
├── quickstart.md                                # Phase 1 output (SC-001〜SC-010 検証手順)
├── contracts/
│   ├── concept-page-model.md                    # @Model ConceptPage 契約
│   ├── concept-synthesis-service.md             # ConceptSynthesisServiceProtocol 契約
│   ├── concept-synthesis-output.md              # @Generable ConceptSynthesisOutput 契約
│   ├── concept-page-store.md                    # ConceptPageStore (rename/merge/delete/setFollowing) 契約
│   ├── concept-page-detail-view.md              # ConceptPageDetailView UI 契約
│   ├── concept-page-card.md                     # ConceptPageCard UI 契約
│   └── knowledge-extraction-service-hook.md     # extract 末尾 hook 追加契約
├── checklists/
│   └── requirements.md                          # (/speckit-specify 段階で作成済、全 PASS)
└── tasks.md                                     # Phase 2 output (/speckit-tasks - NOT created here)
```

### Source Code (repository root)

```text
KnowledgeTree/                                   # main target (既存)
├── Models/
│   ├── Article.swift                            # 既存 (変更なし、@Relationship inverse 自動付与は SwiftData が判定)
│   ├── KnowledgeEntity.swift                    # 既存 (変更なし、ConceptPage 生成トリガーとしてのみ参照)
│   ├── GraphNode.swift                          # 既存 (spec 040、relatedConceptIDs の補助参照に利用)
│   └── ConceptPage.swift                        # ★ 新規 (~80 行) — @Model 12 フィールド + computed property
├── Services/
│   ├── KnowledgeExtractionService.swift         # ★ 改修 (~10 行追加) — extract 末尾に synthesizeConceptIfPossible(article:) hook
│   ├── LanguageModelSessionProtocol.swift       # ★ 改修 (~50 行追加) — ConceptSynthesisOutput @Generable + generateConceptSynthesis + Mock 拡張
│   ├── ConceptSynthesisService.swift            # ★ 新規 (~250 行) — Protocol + FoundationModelsConceptSynthesisService + FallbackConceptSynthesisService
│   ├── ConceptPageStore.swift                   # ★ 新規 (~150 行) — rename/merge/delete/setFollowing
│   ├── EmbeddingService.swift                   # 既存 (spec 021、ConceptPage.summary を embed)
│   ├── BackgroundExtractionScheduler.swift      # ★ 改修 (~30 行追加) — ConceptResynthesisScheduler を並列で登録
│   ├── SearchService.swift                      # ★ 改修 P3 (~30 行) — ConceptPage hit 対応
│   ├── ServiceContainer.swift                   # ★ 改修 (~15 行) — conceptSynthesisService / conceptPageStore 追加
│   └── (既存 service 群: TagStore, GraphNodeStore, KnowledgeDigestService, ...)
├── Views/
│   ├── KnowledgeClipView.swift                  # ★ 改修 (~40 行追加) — 「あなたが追っている人物・モノ」セクション + ConceptPage @Query
│   ├── ConceptPageCard.swift                    # ★ 新規 (~80 行) — 知識 Clip 内カード
│   ├── ConceptPageDetailView.swift              # ★ 新規 (~200 行) — 4 セクション ScrollView + toolbar
│   ├── ConceptPageEditSheet.swift               # ★ 新規 (~150 行) — rename / merge / delete UI + 確認 alert
│   ├── ArticleDetailView.swift                  # ★ 改修 P3 (~30 行) — 「この記事から派生した概念ページ」セクション
│   └── (既存 view 群)
├── SharedSchema.swift                           # ★ 改修 (1 行追加) — `ConceptPage.self` を all 配列に追加
├── KnowledgeTreeApp.swift                       # ★ 改修 (~10 行) — bootstrap で 2 新 service 構築 + inject、BGTask register
├── Info.plist                                   # ★ 改修 — BGTaskSchedulerPermittedIdentifiers に `app.KnowledgeTree.conceptResynthesis` 追加
└── Localization/Localizable.xcstrings           # ★ 改修 — 新規 ~15 文言

KnowledgeTreeTests/                              # unit test target
├── ConceptSynthesisServiceTests.swift           # ★ 新規 (~250 行、8-10 ケース)
├── ConceptPageStoreTests.swift                  # ★ 新規 (~200 行、7-8 ケース)
└── KnowledgeExtractionServiceTests.swift        # ★ 改修 (~30 行追加) — hook 呼び出し検証 1-2 ケース
```

**Structure Decision**: 既存の単一 Xcode project + multi-target 構成 (main `KnowledgeTree` + Share Extension + Safari Extension + Tests + UITests) を維持。本 spec は **main target のみ** に閉じる (Share/Safari extension は変更不要)。新規 Swift ファイルは Xcode の "Sync filesystem" によって自動的に main target に取り込まれる (`Models/` `Services/` `Views/` は既に target membership 設定済の親フォルダ)。BGTaskSchedulerPermittedIdentifiers の Info.plist 編集のみ pbxproj 直編集が必要 (既存 spec 009 と同パターン)。

## Complexity Tracking

> **Constitution Check は全 PASS。Complexity Tracking 記載不要。**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (該当なし) | — | — |

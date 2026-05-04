# Implementation Plan: 知識抽出 + 要約 (Knowledge Extraction + Summarization)

**Branch**: `004-extract-knowledge` *(計画中、spec 001-003 検証 + commit 後に実ブランチを切る)* | **Date**: 2026-05-04 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-summarize/spec.md`

## Summary

spec 003 で抽出した本文 (`ArticleBody.extractedText`) を入力に、Apple Foundation Models で **1 回の生成セッション** で 4 つの出力を取得 (essence + summary + keyFacts + entities)。出力は SwiftData の 3 つの新エンティティ (`ExtractedKnowledge`、`KeyFact`、`KnowledgeEntity`) に永続化し、Article への non-optional 参照で構造的整合性を保つ (Principle III)。一覧画面と Reader View に表示し、ユーザーは記事を開かずとも内容を把握できる。Apple Intelligence 不可能時はサイレントに skip し spec 001-003 機能は完全動作 (Principle V)。

技術的アプローチ: 4 層分離 (Principle VI) — `KnowledgeExtractor` (純粋な LanguageModelSession ラッパ、@Generable 構造化出力)、`KnowledgeExtractionService` (オーケストレーション + availability チェック + ArticleBody trigger)、`ArticleKnowledgeStore` (SwiftData 永続化、generation 出力 → @Model 保存のマッピング含む)、`KnowledgeSummaryView` (UI)。生成と保存を Generable 型 と @Model 型で分離 (transient generation type vs persistent storage type) することで、将来モデル更新時の互換性を確保。

## Technical Context

**Language/Version**: Swift 5.9+ (Xcode 17+ / iOS 26 SDK)。spec 001-003 と同じ。
**Primary Dependencies**: SwiftUI、SwiftData、**FoundationModels (NEW)**、Foundation。サードパーティ AI 禁止 (Constitution Additional Constraints)。
**Storage**: SwiftData。spec 001-003 で構築した App Group container に **3 つの新エンティティ追加**: `ExtractedKnowledge` / `KeyFact` / `KnowledgeEntity`。schema 拡張で `[Article.self, ArticleEnrichment.self, ArticleBody.self, ExtractedKnowledge.self, KeyFact.self, KnowledgeEntity.self]`。
**Testing**: XCTest / Swift Testing。`KnowledgeExtractor` は `LanguageModelSessionProtocol` 抽象でモック可能、テストは `MockLanguageModelSession` で決定論的に走る。`ArticleKnowledgeStore` は in-memory `ModelContainer`。実 Foundation Models を呼ぶテストは Apple Intelligence 対応シミュレータが必要なため CI 不可、quickstart の手動検証で担保。
**Target Platform**: iOS 26+ / iPadOS 26+。本 spec は **Apple Intelligence 対応端末** (iPhone 15 Pro+、iPad mini A17 Pro、iPad Pro M1+) で動作。非対応端末は graceful degradation (spec 004 の機能は出ないが spec 001-003 は完全動作)。
**Project Type**: モバイルアプリ。target 構成は不変 (spec 001 の 4 target 維持)。
**Performance Goals** (spec.md SC + Constitution パフォーマンスゲート):
- ArticleBody .succeeded → ExtractedKnowledge .succeeded まで median **6 秒以内** (SC-001、4 出力 1 セッション)
- 抽出ジョブ中もメインスレッド応答 ≤ 100 ms (SC-004)
- 100 件 ExtractedKnowledge 持ち一覧 60 fps スクロール (SC-005)
- Reader View 表示 300 ms 以内 (SC-006、知識セクション追加レンダリング劣化なし)

**Constraints**:
- **Apple Foundation Models のみ** 使用 (`import FoundationModels`)。サードパーティ AI / 外部 API 禁止 (Principle I + Additional Constraints)
- **新規ネットワークアクセスゼロ** (Foundation Models は on-device、Principle I 完全維持)
- `SystemLanguageModel.availability == .available` 必須 (Principle IV / Additional Constraints)
- 全 UI 文言 日本語 `Localizable.xcstrings` 経由 (Principle VII)
- ハルシネーション抑止: `@Guide` field 制約 + prompt 指示 + UI 「AI 生成」ラベル (3 層、自動検証は MVP 外)

**Scale/Scope**: 単一ユーザー / 単一端末。spec 001-003 と同じ規模。1 記事あたり生成 1 回、長期使用で数百〜数千件の ExtractedKnowledge レコード想定。

## Constitution Check

*GATE: Phase 0 research 前に通過必須。Phase 1 design 後に再評価。*

Reference: `.specify/memory/constitution.md` (v1.0.0)。

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — 本 spec は **新規ネットワークアクセスを一切持たない**。Apple Foundation Models は on-device 実行で外部送信なし。spec 002 の Network Access Justification はそのまま継続有効。新規追加なし。
- [x] **II. MVP ファースト開発** — knowledge graph (cross-article entity 集約)、AI チャット (RAG)、ハルシネーション自動検証、設定画面、多言語、widget、export 等を Out of Scope に明示。本 spec は「1 記事 → 1 ExtractedKnowledge (essence+summary+facts+entities)」を 1 セッション生成 + 表示まで。
- [x] **III. ソースに基づいた知識生成** — `ExtractedKnowledge` / `KeyFact` / `KnowledgeEntity` は **すべて Article への non-optional 参照** を持つ (cascade delete 付き)。**Principle III の構造的要件を data model レベルで満たす最初の spec**。Generable 出力にハルシネーションが含まれる可能性は prompt + Guide + 「AI 生成」UI ラベルで 3 層緩和、自動検証は将来 spec。
- [x] **IV. iOS の実現可能性を重視する** — Apple Foundation Models 公式 API のみ。`SystemLanguageModel.availability` を必ずチェックし `.available` 以外なら skip (graceful degradation)。Apple Intelligence 対応端末縛りは Constitution Principle IV により承認済。macOS 対象外。
- [x] **V. シンプルで落ち着いた UX** — 失敗 / skip / pending 状態を UI に明示しない (知識セクション全体非表示、Principle V)。「Apple Intelligence を有効にしてください」のような押しつけ表示禁止。Reader View の「知識サマリ」セクションは控えめ (本文と区切り線で分離、過剰装飾なし)。
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — 4 層分離: `KnowledgeExtractor` (LanguageModelSession ラッパ、純関数的)、`KnowledgeExtractionService` (orchestration + availability チェック)、`ArticleKnowledgeStore` (SwiftData 永続化、Generable→@Model マッピング)、`KnowledgeSummaryView` (Reader 内 UI コンポーネント)。`LanguageModelSessionProtocol` で Foundation Models を抽象化、テスト容易性確保。
- [x] **VII. 日本語ファースト** — 新規 UI 文言キー (`knowledge.section.title`、`knowledge.summary.heading`、`knowledge.facts.heading`、`knowledge.entities.heading`、`knowledge.aiGeneratedLabel`、`knowledge.bodyHeading`、entity 6 種、fact 5 種) を `Localizable.xcstrings` に追加。生成プロンプトも日本語で「日本語で出力」と明示。spec / plan / research / contracts / quickstart はすべて日本語で記述。

### Quality Gates (二次ゲート)

- [x] **コード品質** — 新規型 (`ExtractedKnowledge`、`KeyFact`、`KnowledgeEntity`、`ExtractedKnowledgeOutput`、`KeyFactOutput`、`KnowledgeEntityOutput`、`KnowledgeExtractor`、`KnowledgeExtractionService`、`ArticleKnowledgeStore`、`LanguageModelSessionProtocol`、`KnowledgeSummaryView`、`KeyFactRow`、`EntityChip`) はすべて単一責務。`fatalError` / `try!` / 強制アンラップ なし。生成 (Generable) と永続化 (@Model) の型分離で、将来モデルバージョン更新時の互換性確保。
- [x] **テスト** — `KnowledgeExtractorTests` (`MockLanguageModelSession` で決定論的、availability チェック + Generable 結果のマッピング)、`KnowledgeExtractionServiceTests` (orchestration + ArticleBody trigger)、`SwiftDataArticleKnowledgeStoreTests` (in-memory ModelContainer + cascade delete)。実 Foundation Models のテストは quickstart 手動検証で担保。
- [x] **アクセシビリティ・UX 一貫性** — 新規 accessibilityIdentifier: `knowledgeSummarySection`、`knowledgeEssence`、`knowledgeSummaryText`、`knowledgeFactRow`、`knowledgeEntityChip`、`knowledgeAIGeneratedLabel`。Dynamic Type 対応、Dark Mode 自動、VoiceOver で entity / fact が日本語で読み上げ。
- [x] **パフォーマンス** — Foundation Models 呼び出しは `Task.detached` で main 一切ブロックしない。`@Query<Article>` 経由で knowledge を relationship 取得 (lazy)。100 件 ExtractedKnowledge 持ち一覧の 60 fps は Instruments で別途検証 (tasks.md で task 化)。

**結論**: すべて check 通過。Complexity Tracking 不要。

## Project Structure

### Documentation (this feature)

```text
specs/004-summarize/
├── plan.md                                  # This file
├── research.md                              # Phase 0 出力
├── data-model.md                            # Phase 1 出力 (3 新エンティティ + Generable 型)
├── quickstart.md                            # Phase 1 出力 (Apple Intelligence 検証込み)
├── spec.md                                  # /speckit-specify 出力 (再々設計版)
├── checklists/
│   └── requirements.md                      # /speckit-specify 出力
├── contracts/                               # Phase 1 出力
│   ├── knowledge-extractor.md               # LanguageModelSession ラッパ
│   ├── knowledge-extraction-service.md      # orchestration + availability
│   └── article-knowledge-store.md           # SwiftData 永続化
└── tasks.md                                 # Phase 2 出力 (/speckit-tasks で生成、本コマンドでは未作成)
```

注: ディレクトリ名 `004-summarize` は内容と不一致 (knowledge 抽出 + 要約)。後で `git mv 004-summarize 004-extract-knowledge` でリネーム推奨だが、spec 内容と branch_name 表記で対応中。

### Source Code (repository root)

spec 001-003 の構造を **拡張する** (target 構成不変、ファイル追加のみ):

```text
KnowledgeTree/
├── Models/
│   ├── (既存: Article, ArticleEnrichment, ArticleBody)
│   └── ExtractedKnowledge.swift             # 新規 (data-model.md / 3 @Model クラスを 1 ファイルに集約: ExtractedKnowledge, KeyFact, KnowledgeEntity + 関連 enum)
├── Services/
│   ├── (既存)
│   ├── LanguageModelSessionProtocol.swift   # 新規 (Foundation Models ラッパ抽象、テスト容易性)
│   ├── KnowledgeExtractor.swift             # 新規 (contracts/knowledge-extractor.md、@Generable 出力型 + 生成ロジック)
│   ├── ArticleKnowledgeStore.swift          # 新規 (contracts/article-knowledge-store.md、Generable→@Model マッピング含む)
│   └── KnowledgeExtractionService.swift     # 新規 (contracts/knowledge-extraction-service.md、orchestration)
├── Views/
│   ├── (既存)
│   ├── ArticleRow.swift                     # 既存、要更新: essence + entity chips を表示
│   ├── ReaderView.swift                     # 既存、要更新: KnowledgeSummaryView を本文の上に表示
│   ├── KnowledgeSummaryView.swift           # 新規 (Reader 冒頭の知識セクション全体)
│   ├── KeyFactRow.swift                     # 新規 (KeyFact 1 行表示、種別アイコン付き)
│   └── EntityChip.swift                     # 新規 (KnowledgeEntity 1 chip、種別アイコン付き)
├── Localization/
│   └── Localizable.xcstrings                # 既存、要更新: knowledge.* 約 12 キー追加
├── KnowledgeTreeApp.swift                   # 既存、要更新: KnowledgeExtractionService bootstrap + backfill
├── Models/Article.swift                     # 既存、要更新: extractedKnowledge: ExtractedKnowledge? relationship 追加
├── Services/BodyExtractionService.swift     # 既存、要更新: ArticleBody .succeeded 時に KnowledgeExtractionService.extract をキック (optional 依存)
├── (他 既存ファイル変更なし)

KnowledgeTreeShareExtension/                 # 全ファイル変更なし

KnowledgeTreeTests/
├── (既存: spec 001-003 のテスト)
├── KnowledgeExtractorTests.swift            # 新規 (MockLanguageModelSession で 8 ケース)
├── KnowledgeExtractionServiceTests.swift    # 新規 (orchestration + availability + ArticleBody trigger)
└── SwiftDataArticleKnowledgeStoreTests.swift # 新規 (in-memory + cascade delete + Generable→@Model マッピング)

KnowledgeTreeUITests/
├── SaveArticleUITests.swift                 # 既存、要更新: 知識セクション表示テスト追加 (launch arg seed)
```

**Structure Decision**:
- spec 001-003 と同じ単一 Xcode project 構成。target 追加なし。
- 新規 Service 群は **app target のみ**。Share Extension は知識抽出をトリガしない (Principle V — 共有を止めない、Share Ext は記事保存のみ集中)。
- `ExtractedKnowledge` / `KeyFact` / `KnowledgeEntity` は 1 ファイル `ExtractedKnowledge.swift` に集約 (関係する 3 @Model + enum を一箇所で管理、Principle VI コード品質)。
- 既存 `BodyExtractionService` を要更新: optional `knowledgeExtractionService` を inject、ArticleBody .succeeded 時に呼ぶ (spec 003 から spec 004 への chain 形式)。
- `Article.swift` に `extractedKnowledge: ExtractedKnowledge?` の cascade relationship を追加。
- App Group ID / entitlements は spec 001 のまま流用。ネットワーク capability は不要 (on-device AI)。

## Complexity Tracking

> **Constitution Check で violations が無いため未記入。**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (なし) | — | — |

## 設計上の意思決定 (Plan-level Decisions)

spec.md で定めず本 plan で決めた事項を明示:

1. **生成型 (Generable) と永続型 (@Model) の分離**: `ExtractedKnowledgeOutput` / `KeyFactOutput` / `KnowledgeEntityOutput` (transient @Generable) と `ExtractedKnowledge` / `KeyFact` / `KnowledgeEntity` (persistent @Model) を別々に定義し、Store 層で マッピング。理由: (a) Foundation Models のモデル更新で出力構造が変わっても永続化形は安定、(b) 永続化形に SwiftData 特有の制約 (relationship、Date、UUID 主キー) を入れられる、(c) テストで Mock Generable 出力を作りやすい。
2. **1 セッション生成 vs 複数セッション**: 1 セッションで 4 出力を取得。理由: (a) 4 回別セッションを呼ぶより合計時間 / 電力 効率的、(b) prompt で「essence と summary と key facts は互いに矛盾しない」と整合性制約を入れられる、(c) Apple Foundation Models の `@Generable` 構造化出力が複合型 (struct + enum + array) を 1 度に生成可能。失敗確率は若干上がるが、`.partiallySucceeded` で部分成功も拾える。
3. **enum を `@Generable` で宣言**: `FactType` (event / claim / statistic / definition / quote)、`EntityType` (person / organization / location / concept / product / work) を `@Generable enum` として宣言し、モデルが case を選ぶ形にする。@Guide で各 case の意味を日本語で記述。
4. **availability subscription は不要**: `SystemLanguageModel.availability` の reactive 監視は実装複雑性が高い。MVP では起動時 + 各抽出ジョブ前の都度チェックで十分。ユーザーが Apple Intelligence を ON 切替後は再起動 backfill で吸収。
5. **per-article session lifecycle**: `LanguageModelSession` を記事ごとに作成 → 使い捨て。理由: (a) Apple ガイドで短命セッションが推奨、(b) 状態漏れリスクなし、(c) 初期化コストは数 ms オーダーで無視可能。
6. **prompt template**: 固定テンプレート (Bundle に埋め込まず Swift String として持つ)。多言語対応・カスタム化は将来 spec。MVP の prompt は spec.md の FR-020 をそのまま日本語で記述。
7. **knowledge セクションの折り畳み**: MVP では常時表示。長くなりすぎる懸念があるが、key facts 5 件 + entity 10 個 + summary 300 字 でも Reader 1 画面の上半分に収まる規模なので問題なし。折り畳み UI は将来 spec。
8. **既存記事の backfill**: 起動時に ArticleBody .succeeded だが ExtractedKnowledge 不在の Article をスキャンしてキューイング。Apple Intelligence 有効化後の自動 catch-up が動く。spec 002 / spec 003 の backfill と直列実行 (並列度 1)。
9. **`schema migration`**: spec 001-003 がまだ未リリースのため、3 新エンティティの追加は SwiftData 自動 lightweight migration で吸収。production リリース後は明示的 migration が必要。

# Implementation Plan: 知識 Clip タブ + Category 統合 AI ダイジェスト + Category 知識総まとめ詳細画面

**Branch**: `018-knowledge-clip-tab` | **Date**: 2026-05-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/018-knowledge-clip-tab/spec.md`

## Summary

新タブ「知識 Clip」を TabView 中央に追加し、Category 単位で AI が複数記事を統合した「ダイジェストカード」を縦スクロール表示する。マルチカード分割は Foundation Models 任せ (`@Generable DigestOutput { cards: [Card] }`)。カードタップで Category 知識総まとめ詳細画面 (CategoryKnowledgeDetailView) に遷移、包括サマリ + Top KeyFact 10 + Top Entity 5 + 元記事一覧で深掘り。新記事保存時に該当 Category Digest を `isStale = true` 化、ユーザーは pull-to-refresh で AI 再集約。Apple Intelligence 不可端末は FallbackKnowledgeDigestService で essence 並べ簡易表示。

技術アプローチ:
- **新規 1 @Model**: KnowledgeDigest (sourceArticles non-optional、Constitution III 整合)
- **新規 1 protocol + 2 実装**: KnowledgeDigestService / Foundation / Fallback
- **新規 3 view**: KnowledgeClipView / KnowledgeClipCard / CategoryKnowledgeDetailView
- **改修 5 ファイル**: KnowledgeTreeApp / SharedSchema / KnowledgeExtractionService / Article / Localizable.xcstrings
- **新規テスト**: KnowledgeDigestServiceTests (7) + KnowledgeDigestModelTests (3)

## Technical Context

**Language/Version**: Swift 6 (Xcode 16+, strict concurrency)
**Primary Dependencies**: SwiftUI 6, SwiftData, Apple Foundation Models (`@Generable`, `LanguageModelSession`)
**Storage**: SwiftData lightweight migration (新 @Model `KnowledgeDigest` 追加、既存スキーマ無傷)
**Testing**: Swift Testing (`@Test` / `#expect`) + in-memory `ModelContainer` + Foundation/Fallback mock
**Target Platform**: iOS 26+ / iPadOS 26+ (Apple Intelligence-capable 推奨、不可端末は Fallback)
**Project Type**: ネイティブ iOS app (Xcode 16 PBXFileSystemSynchronizedRootGroup auto-sync)
**Performance Goals**:
- 知識 Clip タブ初期表示 ≤300ms (1000 記事 / 100 Digest 規模)
- Foundation Models 1 Category 集約 ≤10 秒
- pull-to-refresh 全 stale 一括 ≤30 秒 (10 Category)
- 60fps 維持
**Constraints**:
- 既存 SwiftData schema 完全保持 (KnowledgeDigest 追加のみ、既存無改変)
- 既存 view (ArticleListView / AIBrainView / ArticleDetailView / CategoryFilteredListView) 完全保持
- 既存 unit test 100+ ケース全回帰 PASS
- Foundation Models on-device、外部送信ゼロ
**Scale/Scope**:
- 新規 6 ファイル + 改修 5 ファイル + 新規テスト 2 ファイル = ~13 ファイル
- ~930 行
- ~15-20 タスク (~spec 016 並)

## Constitution Check

Reference: `.specify/memory/constitution.md` (v1.0.0).

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — Foundation Models on-device、KnowledgeDigest ローカル保存、外部 API ゼロ
- [x] **II. MVP ファースト開発** — タイムライン / AI インサイト / BGTask 自動再集約 / Custom Category 等は将来 spec、本 spec は Category ダイジェスト + 詳細画面のみ
- [x] **III. ソースに基づいた知識生成** — `KnowledgeDigest.sourceArticles` を `@Relationship(deleteRule: .nullify)` で保持、UI に元記事リスト表示、AI 出力は必ず元記事 ID を引用
- [x] **IV. iOS の実現可能性を重視する** — Apple Foundation Models / Fallback 切替で Apple Intelligence 不可端末対応、SystemLanguageModel.availability チェック必須
- [x] **V. シンプルで落ち着いた UX** — 既読管理ゼロ、stale マークは控えめ caption、手動 pull-to-refresh のみ、不安喚起 UI 全廃継続
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — KnowledgeDigestService protocol で Foundation/Fallback 差し替え可能、UI / Service / Model 分離、KnowledgeExtractionService への hook 1 箇所のみ
- [x] **VII. 日本語ファースト** — 全 UI 文言 Localizable.xcstrings 経由、Foundation Models prompt も日本語

### Quality Gates (二次ゲート)

- [x] **コード品質** — Swift API Design Guidelines 準拠、新規抽象化 (KnowledgeDigestService) は 2 箇所利用 (Foundation / Fallback)、`fatalError` / `try!` なし
- [x] **テスト** — `KnowledgeTreeTests/` に新規 KnowledgeDigestServiceTests (7) + KnowledgeDigestModelTests (3)、in-memory `ModelContainer` で隔離、Foundation Models mock
- [x] **アクセシビリティ・UX 一貫性** — 全 interactive 要素に accessibilityLabel / Hint、Dynamic Type 互換、VoiceOver 対応、Localizable.xcstrings 経由
- [x] **パフォーマンス** — `@Query<KnowledgeDigest>` は LazyVStack で lazy load、Foundation Models 50 記事 cap でトークン管理、escaping closure は `[weak self]`

**全項目 PASS、Complexity Tracking 不要。**

## Project Structure

### Documentation (this feature)

```text
specs/018-knowledge-clip-tab/
├── plan.md              # This file
├── research.md          # Phase 0 output (R1〜R12)
├── data-model.md        # Phase 1 output (KnowledgeDigest @Model + transient struct)
├── quickstart.md        # Phase 1 output (12 シナリオ)
├── contracts/
│   ├── knowledge-digest-service.md
│   ├── knowledge-digest-model.md
│   ├── knowledge-clip-view.md
│   ├── knowledge-clip-card.md
│   └── category-knowledge-detail-view.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
KnowledgeTree/
├── Models/
│   ├── KnowledgeDigest.swift          # 【新規】@Model (~50 行)
│   └── Article.swift                  # 【改修】digests inverse relationship (~3 行)
├── Services/
│   └── KnowledgeDigestService.swift   # 【新規】protocol + Foundation + Fallback (~250 行)
├── Views/
│   ├── KnowledgeClipView.swift        # 【新規】3rd タブ root (~120 行)
│   ├── KnowledgeClipCard.swift        # 【新規】1 カード view (~120 行)
│   └── CategoryKnowledgeDetailView.swift  # 【新規】詳細画面 (~110 行)
├── KnowledgeTreeApp.swift             # 【改修】3rd タブ + service inject + bootstrap (~30 行追加)
├── SharedSchema.swift                 # 【改修】KnowledgeDigest.self 追加 (~1 行)
└── Localization/
    └── Localizable.xcstrings           # 【改修】10 文言追加

KnowledgeTreeTests/
├── KnowledgeDigestServiceTests.swift  # 【新規】7 ケース (~150 行)
└── KnowledgeDigestModelTests.swift    # 【新規】3 ケース (~50 行)
```

**Structure Decision**: PBXFileSystemSynchronizedRootGroup により Xcode 16+ は新規 .swift ファイルを自動取り込み、pbxproj 編集不要。新規 6 + 改修 5 + 新規テスト 2 = ~13 ファイル。

## Complexity Tracking

(該当なし — 全項目 PASS)

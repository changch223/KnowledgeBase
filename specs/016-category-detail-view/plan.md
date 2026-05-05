# Implementation Plan: Category 詳細画面 + ArticleRow 時間軸 + ArticleDetailView 本文折りたたみ

**Branch**: `016-category-detail-view` | **Date**: 2026-05-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/016-category-detail-view/spec.md`

## Summary

spec 015 実機検証で発覚した B1 バグ (Category 数字 ≠ TagFilteredListView 表示数) を、AIBrainView の Category 行タップ先を **新規 CategoryFilteredListView** に切り替えることで根本解決する。同 view は Category 内全 Tag の Article union を集計表示し、上部にタグフィルターチップ (上位 5 + 「+N」展開) で OR 絞り込み可能。同時に 4 件の UX 改善 (ArticleRow に savedAt 時間軸 / ArticleDetailView 本文 DisclosureGroup 折りたたみ) を 1 spec に集約する。

技術アプローチ:
- **新規 1 view + 新規 1 Hashable destination type**
- **既存 5 ファイル改修**: AIBrainView (NavigationLink target + .navigationDestination 追加) / KnowledgeCategoryRow (topTagName 削除) / ArticleRow (savedAt 表示) / ArticleDetailView (bodySection を DisclosureGroup でラップ) / Localizable.xcstrings (新文言)
- **新 @Model / 新 schema migration / 新 service ゼロ**: spec 015 の Category / CategorySeed と既存 Tag.articles relationship を再利用
- **Apple-quiet 路線維持**: 全 interactive 要素 actionBlue 単一色、gradient/shadow 全廃継続

## Technical Context

**Language/Version**: Swift 6 (Xcode 16+, strict concurrency)
**Primary Dependencies**: SwiftUI 6, SwiftData, Foundation (RelativeDateTimeFormatter / DateFormatter / Calendar)
**Storage**: SwiftData (既存スキーマ変更なし、`Tag.categoryRaw` は spec 015 で導入済)
**Testing**: Swift Testing (`@Test` / `#expect`) + in-memory `ModelContainer`、UI test は XCUITest
**Target Platform**: iOS 26+ / iPadOS 26+ (Apple Intelligence-capable)
**Project Type**: ネイティブ iOS app (Xcode 16 PBXFileSystemSynchronizedRootGroup auto-sync)
**Performance Goals**:
- CategoryFilteredListView 初期表示 ≤ 300 ms (1000 記事規模)
- タグフィルター切替 ≤ 100 ms
- DisclosureGroup expand ≤ 0.5 秒
- 60 fps 維持
**Constraints**:
- 既存 SwiftData schema 完全保持 (新 attribute / migration なし)
- 既存 ArticleListView / TagListView / TagFilteredListView 完全保持 (ArticleRow の savedAt 追加以外無改修)
- 既存 spec 015 までのテスト 66+ ケースが全 PASS
**Scale/Scope**:
- 新規 1 ファイル (~250 行 CategoryFilteredListView)
- 改修 5 ファイル (~150 行 net change)
- ~10-15 タスク

## Constitution Check

Reference: `.specify/memory/constitution.md` (v1.0.0).

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — 全データ (Article / Tag / Category 計算) は SwiftData ローカル。外部送信ゼロ。新規ネットワーク呼び出しなし
- [x] **II. MVP ファースト開発** — タグフィルター AND/NOT / 折りたたみ状態永続化 / ソート切替 は将来 spec、本 spec は OR + DisclosureGroup + savedAt 表示のみ
- [x] **III. ソースに基づいた知識生成** — 本 spec は AI 生成物を作らない (UI 拡張のみ)、既存 ExtractedKnowledge ↔ Article 参照は変わらず
- [x] **IV. iOS の実現可能性を重視する** — 全機能 SwiftUI 標準 (NavigationStack / DisclosureGroup / RelativeDateTimeFormatter) で実装、外部 SDK ゼロ
- [x] **V. シンプルで落ち着いた UX** — gradient / shadow / 多色 phase tint 全廃継続、interactive は actionBlue 単一、本文折りたたみは情報過多回避
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — CategoryFilteredListView は ArticleRow + TagChip + 既存 Tag relationship を再利用、新 service ゼロ、純 UI 拡張
- [x] **VII. 日本語ファースト** — 全文言 Localizable.xcstrings 経由、Category 名は日本語、savedAt フォーマットは ja_JP

### Quality Gates (二次ゲート)

- [x] **コード品質** — Swift API Design Guidelines 準拠、新規抽象化 ≤1 (CategoryFilteredDestination のみ)、`fatalError` / `try!` なし
- [x] **テスト** — `KnowledgeTreeTests/` に新規ユニットテスト (CategoryFilteredListView の computed property テスト + ArticleRow.savedAtDisplay テスト)、in-memory ModelContainer
- [x] **アクセシビリティ・UX 一貫性** — 全 interactive 要素に accessibilityIdentifier / Label / Hint、Dynamic Type / Dark Mode 対応、Localizable.xcstrings 経由
- [x] **パフォーマンス** — `@Query<Tag>` は既存 fetch、フィルターは memory 内 (≤1000 件規模)、escaping closure なし、60 fps 計測は実機検証で確認

**全項目 PASS、Complexity Tracking 不要。**

## Project Structure

### Documentation (this feature)

```text
specs/016-category-detail-view/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── category-filtered-list-view.md
│   ├── category-filtered-destination.md
│   ├── article-row-saved-at.md
│   └── article-detail-body-disclosure.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
KnowledgeTree/
├── Views/
│   ├── CategoryFilteredListView.swift  # 【新規】Category 詳細画面の本体
│   ├── AIBrainView.swift               # 【改修】NavigationLink target + .navigationDestination
│   ├── KnowledgeCategoryRow.swift      # 【改修】topTagName 削除、accessibilityLabel 微調整
│   ├── ArticleRow.swift                # 【改修】savedAt 時間軸表示追加
│   ├── ArticleDetailView.swift         # 【改修】bodySection を DisclosureGroup でラップ
│   ├── ArticleListView.swift           # 【改修】CategoryFilteredDestination Hashable struct を追加 (or 別ファイル)
│   ├── TagFilteredListView.swift       # 既存維持 (TagListView 経由でのみ参照)
│   ├── ArticleRow / TagChip / EntityChip ... 全 26 view 既存
│   └── ...
├── Services/
│   ├── CategorySeed.swift              # 既存 (spec 015)、変更なし
│   ├── AutoCategoryClassifier.swift    # 既存 (spec 015)、変更なし
│   └── ...
├── Models/
│   ├── Tag.swift                       # 既存 (categoryRaw + articles relationship)、変更なし
│   ├── Article.swift                   # 既存、変更なし
│   └── ...
├── Localization/
│   └── Localizable.xcstrings           # 【改修】新文言追加
└── DesignSystem.swift                  # 既存、変更なし

KnowledgeTreeTests/
├── CategoryFilteredListViewTests.swift # 【新規】computed property + フィルター挙動 unit test
├── ArticleRowSavedAtTests.swift        # 【新規】savedAt フォーマット切替 unit test
└── （既存テスト 66+ ケース 全保持）

KnowledgeTreeUITests/
└── （既存維持、新規 UI test は本 spec では追加せず実機検証で代替）
```

**Structure Decision**: 既存 PBXFileSystemSynchronizedRootGroup により Xcode 16+ は新規 .swift ファイルを自動取り込み。pbxproj 編集不要。新規 1 ファイル + 改修 5 ファイル。

## Complexity Tracking

(該当なし — 全項目 PASS)

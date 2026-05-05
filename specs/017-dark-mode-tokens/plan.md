# Implementation Plan: Dark/Light Mode 自動切り替え対応 (Apple-quiet 維持)

**Branch**: `017-dark-mode-tokens` | **Date**: 2026-05-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/017-dark-mode-tokens/spec.md`

## Summary

`DesignSystem.swift` に `Color.adaptive(light:dark:)` extension を新設し、5 new tokens (`actionBlue` / `actionBlueFocus` / `parchment` / `knowledgeTile` / `tagFill`) に Dark variant を追加する。`UIColor { trait in ... }` dynamicProvider で SwiftUI が auto adapt、view 改修ゼロ。9 deprecated alias は actionBlue 経由で auto adapt。DESIGN.md の colors frontmatter に Dark variant を併記し、Known Gaps から「Dark mode: 未文書化」エントリを削除。

技術アプローチ:
- **改修 2 ファイル**: DesignSystem.swift (~30 行追加) / DESIGN.md (~15 行更新)
- **新規 1 ファイル**: ColorAdaptiveTests.swift (~50 行)
- **view 改修ゼロ**: 全 18 view が DS.Color.* token 経由で auto adapt
- **新 @Model / schema migration / 新 service ゼロ**

## Technical Context

**Language/Version**: Swift 6 (Xcode 16+, strict concurrency)
**Primary Dependencies**: SwiftUI 6, UIKit (UIColor dynamicProvider)
**Storage**: 該当なし (色 token のみ、SwiftData 無関係)
**Testing**: Swift Testing (`@Test` / `#expect`) + UIKit `UITraitCollection` で Light/Dark trait 注入
**Target Platform**: iOS 26+ / iPadOS 26+
**Project Type**: ネイティブ iOS app (Xcode 16 PBXFileSystemSynchronizedRootGroup auto-sync)
**Performance Goals**:
- Dark/Light 切替時の再描画 ≤100ms
- 60fps 維持
**Constraints**:
- 既存 view 18 ファイル完全保持 (token 経由で auto adapt)
- 既存 test 93+ ケース全回帰 PASS
- DesignSystem.swift の既存 token API (DS.Color.actionBlue 等) を変えない
**Scale/Scope**:
- 改修 2 ファイル + 新規 1 ファイル = ~95 行
- ~5-8 タスク

## Constitution Check

Reference: `.specify/memory/constitution.md` (v1.0.0).

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — 色 token の変更のみ、データ送信ゼロ
- [x] **II. MVP ファースト開発** — Dynamic Type / iPad Split View / High Contrast / Custom theme 等は将来 spec、本 spec は Dark Mode 一元のみ
- [x] **III. ソースに基づいた知識生成** — AI 出力には影響なし、純 UI 拡張
- [x] **IV. iOS の実現可能性を重視する** — `UIColor { trait in ... }` は iOS 14+ 確立 API、外部 SDK ゼロ
- [x] **V. シンプルで落ち着いた UX** — Dark variant も Apple-quiet (彩度低)、single accent 維持、gradient/shadow 全廃継続
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — DesignSystem.swift 一元、view 改修ゼロ、token-driven 設計
- [x] **VII. 日本語ファースト** — UI 文言は無関係 (色のみ変更)、仕様書日本語

### Quality Gates (二次ゲート)

- [x] **コード品質** — Swift API Design Guidelines 準拠、新規抽象化 1 (`Color.adaptive(light:dark:)`)、`fatalError` / `try!` なし
- [x] **テスト** — `KnowledgeTreeTests/` に新規 ColorAdaptiveTests (UITraitCollection で Light/Dark 注入)、in-memory 構造で隔離
- [x] **アクセシビリティ・UX 一貫性** — token-driven なので全 view で一貫、Dark Mode は本 spec で正式対応、VoiceOver 既存維持
- [x] **パフォーマンス** — Color(uiColor:) は SwiftUI 標準パターン、再描画 ≤100ms、60fps 維持

**全項目 PASS、Complexity Tracking 不要。**

## Project Structure

### Documentation (this feature)

```text
specs/017-dark-mode-tokens/
├── plan.md              # This file
├── research.md          # Phase 0 output (R1〜R10)
├── data-model.md        # Phase 1 output (transient minimal)
├── quickstart.md        # Phase 1 output (9 シナリオ)
├── contracts/
│   └── color-adaptive.md  # Color.adaptive(light:dark:) 契約
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
KnowledgeTree/
├── DesignSystem.swift              # 【改修】Color.adaptive 追加 + 5 tokens を adaptive 化 (~30 行)
└── (全 18 view 改修なし)

DESIGN.md                           # 【改修】colors frontmatter に dark variant 追記 + Migration Notes + Known Gaps から削除 (~15 行)

KnowledgeTreeTests/
├── ColorAdaptiveTests.swift        # 【新規】Color.adaptive 単体テスト (~50 行)
└── (既存テスト全保持、回帰確認)
```

**Structure Decision**: PBXFileSystemSynchronizedRootGroup により Xcode 16+ は新規 .swift ファイルを自動取り込み。pbxproj 編集不要。改修 2 + 新規 1 ファイルのみ。

## Complexity Tracking

(該当なし — 全項目 PASS)

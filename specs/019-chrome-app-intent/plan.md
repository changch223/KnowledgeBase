# Implementation Plan: Chrome 連携 (App Intents + iOS Shortcut + 設定画面 Setup Guide)

**Branch**: `019-chrome-app-intent` | **Date**: 2026-05-06 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/019-chrome-app-intent/spec.md`

## Summary

iOS 16+ App Intents (`AppIntent`) で「URL を 知積に保存」アクションを定義、AppShortcutsProvider で Shortcuts.app 自動登録。Personal Automation で「Chrome 起動時 → 自動保存」を実現。アプリ内 SettingsView (新規) + ChromeShortcutSetupView (新規) で Setup Guide 提供。AI ブレインタブ右上に歯車を追加。

技術アプローチ:
- **新規 4 ファイル**: SaveURLToKnowledgeTreeIntent / ArticleSavingActor / SettingsView / ChromeShortcutSetupView
- **改修 2 ファイル**: AIBrainView (toolbar 歯車 + navigationDestination) / Localizable.xcstrings (13 文言)
- **新規テスト 1 ファイル**: SaveURLToKnowledgeTreeIntentTests (5 ケース)
- **新 @Model / schema migration ゼロ**: 既存 Article を再利用、SwiftData は App Group ModelContainer 共有

## Technical Context

**Language/Version**: Swift 6 (Xcode 16+, strict concurrency)
**Primary Dependencies**: SwiftUI 6, SwiftData, AppIntents (iOS 16+), Foundation
**Storage**: 既存 SwiftData (Article @Model 再利用、App Group ModelContainer 共有)
**Testing**: Swift Testing (`@Test` / `#expect`) + in-memory `ModelContainer` で actor logic 検証
**Target Platform**: iOS 26+ / iPadOS 26+ (AppIntents iOS 16+ で動作可能、Personal Automation iOS 17+)
**Project Type**: ネイティブ iOS app (Xcode 16 PBXFileSystemSynchronizedRootGroup auto-sync)
**Performance Goals**:
- App Intent 実行 ≤5 秒 (URL 受信 → SwiftData 保存)
- Setup Guide 遷移 ≤300ms
- Shortcuts.app deeplink 起動 ≤1 秒
**Constraints**:
- Foundation Models 不要 (App Intent は AI に依存しない純 SwiftData 保存)
- 既存 view (ArticleListView / KnowledgeClipView / AIBrainView / etc.) コア機能完全保持
- 既存 unit test 110+ ケース全回帰 PASS
- App Group ModelContainer で Share Extension と共存
**Scale/Scope**:
- 新規 4 + 改修 2 + 新規テスト 1 = ~7 ファイル
- ~540 行
- ~12 タスク (中スコープ)

## Constitution Check

Reference: `.specify/memory/constitution.md` (v1.0.0).

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — App Intent → SwiftData ローカル保存、外部 API ゼロ
- [x] **II. MVP ファースト開発** — Action 1 つ (URL 保存) のみ、Chrome のみ MVP、Edge/Brave/Arc / 「最近の記事を取得」「タグで検索」は将来 spec
- [x] **III. ソースに基づいた知識生成** — 保存された URL は既存 spec 002/003 backfill (enrichment / body / knowledge) で追跡可能、Constitution III 整合
- [x] **IV. iOS の実現可能性を重視する** — App Intents iOS 16+ / Personal Automation iOS 17+ は Apple 確立 API、本 spec で「将来項目」を MVP 入り
- [x] **V. シンプルで落ち着いた UX** — silent 保存、通知 / バッジ / トースト ゼロ、Setup は任意 (歯車から探す)、不安喚起 UI 全廃継続
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — AppShortcutsProvider + ArticleSavingActor で経路分離、static performSave で testable、UI / Service / Model 分離
- [x] **VII. 日本語ファースト** — 全 UI 文言日本語、AppShortcutsProvider phrases に英語 fallback 併記、Localizable.xcstrings 経由

### Quality Gates (二次ゲート)

- [x] **コード品質** — Swift API Design Guidelines 準拠、新規抽象化 (ArticleSavingActor) は App Intent + main app 双方で利用、`fatalError` / `try!` なし
- [x] **テスト** — `KnowledgeTreeTests/` に新規 SaveURLToKnowledgeTreeIntentTests (5 ケース)、in-memory ModelContainer + static performSave 経由で純関数 testable
- [x] **アクセシビリティ・UX 一貫性** — 全 interactive 要素に accessibilityIdentifier / Label / Hint、Dynamic Type 互換、VoiceOver 対応、Localizable.xcstrings 経由
- [x] **パフォーマンス** — App Intent 実行 ≤5 秒、Setup Guide 遷移 ≤300ms、ModelContainer は actor 内 lazy cache、escaping closure なし

**全項目 PASS、Complexity Tracking 不要。**

## Project Structure

### Documentation (this feature)

```text
specs/019-chrome-app-intent/
├── plan.md              # This file
├── research.md          # Phase 0 output (R1〜R12)
├── data-model.md        # Phase 1 output (transient + actor)
├── quickstart.md        # Phase 1 output (10 シナリオ)
├── contracts/
│   ├── save-url-to-knowledgetree-intent.md
│   ├── app-shortcuts-provider.md
│   ├── article-saving-actor.md
│   ├── settings-view.md
│   └── chrome-shortcut-setup-view.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
KnowledgeTree/
├── AppIntents/                                     # 【新規ディレクトリ】
│   ├── SaveURLToKnowledgeTreeIntent.swift          # 【新規】AppIntent + AppShortcutsProvider
│   └── ArticleSavingActor.swift                    # 【新規】App Intent → SwiftData actor
├── Views/
│   ├── SettingsView.swift                          # 【新規】設定画面 root
│   ├── ChromeShortcutSetupView.swift               # 【新規】Setup Guide
│   └── AIBrainView.swift                           # 【改修】toolbar 歯車 + navigationDestination
└── Localization/
    └── Localizable.xcstrings                       # 【改修】13 文言追加

KnowledgeTreeTests/
└── SaveURLToKnowledgeTreeIntentTests.swift         # 【新規】5 ケース
```

**Structure Decision**:
- AppIntents/ ディレクトリは PBXFileSystemSynchronizedRootGroup により Xcode 16+ で自動取り込み (KnowledgeTree/ 直下、Models/Services/Views と同列)
- ArticleSavingActor は AppIntents/ ディレクトリに置く (App Intent 専用 helper として)
- SettingsView と ChromeShortcutSetupView は Views/ 直下 (既存 view と同列)

## Complexity Tracking

(該当なし — 全項目 PASS)

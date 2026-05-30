# Implementation Plan: Sprint 1 P0 出荷ブロッカー修正

**Branch**: `059-p0-shipping-blockers` | **Date**: 2026-05-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/059-p0-shipping-blockers/spec.md`

## Summary

code review FINAL report の P0 5 件 (placeholder「アプリ名」/ Onboarding 廃止タブ案内 / Settings 重複 iCloud / Chat 引用リンク無反応 / UI test 形骸化) を 1 PR で解消する。新規 schema ゼロ・新規 service ゼロ。既存 navigation 基盤 (ChatTabView の `navigationPath` + `.navigationDestination(for: Article.self)`) と既存 accessibilityIdentifier を再利用し、UI 文言の xcstrings 化 (触る view のみ) + callback 1 本の配線 + 形骸 UI test の置き換えに留める純引き算的修正。

## Technical Context

**Language/Version**: Swift 6 / SwiftUI (iOS 26 target)
**Primary Dependencies**: SwiftUI, SwiftData, Foundation (新規依存なし)
**Storage**: SwiftData (本 spec では @Model 変更ゼロ、CloudKit Production deploy 不要)
**Testing**: Swift Testing (`@Test`/`#expect`) + XCTest (UI test)。本セッションは build + unit test まで、UI test 実行検証はユーザー実機後追い
**Target Platform**: iOS 26 (iPhone / iPad)
**Project Type**: mobile (single app + Share/Safari extension + Widget)
**Performance Goals**: 既存維持 (60fps、起動 < 1 秒)。本 spec は性能に影響しない
**Constraints**: 既存挙動を壊さない (streaming / 確認 alert / restartBanner / DisclosureGroup)。sandbox で UI test 実行不可
**Scale/Scope**: 改修 6 + 新規 1 + 削除 2 + pbxproj = ~400-500 行

## Constitution Check

*GATE: Phase 0 前に PASS、Phase 1 後に再チェック。*

- **I (privacy / on-device)**: UI 文言 + navigation 配線のみ、新規データ収集ゼロ ✅
- **II (MVP / 引き算)**: placeholder / 廃止案内 / 重複 Section / 形骸 test の除去 = 純引き算 ✅
- **III (source 追跡)**: P0-4 で引用リンク → 記事遷移を回復、source 追跡を強化 ✅
- **IV (iOS 実現可能性)**: SwiftUI 標準 (OpenURLAction / NavigationPath / xcstrings)、新規技術なし ✅
- **V (calm UX)**: 矛盾 UI / 無反応リンクの除去で信頼回復 ✅
- **VI (architecture)**: callback DI 既存パターン、Protocol/schema 変更ゼロ ✅
- **VII (日本語ファースト)**: 全文言日本語 + xcstrings key 化 ✅

**結論**: 全 7 原則 PASS。違反ゼロ。

## Project Structure

### Documentation (this feature)

```
specs/059-p0-shipping-blockers/
├── spec.md              # 完成
├── plan.md              # 本ファイル
├── research.md          # Phase 0: R1-R6
├── data-model.md        # Phase 1: @Model 変更ゼロ + transient/callback
├── quickstart.md        # Phase 1: SC-001〜SC-007 検証手順
├── contracts/           # Phase 1: 5 契約
└── checklists/
    └── requirements.md  # 完成 (全 PASS)
```

### Source Code (repository root)

repo root = `KnowledgeTree/`、app folder = `KnowledgeTree/KnowledgeTree/`。

```
KnowledgeTree/
├── Views/
│   ├── EmptyStateView.swift          # P0-1 改修 (R1)
│   ├── OnboardingView.swift          # P0-2 改修 (R2)
│   ├── SettingsView.swift            # P0-3 改修 (R3, :198-216 削除)
│   ├── ChatMessageRow.swift          # P0-4 改修 (R4, callback prop)
│   └── ChatTabView.swift             # P0-4 改修 (R4, callback 注入)
├── Localization/
│   └── Localizable.xcstrings         # R1+R2 文言追加 (~12-15)
KnowledgeTreeUITests/
├── V3RedesignUITests.swift           # P0-5 新規 (R5, 5 シナリオ)
├── UnderstandingTabUITests.swift     # P0-5 削除
└── AIBrainTabUITests.swift           # P0-5 削除
KnowledgeTree.xcodeproj/project.pbxproj  # R5, UITests ファイル参照 入替
```

## Phase 0: Research (research.md)

R1-R6 で各 P0 の修正方式を確定。詳細は [research.md](./research.md)。要点:

- **R1 (P0-1)**: `EmptyStateView.swift:28` の文字列を `list.empty.instruction` key 化、value で「アプリ名」→「iKnow」。
- **R2 (P0-2)**: `OnboardingView.swift` の `pages` 配列 (private struct、String 4×2) を xcstrings key 化、Page 4 を現行導線に書き換え。
- **R3 (P0-3)**: `SettingsView.swift:198-216` の旧 placeholder Section を削除のみ。
- **R4 (P0-4)**: ChatMessageRow に `onArticleLinkTap: ((Article) -> Void)?` 追加 → ChatTabView の既存 `navigationPath.append(article)` を注入。
- **R5 (P0-5)**: 旧 2 ファイル削除 + pbxproj 参照除去 + `V3RedesignUITests.swift` 新規。
- **R6**: テスト戦略 (unit は P0-4 の ID パースに最小限、UI test compile まで、最後に全 regression)。

## Phase 1: Design & Contracts

### data-model.md

@Model 変更ゼロ。新規は ChatMessageRow の callback prop (transient closure) のみ。詳細 [data-model.md](./data-model.md)。

### contracts/

- `empty-state-localization.md` (R1)
- `onboarding-localization.md` (R2)
- `settings-icloud-cleanup.md` (R3)
- `chat-citation-navigation.md` (R4) ★肝
- `v3-uitest-suite.md` (R5)

### quickstart.md

SC-001〜SC-007 の検証手順。実機シナリオ + build/test コマンド。

## Complexity Tracking

特記事項なし。全変更が既存パターンの範囲内、Constitution 違反ゼロ、複雑度の正当化不要。

## 検証 (このセッション)

- `xcodebuild clean build -scheme KnowledgeTree -destination 'platform=iOS Simulator,name=iPhone 17'` → SUCCEEDED + 本 spec 由来 warning ゼロ
- `xcodebuild test ... -only-testing:KnowledgeTreeTests` serial → 全 regression PASS
- UI test (V3RedesignUITests) は **compile 通過まで** (sandbox で実行不可、ユーザー実機後追い)

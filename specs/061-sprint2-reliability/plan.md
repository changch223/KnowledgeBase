# Implementation Plan: Sprint 2 信頼性改善 4 件

**Branch**: `061-sprint2-reliability` | **Date**: 2026-05-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/061-sprint2-reliability/spec.md`

## Summary

code review FINAL report の信頼性 P1 4 件を解消。**P1-2**: iCloud Toggle の set closure が値を保存せず alert のみ → pending state 化でバウンス解消。**P1-3**: ユーザー操作の `try?` 7 箇所を `AppErrorReporter` (os.Logger) 経由の do/catch に置換、削除系は失敗を surface。**P1-6**: ModelContainer 構築失敗の `fatalError` を in-memory fallback に置換し crash 回避。**P1-7**: bootstrap 末尾の独立 backfill 群を `async let` で並列化 (依存 chain は直列維持)。新規 @Model ゼロ。

## Technical Context

**Language/Version**: Swift 6 / SwiftUI (iOS 26)
**Primary Dependencies**: SwiftUI, SwiftData, os (Logger), 構造化並行 (async let)
**Storage**: SwiftData (@Model 変更ゼロ)
**Testing**: Swift Testing。AppErrorReporter は Protocol+DI でテスト可能
**Target Platform**: iOS 26 (iPhone / iPad)
**Project Type**: mobile
**Performance Goals**: P1-7 で cold start 短縮 (独立 backfill 同時進行)
**Constraints**: 既存挙動・calm UX を壊さない。@MainActor service の構造化並行
**Scale/Scope**: 新規 2 + 改修 8 + テスト = ~400-600 行

## Constitution Check

- **I (privacy)**: os.Logger は端末内、新規送信ゼロ ✅
- **II (MVP / 引き算)**: サイレント失敗・バウンス・crash の除去 = 綻び塞ぎ ✅
- **III (source 追跡)**: 影響なし ✅
- **IV (iOS 実現可能性)**: SwiftUI / os.Logger / async let 標準 ✅
- **V (calm UX)**: 失敗 surface は calm 範囲 (log + 削除のみ軽い error)、バウンス除去で体感改善 ✅
- **VI (architecture)**: AppErrorReporter Protocol+DI、bootstrap は並列化のみ (構造分離は P1-5 別 spec) ✅
- **VII (日本語ファースト)**: error/recovery 文言日本語 ✅

**結論**: 全 7 原則 PASS。

## Project Structure

```
specs/061-sprint2-reliability/
├── spec.md / plan.md / research.md / data-model.md / quickstart.md
├── contracts/ (icloud-toggle / error-reporting / store-recovery / backfill-parallel)
└── checklists/requirements.md

KnowledgeTree/
├── Services/AppErrorReporter.swift       # 新規 (P1-3)
├── Views/SettingsView.swift              # P1-2 + P1-3
├── Views/ChatHistorySidebar.swift        # P1-3
├── Views/SavedAnswerDetailView.swift     # P1-3 ×3
├── Views/ArticleDetailView.swift         # P1-3 ×2
├── Views/ConceptPageDetailView.swift     # P1-3
└── KnowledgeTreeApp.swift                # P1-6 + P1-7
KnowledgeTreeTests/AppErrorReporterTests.swift  # 新規
```

## Phase 0: Research (research.md)

- **R1 (P1-2)**: `@State pendingICloudToggle: Bool?` 追加。Toggle.get = `pendingICloudToggle ?? iCloudSyncEnabled`、set で pending 保持 + alert。confirm OK → apply + pending=nil、cancel → pending=nil。
- **R2 (P1-3)**: `AppErrorReporter` (Protocol + os.Logger Default)。7 箇所を do/catch + `reporter.report(error, operation:)`。削除系 (ChatHistorySidebar / SettingsView 全削除 / SavedAnswer 削除) は `@State errorMessage` で軽い表示。pin/follow/tag/markFresh は log + 失敗時 UI 状態を元に戻す。
- **R3 (P1-6)**: fatalError 2 箇所を in-memory ModelContainer fallback に置換。`@State storeLoadFailed: Bool` で起動後に軽い banner。debug は `assertionFailure` 併記。
- **R4 (P1-7)**: bootstrap 末尾 (`:388-427`) の独立 backfill を `async let` で並列化。enrichment→body→knowledge は直列維持、その後 tagStore.cleanup / auto-tag / category / digest / embedding / topic / concept を async let で同時 await。BGTask 予約は最後。

## Phase 1: Design & Contracts

### data-model.md
@Model 変更ゼロ。新規は AppErrorReporter (transient) + 数個の @State。

### contracts/
- `icloud-toggle.md` (P1-2)
- `error-reporting.md` (P1-3)
- `store-recovery.md` (P1-6)
- `backfill-parallel.md` (P1-7)

### quickstart.md
SC-001〜SC-006。

## Complexity Tracking

特記なし。bootstrap 並列化は構造化並行の標準パターン、God-object 分離 (P1-5) には踏み込まない。

## 検証 (このセッション)

- `xcodebuild clean build` → SUCCEEDED + warning ゼロ
- `xcodebuild test -only-testing:KnowledgeTreeTests` serial → 全 regression + AppErrorReporterTests PASS
- 実機 SC-001 (toggle) / SC-003 (store 失敗) はユーザー後追い (store 失敗は inject 困難)

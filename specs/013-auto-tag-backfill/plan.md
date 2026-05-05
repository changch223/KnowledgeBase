# Implementation Plan: 既存記事への auto-tag backfill

**Branch**: `013-auto-tag-backfill` | **Date**: 2026-05-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/013-auto-tag-backfill/spec.md`

## Summary

spec 012 で導入した auto-tag (新規 / 再抽出記事のみ対象) の backfill 機能を、bootstrap 時に **1 回限り** 実行する。既存記事 (タグ 0 件 + knowledge succeeded) を全件処理して上位 5 タグを自動付与。永続フラグ (UserDefaults) で重複実行防止。BottomStatusBar に「タグ整理中…」表示。新規 service 1 つ + ProcessingMonitor.Phase に `.tagBackfilling` 追加 + bootstrap で 1 ブロック呼び出し。新 @Model / 新 schema migration ゼロ。Constitution Principle V (calm UX) を厳守 (push 通知 / バッジ / 完了アラート / トースト 全廃)。

## Technical Context

**Language/Version**: Swift 6 (Swift 6 mode、`@MainActor` isolation)
**Primary Dependencies**: SwiftUI 6 / SwiftData (既存 `Article` / `Tag` / `KnowledgeEntity` / `ExtractedKnowledge`)、Foundation (UserDefaults)、spec 008-012 既存モジュール
**Storage**: SwiftData (既存 entity 読み書き) + UserDefaults.standard (1 つの Bool フラグ `auto_tag_backfill_v1_done`)
**Testing**: Swift Testing (`KnowledgeTreeTests/AutoTagBackfillRunnerTests.swift`) で in-memory ModelContainer + UserDefaults テスト用 (UserDefaults(suiteName:) で隔離)
**Target Platform**: iOS 26+ / iPadOS 26+ (Constitution: Apple Intelligence 対応端末)
**Project Type**: iOS native app (mobile)
**Performance Goals**: 100 件で 30 秒以内 (SC-002)、1000 件で 5 分以内 (SC-003)、2 回目以降起動で 1ms 以内 early return (SC-004)
**Constraints**: オフライン動作必須 (Constitution Principle II)、メイン処理は `@MainActor`、依存追加なし、calm UX (push / バッジ / トースト ゼロ)、起動時 1 回のみ
**Scale/Scope**: 想定: 既存 article 1000 件規模で全件 backfill。10000 件のような極端ケースでも crash しない (起動はブロック、BottomStatusBar 表示で UX 整合)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Reference: `.specify/memory/constitution.md` (v1.0.0).

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — backfill は SwiftData 全 article を読み + Tag を書くのみで完結。外部送信ゼロ。本 spec で新規ネットワーク送信なし。
- [x] **II. MVP ファースト開発** — MVP は spec 013 単体。「タグ整理を再実行」ボタン (Settings 画面) / 段階的 backfill / 結果サマリ表示 / v2 backfill は将来 spec として spec.md に明示。
- [x] **III. ソースに基づいた知識生成** — backfill で付与される各タグは spec 008 / 012 と同じ `KnowledgeEntity` → `ExtractedKnowledge` → `Article` の追跡可能チェーンを保持。新規 AI 生成なし、既存 entity からの派生。
- [x] **IV. iOS の実現可能性を重視する** — iOS 26+ 限定。Apple Intelligence 関係なし (本 spec は AI 呼び出しなし、既存 entity のみ参照)。
- [x] **V. シンプルで落ち着いた UX** — calm UX を厳守。FR-019〜022 で push 通知 / バッジ / 完了アラート / トースト「N 件にタグを付けました」を **明示的に禁止**。BottomStatusBar の「タグ整理中…」のみ。
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — `AutoTagBackfillRunner` は薄い service (新規) で、spec 012 `AutoTagApplier` + spec 008 `TagStore` + spec 005 `ProcessingMonitor` の合成のみ。差し替え可能境界 (将来テスト容易化のため `BackfillFlagStore` protocol を導入) を設定。
- [x] **VII. 日本語ファースト** — UI 文言は本 spec で 1 つ追加 (「タグ整理中…」)。日本語で Localizable.xcstrings に登録。

### Quality Gates (二次ゲート)

- [x] **コード品質** — Swift API Design Guidelines 準拠。`fatalError` / `try!` 新規禁止。`AutoTagBackfillRunner` は class (state 必要)、`BackfillFlagStore` protocol は 2 箇所利用 (production + test) で抽象化価値あり。新規 ProcessingMonitor.Phase 追加は既存 enum 拡張で副作用なし。
- [x] **テスト** — `AutoTagBackfillRunnerTests` で 7 ケース: フラグ false 実行 / フラグ true 早期 return / 候補 filter (3 条件) / 既存タグ skip / failed knowledge skip / 最新優先順序 / empty database。in-memory ModelContainer + 隔離 UserDefaults (`UserDefaults(suiteName:)`)。`private typealias Tag = KnowledgeTree.Tag` (spec 011/012 同パターン)。
- [x] **アクセシビリティ・UX 一貫性** — 「タグ整理中…」テキストは BottomStatusBar 既存 accessibilityLabel パターンに従う (spec 005)。Dynamic Type / Dark Mode / VoiceOver は既存挙動。
- [x] **パフォーマンス** — 100 件 30 秒、1000 件 5 分。各 article ~50ms (spec 012 と同じ)。`@Query` の境界付け不要 (Runner 内 FetchDescriptor で全件取得 1 回のみ、UI 層では使わない)。

### 結果

✅ 全ゲート通過。Complexity Tracking なし。

## Project Structure

### Documentation (this feature)

```text
specs/013-auto-tag-backfill/
├── plan.md              # This file
├── research.md          # Phase 0
├── data-model.md        # Phase 1 (transient ゼロ、UserDefaults キー定義のみ)
├── quickstart.md        # Phase 1 (実機検証手順)
├── contracts/           # Phase 1
│   ├── auto-tag-backfill-runner.md
│   └── backfill-flag-store.md
└── tasks.md             # Phase 2 (/speckit-tasks 出力)
```

### Source Code (repository root)

```text
KnowledgeTree/
├── Services/
│   ├── AutoTagBackfillRunner.swift          ← 新規 (class)
│   ├── BackfillFlagStore.swift              ← 新規 (protocol + UserDefaults 実装)
│   ├── ProcessingMonitor.swift              ← 改修: .tagBackfilling enum case 追加
│   ├── AutoTagApplier.swift                 ← 改修なし (spec 012 既存、再利用)
│   ├── TagStore.swift                       ← 改修なし (spec 008 既存、再利用)
│   └── ...
├── Views/
│   ├── BottomStatusBar.swift                ← 改修: phase label に「タグ整理中」追加
│   └── ...
├── Localization/
│   └── Localizable.xcstrings                ← 改修: 「タグ整理中…」文字列追加
├── Models/                                   ← 改修なし (新 @Model ゼロ)
└── KnowledgeTreeApp.swift                   ← 改修: bootstrap() 末尾に backfillRunner.run() 1 ブロック追加

KnowledgeTreeTests/
└── AutoTagBackfillRunnerTests.swift         ← 新規 (7 ケース)
```

**Structure Decision**: iOS native app の単一ターゲット構成 (mobile)。本 spec は **新規 2 ファイル + 既存 4 ファイル微改修 (ProcessingMonitor / BottomStatusBar / KnowledgeTreeApp / Localizable.xcstrings) + 新規テスト 1 ファイル** で完結。新 @Model / 新 schema / 新 migration ゼロ。

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| `BackfillFlagStore` protocol 導入 | テスト時に UserDefaults.standard を汚染しないため | UserDefaults(suiteName:) を直接 Runner に渡す → 抽象化が緩く将来の差し替え (例: KeyValueStore protocol) が困難 |

`BackfillFlagStore` は 2 箇所 (`UserDefaultsBackfillFlagStore` production + `InMemoryBackfillFlagStore` test) で利用するため、Constitution コード品質ゲートの「2 箇所以上の利用」を満たす。

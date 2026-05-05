# Implementation Plan: タグ自動付与 (AI Auto-Tag)

**Branch**: `012-auto-tag` | **Date**: 2026-05-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/012-auto-tag/spec.md`

## Summary

spec 008 で導入した「AI 提案チップを **タップして採用**」フローを、「AI が **自動付与** → ユーザーが **削除/追加で微調整**」フローに切り替える。新規モジュール `AutoTagApplier` (純粋関数 enum + 副作用 1 箇所) を `KnowledgeExtractionService` の `upsertSucceeded` 直後に hook するだけの薄い実装。新 @Model / 新 service / 新 schema migration ゼロ。Constitution Principle V (calm UX) を厳格に遵守 (push 通知 / バッジ / サウンド / トースト 全廃)。

## Technical Context

**Language/Version**: Swift 6 (Swift 6 mode、`@MainActor` isolation)
**Primary Dependencies**: SwiftUI 6 / SwiftData (既存 `Article` / `Tag` / `KnowledgeEntity` / `ExtractedKnowledge` の relationship 経由)、Foundation Models (本 spec で新規呼び出しなし、spec 004/006/010 既存パイプラインを再利用)
**Storage**: SwiftData (既存 `Article.tags` / `ExtractedKnowledge.entities` / `ExtractedKnowledge.statusRaw` のみ。新 @Model なし、migration なし)
**Testing**: Swift Testing (`KnowledgeTreeTests/AutoTagApplierTests.swift`) で純粋関数 + TagStore 副作用の単体テスト。in-memory ModelContainer 使用
**Target Platform**: iOS 26+ / iPadOS 26+ (Constitution: Apple Intelligence 対応端末)
**Project Type**: iOS native app (mobile)
**Performance Goals**: AutoTagApplier.apply() は knowledge 抽出完了後の 100ms 以内 (上位 5 件 TagStore.addTag = 50ms 以内、Constitution パフォーマンスゲート ≤100ms 準拠)
**Constraints**: オフライン動作必須 (Constitution Principle II)、メイン処理は `@MainActor`、依存追加なし、calm UX (push 通知 / バッジ / サウンド / トースト ゼロ)
**Scale/Scope**: 想定: 1 記事あたり最大 5 タグ自動付与、1000 件規模の記事保有時も全件 auto-apply 判定が 100ms 以内で完了 (= 各記事 ≤0.1ms の判定オーバーヘッド)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Reference: `.specify/memory/constitution.md` (v1.0.0).

### 主要原則 (Core Principles)

- [x] **I. プライバシーファースト・ローカルファースト** — auto-apply は Article / Tag / KnowledgeEntity の **読み取りと書き込み** のみで完結。外部送信ゼロ。本 spec で新規ネットワーク送信なし。
- [x] **II. MVP ファースト開発** — MVP は spec 012 単体。Settings 画面 / 信頼度別挙動 / 永続ブラックリスト / backfill 一括 auto-apply は将来 spec として spec.md に明示。
- [x] **III. ソースに基づいた知識生成** — auto-apply される各タグは `KnowledgeEntity` (=`ExtractedKnowledge.entities` の 1 件) → `ExtractedKnowledge.article` で **元 Article URL に追跡可能** (spec 008 既存リンク維持)。新規 AI 生成なし、既存 entity からの派生のみ。
- [x] **IV. iOS の実現可能性を重視する** — iOS 26+ 限定、Apple Intelligence 未利用可状態では knowledge 抽出 status が `.failed` / `.skipped` のため auto-apply は走らない (FR-004)。fallback UX は spec 008 の手動入力 / 提案チップで継続。
- [x] **V. シンプルで落ち着いた UX** — calm UX を厳格遵守。FR-025〜029 で push 通知 / バッジ / サウンド / 触覚 / トースト / BottomStatusBar 表示 を全て **明示的に禁止**。「気付いたら整理されている」体験のみ提供。
- [x] **VI. 保守しやすい SwiftUI アーキテクチャ** — `AutoTagApplier` は純粋関数 enum + 既存 `SuggestedTagFinder` + `TagStore` の合成 (新 service / 新抽象化なし)。`KnowledgeExtractionService` への hook は 1 行追加のみ。差し替え可能境界は spec 008 既存の `TagStoreProtocol` (もし無ければ将来 spec で抽象化) に従う。
- [x] **VII. 日本語ファースト** — UI 文言は本 spec で **追加なし** (auto-apply は UI 上「タグが付いた」状態として spec 008 既存 TagChip で表示)。新規ローカライゼーション不要。

### Quality Gates (二次ゲート)

- [x] **コード品質** — Swift API Design Guidelines 準拠。`fatalError` / `try!` 新規禁止。`AutoTagApplier` は static func のみで `try? + log` で graceful failure。新規抽象化ゼロ (純粋関数モジュール 1 つ)。
- [x] **テスト** — `AutoTagApplierTests` で 7 ケース: 上位 5 付与 / 既存タグ skip / failed status skip / pending status skip / 冪等性 / 全削除後復活 / entity 空。in-memory ModelContainer (`isStoredInMemoryOnly: true`) で `Tag` / `Article` / `ExtractedKnowledge` / `KnowledgeEntity` をリアル組み立て。`private typealias Tag = KnowledgeTree.Tag` で SwiftUI Tag 曖昧化解消 (spec 011 同パターン)。
- [x] **アクセシビリティ・UX 一貫性** — 本 spec で新規 UI コンポーネント追加なし。auto-apply されたタグは spec 008 既存 TagChip / accessibilityLabel 経由でそのまま VoiceOver 対応。Dynamic Type / Dark Mode は既存挙動。
- [x] **パフォーマンス** — auto-apply は knowledge 抽出完了直後の 100ms 以内 (TagStore.addTag × 5 = ~50ms)。SwiftData `@Query` の境界付け不要 (本 spec で View 層変更なし)。

### 結果

✅ 全ゲート通過。Complexity Tracking なし。

## Project Structure

### Documentation (this feature)

```text
specs/012-auto-tag/
├── plan.md              # This file
├── research.md          # Phase 0
├── data-model.md        # Phase 1 (transient なし、既存 entity 利用のみ)
├── quickstart.md        # Phase 1 (実機検証手順 + テストシナリオ)
├── contracts/           # Phase 1
│   ├── auto-tag-applier.md
│   └── knowledge-extraction-service-hook.md
└── tasks.md             # Phase 2 (/speckit-tasks 出力 — 本 plan では生成しない)
```

### Source Code (repository root)

```text
KnowledgeTree/
├── Services/
│   ├── KnowledgeExtractionService.swift   ← upsertSucceeded 後の hook 1 行 × 2 箇所追加 (改修)
│   ├── AutoTagApplier.swift               ← 新規 (純粋関数 enum)
│   ├── SuggestedTagFinder.swift           ← 改修なし (再利用)
│   ├── TagStore.swift                     ← 改修なし (再利用)
│   ├── TagNormalizer.swift                ← 改修なし (再利用)
│   ├── BackgroundExtractionRunner.swift   ← 改修なし (knowledgeService.extract 経由で auto-apply 自動波及)
│   └── ...
├── Models/                                 ← 改修なし
├── Views/                                  ← 改修なし (spec 008 の SuggestedTagFinder セクションは結果的に表示候補が減るだけ)
└── KnowledgeTreeApp.swift                 ← bootstrap で TagStore を knowledgeService に inject する 1 行のみ追加 (改修)

KnowledgeTreeTests/
└── AutoTagApplierTests.swift              ← 新規 (7 ケース)
```

**Structure Decision**: iOS native app の単一ターゲット構成 (mobile)。本 spec は **新規 1 ファイル + 既存 2 ファイル微改修 (KnowledgeExtractionService + KnowledgeTreeApp bootstrap) + 新規テスト 1 ファイル** で完結。新 @Model / 新 schema / 新 migration / 新 UI コンポーネント / 新 navigationDestination ゼロ。Constitution アーキテクチャ原則 (Principle VI) に最大限沿う。

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (なし) | — | — |

`AutoTagApplier` は純粋関数 enum (1 つの公開 static func + 1-2 つの private helper) で、本 spec の `KnowledgeExtractionService.run()` 内 hook と `AutoTagApplierTests` の 2 箇所で利用するため、Constitution コード品質ゲートの「2 箇所以上の利用」を満たす。

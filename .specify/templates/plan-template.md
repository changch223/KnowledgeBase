# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: [e.g., Python 3.11, Swift 5.9, Rust 1.75 or NEEDS CLARIFICATION]  
**Primary Dependencies**: [e.g., FastAPI, UIKit, LLVM or NEEDS CLARIFICATION]  
**Storage**: [if applicable, e.g., PostgreSQL, CoreData, files or N/A]  
**Testing**: [e.g., pytest, XCTest, cargo test or NEEDS CLARIFICATION]  
**Target Platform**: [e.g., Linux server, iOS 15+, WASM or NEEDS CLARIFICATION]
**Project Type**: [e.g., library/cli/web-service/mobile-app/compiler/desktop-app or NEEDS CLARIFICATION]  
**Performance Goals**: [domain-specific, e.g., 1000 req/s, 10k lines/sec, 60 fps or NEEDS CLARIFICATION]  
**Constraints**: [domain-specific, e.g., <200ms p95, <100MB memory, offline-capable or NEEDS CLARIFICATION]  
**Scale/Scope**: [domain-specific, e.g., 10k users, 1M LOC, 50 screens or NEEDS CLARIFICATION]

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Reference: `.specify/memory/constitution.md` (v1.0.0). Each item below MUST be
checked or explicitly justified in **Complexity Tracking**.

### 主要原則 (Core Principles)

- [ ] **I. プライバシーファースト・ローカルファースト** — 計画は記事本文・要約・タグ・
      知識ベースの保存先がローカル端末内であることを明示し、外部送信が発生する箇所が
      あれば送信先・データ種別・必要性を `spec.md` に記録している。
- [ ] **II. MVP ファースト開発** — 計画は MVP スコープ (記事保存／本文抽出／要約／
      カテゴリ分類／ローカル保存／ソース閲覧) に収まっているか、スコープ外機能
      (AI チャット・RAG・レコメンド等) を将来フェーズとして明示的に分離している。
- [ ] **III. ソースに基づいた知識生成** — AI が生成する要約・インサイト・回答は、
      すべて元記事 URL (または保存済み記事 ID) に追跡可能であり、データモデル上
      非 optional な参照を保持する。根拠なし出力を防ぐ実装方針 (プロンプト制約・
      出力スキーマ・UI 表示) が明記されている。
- [ ] **IV. iOS の実現可能性を重視する** — 計画は記事取り込み手段を「Share Sheet
      (MVP 必須) → Shortcuts (将来) → Safari Extension (将来)」の優先順で扱い、
      iOS 26+ / Apple Intelligence 対応端末を前提とし、`SystemLanguageModel.availability`
      が `.available` でない場合のフォールバック UX を定義している。macOS は対象外。
- [ ] **V. シンプルで落ち着いた UX** — 計画は片手操作・移動中・短時間利用を前提とした
      画面設計を記述し、未読数バッジ等の不安喚起 UI を導入する場合は理由を明記している。
- [ ] **VI. 保守しやすい SwiftUI アーキテクチャ** — 計画は UI / データモデル / 取り込み
      / 抽出 / AI 処理 / 分類 / 保存の各層を明示的に分離し、AI モデルや保存方式を
      差し替え可能にする境界 (プロトコル等) を示している。単一の巨大 View に処理を
      詰め込まない。
- [ ] **VII. 日本語ファースト** — `spec.md`・`plan.md`・UI 文言・サンプルデータ・
      カテゴリ名・エラーメッセージ・オンボーディング文言が日本語で記述されている。
      英語記事を扱う場合の処理方針も明記。

### Quality Gates (二次ゲート)

- [ ] **コード品質** — Swift API Design Guidelines 準拠。`fatalError` / `try!` /
      強制アンラップは `App` レベルのコンテナ初期化のみ。新規抽象化は 2 箇所以上の
      利用または `plan.md` の根拠記載あり。
- [ ] **テスト** — `KnowledgeTreeTests/` に単体テスト、`KnowledgeTreeUITests/` に主要
      フローの UI テスト。SwiftData は `isStoredInMemoryOnly: true` の `ModelContainer`。
      UI テストは `accessibilityIdentifier` で要素特定。決定論的 (ネットワーク不可・
      時刻注入)。
- [ ] **アクセシビリティ・UX 一貫性** — 全インタラクティブ要素に
      `accessibilityIdentifier`。Dynamic Type / Dark Mode / VoiceOver 対応。SF Symbols
      とネイティブ SwiftUI コントロールを優先。生文字列リテラル禁止 (Localizable.xcstrings
      経由)。
- [ ] **パフォーマンス** — 入力フィードバック ≤100 ms、コールド起動 ≤2 s (200 ms 以上の
      悪化は要調査)、`@Query` は predicate または `fetchLimit` で境界付き、100 件超の
      リストは Instruments で 60 fps 実測、escaping closure は `[weak self]`。

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
# [REMOVE IF UNUSED] Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [REMOVE IF UNUSED] Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [REMOVE IF UNUSED] Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure: feature modules, UI flows, platform tests]
```

**Structure Decision**: [Document the selected structure and reference the real
directories captured above]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |

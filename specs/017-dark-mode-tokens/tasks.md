# Tasks: Dark/Light Mode 自動切り替え対応 (spec 017)

**Input**: Design documents from `/specs/017-dark-mode-tokens/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/color-adaptive.md, quickstart.md

**Tests**: 純関数 / Color extension に対する unit test を含める (UITraitCollection で Light/Dark trait 注入で全分岐検証)。

**Organization**: 4 user stories (US1〜US4) ごとに Phase を分けて独立 deliver 可能。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 並列可能 (異なるファイル、依存なし)
- **[Story]**: US1〜US4 のいずれか
- 全タスクに project-relative path を記載

---

## Phase 1: Setup

(該当なし — 新規文言なし、新規ライブラリなし、既存設定変更なし)

---

## Phase 2: Foundational

**Purpose**: 全 User Story 共通の `Color.adaptive(light:dark:)` extension を整備

- [x] T001 `KnowledgeTree/DesignSystem.swift` の末尾 (既存 `View` extension の隣) に `extension Color { static func adaptive(light: Color, dark: Color) -> Color }` を追加。実装は `Color(uiColor: UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })` (contracts/color-adaptive.md 仕様)。`import UIKit` を追加 (現状 SwiftUI のみ import なので必要)

**Checkpoint**: T001 完了で全 US が並列着手可能

---

## Phase 3: User Story 1 (P1) — Dark Mode で全画面が自然な視認性 🎯 MVP

**Goal**: 全カスタム token を adaptive 化、Dark Mode で actionBlue / parchment / tagFill 等が適切に切替

**Independent Test**:
- `xcodebuild test -only-testing:KnowledgeTreeTests/ColorAdaptiveTests` が PASS
- 実機 / Simulator で Dark Mode に切替 → 全画面が Dark 値で表示

- [x] T002 [US1] `KnowledgeTreeTests/ColorAdaptiveTests.swift` を新規作成。`Color.adaptive(light:dark:)` の 7 ケース検証 (contracts/color-adaptive.md):
   1. `testReturnsLightColorInLightMode`: UITraitCollection.userInterfaceStyle = .light で light の RGB を返す
   2. `testReturnsDarkColorInDarkMode`: UITraitCollection.userInterfaceStyle = .dark で dark の RGB を返す
   3. `testActionBlueLightHex`: `DS.Color.actionBlue` Light で RGB ≈ (10/255, 77/255, 140/255)
   4. `testActionBlueDarkHex`: `DS.Color.actionBlue` Dark で RGB ≈ (58/255, 142/255, 239/255)
   5. `testParchmentLightHex`: parchment Light で RGB ≈ (250/255, 248/255, 243/255)
   6. `testParchmentDarkHex`: parchment Dark で RGB ≈ (28/255, 28/255, 30/255)
   7. `testTagFillBothModes`: tagFill が Light = (234/255, 234/255, 239/255) / Dark = (44/255, 44/255, 46/255)

   `UIColor(_: Color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light or .dark))` で trait 注入。`cgColor.components` で RGB 比較 (epsilon 0.01)。

- [x] T003 [US1] `KnowledgeTree/DesignSystem.swift` の `actionBlue` を `Color.adaptive(light: <#0a4d8c>, dark: <#3a8eef>)` に書き換え (Light: red 10/255, green 77/255, blue 140/255; Dark: red 58/255, green 142/255, blue 239/255)
- [x] T004 [US1] `KnowledgeTree/DesignSystem.swift` の `actionBlueFocus` を adaptive 化 (Light #1565b8: red 21/255, green 101/255, blue 184/255; Dark #5aa3f5: red 90/255, green 163/255, blue 245/255)
- [x] T005 [US1] `KnowledgeTree/DesignSystem.swift` の `parchment` を adaptive 化 (Light #faf8f3: red 250/255, green 248/255, blue 243/255; Dark #1c1c1e: red 28/255, green 28/255, blue 30/255)
- [x] T006 [US1] `KnowledgeTree/DesignSystem.swift` の `knowledgeTile` を adaptive 化 (Light #f5f5f7: red 245/255, green 245/255, blue 247/255; Dark #2a2a2c: red 42/255, green 42/255, blue 44/255)
- [x] T007 [US1] `KnowledgeTree/DesignSystem.swift` の `tagFill` を adaptive 化 (Light #eaeaef: red 234/255, green 234/255, blue 239/255; Dark #2c2c2e: red 44/255, green 44/255, blue 46/255)

**Checkpoint**: T002-T007 完了で US1 完成。`xcodebuild test` で `ColorAdaptiveTests` 7/7 PASS、実機 / Simulator で Dark Mode 視覚確認可能

---

## Phase 4: User Story 2 (P1) — Light Mode で従来通り自然な表示

**Goal**: spec 016 までの Light Mode 表示を完全保持

**Independent Test**:
- 既存 unit test 93+ ケース全 PASS (Light 値が変わらないため)
- 実機 / Simulator Light Mode で全画面が spec 016 までと同一表示

(US2 は US1 で 5 tokens を adaptive 化した時点で Light 値も保持される。実装コードゼロ、確認のみ)

- [x] T008 [US2] `xcodebuild test -only-testing:KnowledgeTreeTests` を実行、既存 93+ ケース全 PASS 確認 (新規 ColorAdaptiveTests 7 含めると合計 100+ ケース)
- [x] T009 [US2] Simulator iPhone 17 を Light Mode で起動、ライブラリタブ / AI ブレインタブ / Detail シート / Category 詳細画面 を視覚確認、spec 016 までと完全同一であることを確認

**Checkpoint**: T008-T009 完了で US2 完成、回帰なしを保証

---

## Phase 5: User Story 3 (P1) — システム自動切替に追随

**Goal**: iOS の Light/Dark 自動切替に追随、State 維持

**Independent Test**:
- iOS 設定「自動」モードで時刻に応じて Light/Dark が切替
- 切替時にアプリ State (タグ選択 / 折りたたみ等) が維持される

(US3 は OS の機能、SwiftUI が UITraitCollection 経由で auto handle、追加実装コードなし。検証のみ)

- [x] T010 [US3] 実機検証 (quickstart SC-003): iOS 設定 → 画面表示と明るさ → 自動 ON、時刻を昼 (12:00) → 夜 (22:00) で切替テスト、Light/Dark 自動切替 + State 維持 確認

**Checkpoint**: T010 完了で US3 完成 (実機検証はユーザー実施、Claude 範囲外)

---

## Phase 6: User Story 4 (P2) — Reduce Transparency 設定との互換性

**Goal**: Reduce Transparency ON でも機能不変、Dark Mode と組み合わせ動作

**Independent Test**:
- iOS 設定 → アクセシビリティ → 透明度を下げる ON + Dark Mode ON
- アプリで全画面を操作 (フィルター / 検索 / Detail / 折りたたみ) 機能不変

(US4 は spec 014 で gradient/shadow/blur 全廃済、追加実装コードなし。検証のみ)

- [x] T011 [US4] 実機検証 (quickstart SC-007): 設定 → アクセシビリティ → 透明度を下げる ON + Dark Mode ON、全画面操作テスト、機能不変確認

**Checkpoint**: T011 完了で US4 完成 (実機検証はユーザー実施、Claude 範囲外)

---

## Phase 7: Polish & Cross-Cutting

**Purpose**: DESIGN.md 更新 + ビルド警告ゼロ + CLAUDE.md 更新 + 実機検証 backlog

- [x] T012 [P] `DESIGN.md` の colors frontmatter を更新: 各色に dark variant を併記 (`primary: { light: "#0a4d8c", dark: "#3a8eef" }` 形式)、5 tokens (primary / primary-focus / canvas-parchment / surface-pearl / tag-fill) すべて
- [x] T013 [P] `DESIGN.md` の Migration Notes セクションに「spec 017 で Dark Mode 一元対応済」エントリを追記
- [x] T014 [P] `DESIGN.md` の Known Gaps セクションから「dark mode: 未文書化」エントリを削除 (本 spec で解決)
- [x] T015 [P] `xcodebuild build -scheme KnowledgeTree -destination "platform=iOS Simulator,name=iPhone 17"` でビルド警告ゼロ確認 (本 spec 起因の warning 0)
- [x] T016 [P] `CLAUDE.md` の spec 017 行を「📝 計画完了」→「✅ 実装」に更新 (commit hash 追記)
- [ ] T017 quickstart 9 シナリオ (SC-001〜SC-009) を実機検証 (ユーザー実施)

---

## Dependencies

```
T001 (Foundational: Color.adaptive extension)
   ↓
   ├─→ T002 (US1 test) ─┬─→ T003 (actionBlue) ─┐
   │                     ├─→ T004 (actionBlueFocus) ─┤
   │                     ├─→ T005 (parchment) ─┤  (T003-T007 は同ファイル DesignSystem.swift)
   │                     ├─→ T006 (knowledgeTile) ─┤  → 順次実行が安全
   │                     └─→ T007 (tagFill) ─┘
   │
   └─→ T008 (US2 全テスト回帰) ←─ T003-T007 完了後
   └─→ T009 (US2 Simulator 視覚) ←─ T003-T007 完了後
   └─→ T010 (US3 実機検証)
   └─→ T011 (US4 実機検証)
                                                ↓
                                          T012-T016 (Polish)
                                                ↓
                                          T017 (実機検証)
```

T002 (test) と T003-T007 (実装) は厳密には独立しているが、test を先に書いて TDD 風に進めると安全。

## Parallel Opportunities

- T003-T007 は全部 DesignSystem.swift の異なる token なので論理的に並列可だが、同一ファイル編集なので順次実行が安全 (P 並列マークなし)
- T012-T015 は別ファイル、Polish 段階で並列 (P)
- T002 (test) は実装より前に書ける (TDD)、T003 と並列着手可

## Implementation Strategy

### MVP (US1 + US2 のみで価値提供可)

T001 → T002 → T003-T007 で:
- US1: Dark Mode 5 tokens 全 adaptive、ColorAdaptiveTests PASS
- US2: Light 完全保持 (T003-T007 で Light 値変えていないため自動的に保証)

US3 / US4 は OS 機能依存で実装コードゼロ → 実機検証 (ユーザー実施) で完成扱い。

### 段階リリース提案

1. **Sprint 1 (MVP)**: Phase 2 + 3 + 4 = T001-T009 (US1 + US2 完成、Dark Mode 視覚 + Light 保持 deliver)
2. **Sprint 2 (検証)**: Phase 5 + 6 = T010-T011 (US3 + US4 実機検証)
3. **Sprint 3 (Polish)**: Phase 7 = T012-T017 (DESIGN.md / CLAUDE.md / build / 実機検証)

実装規模目安: 17 タスク、~95 行 (実装は ~80 行、ドキュメント ~15 行)。

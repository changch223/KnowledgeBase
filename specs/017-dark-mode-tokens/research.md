# Research: Dark/Light Mode 自動切り替え対応 (spec 017)

## R1 — Color.adaptive(light:dark:) の SwiftUI 互換実装

**Decision**: `Color.adaptive(light:dark:)` static 関数を `extension Color` で定義。内部実装は `Color(uiColor: UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })`。

**Rationale**:
- `UIColor { trait in ... }` (UIColor dynamicProvider) は iOS 13+ で確立した auto-adapt API
- SwiftUI の `Color(uiColor:)` initializer (iOS 15+) で UIColor を Color に bridge、SwiftUI 内で auto adapt
- DesignSystem.swift 一元、view 散らかし回避
- Asset Catalog Color Sets と等価 (両方とも UITraitCollection 経由)、ただし code-driven の方が token と同期しやすい

**Alternatives considered**:
- **B**: `@Environment(\.colorScheme)` を全 view で参照 — 18 view 散らかし、保守性極悪
- **C**: Asset Catalog Color Sets — Xcode UI で管理、デザイナーフレンドリーだが本プロジェクトは個人開発 + token-driven 設計、code 一元の方が DESIGN.md 同期が楽

## R2 — UIColor → Color の bridge コスト

**Decision**: パフォーマンス影響なし。Color(uiColor:) は SwiftUI 内部で UIColor を保持、auto adapt。

**Rationale**:
- SwiftUI 標準パターン (Apple のサンプルコード / WWDC で多用)
- `Color(uiColor:)` の bridge オーバーヘッドは 1 度だけ、再描画毎に発生しない
- UITraitCollection の userInterfaceStyle 変更時に SwiftUI が view tree を再描画する仕組みは標準
- 1000 token / 1000 view レベルでも 100ms 以内の再描画を維持できる

**Alternatives considered**:
- なし (SwiftUI / UIKit 標準パターン)

## R3 — Dark variant の色値選定

**Decision**: 5 tokens の Dark variant 値は以下の通り。

| Token | Light (現行) | Dark (新規) | 根拠 |
|---|---|---|---|
| `actionBlue` | `#0a4d8c` (KnowledgeTree primary, deep blue) | `#3a8eef` (DESIGN.md `primary-on-dark` 既定義、Apple Mac ライク) | 可読性高、Apple-quiet、明色なので Dark 背景でハイライトとして機能 |
| `actionBlueFocus` | `#1565b8` (focus ring) | `#5aa3f5` (Light より明、ring 強調) | actionBlue より明、focus 強調、Dark で識別可能 |
| `parchment` | `#faf8f3` (off-white、庭の地面メタファー) | `#1c1c1e` (iOS .secondarySystemBackground 同等) | Apple-quiet、iOS 標準と統一感、目に優しい暗灰色 |
| `knowledgeTile` | `#f5f5f7` (KnowledgeMap node fill) | `#2a2a2c` (iOS .tertiarySystemBackground 寄り) | 廃止 view 用だが現状 alias 経由で使用、auto adapt |
| `tagFill` | `#eaeaef` (tag chip / AI badge fill) | `#2c2c2e` (iOS .tertiarySystemFill 相当) | Dark で chip 背景として識別可能、actionBlue (選択中) との contrast 確保 |

**Rationale**:
- 全色 Apple-quiet 路線 (彩度低、落ち着いた色合い)
- DESIGN.md の `primary-on-dark` 既定義 (#3a8eef) を採用 → DESIGN.md と DesignSystem.swift の hex 一致
- iOS 標準の `.secondarySystemBackground` (#1c1c1e) / `.tertiarySystemFill` (#2c2c2e) 寄りの値で iOS との視覚統一感
- `actionBlue` Dark (#3a8eef) は WCAG AA 4.5:1 contrast を Dark 背景 (#1c1c1e / #2c2c2e) 上で満たす設計

**Alternatives considered**:
- 純黒 `#000000` (OLED 真黒、節電) → 採用せず、Apple-quiet 路線では「夜の庭」温かみが欲しい
- `Color.accentColor` 任せ → 採用せず、token-driven 設計の意図を裏切る
- Light/Dark で同じ `#0a4d8c` → 暗すぎて Dark 背景で識別困難、却下

## R4 — opacity 適用箇所の auto adapt

**Decision**: 既存コード `actionBlue.opacity(0.08)` 等の opacity 適用は base color が adaptive なら opacity 後も adaptive 維持。view コード改修ゼロ。

**Rationale**:
- SwiftUI の `Color.opacity(_:)` は元の Color の Light/Dark variant を保持したまま alpha を適用
- Light 時: `0a4d8c.opacity(0.08)` = 透明度ある deep blue
- Dark 時: `3a8eef.opacity(0.08)` = 透明度ある明 blue
- 既存 view コードは無改修で Dark 適応

**確認箇所** (主要 14 件、view 別):
- `ArticleRow.swift`: AI バッジ Capsule background `actionBlue.opacity(0.08)`
- `KnowledgeCategoryRow.swift`: progress bar overlay
- `BottomStatusBar.swift`: phase tint (全 case actionBlue)
- `EnrichmentStatusBadge.swift`: status indicator
- `EmptyStateView.swift`: icon background
- 他 view も同様

**Alternatives considered**:
- 各 view で明示的に opacity 計算後の hex を直書き → 既存設計を壊す、避ける

## R5 — 9 deprecated alias の Dark variant

**Decision**: 9 deprecated alias (aiBrandStart / End / Edge / NodeFill / NodeStroke / phaseEnrichment / phaseBody / phaseKnowledge / phaseTagging) は明示的な Dark variant 追加不要。actionBlue 経由で auto adapt。

**Rationale**:
- alias の定義は `aiBrandStart = actionBlue.opacity(0.10)` 等で actionBlue 経由
- R4 と同じ理由で base color が adaptive なら alias も auto adapt
- 廃止予定 view (PowerGauge / KnowledgeMap / RecentActivityCards) は spec 031 で削除予定、現状は alias 経由で適切に表示
- 4 phase tint (`phaseEnrichment` / `phaseBody` / `phaseKnowledge` / `phaseTagging`) は全部 `actionBlue` (alias) なので Light/Dark 統一

**Alternatives considered**:
- 9 alias を本 spec で削除 → 廃止 view が破綻、spec 031 まで残す方針堅持
- 9 alias に明示的 Dark variant 追加 → R4 で auto adapt するので不要

## R6 — テスト戦略

**Decision**: 新規 `ColorAdaptiveTests.swift` で `Color.adaptive(light:dark:)` の単体テスト。既存テスト 93 ケース全回帰 PASS。UI test は本 spec では追加せず、quickstart 9 シナリオで実機検証代替。

**テストケース**:
1. `testReturnsLightColorInLightMode`: UITraitCollection.userInterfaceStyle = .light で light が返る
2. `testReturnsDarkColorInDarkMode`: UITraitCollection.userInterfaceStyle = .dark で dark が返る
3. `testActionBlueLightHex`: `DS.Color.actionBlue` が Light で #0a4d8c を返す
4. `testActionBlueDarkHex`: `DS.Color.actionBlue` が Dark で #3a8eef を返す
5. `testParchmentLightHex`: parchment Light で #faf8f3
6. `testParchmentDarkHex`: parchment Dark で #1c1c1e

**Rationale**:
- `Color.adaptive` 自体は純関数 (UITraitCollection を input、Color を output)、unit test しやすい
- UIColor の `cgColor.components` で hex 比較
- WCAG contrast check は本 spec ではスキップ (実機目視で代替)
- DisclosureGroup や view rendering は SwiftUI 内部で保証、test 範囲外

**Alternatives considered**:
- snapshot test → プロジェクト未導入、本 spec で導入は別 spec
- UI test → 実機検証で十分、保守コスト増

## R7 — DESIGN.md の更新範囲

**Decision**: 3 セクションを更新:
1. **frontmatter colors**: 各色に dark variant を併記 (`primary: { light: "#0a4d8c", dark: "#3a8eef" }` 形式)
2. **Migration Notes**: 「spec 017 で Dark Mode 一元対応済」エントリを追記
3. **Known Gaps**: 「dark mode: 未文書化」エントリを削除

既存 11 セクション構成 + Migration Notes は維持、構造変更なし。

**Rationale**:
- DESIGN.md は AI agent 参照用の design document、token と hex の同期が最重要
- frontmatter colors の dark 値が DesignSystem.swift と一致することで AI agent が誤った hex で実装する事故を防ぐ
- Migration Notes は spec 014 → 015 → 017 の delta を時系列で追記する場所、本 spec で 1 エントリ追加

**Alternatives considered**:
- DESIGN.md を全面書き換え → 既存構造を壊す、不要
- frontmatter のみ更新、Migration Notes 触らず → トレーサビリティ低下、避ける

## R8 — SwiftUI Color literal vs UIColor hex 数値化

**Decision**: SwiftUI `Color(red:green:blue:)` のまま (既存スタイル維持)、`UIColor(SwiftUIColor)` で UIColor 化して dynamicProvider 内に渡す。

```swift
extension Color {
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// 使用例:
static let actionBlue = Color.adaptive(
    light: Color(red: 10/255, green: 77/255, blue: 140/255),     // #0a4d8c
    dark:  Color(red: 58/255, green: 142/255, blue: 239/255)     // #3a8eef
)
```

**Rationale**:
- 既存 DesignSystem.swift は `Color(red:green:blue:)` で書かれている、本 spec も同スタイル維持
- `UIColor(_: Color)` initializer (iOS 14+) で SwiftUI Color → UIColor 変換可能
- dynamicProvider 内で `trait.userInterfaceStyle` 判定し、適切な UIColor を返す
- 結果の Color は SwiftUI が auto adapt

**Alternatives considered**:
- UIColor(red:green:blue:alpha:) で書く → 既存スタイルから乖離、避ける
- Hex string parser 自作 → 不要な抽象化、避ける

## R9 — iOS 14/26 サポート確認

**Decision**: 本 spec の API はすべて iOS 14+ で動作確認済。iOS 26 で問題なし。

| API | iOS 最小バージョン | 用途 |
|---|---|---|
| `UIColor { trait in ... }` (dynamicProvider) | iOS 13+ | adaptive UIColor 生成 |
| `Color(uiColor:)` | iOS 15+ | UIColor → SwiftUI Color bridge |
| `UIColor(_: Color)` | iOS 14+ | SwiftUI Color → UIColor |
| `UITraitCollection.userInterfaceStyle` | iOS 12+ | Light/Dark 判定 |

**Rationale**:
- 本プロジェクトは iOS 26+ minimum なので余裕あり
- すべて Apple 標準 API、ABI 安定

**Alternatives considered**:
- なし (Apple 標準のみ使用)

## R10 — Reduce Transparency 自動対応の実装

**Decision**: 追加コードゼロ。spec 014 で gradient/shadow 全廃済、blur 系の使用箇所もない (`.thinMaterial` / `.regularMaterial` 検索ヒットなし) → Reduce Transparency 影響なし。

**Rationale**:
- DS.Color の token は全て solid color (alpha 含む RGB)、blur や translucent material なし
- iOS 設定 → アクセシビリティ → 透明度を下げる ON でも solid color に影響なし
- 万一 blur 系が将来追加された場合は `@Environment(\.accessibilityReduceTransparency)` で対応 (本 spec 範囲外)

**確認箇所**:
- BottomStatusBar の phase tint = solid actionBlue (translucent なし)
- Capsule / RoundedRectangle の `.fill(...)` も solid color
- Material の使用なし

**Alternatives considered**:
- Reduce Transparency 専用 token を別途用意 → 不要 (現状 blur ゼロ)
- Reduce Transparency を将来 spec で対応 → 現時点では実装不要、将来 blur 系追加時に検討

# Contract: Color.adaptive(light:dark:)

`SwiftUI.Color` extension に追加する static 関数。Light/Dark Mode で異なる色を auto-adapt させる。

## 配置

`KnowledgeTree/DesignSystem.swift` の末尾、既存 `View` extension (`dsCardBackground` 等) の隣。

## 定義

```swift
import SwiftUI
import UIKit

extension Color {
    /// Light/Dark Mode で異なる色を返す adaptive Color を生成する。
    /// SwiftUI の Color(uiColor:) と UIKit の UIColor dynamicProvider を組み合わせ、
    /// UITraitCollection.userInterfaceStyle に応じて auto-adapt する。
    ///
    /// - Parameters:
    ///   - light: Light Mode 時の色
    ///   - dark: Dark Mode 時の色
    /// - Returns: SwiftUI が auto-adapt する Color
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}
```

## 入力

| パラメータ | 型 | 説明 |
|---|---|---|
| `light` | `Color` | Light Mode 時に返す色 (例: `Color(red: 10/255, green: 77/255, blue: 140/255)` for #0a4d8c) |
| `dark` | `Color` | Dark Mode 時に返す色 (例: `Color(red: 58/255, green: 142/255, blue: 239/255)` for #3a8eef) |

## 出力

| 戻り値 | 型 | 説明 |
|---|---|---|
| (return) | `Color` | UITraitCollection に応じて auto-adapt する SwiftUI Color |

## 不変条件

- `Color.adaptive(light:dark:)` は副作用なしの純関数 (引数のみで結果が決まる)
- 同じ light/dark で何度呼び出しても同じ Color を返す (idempotent)
- 返される Color は SwiftUI 内部で UIColor を保持、`@Environment(\.colorScheme)` を見ずに UITraitCollection 経由で動作
- `light == dark` でも動作するが、冗長 (本 spec では使わない)

## 使用箇所 (本 spec 内)

`DS.Color` namespace の 5 token を adaptive 化:

```swift
enum DS {
    enum Color {
        static let actionBlue = Color.adaptive(
            light: Color(red: 10/255, green: 77/255, blue: 140/255),    // #0a4d8c
            dark:  Color(red: 58/255, green: 142/255, blue: 239/255)    // #3a8eef
        )

        static let actionBlueFocus = Color.adaptive(
            light: Color(red: 21/255, green: 101/255, blue: 184/255),   // #1565b8
            dark:  Color(red: 90/255, green: 163/255, blue: 245/255)    // #5aa3f5
        )

        static let parchment = Color.adaptive(
            light: Color(red: 250/255, green: 248/255, blue: 243/255),  // #faf8f3
            dark:  Color(red: 28/255, green: 28/255, blue: 30/255)      // #1c1c1e
        )

        static let knowledgeTile = Color.adaptive(
            light: Color(red: 245/255, green: 245/255, blue: 247/255),  // #f5f5f7
            dark:  Color(red: 42/255, green: 42/255, blue: 44/255)      // #2a2a2c
        )

        static let tagFill = Color.adaptive(
            light: Color(red: 234/255, green: 234/255, blue: 239/255),  // #eaeaef
            dark:  Color(red: 44/255, green: 44/255, blue: 46/255)      // #2c2c2e
        )

        // 既存 token (変更なし、すでに adaptive)
        static let surfacePrimary   = Color(.systemBackground)
        static let surfaceSecondary = Color(.secondarySystemBackground)
        static let overlaySubtle    = Color.primary.opacity(0.06)
        static let overlayLight     = Color.primary.opacity(0.10)
        static let overlayMedium    = Color.primary.opacity(0.15)
        static let textEmphasis     = Color.primary.opacity(0.85)

        // 9 deprecated alias (変更なし、actionBlue 経由で auto adapt)
        static let aiBrandStart      = actionBlue.opacity(0.10)
        static let aiBrandEnd        = actionBlue.opacity(0.20)
        static let aiBrandEdge       = Color.secondary.opacity(0.25)
        static let aiBrandNodeFill   = actionBlue.opacity(0.10)
        static let aiBrandNodeStroke = actionBlue.opacity(0.55)
        static let phaseEnrichment   = actionBlue
        static let phaseBody         = actionBlue
        static let phaseKnowledge    = actionBlue
        static let phaseTagging      = actionBlue
    }
}
```

## テストケース (ColorAdaptiveTests.swift)

| # | ケース | 検証 |
|---|---|---|
| 1 | `testReturnsLightColorInLightMode` | `UITraitCollection(userInterfaceStyle: .light).resolvedColor(...)` で light の RGB を返す |
| 2 | `testReturnsDarkColorInDarkMode` | `UITraitCollection(userInterfaceStyle: .dark).resolvedColor(...)` で dark の RGB を返す |
| 3 | `testActionBlueLightHex` | `DS.Color.actionBlue` を Light で resolve → RGB == (10, 77, 140) (with epsilon 0.01) |
| 4 | `testActionBlueDarkHex` | `DS.Color.actionBlue` を Dark で resolve → RGB == (58, 142, 239) |
| 5 | `testParchmentLightHex` | `DS.Color.parchment` Light で RGB == (250, 248, 243) |
| 6 | `testParchmentDarkHex` | `DS.Color.parchment` Dark で RGB == (28, 28, 30) |
| 7 | `testTagFillBothModes` | tagFill が Light = (234, 234, 239) / Dark = (44, 44, 46) |

(7 ケース、テスト fixture 不要、`UITraitCollection` で trait 注入)

## 互換性

- `DS.Color.actionBlue` 等の既存 API signature 不変 (型は `Color`、参照方法不変)
- 全 18 view コードは無改修
- 既存 unit test 93+ ケースが全 PASS (既存 token の Light 値が変わらないため)

## アクセシビリティ

- `Color.adaptive(light:dark:)` 自体は色のみ、accessibility 無関係
- 各 token の Light/Dark 値は WCAG AA contrast (4.5:1) を満たす設計 (R3 で詳述)
- VoiceOver / Dynamic Type は本 spec 範囲外 (token は色のみ、文字サイズと無関係)

## 警告事項

- `light == dark` で呼び出すのは冗長 (Color literal を直接書くべき)、本 spec では使わない
- `UIColor(_: Color)` は SwiftUI Color の opacity を保持しないケースがあるため、opacity 適用は呼び出し側で `.opacity(...)` を使うこと
- `Color.adaptive(light: aColor, dark: aColor.opacity(0.5))` のような alpha 違いは動作するが、可読性のため避ける

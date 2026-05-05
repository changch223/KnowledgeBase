# Contract: DesignSystem

**Created**: 2026-05-05
**File**: `KnowledgeTree/DesignSystem.swift`

## 責務

KnowledgeTree 全 view にまたがるデザイントークンと最頻出 ViewModifier の single source of truth。

## API

```swift
import SwiftUI

enum DS {
    enum Color {
        // Surface
        static let surfacePrimary: SwiftUI.Color
        static let surfaceSecondary: SwiftUI.Color

        // Overlay
        static let overlaySubtle: SwiftUI.Color
        static let overlayLight: SwiftUI.Color
        static let overlayMedium: SwiftUI.Color

        // AI brand
        static let aiBrandStart: SwiftUI.Color
        static let aiBrandEnd: SwiftUI.Color
        static let aiBrandEdge: SwiftUI.Color
        static let aiBrandNodeFill: SwiftUI.Color
        static let aiBrandNodeStroke: SwiftUI.Color

        // Phase tints
        static let phaseEnrichment: SwiftUI.Color
        static let phaseBody: SwiftUI.Color
        static let phaseKnowledge: SwiftUI.Color
        static let phaseTagging: SwiftUI.Color

        // Text
        static let textEmphasis: SwiftUI.Color
    }

    enum Spacing {
        static let xxs: CGFloat       // 2
        static let xs: CGFloat        // 4
        static let sm: CGFloat        // 6
        static let md: CGFloat        // 8
        static let lg: CGFloat        // 10
        static let xl: CGFloat        // 12
        static let xxl: CGFloat       // 16
        static let xxxl: CGFloat      // 20
        static let section: CGFloat   // 24
    }

    enum Radius {
        static let thumb: CGFloat     // 8
        static let chip: CGFloat      // 12
        static let card: CGFloat      // 16
        static let hero: CGFloat      // 20
    }

    enum Typography {
        static let heroCounter: Font
        static let heroSubtitle: Font
        static let heroBrand: Font
        static let sectionTitle: Font
        static let rowTitle: Font
        static let aiLabel: Font
        static let chipLabel: Font
        static let chipIcon: Font
        static let mapNodeLabel: Font
        static let bodyLineSpacing: CGFloat   // 8
    }

    enum Animation {
        static let standard: SwiftUI.Animation
        static let counterAppear: SwiftUI.Animation
        static let counterUpdate: SwiftUI.Animation
        static let pulseLoop: SwiftUI.Animation
        static let nodeAppear: SwiftUI.Animation
        static let statusBar: SwiftUI.Animation
        static let interactive: SwiftUI.Animation

        /// Reduce Motion ON で nil を返す。`withAnimation(nil)` で即時更新。
        static func ifMotionAllowed(_ anim: SwiftUI.Animation) -> SwiftUI.Animation?
    }
}

extension View {
    /// secondarySystemBackground で背景を埋め、RoundedRectangle で clip。
    func dsCardBackground(radius: CGFloat = DS.Radius.card) -> some View

    /// AI brand gradient (accentColor → purple) で背景を埋める。
    func dsAIGradientBackground(radius: CGFloat = DS.Radius.hero) -> some View
}
```

## 入力契約

すべて値型 (`SwiftUI.Color` / `CGFloat` / `Font` / `SwiftUI.Animation`)、ビルド時定数。

## 出力契約

`enum DS` の static プロパティを read-only で参照する。set 不可 (let 定義)。

`ifMotionAllowed(_:)` は `UIAccessibility.isReduceMotionEnabled` を runtime で評価:
- ON → `nil` (= `withAnimation(nil)` で即時更新)
- OFF → 渡されたアニメをそのまま返す

ViewModifier 2 つは `some View` を返す、SwiftUI 標準パターン。

## 副作用

なし。値型の参照のみ、SwiftData / Foundation Models 等への副作用ゼロ。

## 依存

- `import SwiftUI` のみ
- `UIAccessibility` (UIKit) は `ifMotionAllowed` 内で参照

SwiftData / SwiftData @Model 不要 → Share Extension からも import 可能。

## 使用例

### Color

```swift
.background(DS.Color.surfaceSecondary)
.foregroundStyle(DS.Color.textEmphasis)
.fill(DS.Color.aiBrandStart)
```

### Spacing

```swift
VStack(spacing: DS.Spacing.md) {
    // ...
}
.padding(.horizontal, DS.Spacing.xxl)
```

### Animation + Reduce Motion

```swift
withAnimation(DS.Animation.ifMotionAllowed(DS.Animation.counterAppear)) {
    animatedCount = realCount
}
```

### ViewModifier

```swift
HStack { /* card content */ }
    .dsCardBackground()
    .dsCardBackground(radius: DS.Radius.hero)  // 大型カード用

Color.clear
    .dsAIGradientBackground()
```

## テスト

本 spec では DS Token の値固定 unit test は **追加しない** (将来 spec で導入検討)。理由:

- DS の値変更は意図的なデザイン調整であり、test で固定化すると「変更時にテストも更新」のオーバーヘッドが高い
- 既存 66 unit テストは Service / Store 層中心、View 層の visual 結果はテストしていない

既存 KnowledgeTreeTests が pass し続けることのみ確認 (data 層 / Service 層に影響なし、View 層のみ変更だから)。

## 副作用境界

`enum DS` は純粋な値型集合。`UIAccessibility.isReduceMotionEnabled` のみ runtime 状態を読むが、これは Apple OS API の global state で、本 spec では read-only。

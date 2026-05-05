# Phase 0 Research: spec 014 (デザインシステム + Phase 3/4 視覚改善)

**Created**: 2026-05-05
**Status**: Retroactive

実装で採用された技術判断を 5 つの研究項目 (R1〜R5) で記録。

---

## R1: トークン分類体系 (Color / Spacing / Radius / Typography / Animation)

### Decision

5 つの sub-enum で分類:

```swift
enum DS {
    enum Color { ... }
    enum Spacing { ... }
    enum Radius { ... }
    enum Typography { ... }
    enum Animation { ... }
}
```

### Rationale

- iOS / SwiftUI で頻出する 5 つのドメインに対応
- Apple HIG (Human Interface Guidelines) も同様のカテゴリ分け (color / spacing / typography)
- Animation を独立カテゴリにすることで、Reduce Motion ガード `ifMotionAllowed(_:)` を 1 箇所で集約可能

### Alternatives considered

- **A**: フラット (DS.cardRadius / DS.heroSpacing 等) → 名前空間がフラットすぎて衝突しやすい、却下
- **B**: protocol + struct 化 (DesignTokens protocol + LightTheme/DarkTheme struct) → 将来 theme 切替が必要なら有用だが本 spec では over-engineering、却下
- **C**: extension Color / extension Font 等の散在 → magic number 駆逐の趣旨と矛盾、却下

---

## R2: Color の意味付け (semantic naming vs primitive)

### Decision

**Semantic 重視**で命名。`DS.Color.surfacePrimary` (用途) ベース、必要に応じて `DS.Color.aiBrandStart` のような特化型。

```swift
enum Color {
    // Surface
    static let surfacePrimary   = SwiftUI.Color(.systemBackground)
    static let surfaceSecondary = SwiftUI.Color(.secondarySystemBackground)

    // Overlay (replaces .opacity(0.06–0.20) literals)
    static let overlaySubtle = SwiftUI.Color.primary.opacity(0.06)
    // ...

    // AI brand
    static let aiBrandStart = SwiftUI.Color.accentColor.opacity(0.15)
    // ...

    // Phase tints
    static let phaseEnrichment = SwiftUI.Color.secondary
    // ...
}
```

### Rationale

- 用途ベースで命名 → view 側で「なぜこの色?」が読みやすい (例: `.fill(DS.Color.surfaceSecondary)` >> `.fill(Color.gray.opacity(0.15))`)
- AI brand は 5 トークン (`aiBrandStart/End/Edge/NodeFill/NodeStroke`) で AI ブレイン系の視覚言語を統一
- BottomStatusBar の phase tint は `phaseEnrichment` / `phaseBody` / `phaseKnowledge` / `phaseTagging` で spec 005 / 013 のフェーズ enum と 1 対 1 対応

### Alternatives considered

- **A**: `DS.Color.gray100` / `DS.Color.gray200` 等の primitive 命名 → CSS / Tailwind 風だが、SwiftUI の `.systemBackground` 等が adaptive で素晴らしいので primitive は不要、却下
- **B**: Color asset Catalog で named color → ライト/ダークの手動チューニングが可能になるメリットあるが、現時点で不要 (将来 spec)

---

## R3: Spacing スケールの粒度 (xxs〜section の 9 段階)

### Decision

9 段階: `xxs(2) / xs(4) / sm(6) / md(8) / lg(10) / xl(12) / xxl(16) / xxxl(20) / section(24)`

### Rationale

- 既存 view の magic number を集計すると 2/4/6/8/10/12/16/20/24 がほぼ全て → 9 段階で網羅
- 4-point grid に概ね収まる (Apple HIG 推奨)
- `section` だけ特別命名: 「セクション間の大きい余白」(VStack の最外スペーシング等) を意味
- Tailwind 風の `space-1` / `space-2` などの数値命名より「サイズ感」が読みやすい

### Alternatives considered

- **A**: 4-point grid 厳守 (`s4 / s8 / s12 / s16 / s20 / s24`) → 2pt や 6pt が必要なケース (chip 内の微小調整等) で困る、却下
- **B**: 12 段階や 16 段階 → 過剰、選択困難になる、却下
- **C**: 数値リテラル直書き派 → magic number 駆逐の趣旨と矛盾、却下

---

## R4: Animation トークン化 + Reduce Motion ガード

### Decision

7 種の Animation スタイル + `ifMotionAllowed(_:)` 関数:

```swift
enum Animation {
    static let standard      = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let counterAppear = SwiftUI.Animation.easeOut(duration: 0.55)
    static let counterUpdate = SwiftUI.Animation.easeOut(duration: 0.35)
    static let pulseLoop     = SwiftUI.Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    static let nodeAppear    = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.75)
    static let statusBar     = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.85)
    static let interactive   = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.9)

    static func ifMotionAllowed(_ anim: SwiftUI.Animation) -> SwiftUI.Animation? {
        UIAccessibility.isReduceMotionEnabled ? nil : anim
    }
}
```

使い方:

```swift
withAnimation(DS.Animation.ifMotionAllowed(DS.Animation.counterAppear)) {
    animatedCount = realCount
}
```

`nil` を渡すと `withAnimation(nil)` → 即時更新 (アニメなし)。

### Rationale

- 7 種で AI ブレインタブ全アニメをカバー (counterAppear / counterUpdate / pulseLoop / nodeAppear / statusBar / interactive / standard)
- `ifMotionAllowed` は 1 関数で全 view から呼び出し可能 → Reduce Motion 対応が漏れない
- `UIAccessibility.isReduceMotionEnabled` は static、毎回チェックするコスト無視できる

### Alternatives considered

- **A**: 各 view で `if UIAccessibility.isReduceMotionEnabled { ... } else { ... }` を書く → 漏れる、却下
- **B**: `@Environment(\.accessibilityReduceMotion)` を view 内で読む → SwiftUI 標準、しかし trigger 時に view 全体が再描画される副作用あり、`ifMotionAllowed` 関数のほうがピンポイント、採用
- **C**: macros で自動 wrap → 過剰、却下

---

## R5: ViewModifier の最小化 (`dsCardBackground` / `dsAIGradientBackground` のみ)

### Decision

`extension View` で 2 つの ViewModifier のみ:

```swift
extension View {
    func dsCardBackground(radius: CGFloat = DS.Radius.card) -> some View {
        background(
            DS.Color.surfaceSecondary,
            in: RoundedRectangle(cornerRadius: radius, style: .continuous)
        )
    }

    func dsAIGradientBackground(radius: CGFloat = DS.Radius.hero) -> some View {
        background(
            LinearGradient(
                colors: [DS.Color.aiBrandStart, DS.Color.aiBrandEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: radius, style: .continuous)
        )
    }
}
```

### Rationale

- 18 view で頻出する 2 パターン (カード背景 / AI gradient 背景) のみ抽象化
- Constitution コード品質ゲート「新規抽象化は 2 箇所以上の利用」要件を満たす
- それ以外のスタイル (specular highlight / hairline border / shadow pulse 等) は 1 view 専用なので ViewModifier 化せず inline

### Alternatives considered

- **A**: 全パターンを ViewModifier 化 (dsHairlineBorder / dsSpecularHighlight 等) → 利用箇所 1 つだけのものを抽象化すると保守コスト増、却下
- **B**: ViewModifier 0 個、view 側で直接書く → magic number 駆逐の効果が低下、却下
- **C**: SwiftUI ButtonStyle / LabelStyle 拡張 → 本 spec で button / label の style 統一は対象外 (将来 spec)

---

## まとめ

すべての R1〜R5 で技術判断を確定。NEEDS CLARIFICATION 残存ゼロ。

**コア発見**:
- 5 トークンカテゴリ + 2 ViewModifier で 18 view を統一可能
- `ifMotionAllowed(_:)` 1 関数で Reduce Motion 対応漏れゼロ
- AI brand 5 トークンで AI ブレイン系の視覚言語が統一
- 既存 Color / Spacing 散在を 100% 駆逐 (本 spec で `grep -r "cornerRadius: [0-9]"` などで確認可能)

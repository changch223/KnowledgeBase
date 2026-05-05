# Data Model: spec 017

## 既存エンティティ

新規 @Model なし、変更なし。SwiftData schema 完全無関係 (色 token のみの spec)。

## 新規 transient 型

なし (純粋に extension method の追加)。

## 新規拡張

### Color.adaptive(light:dark:)

`KnowledgeTree/DesignSystem.swift` 内に extension で追加。

```swift
extension Color {
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}
```

**入出力**:
- 入力: `light: Color` (Light Mode 時の色), `dark: Color` (Dark Mode 時の色)
- 出力: `Color` (UITraitCollection に応じて auto-adapt する SwiftUI Color)

**特性**:
- Pure (副作用なし)
- Idempotent (同じ入力で同じ出力)
- Thread-safe (UIColor dynamicProvider は trait collection 評価時にメインスレッド呼び出し)

## 改修 token

| Token | 旧定義 (Light のみ) | 新定義 (Light/Dark adaptive) |
|---|---|---|
| `actionBlue` | `Color(red: 10/255, green: 77/255, blue: 140/255)` | `.adaptive(light: Color(red: 10/255, ...), dark: Color(red: 58/255, green: 142/255, blue: 239/255))` |
| `actionBlueFocus` | `Color(red: 21/255, green: 101/255, blue: 184/255)` | `.adaptive(light: ..., dark: Color(red: 90/255, green: 163/255, blue: 245/255))` |
| `parchment` | `Color(red: 250/255, green: 248/255, blue: 243/255)` | `.adaptive(light: ..., dark: Color(red: 28/255, green: 28/255, blue: 30/255))` |
| `knowledgeTile` | `Color(red: 245/255, green: 245/255, blue: 247/255)` | `.adaptive(light: ..., dark: Color(red: 42/255, green: 42/255, blue: 44/255))` |
| `tagFill` | `Color(red: 234/255, green: 234/255, blue: 239/255)` | `.adaptive(light: ..., dark: Color(red: 44/255, green: 44/255, blue: 46/255))` |

## 永続化スキーマへの影響

**ゼロ**。SwiftData / Tag / Article / Category / 全 @Model に影響なし。

## State 遷移

なし (token は値のみ、状態なし)。`@Environment(\.colorScheme)` は SwiftUI 内部で trait change を検知して view を再描画 → token は trait に応じた色を返す、それだけ。

## 検証ルール

| ルール | 検証 |
|---|---|
| `Color.adaptive(light:dark:)` は light != dark で動作 | 必須 (本 spec で改修する 5 tokens すべて light != dark) |
| `Color.adaptive(light:dark:)` は light == dark でも動作 | 任意 (将来 token 追加時の許容、ただし冗長) |
| 既存 token API (`DS.Color.actionBlue` 等) の signature 不変 | 必須 (view 改修ゼロのため) |
| token 値が DESIGN.md frontmatter colors と一致 | 必須 (AI agent 誤実装防止) |

## エラーケース

`Color.adaptive(light:dark:)` は副作用なしの純関数、エラーケースなし。`UIColor` dynamicProvider 内で SwiftUI が trait collection を提供しない場合は SwiftUI 側のバグだが、本 spec 範囲外。

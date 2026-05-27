# Contract: FABButton (Floating Action Button)

## Purpose

知識 Clip + ライブラリ で再利用される FAB component。タップで callback 実行 (記事追加 sheet 等)。

## Component

```swift
struct FABButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor, in: .circle)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .padding(.trailing, 16)
        .padding(.bottom, 16)
        .accessibilityLabel("fab.accessibility.label")
    }
}
```

## 使用例

```swift
.overlay(alignment: .bottomTrailing) {
    FABButton(icon: "plus") {
        showAddArticle = true
    }
}
```

## Specifications

- サイズ: 56x56 (Material Design 標準)
- 形状: circle
- color: `Color.accentColor` (DesignSystem)
- shadow: 軽い (`black.opacity(0.2)`, radius 4)
- 配置: 右下、padding 16

## MVP 範囲外 (将来 polish)

- scroll down で hide / scroll up で show (Apple News パターン)
- haptic on tap
- アニメーション (scale on press)

MVP では常時表示、tap で callback 実行のみ。

## アクセシビリティ

- `accessibilityLabel` 動的設定可能なら拡張 (例: "記事を追加")
- 現状は generic `fab.accessibility.label` (xcstrings で「追加」等)

## xcstrings 追加

- `fab.accessibility.label` = "追加"

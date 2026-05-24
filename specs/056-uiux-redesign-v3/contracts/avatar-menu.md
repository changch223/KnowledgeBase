# Contract: AvatarMenu

## Purpose

知識 Clip タブ右上に配置するアバター/プロフィール icon。tap で SettingsView を sheet 表示 (NavigationStack 内)。Apple News パターン。

## Component

```swift
struct AvatarMenu: View {
    @State private var showSettings = false
    
    var body: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.title2)
                .foregroundStyle(.primary)
        }
        .accessibilityIdentifier("toolbar.avatar")
        .accessibilityLabel("avatar.menu.accessibility")
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
    }
}
```

## 配置

KnowledgeClipView の toolbar:

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        AvatarMenu()
    }
}
```

## SettingsView 既存維持

- SettingsView (既存) は無変更で sheet 内に表示
- NavigationStack 内なので push 遷移 (例: Tag 管理) も動作
- swipe down で sheet dismiss

## iPad での挙動

- iOS 26 standard: iPad では sheet が中央 modal 表示 (modally adapted)
- iPhone push 形式は採用しない (sheet 統一でコード simple)

## xcstrings 追加

- `avatar.menu.accessibility` = "プロフィール、設定を開く"

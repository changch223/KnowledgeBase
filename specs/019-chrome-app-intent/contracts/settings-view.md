# Contract: SettingsView

新規 SwiftUI view。AI ブレインタブ右上の歯車から push 遷移、設定画面の root。

## 配置

`KnowledgeTree/Views/SettingsView.swift` (新規、SettingsDestination + ChromeSetupDestination も同ファイル末尾)。

## 定義

```swift
import SwiftUI

struct SettingsView: View {
    @AppStorage("settings.shortcutSetupCompleted") private var setupCompleted: Bool = false

    var body: some View {
        Form {
            Section("settings.section.externalIntegration") {
                NavigationLink(value: ChromeSetupDestination()) {
                    HStack {
                        Image(systemName: "safari")
                            .foregroundStyle(DS.Color.actionBlue)
                            .frame(width: 24)
                        Text("settings.chromeSetup.entry")
                        Spacer()
                        if setupCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DS.Color.actionBlue)
                                .accessibilityIdentifier("settings.chromeSetup.completedMark")
                        }
                    }
                }
                .accessibilityIdentifier("settings.chromeSetup.entry")
            }
        }
        .navigationTitle("settings.title")
        .navigationDestination(for: ChromeSetupDestination.self) { _ in
            ChromeShortcutSetupView()
        }
        .accessibilityIdentifier("settings.root")
    }
}

struct SettingsDestination: Hashable {}
struct ChromeSetupDestination: Hashable {}
```

## 入力

なし (state は `@AppStorage` 経由で UserDefaults から)。

## 出力

なし (UI のみ)。

## State

| State | 型 | 用途 |
|---|---|---|
| `setupCompleted` | `Bool` (`@AppStorage`) | ChromeShortcutSetupView の Setup 完了フラグ、SettingsView の checkmark 表示制御 |

## View 構成

```
Form
  Section "外部連携"
    NavigationLink → ChromeShortcutSetupView
      Image (safari, actionBlue)
      Text "Chrome から自動保存"
      Spacer
      [if setupCompleted] Image (checkmark.circle.fill, actionBlue)
```

## 不変条件

- `setupCompleted = true` 時のみ右側 checkmark 表示
- NavigationLink は Hashable destination 経由、SwiftUI 標準パターン
- Form 形式で iOS 標準設定アプリ風 UX

## アクセシビリティ

- accessibilityIdentifier `settings.root`、`settings.chromeSetup.entry`、`settings.chromeSetup.completedMark`
- VoiceOver: 「Chrome から自動保存」読み上げ + 完了時に「セットアップ完了」追加読み上げ (システム標準)
- Dynamic Type 対応 (Form / Section / NavigationLink は SwiftUI 標準)

## 互換性

- spec 016 / 018 の Hashable destination パターン同様
- DS.Color.actionBlue (spec 014/017) 経由で Dark Mode 自動対応
- @AppStorage は UserDefaults.standard、再起動でも保持

## テスト戦略

- View rendering test は本 spec で省略 (NavigationStack の navigation 挙動は SwiftUI 内部、test 困難)
- 実機検証 (quickstart SC-006-007) で目視確認

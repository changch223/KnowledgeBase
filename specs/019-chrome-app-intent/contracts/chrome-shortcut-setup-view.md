# Contract: ChromeShortcutSetupView

新規 SwiftUI view。SettingsView の「Chrome から自動保存」エントリから push 遷移、3 ステップの Setup Guide。

## 配置

`KnowledgeTree/Views/ChromeShortcutSetupView.swift` (新規)。

## 定義 (概要)

```swift
import SwiftUI

struct ChromeShortcutSetupView: View {
    @AppStorage("settings.shortcutSetupCompleted") private var setupCompleted: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                // 説明文
                Text("settings.chromeSetup.description")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Step 1 (Open Shortcuts.app ボタン付き)
                stepCard(
                    number: 1,
                    titleKey: "settings.chromeSetup.step1.title",
                    descriptionKey: "settings.chromeSetup.step1.description",
                    actionButton: AnyView(openShortcutsButton)
                )

                // Step 2 (静的)
                stepCard(
                    number: 2,
                    titleKey: "settings.chromeSetup.step2.title",
                    descriptionKey: "settings.chromeSetup.step2.description",
                    actionButton: nil
                )

                // Step 3 (静的)
                stepCard(
                    number: 3,
                    titleKey: "settings.chromeSetup.step3.title",
                    descriptionKey: "settings.chromeSetup.step3.description",
                    actionButton: nil
                )

                // Complete / Reset ボタン
                if setupCompleted {
                    Button("settings.chromeSetup.resetLink") {
                        setupCompleted = false
                    }
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.chromeSetup.resetButton")
                } else {
                    Button("settings.chromeSetup.completeButton") {
                        setupCompleted = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.Color.actionBlue)
                    .accessibilityIdentifier("settings.chromeSetup.completeButton")
                }
            }
            .padding(DS.Spacing.xxl)
        }
        .navigationTitle("settings.chromeSetup.title")
        .accessibilityIdentifier("settings.chromeSetup.root")
    }

    private var openShortcutsButton: some View {
        Button {
            if let url = URL(string: "shortcuts://") {
                UIApplication.shared.open(url)
            }
        } label: {
            Label("settings.chromeSetup.openShortcutsButton", systemImage: "arrow.up.forward.app")
        }
        .buttonStyle(.bordered)
        .tint(DS.Color.actionBlue)
        .accessibilityIdentifier("settings.chromeSetup.openShortcutsButton")
    }

    @ViewBuilder
    private func stepCard(
        number: Int,
        titleKey: LocalizedStringKey,
        descriptionKey: LocalizedStringKey,
        actionButton: AnyView?
    ) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(DS.Color.actionBlue)
                    .frame(width: 32, height: 32)
                Text("\(number)")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(titleKey)
                    .font(DS.Typography.sectionTitle)
                Text(descriptionKey)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionButton {
                    actionButton.padding(.top, DS.Spacing.sm)
                }
            }
        }
        .padding(DS.Spacing.xxl)
        .dsCardBackground()
    }
}
```

## State

| State | 型 | 用途 |
|---|---|---|
| `setupCompleted` | `Bool` (`@AppStorage`) | 「セットアップ完了」フラグ、Complete / Reset ボタン切替 |

## View 構成

```
ScrollView
  VStack
    Text (description, secondary)
    Step Card 1 (number Circle + title + description + "Shortcuts アプリを開く" Button)
    Step Card 2 (number Circle + title + description)
    Step Card 3 (number Circle + title + description)
    [if setupCompleted] Button "もう一度見る" (secondary)
    [else] Button "セットアップ完了" (borderedProminent, actionBlue)
```

## 不変条件

- Step Card は 3 つ、番号は actionBlue Circle + white text
- Step 1 のみアクションボタン (`shortcuts://` deeplink 起動)
- 「セットアップ完了」ボタン → `setupCompleted = true`、戻ると SettingsView に checkmark
- 「もう一度見る」リンク → `setupCompleted = false`、Setup を再表示
- `dsCardBackground()` で Dark Mode (spec 017) 自動対応

## アクセシビリティ

- accessibilityIdentifier:
  - `settings.chromeSetup.root` (画面全体)
  - `settings.chromeSetup.openShortcutsButton` (Step 1 ボタン)
  - `settings.chromeSetup.completeButton` (Complete ボタン)
  - `settings.chromeSetup.resetButton` (Reset リンク)
- Step Number Circle は `accessibilityHidden(true)` で読み上げから除外
- Step title + description は VoiceOver で読み上げ
- Dynamic Type 対応 (`fixedSize(horizontal:vertical:)` で descriptions が wrap)

## 動作シナリオ

| シナリオ | 入力 | 結果 |
|---|---|---|
| 初回表示 | setupCompleted = false | Complete ボタン表示 |
| 「Shortcuts アプリを開く」タップ | - | `UIApplication.shared.open("shortcuts://")` で Shortcuts.app 起動 |
| 「セットアップ完了」タップ | - | setupCompleted = true、戻ると SettingsView に checkmark |
| 完了状態で再表示 | setupCompleted = true | Reset リンク表示 |
| 「もう一度見る」タップ | - | setupCompleted = false、Complete ボタンに戻る |

## 互換性

- DS.Color.actionBlue / DS.Spacing.* / DS.Typography.* / dsCardBackground() (spec 014/017)
- iOS 16+ `UIApplication.shared.open(_:)` で URL scheme 起動
- @AppStorage で UserDefaults 永続化、再起動でも保持

## テスト戦略

- View rendering test は本 spec で省略
- 実機検証 (quickstart SC-008-010) で目視確認
- 「Shortcuts アプリを開く」ボタンの URL scheme 起動は実機のみ確認可能

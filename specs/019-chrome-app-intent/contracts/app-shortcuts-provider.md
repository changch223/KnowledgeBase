# Contract: KnowledgeTreeShortcuts (AppShortcutsProvider)

iOS 16+ AppShortcutsProvider。`SaveURLToKnowledgeTreeIntent` を Shortcuts.app + Spotlight + Siri に **自動登録**する。

## 配置

`KnowledgeTree/AppIntents/SaveURLToKnowledgeTreeIntent.swift` 内 (同ファイル末尾)。

## 定義

```swift
struct KnowledgeTreeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveURLToKnowledgeTreeIntent(),
            phrases: [
                "知積に保存",
                "URL を 知積に保存",
                "Save to \(.applicationName)",
            ],
            shortTitle: "保存",
            systemImageName: "square.and.arrow.down"
        )
    }
}
```

## 動作仕様

1. **自動登録**: アプリインストール時、iOS が AppShortcutsProvider を自動 detect
2. **Shortcuts.app 露出**: `appShortcuts` の内容が Shortcuts.app の「Apps」セクションに自動表示
3. **Spotlight 検索**: 「知積」「Save」等で検索すると候補に表示
4. **Siri 音声起動**: phrases いずれかで「Hey Siri、〜」発話するとアクション起動

## 不変条件

- `phrases` は最低 2 つ (日本語 + 英語)、Siri 認識率向上のため
- `\(.applicationName)` placeholder で「KnowledgeTree」(or 「知積」) が動的展開
- `systemImageName: "square.and.arrow.down"` は SF Symbol (Share Sheet と一貫)
- `shortTitle: "保存"` は Shortcuts.app UI で短縮表示時に使用

## 検証方法

- アプリインストール → Shortcuts.app 起動 → 「Apps」セクション or 検索で「知積に保存」が表示される
- Spotlight 検索で「知積」を入力 → 候補にアクションが表示される
- 「Hey Siri、知積に保存」で Siri が応答 (URL パラメータの音声入力可否は別途検証)

## 互換性

- iOS 16+ で確立した AppShortcutsProvider protocol
- Info.plist への明示 entry 不要
- entitlements 改修不要

## テスト戦略

AppShortcutsProvider 自動登録は実機検証 (Shortcuts.app 目視)。unit test 不可 (iOS framework が必要)。

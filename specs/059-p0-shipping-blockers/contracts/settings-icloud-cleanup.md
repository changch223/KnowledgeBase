# Contract: Settings 重複 iCloud Section 削除 (P0-3 / R3)

## 対象

- `KnowledgeTree/Views/SettingsView.swift:198-216` (旧 placeholder Section)

## 変更

`:198-216` の「近日対応」placeholder Section を**丸ごと削除**。

```swift
// 削除対象 (要点)
// spec 050: iCloud sync (近日対応 placeholder、v2.0 で実装予定)
Section {
    ... Image "icloud" ...
    Text("iCloud で同期")
    Text("近日対応 — 複数の端末で同じ知識ベースを共有")
    ... .accessibilityIdentifier("settings.icloud.placeholder")
} footer: {
    Text("現在は全てこの端末内に保存されます。iCloud 同期は次のバージョンで予定しています。")
}
```

## 維持 (無改修)

| 要素 | 行 |
|---|---|
| 動作する iCloud toggle Section | `:54-101` |
| `settings.icloud.toggle` id | `:95` |
| restartBanner (`settings.icloud.restartBanner`) | `:56-70` |
| ON/OFF 確認 alert | `:311-329` |

## 契約条件

| 条件 | 期待 |
|---|---|
| Settings 表示 | iCloud Section 1 つのみ (動作 toggle)、SC-003 |
| `settings.icloud.placeholder` id | 存在しない |
| `settings.icloud.restartBanner` id | toggle 切替後に条件付き表示 (既存挙動) |
| 前後 Section の区切り | 壊れない |
| 未使用化する文言 | 残骸を残さない (削除文言の key があれば確認) |

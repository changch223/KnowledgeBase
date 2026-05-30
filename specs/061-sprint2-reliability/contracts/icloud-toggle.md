# Contract: iCloud Toggle バウンス解消 (P1-2)

## 対象
- `KnowledgeTree/Views/SettingsView.swift:71-94` (Toggle) + `:312-329` (確認 alert)

## 変更
- `@State private var pendingICloudToggle: Bool?` 追加
- Toggle.get = `pendingICloudToggle ?? iCloudSyncEnabled`
- Toggle.set = `pendingICloudToggle = newValue` + alert 表示
- enable alert OK = `iCloudSyncEnabled = true; pendingICloudToggle = nil; showRestartBanner = true`
- enable alert Cancel = `pendingICloudToggle = nil`
- disable alert も同様 (OK で false 適用、Cancel で nil)

## 契約条件
| 条件 | 期待 |
|---|---|
| OFF でトグル tap | スイッチが弾き返らず ON 表示 + 確認 alert (SC-001) |
| 確認 Cancel | スイッチ OFF に戻る |
| 確認 OK | スイッチ ON 確定 + 再起動 banner (既存挙動、FR-003) |
| `settings.icloud.toggle` id | 維持 |

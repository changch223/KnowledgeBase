# Data Model: Sprint 2 信頼性改善 4 件

## SwiftData @Model 変更

**ゼロ。** 本 spec は永続化スキーマを一切変更しない (FR-011)。

## 既存 @Model (参照のみ、無改修)

| Model | 関与 |
|---|---|
| ChatSession / ChatMessage | P1-3 セッション・履歴削除 |
| SavedAnswer | P1-3 ピン / markFresh / 削除 |
| Article / Tag | P1-3 タグ追加・削除 |
| ConceptPage | P1-3 フォロー切替 |
| (全 @Model) | P1-6 ModelContainer 構築 / P1-7 backfill |

## 新規 transient / 型

| 名前 | 種類 | 役割 |
|---|---|---|
| `AppErrorReporting` | Protocol (@MainActor) | ユーザー操作失敗の記録インターフェース |
| `AppErrorReporter` | final class (Default) | os.Logger ベース実装、`shared` singleton |
| `pendingICloudToggle` | `@State Bool?` (SettingsView) | iCloud toggle の楽観表示 pending (P1-2) |
| `storeLoadFailed` | UserDefaults bool key (P1-6) | ModelContainer in-memory fallback 発生フラグ → body で banner |
| `errorMessage` 系 | `@State String?` (各 view) | 削除失敗時の軽い表示 (P1-3) |

## UserDefaults キー

| key | 用途 |
|---|---|
| `spec061_storeLoadFailed` | ModelContainer 構築失敗 → in-memory fallback で起動した印 (P1-6 banner) |

## 状態遷移

- **iCloud toggle (P1-2)**: `idle → pending(newValue) → [OK: applied | Cancel: idle (revert)]`

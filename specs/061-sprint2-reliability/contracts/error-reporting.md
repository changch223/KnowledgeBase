# Contract: ユーザー操作のサイレント失敗 surface (P1-3)

## 新規: AppErrorReporter

```swift
@MainActor protocol AppErrorReporting {
    func report(_ error: Error, operation: String)
}
@MainActor final class AppErrorReporter: AppErrorReporting {
    static let shared = AppErrorReporter()
    func report(_ error: Error, operation: String)  // os.Logger.error
}
```

## 改修対象 (7 箇所、try? → do/catch)

| ファイル:行 | 操作 | feedback |
|---|---|---|
| ChatHistorySidebar:99 | セッション削除 | error 表示 (削除) |
| SettingsView:288 | チャット履歴全削除 | error 表示 (削除) |
| SavedAnswerDetailView:40 | ピン切替 | log + 失敗時 state 復元 |
| SavedAnswerDetailView:106 | markFresh | log + 失敗時 state 復元 |
| SavedAnswerDetailView:126 | 削除 | error 表示 (削除) |
| ArticleDetailView:243 | タグ追加 | log + 失敗時 state 復元 |
| ArticleDetailView:248 | タグ削除 | log + 失敗時 state 復元 |
| ConceptPageDetailView:53 | フォロー切替 | log + 失敗時 state 復元 |

## 契約条件
| 条件 | 期待 |
|---|---|
| 保存失敗 | `AppErrorReporter.report` が呼ばれ log 記録 (FR-004) |
| 削除失敗 | ユーザーに error 表示 (成功表示にしない、FR-005) |
| 非破壊操作失敗 | log + UI を元の値へ復元 (calm UX) |
| 裏処理 try? | 無改修 (FR-006) |
| 成功時 | 従来通り反映 (退行なし) |

## テスト
- `AppErrorReporterTests`: Mock で report 呼び出し + operation 文字列 (~3 ケース)

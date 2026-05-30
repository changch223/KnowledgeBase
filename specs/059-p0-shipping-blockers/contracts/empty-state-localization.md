# Contract: ライブラリ空状態 文言修正 (P0-1 / R1)

## 対象

- `KnowledgeTree/Views/EmptyStateView.swift:28`
- `KnowledgeTree/Localization/Localizable.xcstrings`

## 変更

### EmptyStateView.swift:28

```swift
// before
Text("Safari で記事を開いて「共有」→ アプリ名 で保存できます")
// after
Text("list.empty.instruction")
```

### Localizable.xcstrings 追加

| key | ja value |
|---|---|
| `list.empty.instruction` | `Safari で記事を開いて「共有」→ iKnow で保存できます` |

## 契約条件

| 条件 | 期待 |
|---|---|
| 記事ゼロでライブラリ空状態表示 | 案内文に「iKnow」表示、「アプリ名」リテラル 0 箇所 (SC-001) |
| accessibilityIdentifier `articleListEmpty` | 維持 (UI test の label 検証に使用) |
| 既存 `list.empty.title` / entrance animation / bob | 無改修 |

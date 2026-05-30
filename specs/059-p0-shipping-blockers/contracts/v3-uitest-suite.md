# Contract: UI test 刷新 (P0-5 / R5)

## 削除

| ファイル | 理由 |
|---|---|
| `KnowledgeTreeUITests/UnderstandingTabUITests.swift` | `tab.learning` 参照、学習タブ廃止で無効 |
| `KnowledgeTreeUITests/AIBrainTabUITests.swift` | `tab.aibrain` 参照、AIブレインタブ廃止で無効 |

pbxproj から `PBXFileReference` / `PBXBuildFile` / UITests target `Sources` 参照を除去。

## 新規: V3RedesignUITests.swift

現行タブ id: `tab.knowledgeClip` / `tab.library` / `tab.chat` (KnowledgeTreeApp:92/99/106)。

| # | シナリオ | 検証 |
|---|---|---|
| 1 | 起動 default = 知識 Clip | `tab.knowledgeClip` 存在 + selected |
| 2 | Add Article sheet 開く | FAB/toolbar tap → sheet 表示 |
| 3 | Library タブ navigate | `tab.library` tap → 一覧/tag list 表示 |
| 4 | Chat タブ empty-state | `tab.chat` tap → empty-state 表示 |
| 5 | Settings を Avatar menu から | avatar tap → Settings 表示 |

## 契約条件

| 条件 | 期待 |
|---|---|
| UI test suite 全走査 | `tab.learning` / `tab.aibrain` 参照 0 件 (SC-005) |
| V3RedesignUITests | 現行 3 タブ検証シナリオ 5 件 (SC-005) |
| compile | 通過 (本セッション担保) |
| 実行 | sandbox 制約で本セッション不可、ユーザー実機後追い |
| `SaveArticleUITests` flaky 1 件 | 対象外、維持 |

## 実装メモ

- launch arguments / setUp は既存 `SaveArticleUITests` の流儀踏襲。
- 不足 accessibilityIdentifier は実装側に最小限追加 (AddArticleSheet / AvatarMenu)。

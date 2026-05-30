# Contract: ModelContainer crash 回避 (P1-6)

## 対象
- `KnowledgeTree/KnowledgeTreeApp.swift:57-81` (`sharedModelContainer` クロージャ)

## 変更
- fatalError 2 箇所 (`:76` local fallback 失敗 / `:79` 通常失敗) を in-memory ModelContainer fallback に置換
- in-memory fallback 成功時 `UserDefaults "spec061_storeLoadFailed" = true`
- in-memory も失敗時のみ fatalError 残置 (理論上ほぼ起きない)
- `#if DEBUG assertionFailure` 併記
- body 側で `storeLoadFailed` を読んで軽い警告 banner

## 契約条件
| 条件 | 期待 |
|---|---|
| store 構築失敗 | crash せず in-memory で起動 (SC-003 / FR-007) |
| store 構築失敗後 | 「データ読み込みに問題」banner 表示 |
| store 正常 | 従来通り永続 store + banner なし (FR-008 退行なし) |
| debug build | assertionFailure で検知 |

## テスト
- 構築失敗の inject は困難 → 構造レビュー + 通常起動 regression。unit は対象外。

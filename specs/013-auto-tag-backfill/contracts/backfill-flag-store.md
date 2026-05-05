# Contract: BackfillFlagStore

**Created**: 2026-05-05
**File**: `KnowledgeTree/Services/BackfillFlagStore.swift`

## 責務

backfill 完了状態の永続化を抽象化する。production は UserDefaults.standard、test は InMemory で UserDefaults 汚染なし。

## API

```swift
protocol BackfillFlagStore {
    /// backfill が既に完了しているかチェック (デフォルト false、起動時に check)
    func isCompleted() -> Bool
    /// backfill 完了 → 次回起動時の skip マーカー
    func markCompleted()
}

final class UserDefaultsBackfillFlagStore: BackfillFlagStore {
    private let key: String
    private let defaults: UserDefaults

    init(
        key: String = "auto_tag_backfill_v1_done",
        defaults: UserDefaults = .standard
    ) {
        self.key = key
        self.defaults = defaults
    }

    func isCompleted() -> Bool { defaults.bool(forKey: key) }
    func markCompleted() { defaults.set(true, forKey: key) }
}

final class InMemoryBackfillFlagStore: BackfillFlagStore {
    private var done = false
    func isCompleted() -> Bool { done }
    func markCompleted() { done = true }
}
```

## 入力契約

### `UserDefaultsBackfillFlagStore.init`

| パラメータ | 型 | デフォルト | 制約 |
|---|---|---|---|
| `key` | `String` | `"auto_tag_backfill_v1_done"` | 空文字列禁止 (UserDefaults の key として無効) |
| `defaults` | `UserDefaults` | `.standard` | テスト時は `UserDefaults(suiteName: "com.knowledgetree.test")` で隔離可 |

### `isCompleted()`

戻り値: `Bool`
- production: `UserDefaults.standard.bool(forKey: key)` の結果
- 未設定 (1 度も markCompleted を呼んでいない) なら `false` (UserDefaults.bool のデフォルト)

### `markCompleted()`

副作用: `UserDefaults.standard.set(true, forKey: key)`
- 副作用は同期的、即座に永続化される (UserDefaults は internal で background flush)
- 例外を throw しない

## 実装サンプル (production)

```swift
final class UserDefaultsBackfillFlagStore: BackfillFlagStore {
    private let key: String
    private let defaults: UserDefaults

    init(
        key: String = "auto_tag_backfill_v1_done",
        defaults: UserDefaults = .standard
    ) {
        precondition(!key.isEmpty, "BackfillFlagStore key must not be empty")
        self.key = key
        self.defaults = defaults
    }

    func isCompleted() -> Bool {
        defaults.bool(forKey: key)
    }

    func markCompleted() {
        defaults.set(true, forKey: key)
    }
}
```

## 実装サンプル (test)

```swift
final class InMemoryBackfillFlagStore: BackfillFlagStore {
    private var done: Bool

    init(initial: Bool = false) {
        self.done = initial
    }

    func isCompleted() -> Bool { done }
    func markCompleted() { done = true }
}
```

## キー命名規則

将来の v2 backfill (例: 限度を 5 → 10 に変更、または新しい AI モデル導入で再評価) で再実行を発火させるため、キーは `_v1` 接尾辞付き。

| 想定キー | 用途 |
|---|---|
| `auto_tag_backfill_v1_done` | spec 013 の初回 backfill (本 spec) |
| `auto_tag_backfill_v2_done` | 将来 spec で v2 リリース時に追加 (例: limit 変更 / new entity threshold) |

新キーが false なら、その時点で再 backfill が実行される (= ユーザーは spec バージョンアップで「いい感じに整理し直された」を体験)。

## 副作用境界

- production の `UserDefaultsBackfillFlagStore` は `UserDefaults.standard` プロセス共有 (App Group ではない、main app のみ)
- test の `InMemoryBackfillFlagStore` は instance state のみ、プロセス global state を汚染しない
- thread safety: UserDefaults は internally thread-safe、本 spec では @MainActor 上での利用を想定

## Constitution 整合

Additional Constraints の「UserDefaults の非自明な用途禁止」例外:
- 「1 度だけ実行する migration / backfill フラグ」は UserDefaults の典型的な用法
- データ本体 (Article / Tag) は SwiftData に保存、フラグだけ UserDefaults

## 依存

- `Foundation` (UserDefaults, String)

## テスト

production / test 双方の実装を `AutoTagBackfillRunnerTests` 内で利用 (BackfillFlagStore 自体の単独 test は不要、シンプルすぎるため)。

将来 spec で UserDefaults の suite を切り替える場合のみ、`UserDefaultsBackfillFlagStore` 単体テストを追加する。

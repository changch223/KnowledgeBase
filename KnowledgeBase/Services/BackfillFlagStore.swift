//
//  BackfillFlagStore.swift
//  KnowledgeTree
//
//  spec 013 — backfill 完了状態の永続化を抽象化する protocol。
//  production: UserDefaults.standard、test: in-memory で副作用隔離。
//
//  contracts/backfill-flag-store.md 準拠。
//

import Foundation

/// backfill が既に完了したか / 完了マーク のみを扱う最小 protocol。
protocol BackfillFlagStore {
    func isCompleted() -> Bool
    func markCompleted()
}

/// production 用。UserDefaults.standard に Bool フラグを保存。
/// Constitution Additional Constraints の「UserDefaults の非自明な用途禁止」例外:
/// 「1 度だけ実行する migration / backfill フラグ」は典型的な使い方。
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

/// test 用。プロセス state を汚染しない in-memory 実装。
final class InMemoryBackfillFlagStore: BackfillFlagStore {
    private var done: Bool

    init(initial: Bool = false) {
        self.done = initial
    }

    func isCompleted() -> Bool { done }
    func markCompleted() { done = true }
}

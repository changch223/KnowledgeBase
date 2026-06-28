//
//  LastOpenedStore.swift
//  KnowledgeTree
//
//  spec 035 — 知識 Clip タブを最後に開いた時刻を UserDefaults に保存。
//  「最近のあなた」差分ダイジェストの差分起点として使う。
//

import Foundation

@MainActor
final class LastOpenedStore {

    private let defaults: UserDefaults
    private let key = "knowledgeClip.lastOpenedAt"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 最後に開いた時刻。未設定 (初回起動) は nil。
    var lastOpenedAt: Date? {
        get {
            let ti = defaults.double(forKey: key)
            return ti > 0 ? Date(timeIntervalSince1970: ti) : nil
        }
        set {
            if let v = newValue {
                defaults.set(v.timeIntervalSince1970, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }

    /// 現在時刻で更新。
    func touch(now: Date = .now) {
        lastOpenedAt = now
    }

    /// テスト用 reset。
    func reset() {
        defaults.removeObject(forKey: key)
    }
}

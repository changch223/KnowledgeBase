//
//  LintRunStore.swift
//  KnowledgeTree
//
//  最終 Lint 実行日時を UserDefaults に永続化する軽量ストア。
//  手動実行 (LintNowButton) と BGTask 両方から呼ぶ。
//

import Foundation

enum LintRunStore {
    private static let key = "lintLastRunDate"

    static var lastRunDate: Date? {
        get { UserDefaults.standard.object(forKey: key) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static func markRan() {
        lastRunDate = .now
    }

    /// 相対時刻文字列 (「3日前」「今日 03:00」など)。
    static func formattedLastRun() -> String? {
        guard let date = lastRunDate else { return nil }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .full
        rel.locale = Locale(identifier: "ja_JP")
        let relStr = rel.localizedString(for: date, relativeTo: .now)

        let time = DateFormatter()
        time.locale = Locale(identifier: "ja_JP")
        time.dateFormat = "M/d HH:mm"
        return "\(relStr)（\(time.string(from: date))）"
    }
}

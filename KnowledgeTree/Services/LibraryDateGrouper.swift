//
//  LibraryDateGrouper.swift
//  KnowledgeTree
//
//  spec 056 — ライブラリタブで Article を Apple Photos 風 日付別 group に分類する純粋関数 + enum。
//  Date 注入 (now: parameter) で deterministic test 可能。
//

import Foundation
import SwiftUI

enum LibraryDateGroup: String, CaseIterable, Identifiable, Hashable {
    case today
    case yesterday
    case thisWeek
    case thisMonth
    case earlier

    var id: String { rawValue }

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .today: return "library.dateGroup.today"
        case .yesterday: return "library.dateGroup.yesterday"
        case .thisWeek: return "library.dateGroup.thisWeek"
        case .thisMonth: return "library.dateGroup.thisMonth"
        case .earlier: return "library.dateGroup.earlier"
        }
    }
}

enum LibraryDateGrouper {
    /// Article 配列を日付別 group に分類して返す。
    /// 各 group 内は savedAt desc ソート、空 group は除外、ordered by group enum case 順。
    static func group(
        _ articles: [Article],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [(LibraryDateGroup, [Article])] {
        var groups: [LibraryDateGroup: [Article]] = [:]
        for article in articles {
            let group = classify(article.savedAt, now: now, calendar: calendar)
            groups[group, default: []].append(article)
        }
        return LibraryDateGroup.allCases.compactMap { group -> (LibraryDateGroup, [Article])? in
            guard let arts = groups[group], !arts.isEmpty else { return nil }
            let sorted = arts.sorted { $0.savedAt > $1.savedAt }
            return (group, sorted)
        }
    }

    /// 1 つの Date を date group に分類。
    static func classify(
        _ date: Date,
        now: Date,
        calendar: Calendar
    ) -> LibraryDateGroup {
        let todayStart = calendar.startOfDay(for: now)
        guard let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) else {
            return date >= todayStart ? .today : .earlier
        }

        // ISO 8601 月曜始まりで「今週月曜 0:00」を計算 (calendar.firstWeekday と独立)
        let weekday = calendar.component(.weekday, from: todayStart)
        // Sunday=1, Monday=2, ..., Saturday=7 (Gregorian standard)
        // 月曜起点で「monday からの経過日数」を算出: weekday=2 → 0, weekday=3 → 1, ..., weekday=1 (Sun) → 6
        let daysFromMonday = (weekday + 5) % 7
        let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: todayStart) ?? todayStart

        // 今月 1 日 0:00
        let monthStartComponents = calendar.dateComponents([.year, .month], from: now)
        let monthStart = calendar.date(from: monthStartComponents) ?? todayStart

        if date >= todayStart {
            return .today
        } else if date >= yesterdayStart {
            return .yesterday
        } else if date >= weekStart {
            return .thisWeek
        } else if date >= monthStart {
            return .thisMonth
        } else {
            return .earlier
        }
    }
}

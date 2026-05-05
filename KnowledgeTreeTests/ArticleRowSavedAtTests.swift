//
//  ArticleRowSavedAtTests.swift
//  KnowledgeTreeTests
//
//  spec 016 — SavedAtFormatter.format(_:now:) の純関数 5 ケース。
//  fixture 不要、Date(timeIntervalSince1970:) で時刻注入。
//

import Testing
import Foundation
@testable import KnowledgeTree

struct ArticleRowSavedAtTests {

    /// 今日 (同一日) → 「今日 HH:mm」
    @Test func testTodaySameDay() {
        let now = makeDate(year: 2026, month: 5, day: 5, hour: 18, minute: 0)
        let savedAt = makeDate(year: 2026, month: 5, day: 5, hour: 14, minute: 30)
        let result = SavedAtFormatter.format(savedAt, now: now)
        #expect(result == "今日 14:30")
    }

    /// 前日 (Calendar.isDateInYesterday) → 「昨日 HH:mm」
    @Test func testYesterday() {
        let now = makeDate(year: 2026, month: 5, day: 5, hour: 12, minute: 0)
        let savedAt = makeDate(year: 2026, month: 5, day: 4, hour: 9, minute: 15)
        let result = SavedAtFormatter.format(savedAt, now: now)
        #expect(result == "昨日 09:15")
    }

    /// 3 日前 → RelativeDateTimeFormatter.localizedString が日本語で返る
    @Test func testThreeDaysAgoUsesRelativeFormatter() {
        let now = makeDate(year: 2026, month: 5, day: 5, hour: 12, minute: 0)
        let savedAt = makeDate(year: 2026, month: 5, day: 2, hour: 12, minute: 0)
        let result = SavedAtFormatter.format(savedAt, now: now)
        // RelativeDateTimeFormatter ja_JP の正確な出力は OS バージョン依存だが、
        // 「今日」「昨日」「YYYY/MM/DD」のいずれでもないこと、何らかの非空文字列であることを検証
        #expect(!result.hasPrefix("今日"))
        #expect(!result.hasPrefix("昨日"))
        #expect(!result.contains("/"))
        #expect(!result.isEmpty)
    }

    /// 30 日前 → 絶対日付「YYYY/MM/DD」
    @Test func testThirtyDaysAgoUsesAbsoluteFormatter() {
        let now = makeDate(year: 2026, month: 5, day: 5, hour: 12, minute: 0)
        let savedAt = makeDate(year: 2026, month: 4, day: 5, hour: 12, minute: 0)
        let result = SavedAtFormatter.format(savedAt, now: now)
        #expect(result == "2026/04/05")
    }

    /// 1 年以上前 → 絶対日付
    @Test func testOneYearAgoUsesAbsoluteFormatter() {
        let now = makeDate(year: 2026, month: 5, day: 5, hour: 12, minute: 0)
        let savedAt = makeDate(year: 2025, month: 1, day: 15, hour: 10, minute: 0)
        let result = SavedAtFormatter.format(savedAt, now: now)
        #expect(result == "2025/01/15")
    }

    /// accessibilityText: ja_JP の絶対値で返る
    @Test func testAccessibilityText() {
        let savedAt = makeDate(year: 2026, month: 5, day: 5, hour: 14, minute: 30)
        let result = SavedAtFormatter.accessibilityText(savedAt)
        #expect(result.hasSuffix("保存"))
        #expect(result.contains("2026"))
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone.current
        return Calendar.current.date(from: components)!
    }
}

//
//  LearningCardsProvider.swift
//  iKnowWidget
//
//  spec 052 — Widget TimelineProvider。
//  15 分間隔で WidgetCardSnapshot.fetchTop() を呼び、上位 1-2 件の card を Timeline に流す。
//
//  Widget process は App Group SwiftData container 経由で main app の保存データを読むのみ。
//  AI / Foundation Models / Service 呼び出しは Widget extension の制限で避ける。
//

import WidgetKit
import SwiftUI

struct LearningCardsProvider: TimelineProvider {

    /// Reload 間隔 (15 分)。card surface は 15 分頻度で更新で十分 (calm UX、battery 節約)。
    private let reloadInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> LearningCardsEntry {
        LearningCardsEntry(
            date: .now,
            cards: [WidgetCardSnapshot.placeholder]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LearningCardsEntry) -> Void) {
        // Widget gallery 用 snapshot — 同期で placeholder か実データを返す
        let limit = limitForFamily(context.family)
        Task { @MainActor in
            let cards = WidgetCardSnapshot.fetchTop(limit: limit)
            completion(LearningCardsEntry(date: .now, cards: cards))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LearningCardsEntry>) -> Void) {
        let limit = limitForFamily(context.family)
        Task { @MainActor in
            let cards = WidgetCardSnapshot.fetchTop(limit: limit)
            let entry = LearningCardsEntry(date: .now, cards: cards)
            let nextUpdate = Date().addingTimeInterval(reloadInterval)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    /// family 別の表示件数。
    /// - accessoryRectangular / systemSmall: 1 件 (情報密度低)
    /// - systemMedium: 2 件 (情報密度中)
    private func limitForFamily(_ family: WidgetFamily) -> Int {
        switch family {
        case .systemMedium: return 2
        default:            return 1
        }
    }
}

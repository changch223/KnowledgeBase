//
//  iKnowWidget.swift
//  iKnowWidget
//
//  spec 052 — 学習カード Widget (LearningCardsWidget)。
//  Lockscreen (accessoryRectangular) + Homescreen (systemSmall / systemMedium) で
//  上位 1-2 件の UnderstandingCard を ambient 表示、tap で main app の DeepDiveChatView に遷移。
//
//  - StaticConfiguration (AppIntentConfiguration ではなく、設定 UI 不要)
//  - TimelineProvider 15 分間隔 reload
//  - WidgetCardSnapshot 経由で App Group SwiftData から SurfaceService 計算済データを読む
//  - AI 呼ばない (Widget extension process は Foundation Models 制限)
//  - defensive snapshot pattern (CloudKit / SwiftData invalidate 中の crash 予防)
//

import WidgetKit
import SwiftUI

// MARK: - Widget definition

struct iKnowWidget: Widget {
    let kind: String = "iKnowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LearningCardsProvider()) { entry in
            LearningCardsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("widget.today.title")
        .description("widget.description")
        .supportedFamilies([.accessoryRectangular, .systemSmall, .systemMedium])
    }
}

// MARK: - TimelineEntry

struct LearningCardsEntry: TimelineEntry {
    let date: Date
    let cards: [WidgetCardSnapshot]
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    iKnowWidget()
} timeline: {
    LearningCardsEntry(date: .now, cards: [.placeholder])
    LearningCardsEntry(date: .now, cards: [])
}

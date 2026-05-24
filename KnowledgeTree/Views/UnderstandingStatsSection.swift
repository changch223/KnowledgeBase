//
//  UnderstandingStatsSection.swift
//  KnowledgeTree
//
//  spec 044 P3 — AI ブレインタブに表示する軽量学習統計セクション。
//  - 「今月『わかった』N 件」
//  - 「最近深掘り N 概念」(過去 7 日の distinct ConceptPage 数)
//  - 両方 0 件で section ごと非表示 (calm UX、SC-010)
//

import SwiftUI
import SwiftData

struct UnderstandingStatsSection: View {
    @Query private var interactions: [UnderstandingInteraction]

    init() {
        // 過去 31 日分のみ fetch (本セクションで使う集計は当月 + 過去 7 日のみ)
        let cutoff = Calendar.current.date(byAdding: .day, value: -31, to: .now) ?? .now
        _interactions = Query(
            filter: #Predicate<UnderstandingInteraction> { $0.occurredAt >= cutoff }
        )
    }

    private var thisMonthUnderstoodCount: Int {
        let startOfMonth = Self.startOfMonth(for: .now)
        return interactions.filter {
            $0.action == UnderstandingInteraction.Action.understood.rawValue
                && $0.occurredAt >= startOfMonth
        }.count
    }

    private var recentDistinctDeepDiveConceptCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let recentOpened = interactions.filter {
            $0.action == UnderstandingInteraction.Action.openedChat.rawValue
                && $0.targetKind == UnderstandingInteraction.Kind.conceptPage.rawValue
                && $0.occurredAt >= cutoff
        }
        return Set(recentOpened.map(\.targetID)).count
    }

    var body: some View {
        let understoodCount = thisMonthUnderstoodCount
        let deepDiveCount = recentDistinctDeepDiveConceptCount

        if understoodCount == 0 && deepDiveCount == 0 {
            // calm UX: 0 件で section ごと非表示 (SC-010)
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("学習統計")
                    .font(DS.Typography.sectionTitle)
                if understoodCount > 0 {
                    Text("今月 \(understoodCount) 件「わかった」")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                if deepDiveCount > 0 {
                    Text("最近深掘り \(deepDiveCount) 概念")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCardBackground(radius: DS.Radius.card)
            .accessibilityIdentifier("aibrain.understanding_stats")
        }
    }

    private static func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }
}

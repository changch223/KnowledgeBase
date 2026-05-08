//
//  AIBrainStatsRow.swift
//  KnowledgeTree
//
//  AI ブレインタブ v2 — Section 1: 記事数・知識数・ファクト数の3列統計行。
//

import SwiftUI
import SwiftData

struct AIBrainStatsRow: View {
    @Query private var articles: [Article]
    @Query private var entities: [KnowledgeEntity]
    @Query private var keyFacts: [KeyFact]

    @State private var displayedArticleCount: Int = 0
    @State private var displayedEntityCount: Int = 0
    @State private var displayedFactCount: Int = 0

    private var uniqueEntityCount: Int {
        Set(entities.map { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }).count
    }

    var body: some View {
        HStack(spacing: 0) {
            statItem(value: displayedArticleCount, label: "aibrain.stats.articles")
            Divider().frame(height: 40)
            statItem(value: displayedEntityCount, label: "aibrain.stats.entities")
            Divider().frame(height: 40)
            statItem(value: displayedFactCount, label: "aibrain.stats.facts")
        }
        .padding(.vertical, DS.Spacing.xxl)
        .dsCardBackground(radius: DS.Radius.card)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("aibrain.stats_row")
        .accessibilityLabel(
            Text("記事 \(articles.count)、知識 \(uniqueEntityCount)、事実 \(keyFacts.count)")
        )
        .onAppear {
            withAnimation(DS.Animation.ifMotionAllowed(DS.Animation.counterAppear)) {
                displayedArticleCount = articles.count
                displayedEntityCount  = uniqueEntityCount
                displayedFactCount    = keyFacts.count
            }
        }
        .onChange(of: articles.count) { _, v in
            withAnimation(DS.Animation.ifMotionAllowed(DS.Animation.counterUpdate)) {
                displayedArticleCount = v
            }
        }
        .onChange(of: uniqueEntityCount) { _, v in
            withAnimation(DS.Animation.ifMotionAllowed(DS.Animation.counterUpdate)) {
                displayedEntityCount = v
            }
        }
        .onChange(of: keyFacts.count) { _, v in
            withAnimation(DS.Animation.ifMotionAllowed(DS.Animation.counterUpdate)) {
                displayedFactCount = v
            }
        }
    }

    @ViewBuilder
    private func statItem(value: Int, label: LocalizedStringKey) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Text("\(value)")
                .font(.title2.bold().monospacedDigit())
                .contentTransition(.numericText(countsDown: false))
            Text(label)
                .font(DS.Typography.chipLabel)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

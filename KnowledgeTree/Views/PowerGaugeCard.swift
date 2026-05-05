//
//  PowerGaugeCard.swift
//  KnowledgeTree
//
//  spec 011 — AI ブレインタブ Section 1: 蓄積量を一目で確認できる Power Gauge。
//  Phase 3 redesign: material + gradient layering, shadow pulse, mini-stats cluster.
//

import SwiftUI
import SwiftData

struct PowerGaugeCard: View {
    @Query private var articles: [Article]
    @Query private var entities: [KnowledgeEntity]
    @Query private var keyFacts: [KeyFact]

    @State private var animatedArticleCount: Int = 0
    @State private var animatedEntityCount: Int = 0
    @State private var animatedFactCount: Int = 0
    @State private var pulseShadowRadius: CGFloat = 8

    private var entityCount: Int {
        Set(entities.map {
            $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }).count
    }

    var body: some View {
        ZStack {
            // Base: system material for depth
            RoundedRectangle(cornerRadius: DS.Radius.hero, style: .continuous)
                .fill(.ultraThinMaterial)

            // AI brand gradient overlay
            RoundedRectangle(cornerRadius: DS.Radius.hero, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [DS.Color.aiBrandStart, DS.Color.aiBrandEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Specular highlight at top edge
            VStack {
                LinearGradient(
                    colors: [Color.white.opacity(0.12), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.hero, style: .continuous))

            // Content
            VStack(spacing: DS.Spacing.md) {
                Text("\(animatedArticleCount) 記事を吸収済")
                    .font(DS.Typography.heroCounter)
                    .contentTransition(.numericText(countsDown: false))
                    .foregroundStyle(.primary)

                // Mini-stats cluster (Apple Health card pattern)
                HStack(spacing: DS.Spacing.xxxl) {
                    VStack(spacing: DS.Spacing.xxs) {
                        Text("\(animatedEntityCount)")
                            .font(.title3.bold().monospacedDigit())
                            .contentTransition(.numericText(countsDown: false))
                        Text("知識")
                            .font(DS.Typography.heroSubtitle)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                        .frame(height: 28)

                    VStack(spacing: DS.Spacing.xxs) {
                        Text("\(animatedFactCount)")
                            .font(.title3.bold().monospacedDigit())
                            .contentTransition(.numericText(countsDown: false))
                        Text("キーファクト")
                            .font(DS.Typography.heroSubtitle)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Your AI is growing")
                    .font(DS.Typography.heroBrand)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.Spacing.xxxl)
            .padding(.vertical, DS.Spacing.xxl)
        }
        // Hairline border
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.hero, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        // Shadow pulse instead of scale jitter
        .shadow(color: DS.Color.aiBrandEnd.opacity(0.6), radius: pulseShadowRadius, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("aibrain.power_gauge")
        .accessibilityLabel(
            Text("AI パワー: \(articles.count) 記事、\(entityCount) 知識、\(keyFacts.count) キーファクト")
        )
        .onAppear {
            withAnimation(DS.Animation.ifMotionAllowed(DS.Animation.counterAppear)) {
                animatedArticleCount = articles.count
                animatedEntityCount  = entityCount
                animatedFactCount    = keyFacts.count
            }
            withAnimation(DS.Animation.ifMotionAllowed(DS.Animation.pulseLoop)) {
                pulseShadowRadius = 16
            }
        }
        .onChange(of: articles.count) { _, newValue in
            withAnimation(DS.Animation.ifMotionAllowed(DS.Animation.counterUpdate)) {
                animatedArticleCount = newValue
            }
        }
        .onChange(of: entityCount) { _, newValue in
            withAnimation(DS.Animation.ifMotionAllowed(DS.Animation.counterUpdate)) {
                animatedEntityCount = newValue
            }
        }
        .onChange(of: keyFacts.count) { _, newValue in
            withAnimation(DS.Animation.ifMotionAllowed(DS.Animation.counterUpdate)) {
                animatedFactCount = newValue
            }
        }
    }
}

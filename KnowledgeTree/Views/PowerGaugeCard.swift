//
//  PowerGaugeCard.swift
//  KnowledgeTree
//
//  spec 011 — AI ブレインタブ Section 1: 蓄積量を一目で確認できる Power Gauge。
//  contracts/power-gauge-card.md 準拠。
//
//  - Article 数 / KnowledgeEntity 重複排除数 / KeyFact 数を表示
//  - 起動時 0 → 実数 カウントアップアニメーション (~0.6 秒)
//  - 静かなパルスアニメーション (scale 1.0 ↔ 1.02 / 周期 2 秒)
//  - 「Your AI is growing」固定英文 (ブランド演出、spec.md 根拠あり)
//

import SwiftUI
import SwiftData

struct PowerGaugeCard: View {
    @Query private var articles: [Article]
    @Query private var entities: [KnowledgeEntity]
    @Query private var keyFacts: [KeyFact]

    @State private var animatedArticleCount: Int = 0
    @State private var pulseScale: CGFloat = 1.0

    private var entityCount: Int {
        Set(
            entities.map {
                $0.name
                    .lowercased()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        ).count
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.18), .purple.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(spacing: 8) {
                Text("\(animatedArticleCount) 記事を吸収済")
                    .font(.title.bold())
                    .contentTransition(.numericText())
                    .foregroundStyle(.primary)

                Text("\(entityCount) 知識  ·  \(keyFacts.count) キーファクト")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Your AI is growing")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .scaleEffect(pulseScale)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("aibrain.power_gauge")
        .accessibilityLabel(
            Text("AI パワー: \(articles.count) 記事、\(entityCount) 知識、\(keyFacts.count) キーファクト")
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animatedArticleCount = articles.count
            }
            withAnimation(
                .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.02
            }
        }
        .onChange(of: articles.count) { _, newValue in
            withAnimation(.easeOut(duration: 0.4)) {
                animatedArticleCount = newValue
            }
        }
    }
}

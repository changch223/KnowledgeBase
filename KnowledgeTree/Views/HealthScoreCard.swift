//
//  HealthScoreCard.swift
//  KnowledgeTree
//
//  spec 058 — Settings 上部に控えめに表示する健全性スコア card。
//  「整理対象 N 件」を 1 行で。0 件なら「整理対象はありません ✨」。
//

import SwiftUI

struct HealthScoreCard: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(RefreshTrigger.self) private var refreshTrigger

    @State private var score: HealthScore?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            if let score {
                if score.isHealthy {
                    Label("settings.health.healthy", systemImage: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                } else {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "wand.and.stars")
                            .foregroundStyle(.tint)
                        Text("settings.health.targetCount \(score.total)")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityIdentifier("settings.healthScoreCard")
        .task { recompute() }
        .onChange(of: refreshTrigger.version) { _, _ in recompute() }
    }

    private func recompute() {
        score = services.healthScoreService?.compute()
    }
}

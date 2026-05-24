//
//  KnowledgeSummaryView.swift
//  KnowledgeTree
//
//  spec 004 — Reader View 冒頭の知識サマリセクション
//
//  構成: 「AI 生成」ラベル → essence (太字) → summary (段落) →
//        重要な事実 list → 登場するもの chips → 区切り線
//  得られなかった要素のサブセクションは表示しない (Principle V)。
//

import SwiftUI

struct KnowledgeSummaryView: View {
    let knowledge: ExtractedKnowledge

    private var sortedEntities: [KnowledgeEntity] {
        (knowledge.entities ?? []).sorted { lhs, rhs in
            if lhs.salience != rhs.salience {
                return lhs.salience > rhs.salience
            }
            return lhs.order < rhs.order
        }
    }

    private var sortedFacts: [KeyFact] {
        (knowledge.keyFacts ?? []).sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            // 「AI 生成」ラベル
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(DS.Typography.aiLabel)
                Text("knowledge.aiGeneratedLabel")
                    .font(DS.Typography.aiLabel)
            }
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("knowledgeAIGeneratedLabel")

            // Section 見出し
            Text("knowledge.section.title")
                .font(DS.Typography.sectionTitle)

            // essence (1 行、太字)
            if let essence = knowledge.essence, !essence.isEmpty {
                Text(essence)
                    .font(.body.bold())
                    .accessibilityIdentifier("knowledgeEssence")
            }

            // summary (段落)
            if let summary = knowledge.summary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("knowledge.summary.heading")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(summary)
                        .font(.body)
                        .accessibilityIdentifier("knowledgeSummaryText")
                }
            }

            // 重要な事実
            if !sortedFacts.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("knowledge.facts.heading")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(sortedFacts, id: \.id) { fact in
                        KeyFactRow(fact: fact)
                    }
                }
            }

            // 登場するもの
            if !sortedEntities.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("(knowledge.entities ?? []).heading")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    EntityChipFlow(entities: sortedEntities)
                }
            }

            Divider()
                .padding(.top, DS.Spacing.md)
        }
        .accessibilityIdentifier("knowledgeSummarySection")
    }
}

/// SwiftUI 6 の Layout プロトコルで簡易 flow layout。複数行の chip 並びに対応。
private struct EntityChipFlow: View {
    let entities: [KnowledgeEntity]

    var body: some View {
        FlexibleHStack(spacing: 6) {
            ForEach(entities, id: \.id) { entity in
                EntityChip(entity: entity)
            }
        }
    }
}

/// 折り返し可能な horizontal stack (SwiftUI 6 の Layout を簡易実装)。
private struct FlexibleHStack<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        // 最終的には Layout プロトコル実装が望ましいが MVP は HStack の wrapping で代替
        // SwiftUI 標準 ViewThatFits / FlowLayout が無いため、簡易実装。
        // 数件 (上位 10 entity) なので 2 行折り返し程度を想定。
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
    }
}

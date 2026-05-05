//
//  RecentActivityCards.swift
//  KnowledgeTree
//
//  spec 011 Phase 6 / US3 — AI ブレインタブ Section 3。
//  Phase 3 redesign: Apple Health式アイコン背景、シャドウ、ヘアラインボーダー、固定サイズカード。
//

import SwiftUI
import SwiftData

struct RecentActivityCards: View {
    @Query private var allTags: [Tag]
    @Query private var allEntities: [KnowledgeEntity]

    private let sevenDaysAgo: Date

    init(now: Date = Date()) {
        self.sevenDaysAgo = now.addingTimeInterval(-7 * 86400)
    }

    private var snapshot: RecentActivitySnapshot {
        RecentActivitySnapshotBuilder.build(
            tags: allTags,
            entities: allEntities,
            sevenDaysAgo: sevenDaysAgo
        )
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.xl) {
                cardThisWeek(count: snapshot.articlesThisWeek)
                cardGrowingTags(snapshot.growingTags)
                cardNewConnections(snapshot.newConnections)
            }
            .padding(.horizontal, DS.Spacing.xxl)
        }
        .accessibilityIdentifier("aibrain.recent_activity")
    }

    // MARK: - Card A: 今週吸収数

    @ViewBuilder
    private func cardThisWeek(count: Int) -> some View {
        cardContainer {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                iconBadge(systemName: "tray.and.arrow.down.fill", color: .accentColor)
                if count > 0 {
                    Text("今週 \(count) 件 新たに吸収")
                        .font(.subheadline.weight(.medium))
                } else {
                    Text("今週はまだ吸収していません")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("aibrain.recent.card.this_week")
        .accessibilityLabel(Text("今週の吸収: \(count) 件"))
    }

    // MARK: - Card B: 育ったテーマ

    @ViewBuilder
    private func cardGrowingTags(_ tags: [RecentActivitySnapshot.GrowingTag]) -> some View {
        cardContainer {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                iconBadge(systemName: "leaf.fill", color: .green)
                Text("最近育ったテーマ")
                    .font(.subheadline.weight(.medium))
                if tags.isEmpty {
                    Text("まだありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        ForEach(tags, id: \.name) { tag in
                            Text("・\(tag.name)")
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("aibrain.recent.card.growing")
    }

    // MARK: - Card C: 新しい繋がり

    @ViewBuilder
    private func cardNewConnections(_ pairs: [RecentActivitySnapshot.Connection]) -> some View {
        cardContainer {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                iconBadge(systemName: "point.3.connected.trianglepath.dotted", color: .purple)
                Text("新しい繋がり")
                    .font(.subheadline.weight(.medium))
                if pairs.isEmpty {
                    Text("まだありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        ForEach(pairs, id: \.self) { pair in
                            Text("\(pair.first) ↔ \(pair.second)")
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("aibrain.recent.card.connections")
    }

    // MARK: - Shared icon badge (Apple Health style)

    @ViewBuilder
    private func iconBadge(systemName: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.12))
                .frame(width: 36, height: 36)
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    // MARK: - Card container

    @ViewBuilder
    private func cardContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(width: 180, height: 140, alignment: .topLeading)
            .padding(DS.Spacing.xl)
            .dsCardBackground(radius: DS.Radius.card)
            .shadow(color: Color.primary.opacity(0.06), radius: 8, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
    }
}

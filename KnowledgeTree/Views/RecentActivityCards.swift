//
//  RecentActivityCards.swift
//  KnowledgeTree
//
//  spec 011 Phase 6 / US3 — AI ブレインタブ Section 3。
//  直近 7 日のアクティビティを 3 枚カード横スクロール表示。
//
//  - カード A: 「今週 N 件 新たに吸収」(savedAt > 7 日前 の Article 件数)
//  - カード B: 「最近育ったテーマ」(直近 7 日でタグ別件数 desc Top3)
//  - カード C: 「新しい繋がり」(直近 7 日で初出現の KnowledgeEntity ペア)
//
//  contracts/recent-activity-cards.md 準拠。
//

import SwiftUI
import SwiftData

struct RecentActivityCards: View {
    @Query private var allTags: [Tag]
    @Query private var allEntities: [KnowledgeEntity]

    private let sevenDaysAgo: Date

    /// テスト時に時刻注入できるよう init に `now` を受ける。
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
            HStack(spacing: 12) {
                cardThisWeek(count: snapshot.articlesThisWeek)
                cardGrowingTags(snapshot.growingTags)
                cardNewConnections(snapshot.newConnections)
            }
            .padding(.horizontal)
        }
        .accessibilityIdentifier("aibrain.recent_activity")
    }

    // MARK: - Card A: 今週吸収数

    @ViewBuilder
    private func cardThisWeek(count: Int) -> some View {
        cardContainer {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
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
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                Text("最近育ったテーマ")
                    .font(.subheadline.weight(.medium))
                if tags.isEmpty {
                    Text("まだありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
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
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.title3)
                    .foregroundStyle(.purple)
                Text("新しい繋がり")
                    .font(.subheadline.weight(.medium))
                if pairs.isEmpty {
                    Text("まだありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
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

    // MARK: - Card container (共通カードシェル)

    @ViewBuilder
    private func cardContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(width: 200, alignment: .topLeading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
    }
}

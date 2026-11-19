//
//  ConceptShelfSection.swift
//  KnowledgeTree
//
//  spec 105 — 書架トピック (記事が多い広いトピック) のホーム表示。
//  1 枚のカードではなく「見出し行 + 子トピックのカード (最大 3 件) + すべて表示」で描く。
//

import SwiftUI

struct ConceptShelfSection: View {
    let entry: ConceptFeedEntry
    /// 子トピックのカードが画面に出たとき (既読化) に呼ぶ。
    var onSeen: (ConceptPage) -> Void = { _ in }
    /// 書架ページ自身の見出し行が画面に出たとき (既読化) に呼ぶ。
    var onShelfSeen: () -> Void = {}

    private static let maxChildren = 3
    private var page: ConceptPage { entry.page }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            NavigationLink(value: ConceptPageDetailDestination(id: page.id)) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    Text(page.name)
                        .font(.title2)
                        .fontDesign(.serif)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Color.sumiInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if page.isFollowing {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(DS.Color.sumiLight)
                            .accessibilityHidden(true)
                    }
                    Text(String(format: String(localized: "shelf.childCount %lld"), entry.children.count))
                        .font(.caption)
                        .foregroundStyle(DS.Color.sumiLight)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DS.Color.sumiLight)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, DS.Spacing.xxl)
            }
            .buttonStyle(.plain)
            .onAppear { onShelfSeen() }
            .accessibilityIdentifier("conceptShelfHeader_\(page.id.uuidString)")

            ForEach(entry.children.prefix(Self.maxChildren), id: \.id) { child in
                ConceptSummaryCard(
                    entry: ConceptFeedEntry(
                        page: child,
                        children: [],
                        articleCount: (child.relatedArticles ?? []).count
                    ),
                    onSeen: { onSeen(child) }
                )
            }

            if entry.children.count > Self.maxChildren {
                NavigationLink(value: ConceptPageDetailDestination(id: page.id)) {
                    HStack {
                        Text(String(format: String(localized: "concept.insights.showAll %lld"), entry.children.count))
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.sumiMid)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DS.Color.sumiLight)
                    }
                    .padding(.horizontal, DS.Spacing.xxl)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

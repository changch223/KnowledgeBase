//
//  FollowingPeopleSection.swift
//  KnowledgeTree
//
//  spec 056 + spec 058 polish — 知識 Clip タブ「コンセプト」セクション。
//  全 ConceptPage を「お気に入り優先 + 関連記事数多い順」で表示。
//  Q1 ConceptPage 直接アクセスを実現 (知識 Clip → コンセプト card → 詳細画面)。
//

import SwiftUI
import SwiftData

struct FollowingPeopleSection: View {
    // spec 063 (LLM Wiki): 非表示ページ (isHidden) は除外。
    @Query(
        filter: #Predicate<ConceptPage> { !$0.isHidden },
        sort: [SortDescriptor(\ConceptPage.updatedAt, order: .reverse)]
    )
    private var allPages: [ConceptPage]

    /// お気に入り優先 + 関連記事数多い順、上位 5 件
    private var topPages: [ConceptPage] {
        let sorted = allPages.sorted { lhs, rhs in
            if lhs.isFollowing != rhs.isFollowing {
                return lhs.isFollowing  // お気に入り優先
            }
            let lhsCount = (lhs.relatedArticles ?? []).count
            let rhsCount = (rhs.relatedArticles ?? []).count
            if lhsCount != rhsCount {
                return lhsCount > rhsCount  // 関連記事多い順
            }
            return lhs.updatedAt > rhs.updatedAt  // 同数なら updatedAt desc
        }
        return Array(sorted.prefix(5))
    }

    private var totalCount: Int { allPages.count }

    var body: some View {
        if topPages.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Text("knowledgeClip.section.following")
                        .font(.headline)
                    Spacer()
                    if totalCount > 5 {
                        NavigationLink(value: ConceptPageListDestination()) {
                            Text("knowledgeClip.moreLink")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)

                LazyVStack(spacing: DS.Spacing.md) {
                    ForEach(topPages) { page in
                        NavigationLink(value: ConceptPageDetailDestination(id: page.id)) {
                            FollowingConceptPageRow(page: page)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("following.card.\(page.id.uuidString)")
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)
            }
            .accessibilityIdentifier("section.following")
        }
    }
}

// spec 058: ActionItemBadgeData 削除 (⚠️ badge 廃止に伴い)

private struct FollowingConceptPageRow: View {
    let page: ConceptPage

    private var relatedArticleCount: Int {
        (page.relatedArticles ?? []).count
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.xs) {
                    if page.isFollowing {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    Text(page.name)
                        .font(.headline)
                        .lineLimit(1)
                }

                HStack(spacing: DS.Spacing.sm) {
                    UnderstandingDotsIndicator(value: page.userUnderstanding)
                    Text("following.relatedArticles \(relatedArticleCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if page.isStale {
                    Text("following.staleHint")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(DS.Spacing.lg)
        .background(DS.Color.surfaceSecondary, in: .rect(cornerRadius: DS.Radius.chip))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.chip)
                .stroke(DS.Color.aiBrandEdge.opacity(0.3), lineWidth: 0.5)
        )
    }
}

private struct UnderstandingDotsIndicator: View {
    let value: Int  // 0-5

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i < value ? Color.accentColor : DS.Color.aiBrandEdge.opacity(0.5))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

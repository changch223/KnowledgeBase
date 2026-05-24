//
//  FollowingPeopleSection.swift
//  KnowledgeTree
//
//  spec 056 — 知識 Clip タブ 3 番目セクション「追っている人物・モノ」(Following)。
//  - isFollowing == true な ConceptPage 上位 5 件 (updatedAt desc)
//  - サブヘッダ位置に「⚠️ 更新が必要 (N)」badge (件数 0 で非表示)
//    旧 FactConflictsSection + StaleSavedAnswersSection を統合
//

import SwiftUI
import SwiftData

struct FollowingPeopleSection: View {
    @Query(
        filter: #Predicate<ConceptPage> { $0.isFollowing == true },
        sort: [SortDescriptor(\ConceptPage.updatedAt, order: .reverse)]
    )
    private var followingPages: [ConceptPage]

    @Query(
        filter: #Predicate<ConflictProposal> { $0.status == "pending" }
    )
    private var pendingConflicts: [ConflictProposal]

    @Query(
        filter: #Predicate<SavedAnswer> { $0.isStale == true }
    )
    private var staleAnswers: [SavedAnswer]

    private var topPages: [ConceptPage] {
        Array(followingPages.prefix(5))
    }

    private var totalCount: Int { followingPages.count }

    private var badgeData: ActionItemBadgeData {
        ActionItemBadgeData(
            conflictCount: pendingConflicts.count,
            staleSavedAnswerCount: staleAnswers.count
        )
    }

    var body: some View {
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

            // ⚠️ 更新が必要 badge
            if badgeData.shouldShow {
                NavigationLink(value: ActionItemsReviewDestination()) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("knowledgeClip.actionItems.needsUpdate \(badgeData.total)")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(DS.Spacing.md)
                    .background(Color.orange.opacity(0.1), in: .rect(cornerRadius: DS.Radius.chip))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DS.Spacing.xxl)
                .accessibilityIdentifier("following.actionItemsBadge")
            }

            if topPages.isEmpty {
                ContentUnavailableView(
                    "knowledgeClip.empty.following",
                    systemImage: "star",
                    description: Text("knowledgeClip.empty.following.body")
                )
                .padding(.vertical, DS.Spacing.xxl)
            } else {
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
        }
        .accessibilityIdentifier("section.following")
    }
}

/// ⚠️ 更新が必要 badge の表示判定 + 件数。
struct ActionItemBadgeData {
    let conflictCount: Int
    let staleSavedAnswerCount: Int

    var total: Int { conflictCount + staleSavedAnswerCount }
    var shouldShow: Bool { total > 0 }
}

private struct FollowingConceptPageRow: View {
    let page: ConceptPage

    private var relatedArticleCount: Int {
        (page.relatedArticles ?? []).count
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(page.name)
                    .font(.headline)
                    .lineLimit(1)

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

//
//  TagListView.swift
//  KnowledgeTree
//
//  spec 008 — 全 Tag の一覧画面。各 row タップで TagFilteredListView へ遷移。
//

import SwiftUI
import SwiftData

struct TagListView: View {
    @Query private var tags: [Tag]

    /// spec 058 polish: 記事数多い順 desc + tiebreak で名前昇順。
    private var sortedTags: [Tag] {
        tags.sorted { lhs, rhs in
            let lhsCount = (lhs.articles ?? []).count
            let rhsCount = (rhs.articles ?? []).count
            if lhsCount != rhsCount {
                return lhsCount > rhsCount
            }
            return lhs.name < rhs.name
        }
    }

    var body: some View {
        Group {
            if sortedTags.isEmpty {
                ContentUnavailableView(
                    "tag.list.empty.title",
                    systemImage: "tag"
                )
            } else {
                List(sortedTags) { tag in
                    NavigationLink(value: TagFilteredDestination(tagName: tag.name)) {
                        HStack {
                            Image(systemName: "tag")
                                .foregroundStyle(.secondary)
                            Text(tag.name)
                                .font(.body)
                            Spacer()
                            Text("\((tag.articles ?? []).count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("tagListRow-\(tag.name)")
                }
            }
        }
        .navigationTitle("tag.list.title")
    }
}

//
//  TagListView.swift
//  KnowledgeTree
//
//  spec 008 — 全 Tag の一覧画面。各 row タップで TagFilteredListView へ遷移。
//

import SwiftUI
import SwiftData

struct TagListView: View {
    @Query(sort: \Tag.name, order: .forward) private var tags: [Tag]

    var body: some View {
        Group {
            if tags.isEmpty {
                ContentUnavailableView(
                    "tag.list.empty.title",
                    systemImage: "tag"
                )
            } else {
                List(tags) { tag in
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

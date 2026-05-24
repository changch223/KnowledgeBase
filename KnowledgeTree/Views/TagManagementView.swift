//
//  TagManagementView.swift
//  KnowledgeTree
//
//  spec 024 — タグ管理画面。
//  全 Tag を article 数降順で List 表示、tap で TagEditSheet。
//  検索 (TagNormalizer 不要、表示名そのまま contain match)。
//

import SwiftUI
import SwiftData

struct TagManagementView: View {
    @Query private var allTags: [Tag]
    @State private var selectedTag: Tag?
    @State private var searchQuery: String = ""

    private var filteredTags: [Tag] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let candidates = allTags
        let matched = trimmed.isEmpty
            ? candidates
            : candidates.filter { $0.name.lowercased().contains(trimmed) }
        // article count desc、同数なら name asc
        return matched.sorted { lhs, rhs in
            if (lhs.articles ?? []).count != (rhs.articles ?? []).count {
                return (lhs.articles ?? []).count > (rhs.articles ?? []).count
            }
            return lhs.name < rhs.name
        }
    }

    var body: some View {
        Group {
            if allTags.isEmpty {
                ContentUnavailableView(
                    "tag.management.empty",
                    systemImage: "tag.slash"
                )
            } else {
                List {
                    Section {
                        ForEach(filteredTags) { tag in
                            Button {
                                selectedTag = tag
                            } label: {
                                TagRow(tag: tag)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("tag.management.row")
                        }
                    } header: {
                        Text("tag.management.hint")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
                .searchable(text: $searchQuery, prompt: Text("tag.management.searchPlaceholder"))
            }
        }
        .navigationTitle("tag.management.title")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedTag) { tag in
            TagEditSheet(tag: tag, onCompletion: {
                selectedTag = nil
            })
        }
        .accessibilityIdentifier("tag.management.root")
    }
}

private struct TagRow: View {
    let tag: Tag

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                if let category = tag.categoryRaw, !category.isEmpty {
                    Text(category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("tag.management.row.articleCount \((tag.articles ?? []).count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

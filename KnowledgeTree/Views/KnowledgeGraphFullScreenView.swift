//
//  KnowledgeGraphFullScreenView.swift
//  KnowledgeTree
//
//  spec 056 — AI チャットタブ toolbar 📊 アイコン tap から push される、
//  全 Category の Knowledge Graph 可視化画面。AI ブレインタブ root 削除の代替動線。
//

import SwiftUI
import SwiftData

/// AI チャットタブ toolbar 📊 アイコンから push される Hashable destination。
struct KnowledgeGraphFullScreenDestination: Hashable {}

struct KnowledgeGraphFullScreenView: View {
    @Query(sort: [SortDescriptor(\GraphNode.salience, order: .reverse)])
    private var allNodes: [GraphNode]

    private var allCategories: [String] {
        Set(allNodes.map { $0.categoryRaw }.filter { !$0.isEmpty }).sorted()
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.xxl) {
                if allCategories.isEmpty {
                    ContentUnavailableView(
                        "knowledgeGraph.empty.title",
                        systemImage: "chart.dots.scatter",
                        description: Text("knowledgeGraph.empty.body")
                    )
                    .padding(.vertical, DS.Spacing.xxxl)
                } else {
                    ForEach(allCategories, id: \.self) { category in
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            Text(category)
                                .font(.headline)
                                .padding(.horizontal, DS.Spacing.xxl)
                            CategoryGraphView(categoryRaw: category)
                                .frame(height: 300)
                                .padding(.horizontal, DS.Spacing.xxl)
                        }
                    }
                }
            }
            .padding(.vertical, DS.Spacing.xxl)
        }
        .navigationTitle("knowledgeGraph.fullScreen.title")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("view.knowledgeGraphFullScreen")
    }
}

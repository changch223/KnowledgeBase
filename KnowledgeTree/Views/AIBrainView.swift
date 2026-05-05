//
//  AIBrainView.swift
//  KnowledgeTree
//
//  spec 011 — AI ブレインタブの root view。
//  contracts/ai-brain-view.md 準拠。
//
//  - NavigationStack 内の縦 ScrollView に 3 セクション (Power / Map / Recent) を配置
//  - MVP では Section 1 (PowerGaugeCard) のみ実装済
//  - Section 2 (KnowledgeMapView) と Section 3 (RecentActivityCards) は spec 011
//    Phase 5 / Phase 6 で順次追加
//  - navigationDestination は spec 008 既存の TagFilteredDestination 型を再利用
//

import SwiftUI
import SwiftData

struct AIBrainView: View {
    @Environment(ProcessingMonitor.self) private var monitor

    @Query private var allTags: [Tag]

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        PowerGaugeCard()
                            .frame(height: 160)
                            .padding(.horizontal)

                        KnowledgeMapView(tags: allTags)
                            .frame(minHeight: 320)
                            .padding(.horizontal)

                        RecentActivityCards()
                            .frame(height: 140)
                    }
                    .padding(.vertical, 16)
                }
                .accessibilityIdentifier("aibrain.scroll")
                .navigationTitle("aibrain.tab.title")
                .navigationDestination(for: TagFilteredDestination.self) { dest in
                    TagFilteredListView(tagName: dest.tagName)
                }
                .navigationDestination(for: EntityFilteredDestination.self) { dest in
                    EntityFilteredListView(entityName: dest.entityName)
                }

                BottomStatusBar(monitor: monitor)
                    .animation(.easeInOut(duration: 0.2), value: monitor.totalActiveCount)
                    .animation(.easeInOut(duration: 0.2), value: monitor.current?.id)
            }
        }
        .accessibilityIdentifier("aibrain.root")
    }
}

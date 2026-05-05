//
//  AIBrainView.swift
//  KnowledgeTree
//
//  spec 011 — AI ブレインタブの root view。
//  Phase 3 redesign: large title, scroll indicator hidden, full-bleed gradient background.
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
                    ZStack(alignment: .top) {
                        // Full-bleed AI brand gradient at top (Apple Weather style)
                        LinearGradient(
                            colors: [DS.Color.aiBrandStart.opacity(0.6), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 300)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                        VStack(spacing: DS.Spacing.xl) {
                            PowerGaugeCard()
                                .frame(height: 180)
                                .padding(.horizontal, DS.Spacing.xxl)

                            KnowledgeMapView(tags: allTags)
                                .frame(minHeight: 320)
                                .padding(.horizontal, DS.Spacing.xxl)

                            RecentActivityCards()
                                .frame(height: 160)
                        }
                        .padding(.vertical, DS.Spacing.xxl)
                    }
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("aibrain.scroll")
                .navigationTitle("aibrain.tab.title")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: TagFilteredDestination.self) { dest in
                    TagFilteredListView(tagName: dest.tagName)
                }
                .navigationDestination(for: EntityFilteredDestination.self) { dest in
                    EntityFilteredListView(entityName: dest.entityName)
                }

                BottomStatusBar(monitor: monitor)
                    .animation(DS.Animation.statusBar, value: monitor.totalActiveCount)
                    .animation(DS.Animation.statusBar, value: monitor.current?.id)
            }
        }
        .accessibilityIdentifier("aibrain.root")
    }
}

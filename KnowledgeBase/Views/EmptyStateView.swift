//
//  EmptyStateView.swift
//  KnowledgeTree
//
//  spec 001 / FR-013 / Principle V
//  Phase 4: entrance animation + subtle bob + Share Sheet instruction text
//

import SwiftUI

struct EmptyStateView: View {
    @State private var appeared: Bool = false
    @State private var isBobbing: Bool = false

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .scaleEffect(appeared ? 1.0 + (isBobbing ? 0.03 : 0) : 0.8)

            VStack(spacing: DS.Spacing.sm) {
                Text("list.empty.title")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("list.empty.instruction")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("articleListEmpty")
        .onAppear {
            withAnimation(DS.Animation.ifMotionAllowed(DS.Animation.nodeAppear)) {
                appeared = true
            }
            withAnimation(DS.Animation.ifMotionAllowed(DS.Animation.pulseLoop)) {
                isBobbing = true
            }
        }
    }
}

#Preview {
    EmptyStateView()
}

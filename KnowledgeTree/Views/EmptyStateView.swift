//
//  EmptyStateView.swift
//  KnowledgeTree
//
//  spec 001 / FR-013 / Principle V (シンプルで落ち着いた UX)
//

import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("list.empty.title")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("articleListEmpty")
    }
}

#Preview {
    EmptyStateView()
}

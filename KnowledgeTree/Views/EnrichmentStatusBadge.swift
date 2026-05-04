//
//  EnrichmentStatusBadge.swift
//  KnowledgeTree
//
//  spec 002 — 取得中 / 未取得 / 取得失敗 のインジケータ
//

import SwiftUI

struct EnrichmentStatusBadge: View {
    let status: EnrichmentStatus

    var body: some View {
        switch status {
        case .pending, .fetching:
            badge(systemName: "arrow.triangle.2.circlepath",
                  label: "enrichment.statusFetching",
                  identifier: "articleEnrichmentStatusFetching")
        case .failed:
            badge(systemName: "cloud.slash",
                  label: "enrichment.statusUnfetched",
                  identifier: "articleEnrichmentStatusUnfetched")
        case .permanentlyFailed:
            badge(systemName: "exclamationmark.triangle",
                  label: "enrichment.statusFailed",
                  identifier: "articleEnrichmentStatusFailed")
        case .succeeded:
            EmptyView()
        }
    }

    private func badge(systemName: String, label: LocalizedStringKey, identifier: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier)
    }
}

#Preview {
    VStack(spacing: 12) {
        EnrichmentStatusBadge(status: .pending)
        EnrichmentStatusBadge(status: .fetching)
        EnrichmentStatusBadge(status: .failed)
        EnrichmentStatusBadge(status: .permanentlyFailed)
        EnrichmentStatusBadge(status: .succeeded)
    }
    .padding()
}

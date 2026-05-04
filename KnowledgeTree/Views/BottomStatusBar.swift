//
//  BottomStatusBar.swift
//  KnowledgeTree
//
//  spec 005 — 一覧画面下部に固定表示するバックグラウンド処理インジケータ。
//  ProcessingMonitor を観察し、現在処理中の記事 + フェーズ + 残件数を表示。
//  isIdle のときは非表示 (Principle V: calm UX)。
//

import SwiftUI

struct BottomStatusBar: View {
    let monitor: ProcessingMonitor

    var body: some View {
        if let current = monitor.current {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                    .tint(phaseTintColor(current.phase))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(phaseLabel(current.phase))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        // spec 006: chunked summarization 等の N/M 進捗
                        if let index = current.progressIndex,
                           let total = current.progressTotal {
                            Text("\(index)/\(total)")
                                .font(.caption2.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(current.articleTitle)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if monitor.totalActiveCount > 1 {
                    Text("+\(monitor.totalActiveCount - 1)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.tertiary, in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.thinMaterial)
            .overlay(alignment: .top) {
                Divider()
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityIdentifier("bottomStatusBar")
            .accessibilityElement(children: .combine)
        }
    }

    private func phaseLabel(_ phase: ProcessingMonitor.Phase) -> LocalizedStringKey {
        switch phase {
        case .enrichment: return "status.phase.enrichment"
        case .body:       return "status.phase.body"
        case .knowledge:  return "status.phase.knowledge"
        }
    }

    private func phaseTintColor(_ phase: ProcessingMonitor.Phase) -> Color {
        switch phase {
        case .enrichment: return .secondary
        case .body:       return .blue
        case .knowledge:  return .purple
        }
    }
}

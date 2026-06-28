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
            HStack(spacing: DS.Spacing.lg) {
                ProgressView()
                    .controlSize(.small)
                    .tint(phaseTintColor(current.phase))

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.sm) {
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
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(.tertiary, in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.vertical, DS.Spacing.lg)
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
        case .enrichment:          return "status.phase.enrichment"
        case .body:                return "status.phase.body"
        case .knowledge:           return "status.phase.knowledge"
        case .tagBackfilling:      return "status.phase.tagBackfilling"
        case .categoryClassifying: return "status.phase.categoryClassifying"
        }
    }

    /// spec 015: 全 phase で単一 actionBlue を返す (Apple single-accent rule、DESIGN.md 準拠)。
    /// phase 識別は phaseLabel のテキストのみで担保。
    private func phaseTintColor(_ phase: ProcessingMonitor.Phase) -> Color {
        DS.Color.actionBlue
    }
}

//
//  ProcessingInlineStatus.swift
//  KnowledgeTree
//
//  spec 103 — 処理中表示を 1 行に。旧 BottomStatusBar (画面下部の重なり) を置き換える。
//  ProcessingMonitor.totalActiveCount > 0 のときだけ「N 件を整理中」を表示 (calm UX)。
//  フェーズ名・記事名・N/M は出さない。
//

import SwiftUI

struct ProcessingInlineStatus: View {
    let monitor: ProcessingMonitor

    var body: some View {
        if monitor.totalActiveCount > 0 {
            HStack(spacing: DS.Spacing.sm) {
                SumiKnowledgeSpinnerSmall()
                Text("status.inline.organizing \(monitor.totalActiveCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.vertical, DS.Spacing.sm)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("processingInlineStatus")
        }
    }
}

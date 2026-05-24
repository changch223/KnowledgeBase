//
//  StaleSavedAnswersSection.swift
//  KnowledgeTree
//
//  spec 046 — 知識 Clip タブの「確認が必要な答え」セクション。
//
//  spec 037 FactConflictsSection と同パターン。
//  spec 045 で導入した isStale UI 表示を知識 Clip タブで主動線化する。
//
//  - @Query で isStale=true な SavedAnswer を fetch (updatedAt desc)
//  - 0 件で完全非表示 (calm UX、FactConflictsSection と同)
//  - 上位 5 件表示、6+ 件で「+N すべて見る」リンク
//  - 各行は SavedAnswerRow (spec 045 で stale chip 表示済) + NavigationLink → SavedAnswerDetailView
//

import SwiftUI
import SwiftData

struct StaleSavedAnswersSection: View {

    @Query(
        filter: #Predicate<SavedAnswer> { $0.isStale == true },
        sort: [SortDescriptor(\SavedAnswer.updatedAt, order: .reverse)]
    )
    private var staleAnswers: [SavedAnswer]

    /// 上位表示する最大件数。
    private let topLimit: Int = 5

    var body: some View {
        if staleAnswers.isEmpty {
            EmptyView()
        } else {
            sectionBody
        }
    }

    private var sectionBody: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            header
            let top = Array(staleAnswers.prefix(topLimit))
            ForEach(top, id: \.id) { answer in
                NavigationLink(value: SavedAnswerDetailDestination(id: answer.id)) {
                    SavedAnswerRow(answer: answer)
                }
                .buttonStyle(.plain)
                Divider()
            }
            if staleAnswers.count > top.count {
                NavigationLink(value: SavedAnswerHistoryDestination()) {
                    HStack {
                        Spacer()
                        Text(String(format: String(localized: "+%lld すべて見る"), staleAnswers.count - top.count))
                            .font(.callout)
                            .foregroundStyle(DS.Color.actionBlue)
                        Spacer()
                    }
                    .padding(.vertical, DS.Spacing.md)
                }
                .accessibilityIdentifier("clip.staleAnswers.allLink")
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .accessibilityIdentifier("clip.staleAnswers.section")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.orange)
                Text(String(format: String(localized: "確認が必要な答え (%lld)"), staleAnswers.count))
                    .font(DS.Typography.sectionTitle)
                    .foregroundStyle(.primary)
            }
            Text("関連する新しい記事が保存されたため、これらの答えは古くなっている可能性があります。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

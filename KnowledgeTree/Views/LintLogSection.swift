//
//  LintLogSection.swift
//  KnowledgeTree
//
//  spec 058 — Settings 内の「整理ログ (直近 30 件)」section。
//  Lint loop の各操作 (merge / delete / link / reclassify / refresh) を日時 desc で表示。
//

import SwiftUI
import SwiftData

struct LintLogSection: View {
    @Query(
        sort: [SortDescriptor(\LintLog.timestamp, order: .reverse)]
    )
    private var allLogs: [LintLog]

    private var topLogs: [LintLog] {
        Array(allLogs.prefix(30))
    }

    var body: some View {
        Section {
            if topLogs.isEmpty {
                ContentUnavailableView(
                    "settings.lintLog.empty.title",
                    systemImage: "tray",
                    description: Text("settings.lintLog.empty.body")
                )
            } else {
                ForEach(topLogs) { log in
                    LintLogRow(log: log)
                }
            }
        } header: {
            Text("settings.lintLog.section.title")
        }
        .accessibilityIdentifier("settings.lintLogSection")
    }
}

private struct LintLogRow: View {
    let log: LintLog

    private var actionLocalizedTitle: LocalizedStringKey {
        switch log.action {
        case .merge:                return "lintLog.action.merge"
        case .deleteConceptPage:    return "lintLog.action.deleteConceptPage"
        case .deleteTag:            return "lintLog.action.deleteTag"
        case .linkConceptPage:      return "lintLog.action.linkConceptPage"
        case .reclassifyTag:        return "lintLog.action.reclassifyTag"
        case .refreshSavedAnswer:   return "lintLog.action.refreshSavedAnswer"
        case .unknown:              return "lintLog.action.unknown"
        }
    }

    private var actionIcon: String {
        switch log.action {
        case .merge:                return "arrow.triangle.merge"
        case .deleteConceptPage,
             .deleteTag:            return "trash"
        case .linkConceptPage:      return "link"
        case .reclassifyTag:        return "tag.fill"
        case .refreshSavedAnswer:   return "arrow.clockwise"
        case .unknown:              return "questionmark.circle"
        }
    }

    private var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.localizedString(for: log.timestamp, relativeTo: .now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: actionIcon)
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .frame(width: 20)
                Text(actionLocalizedTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(relativeTimestamp)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(log.targetName)
                .font(.subheadline)
                .lineLimit(2)
                .padding(.leading, 28)
        }
        .padding(.vertical, 2)
    }
}

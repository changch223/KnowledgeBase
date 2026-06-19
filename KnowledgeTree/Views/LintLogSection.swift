//
//  LintLogSection.swift
//  KnowledgeTree
//
//  spec 058 — 整理ログ。Lint loop の各操作 (merge / delete / link / reclassify / refresh) を日時 desc で表示。
//  spec 087: Settings 直下の Section から、タップで開く詳細画面 (LintLogDetailView) に移動。
//           分野再分類は「xxx → xxx」で変更前後の分野を併記。
//

import SwiftUI
import SwiftData

/// spec 087: 設定の「整理ログ」NavigationLink から push される一覧画面。
struct LintLogDetailView: View {
    @Query(
        sort: [SortDescriptor(\LintLog.timestamp, order: .reverse)]
    )
    private var allLogs: [LintLog]

    private var topLogs: [LintLog] {
        Array(allLogs.prefix(50))
    }

    var body: some View {
        List {
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
        }
        .navigationTitle("settings.lintLog.section.title")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.lintLogDetail")
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
        case .promoteCategory:      return "lintLog.action.promoteCategory"
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
        case .promoteCategory:      return "sparkles"
        case .unknown:              return "questionmark.circle"
        }
    }

    /// spec 087: 分野再分類のとき「(変更前) → (変更後)」。空/未分類は「未分類」表記。
    private var reclassifyTransition: String? {
        guard log.action == .reclassifyTag else { return nil }
        let rawBefore = (log.beforeState ?? "").trimmingCharacters(in: .whitespaces)
        let to = (log.afterState ?? "").trimmingCharacters(in: .whitespaces)
        guard !to.isEmpty else { return nil }
        let from = (rawBefore.isEmpty || rawBefore == "(none)")
            ? String(localized: "lintLog.uncategorized")
            : rawBefore
        return "\(from) → \(to)"
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
                // spec 087: 分野再分類の横に「xxx → xxx」を同じフォントサイズで併記。
                if let transition = reclassifyTransition {
                    Text(transition)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
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

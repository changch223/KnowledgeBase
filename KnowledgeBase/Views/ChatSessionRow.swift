//
//  ChatSessionRow.swift
//  KnowledgeTree
//
//  spec 033 — 履歴サイドバー内の 1 セッション row。
//  title (最初の user message 先頭 30 字 or 「新しいチャット」) + 最終 message プレビュー +
//  相対時刻 (たった今 / N 分前 / N 時間前 / 昨日 / N 日前)。
//  アクティブ状態の row は actionBlue でハイライト。
//

import SwiftUI

struct ChatSessionRow: View {
    let session: ChatSession
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: DS.Spacing.sm) {
                if session.mode == .deepDive {
                    Image(systemName: "book.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .accessibilityLabel(Text("chat.sidebar.badge.deepDive"))
                }
                Text(displayTitle)
                    .font(.body)
                    .foregroundStyle(isActive ? DS.Color.actionBlue : .primary)
                    .lineLimit(1)
                Spacer()
                Text(relativeTimeKey)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let preview = lastMessagePreview, !preview.isEmpty {
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("chat.sidebar.row")
    }

    // MARK: - Helpers

    private var displayTitle: String {
        let trimmed = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? NSLocalizedString("chat.sidebar.untitled", comment: "") : trimmed
    }

    private var lastMessagePreview: String? {
        let sorted = (session.messages ?? []).sorted { $0.timestamp > $1.timestamp }
        guard let last = sorted.first else { return nil }
        let text = last.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.count > 60 ? String(text.prefix(60)) + "…" : text
    }

    private var relativeTimeKey: LocalizedStringKey {
        let date = session.lastMessageAt
        let secondsAgo = Date.now.timeIntervalSince(date)
        let minutesAgo = Int(secondsAgo / 60)
        let hoursAgo = Int(secondsAgo / 3600)

        if secondsAgo < 60 {
            return "chat.relativeTime.now"
        }
        if minutesAgo < 60 {
            return "chat.relativeTime.minutes \(minutesAgo)"
        }
        if Calendar.current.isDateInToday(date) {
            return "chat.relativeTime.hours \(hoursAgo)"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "chat.relativeTime.yesterday"
        }
        let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
        return "chat.relativeTime.daysAgo \(days)"
    }
}

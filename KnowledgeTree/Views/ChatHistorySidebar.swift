//
//  ChatHistorySidebar.swift
//  KnowledgeTree
//
//  spec 033 — AI チャット履歴サイドバー。
//  iPad: NavigationSplitView の sidebar 列、iPhone: overlay/sheet 内に配置。
//  ・「+ 新しいチャット」button
//  ・session list (lastMessageAt 降順)
//  ・row tap で session 切替 (pinnedSessionID 更新)
//  ・row 左 swipe で削除 (cascade で message も削除)
//

import SwiftUI
import SwiftData

struct ChatHistorySidebar: View {
    @Binding var pinnedSessionID: UUID?
    var onCreate: () -> Void
    var onSelect: (UUID) -> Void

    @Query(sort: \ChatSession.lastMessageAt, order: .reverse)
    private var allSessions: [ChatSession]
    @Environment(ServiceContainer.self) private var serviceContainer

    var body: some View {
        List {
            Section {
                Button {
                    onCreate()
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(DS.Color.actionBlue)
                        Text("chat.sidebar.newSession")
                            .font(.body)
                    }
                }
                .accessibilityIdentifier("chat.sidebar.newButton")
            }

            Section {
                if allSessions.isEmpty {
                    Text("chat.sidebar.empty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allSessions) { session in
                        Button {
                            onSelect(session.id)
                        } label: {
                            ChatSessionRow(
                                session: session,
                                isActive: session.id == pinnedSessionID
                            )
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteSession(session)
                            } label: {
                                Label("chat.sidebar.deleteAction", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("chat.sidebar.title")
        .accessibilityIdentifier("chat.sidebar")
    }

    private func deleteSession(_ session: ChatSession) {
        let isActiveDeleted = session.id == pinnedSessionID
        try? serviceContainer.chatService?.deleteSession(session)
        if isActiveDeleted {
            // アクティブ session 削除 → pinnedSessionID をクリア (next computed で最新 / 新規 fallback)
            pinnedSessionID = nil
        }
    }
}

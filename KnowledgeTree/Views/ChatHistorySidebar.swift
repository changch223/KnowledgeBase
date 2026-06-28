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

    /// spec 061 (P1-3): セッション削除失敗を伝える軽い alert。
    @State private var showDeleteError: Bool = false

    /// V3.0 polish (2026-05-24): 「深掘り」と「一般」で履歴を分けて表示。
    private var generalSessions: [ChatSession] {
        allSessions.filter { $0.mode == .general }
    }

    private var deepDiveSessions: [ChatSession] {
        allSessions.filter { $0.mode == .deepDive }
    }

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

            // AI チャット (general mode) — タブから新規作成 + 通常質問
            Section(header: Text("chat.sidebar.section.general")) {
                if generalSessions.isEmpty {
                    Text("chat.sidebar.empty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(generalSessions) { session in
                        sessionButton(session)
                    }
                }
            }

            // 学習チャット (deepDive mode) は非表示 (spec 099: 学習タブ廃止で導線なし)
        }
        .listStyle(.sidebar)
        .navigationTitle("chat.sidebar.title")
        // spec 061 (P1-3): セッション削除失敗の表示
        .alert("error.action.deleteFailed.title", isPresented: $showDeleteError) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text("error.action.deleteFailed")
        }
        .accessibilityIdentifier("chat.sidebar")
    }

    @ViewBuilder
    private func sessionButton(_ session: ChatSession) -> some View {
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

    private func deleteSession(_ session: ChatSession) {
        let isActiveDeleted = session.id == pinnedSessionID
        // spec 061 (P1-3): 削除失敗を黙殺せず記録 + 表示。
        do {
            try serviceContainer.chatService?.deleteSession(session)
        } catch {
            AppErrorReporter.shared.report(error, operation: "deleteChatSession")
            showDeleteError = true
            return
        }
        if isActiveDeleted {
            // アクティブ session 削除 → pinnedSessionID をクリア (next computed で最新 / 新規 fallback)
            pinnedSessionID = nil
        }
    }
}

//
//  SettingsView.swift
//  KnowledgeTree
//
//  spec 019 — 設定画面 root。AI ブレインタブ右上の歯車から push 遷移。
//
//  spec 019 撤回 (2026-05-06): Chrome 連携 (App Intents + iOS Shortcut Setup Guide) は
//  Chrome iOS の x-callback-url が「現在のタブ URL」を返さない技術制約により実用化不可。
//  Chrome は Share Extension (spec 001) のみで運用、Setup Guide は SettingsView から撤去。
//  AppIntent / AppShortcutsProvider 実装は Safari Web Extension が ArticleSavingActor に
//  依存するため残置 (副作用で Shortcuts.app に「知積に保存」アクションは登録される)。
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("settings.safariSetupCompleted") private var safariSetupCompleted: Bool = false

    @Environment(ServiceContainer.self) private var serviceContainer
    @State private var showDeleteChatConfirm: Bool = false

    var body: some View {
        Form {
            Section("settings.section.externalIntegration") {
                // Safari (spec 020)
                NavigationLink(value: SafariSetupDestination()) {
                    HStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "safari")
                            .foregroundStyle(DS.Color.actionBlue)
                            .frame(width: 24)
                        Text("settings.safariSetup.entry")
                        Spacer()
                        if safariSetupCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DS.Color.actionBlue)
                                .accessibilityIdentifier("settings.safariSetup.completedMark")
                        }
                    }
                }
                .accessibilityIdentifier("settings.safariSetup.entry")
            }

            // spec 021: AI チャット履歴削除
            Section {
                Button(role: .destructive) {
                    showDeleteChatConfirm = true
                } label: {
                    HStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "trash")
                            .frame(width: 24)
                        Text("chat.settings.deleteAllHistory")
                    }
                }
                .accessibilityIdentifier("settings.chat.deleteHistory")
            }
        }
        .navigationTitle("settings.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SafariSetupDestination.self) { _ in
            SafariSetupView()
        }
        .alert(
            "chat.settings.deleteAllHistory.confirmTitle",
            isPresented: $showDeleteChatConfirm
        ) {
            Button("chat.settings.deleteAllHistory.confirmAction", role: .destructive) {
                try? serviceContainer.chatService?.deleteAllSessions()
            }
            Button("settings.safariSetup.confirmAutoSave.cancel", role: .cancel) { }
        } message: {
            Text("chat.settings.deleteAllHistory.confirmMessage")
        }
        .accessibilityIdentifier("settings.root")
    }
}

/// AIBrainView 右上の歯車から SettingsView に push 遷移する Hashable destination。
struct SettingsDestination: Hashable {}

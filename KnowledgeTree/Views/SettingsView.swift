//
//  SettingsView.swift
//  KnowledgeTree
//
//  spec 019 — 設定画面 root。AI ブレインタブ右上の歯車から push 遷移。
//  「外部連携」セクション下に「Chrome から自動保存」エントリ。
//
//  iOS 標準 Form 形式、setupCompleted 時は entry に checkmark。
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("settings.shortcutSetupCompleted") private var chromeSetupCompleted: Bool = false
    @AppStorage("settings.safariSetupCompleted") private var safariSetupCompleted: Bool = false

    @Environment(ServiceContainer.self) private var serviceContainer
    @State private var showDeleteChatConfirm: Bool = false

    var body: some View {
        Form {
            Section("settings.section.externalIntegration") {
                // Chrome (spec 019)
                NavigationLink(value: ChromeSetupDestination()) {
                    HStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "globe")
                            .foregroundStyle(DS.Color.actionBlue)
                            .frame(width: 24)
                        Text("settings.chromeSetup.entry")
                        Spacer()
                        if chromeSetupCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DS.Color.actionBlue)
                                .accessibilityIdentifier("settings.chromeSetup.completedMark")
                        }
                    }
                }
                .accessibilityIdentifier("settings.chromeSetup.entry")

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
        .navigationDestination(for: ChromeSetupDestination.self) { _ in
            ChromeShortcutSetupView()
        }
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

/// SettingsView から ChromeShortcutSetupView に push 遷移する Hashable destination。
struct ChromeSetupDestination: Hashable {}

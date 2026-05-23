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
    /// spec 041: ナレッジグラフ表示 toggle (default OFF、Phase B でユーザー判断)
    @AppStorage("settings.graphVisible") private var graphVisible: Bool = false

    @Environment(ServiceContainer.self) private var serviceContainer
    @State private var showDeleteChatConfirm: Bool = false

    var body: some View {
        Form {
            // spec 041: ナレッジグラフ表示 toggle
            Section {
                Toggle(isOn: $graphVisible) {
                    HStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "circle.hexagongrid")
                            .foregroundStyle(DS.Color.actionBlue)
                            .frame(width: 24)
                        Text("settings.graph.entry")
                    }
                }
                .accessibilityIdentifier("settings.graph.toggle")
            } header: {
                Text("settings.section.display")
            } footer: {
                Text("settings.graph.footer")
            }

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

                // spec 042: 翻訳セットアップ (英語記事抽出時に必要)
                NavigationLink(value: TranslationSetupDestination()) {
                    HStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "character.book.closed")
                            .foregroundStyle(DS.Color.actionBlue)
                            .frame(width: 24)
                        Text("settings.translationSetup.entry")
                        Spacer()
                        if serviceContainer.translationAvailability?.needsSetup == true {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                                .accessibilityIdentifier("settings.translationSetup.needsSetupMark")
                        }
                    }
                }
                .accessibilityIdentifier("settings.translationSetup.entry")
            }

            // spec 024: タグ管理
            Section {
                NavigationLink(value: TagManagementDestination()) {
                    HStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "tag")
                            .foregroundStyle(DS.Color.actionBlue)
                            .frame(width: 24)
                        Text("settings.tag.entry")
                    }
                }
                .accessibilityIdentifier("settings.tag.entry")
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
        .navigationDestination(for: TagManagementDestination.self) { _ in
            TagManagementView()
        }
        .navigationDestination(for: TranslationSetupDestination.self) { _ in
            TranslationSetupView()
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

/// SettingsView から TagManagementView (spec 024) に push 遷移する Hashable destination。
struct TagManagementDestination: Hashable {}

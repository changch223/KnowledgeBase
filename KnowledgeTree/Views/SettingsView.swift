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
//  依存するため残置 (副作用で Shortcuts.app に「iKnow に保存」アクションは登録される)。
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("settings.safariSetupCompleted") private var safariSetupCompleted: Bool = false
    /// spec 041: ナレッジグラフ表示 toggle (default OFF、Phase B でユーザー判断)
    @AppStorage("settings.graphVisible") private var graphVisible: Bool = false
    /// spec 051 Phase A 完成: iCloud sync 有効化 toggle (default OFF、opt-in)。
    /// 切替後はアプリ再起動が必要 (ModelContainer は launch 時に 1 度だけ構築)。
    @AppStorage(SharedSchema.iCloudSyncFlagKey) private var iCloudSyncEnabled: Bool = false
    @Environment(ServiceContainer.self) private var serviceContainer
    @State private var showDeleteChatConfirm: Bool = false
    /// spec 049: onboarding 再表示用
    @State private var showOnboardingReplay: Bool = false
    /// spec 051: iCloud sync ON 確認 alert
    @State private var showICloudEnableConfirm: Bool = false
    /// spec 051: iCloud sync OFF 確認 alert
    @State private var showICloudDisableConfirm: Bool = false
    /// spec 051: toggle 切替後の「再起動が必要」banner
    @State private var showRestartBanner: Bool = false

    /// spec 050: App Store 表示用 version (CFBundleShortVersionString + CFBundleVersion)
    private var appVersionString: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(v) (\(b))"
    }

    var body: some View {
        Form {
            // spec 058: 健全性スコア + 「今すぐ整理」 button (最上部に控えめに配置)
            Section {
                HealthScoreCard()
                LintNowButton()
            } header: {
                Text("settings.health.section.title")
            }

            // spec 058: 整理ログ (直近 30 件)
            LintLogSection()

            // spec 051 Phase A 完成: iCloud sync toggle (opt-in、再起動必要)
            Section {
                if showRestartBanner {
                    HStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundStyle(.orange)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("アプリを再起動してください")
                                .font(.callout.weight(.medium))
                            Text("iCloud 同期の設定変更を反映するため、アプリを完全に終了してから再度開いてください")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("settings.icloud.restartBanner")
                }
                Toggle(isOn: Binding(
                    get: { iCloudSyncEnabled },
                    set: { newValue in
                        if newValue {
                            showICloudEnableConfirm = true
                        } else {
                            showICloudDisableConfirm = true
                        }
                    }
                )) {
                    HStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "icloud")
                            .foregroundStyle(iCloudSyncEnabled ? DS.Color.actionBlue : .secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("iCloud で同期")
                            Text(iCloudSyncEnabled
                                ? "同一 Apple ID の他端末と双方向同期"
                                : "OFF: この端末内のみに保存")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityIdentifier("settings.icloud.toggle")
            } header: {
                Text("同期")
            } footer: {
                Text(iCloudSyncEnabled
                    ? "OS 設定 → ユーザー名 → iCloud が ON になっている必要があります。同期データはあなたの iCloud private database 内のみ、他人に公開されません。"
                    : "OFF にすると、新規保存はこの端末のみに保存されます。既に iCloud にアップロード済みのデータは残ります。")
            }

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

            // spec 043: 保存された答えの履歴
            Section {
                NavigationLink(value: SavedAnswerHistoryDestination()) {
                    HStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "quote.bubble")
                            .foregroundStyle(DS.Color.actionBlue)
                            .frame(width: 24)
                        Text("SavedAnswer.history.title")
                    }
                }
                .accessibilityIdentifier("settings.savedAnswerHistory.entry")
            }

            // spec 049: onboarding 再表示
            Section {
                Button {
                    OnboardingFlagStore.shared.reset()
                    showOnboardingReplay = true
                } label: {
                    HStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "sparkles")
                            .frame(width: 24)
                        Text("はじめての方への説明をもう一度見る")
                    }
                }
                .accessibilityIdentifier("settings.onboarding.replay")
            }

            // spec 050: iCloud sync (近日対応 placeholder、v2.0 で実装予定)
            Section {
                HStack(spacing: DS.Spacing.lg) {
                    Image(systemName: "icloud")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iCloud で同期")
                        Text("近日対応 — 複数の端末で同じ知識ベースを共有")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .accessibilityIdentifier("settings.icloud.placeholder")
            } footer: {
                Text("現在は全てこの端末内に保存されます。iCloud 同期は次のバージョンで予定しています。")
                    .font(.caption)
            }

            // spec 050: プライバシー + サポート
            Section {
                if let url = URL(string: "https://github.com/changch223/KnowledgeTree/blob/main/PRIVACY.md") {
                    Link(destination: url) {
                        HStack(spacing: DS.Spacing.lg) {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(DS.Color.actionBlue)
                                .frame(width: 24)
                            Text("プライバシーポリシー")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                        }
                    }
                    .accessibilityIdentifier("settings.privacy")
                }
                if let url = URL(string: "https://github.com/changch223/KnowledgeTree/issues") {
                    Link(destination: url) {
                        HStack(spacing: DS.Spacing.lg) {
                            Image(systemName: "questionmark.bubble")
                                .foregroundStyle(DS.Color.actionBlue)
                                .frame(width: 24)
                            Text("不具合の報告 / 要望")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                        }
                    }
                    .accessibilityIdentifier("settings.support")
                }
            } header: {
                Text("情報")
            }

            // spec 050: バージョン情報 (App Store 表示用)
            Section {
                HStack(spacing: DS.Spacing.lg) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    Text("バージョン")
                    Spacer()
                    Text(appVersionString)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .accessibilityIdentifier("settings.version")
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
        .fullScreenCover(isPresented: $showOnboardingReplay) {
            OnboardingView(isPresented: $showOnboardingReplay)
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
        .navigationDestination(for: SavedAnswerHistoryDestination.self) { _ in
            SavedAnswerHistoryView()
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
        // spec 051: iCloud sync ON 確認
        .alert("iCloud で同期を開始しますか?", isPresented: $showICloudEnableConfirm) {
            Button("開始") {
                iCloudSyncEnabled = true
                showRestartBanner = true
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("現在の知識ベースを iCloud に同期します。設定変更を反映するためアプリの再起動が必要です。初回 sync は数分かかります。")
        }
        // spec 051: iCloud sync OFF 確認
        .alert("iCloud 同期を停止しますか?", isPresented: $showICloudDisableConfirm) {
            Button("停止", role: .destructive) {
                iCloudSyncEnabled = false
                showRestartBanner = true
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("新規保存はこの端末のみに保存されます。iCloud 上のデータは残ります (再 ON で復元可能)。設定変更を反映するためアプリの再起動が必要です。")
        }
        .accessibilityIdentifier("settings.root")
    }
}

/// AIBrainView 右上の歯車から SettingsView に push 遷移する Hashable destination。
struct SettingsDestination: Hashable {}

/// spec 043: SettingsView から SavedAnswerHistoryView に push 遷移する Hashable destination。
struct SavedAnswerHistoryDestination: Hashable {}

/// SettingsView から TagManagementView (spec 024) に push 遷移する Hashable destination。
struct TagManagementDestination: Hashable {}

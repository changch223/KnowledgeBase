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
import SwiftData

struct SettingsView: View {
    @AppStorage("settings.safariSetupCompleted") private var safariSetupCompleted: Bool = false
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
    /// spec 061 (P1-2): iCloud toggle のバウンス解消用 pending state。
    /// tap 直後は pending を楽観表示し、確認 alert の結果で確定 (OK) / 破棄 (Cancel) する。
    @State private var pendingICloudToggle: Bool?
    /// spec 061 (P1-3): チャット履歴全削除の失敗を伝える軽い alert。
    @State private var showDeleteChatError: Bool = false

    /// spec 050: App Store 表示用 version (CFBundleShortVersionString + CFBundleVersion)
    private var appVersionString: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(v) (\(b))"
    }

    var body: some View {
        Form {
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
                    // spec 061 (P1-2): pending を楽観表示してバウンスを防ぐ。
                    get: { pendingICloudToggle ?? iCloudSyncEnabled },
                    set: { newValue in
                        pendingICloudToggle = newValue
                        if newValue {
                            showICloudEnableConfirm = true
                        } else {
                            showICloudDisableConfirm = true
                        }
                    }
                )) {
                    HStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "icloud")
                            .foregroundStyle(iCloudSyncEnabled ? DS.Color.sumiInk : .secondary)
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
            // spec 090: ユーザー要望でグラフ機能を一旦 UI から外すため非表示 (トグル + 分野詳細グラフ)。

            Section("settings.section.externalIntegration") {
                // Safari (spec 020)
                NavigationLink(value: SafariSetupDestination()) {
                    HStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "safari")
                            .foregroundStyle(DS.Color.sumiInk)
                            .frame(width: 24)
                        Text("settings.safariSetup.entry")
                        Spacer()
                        if safariSetupCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DS.Color.sumiInk)
                                .accessibilityIdentifier("settings.safariSetup.completedMark")
                        }
                    }
                }
                .accessibilityIdentifier("settings.safariSetup.entry")

                // spec 042: 翻訳セットアップ (英語記事抽出時に必要)
                NavigationLink(value: TranslationSetupDestination()) {
                    HStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "character.book.closed")
                            .foregroundStyle(DS.Color.sumiInk)
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

            // spec 090: 「管理」(手動) と「整理」(自動) を 2 グループに分割。
            Section {
                NavigationLink(value: TagManagementDestination()) {
                    HStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "tag")
                            .foregroundStyle(DS.Color.sumiInk)
                            .frame(width: 24)
                        Text("settings.tag.entry")
                    }
                }
                .accessibilityIdentifier("settings.tag.entry")

            } header: {
                Text("settings.section.manage")
            }

            // 知識の整合性チェック — 手動実行・ログ行。
            Section {
                NavigationLink {
                    LintLogDetailView()
                } label: {
                    LintLogSummaryLabel()
                }

                LintNowButton()
            } header: {
                Text("settings.section.organize")
            } footer: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.lint.description")
                    if let lastRun = LintRunStore.formattedLastRun() {
                        Text(String(format: NSLocalizedString("settings.lint.lastRun", comment: ""), lastRun))
                    } else {
                        Text("settings.lint.neverRun")
                    }
                }
            }

            // spec 043/087: 保存された答えの履歴は非表示 (未使用)。

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

            // spec 059 (P0-3): 旧「近日対応」iCloud placeholder Section を削除。
            // spec 051 で iCloud sync は実装済 (上部の動作する toggle Section が正)。

            // spec 050: プライバシー + サポート
            Section {
                if let url = URL(string: "https://github.com/changch223/KnowledgeTree/blob/main/PRIVACY.md") {
                    Link(destination: url) {
                        HStack(spacing: DS.Spacing.lg) {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(DS.Color.sumiInk)
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
                                .foregroundStyle(DS.Color.sumiInk)
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
        .scrollContentBackground(.hidden)
        .background(DS.Color.washiBackground)
        .navigationTitle("settings.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DS.Color.washiBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
                // spec 061 (P1-3): 失敗を黙殺せず記録 + ユーザーに表示。
                do {
                    try serviceContainer.chatService?.deleteAllSessions()
                } catch {
                    AppErrorReporter.shared.report(error, operation: "deleteAllChatSessions")
                    showDeleteChatError = true
                }
            }
            Button("settings.safariSetup.confirmAutoSave.cancel", role: .cancel) { }
        } message: {
            Text("chat.settings.deleteAllHistory.confirmMessage")
        }
        // spec 051: iCloud sync ON 確認
        // spec 061 (P1-2): OK で pending を確定、Cancel で pending を破棄 (toggle が元位置に戻る)。
        .alert("iCloud で同期を開始しますか?", isPresented: $showICloudEnableConfirm) {
            Button("開始") {
                iCloudSyncEnabled = true
                pendingICloudToggle = nil
                showRestartBanner = true
            }
            Button("キャンセル", role: .cancel) {
                pendingICloudToggle = nil
            }
        } message: {
            Text("現在の知識ベースを iCloud に同期します。設定変更を反映するためアプリの再起動が必要です。初回 sync は数分かかります。")
        }
        // spec 051: iCloud sync OFF 確認
        .alert("iCloud 同期を停止しますか?", isPresented: $showICloudDisableConfirm) {
            Button("停止", role: .destructive) {
                iCloudSyncEnabled = false
                pendingICloudToggle = nil
                showRestartBanner = true
            }
            Button("キャンセル", role: .cancel) {
                pendingICloudToggle = nil
            }
        } message: {
            Text("新規保存はこの端末のみに保存されます。iCloud 上のデータは残ります (再 ON で復元可能)。設定変更を反映するためアプリの再起動が必要です。")
        }
        // spec 061 (P1-3): チャット履歴全削除の失敗表示
        .alert("error.action.deleteFailed.title", isPresented: $showDeleteChatError) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text("error.action.deleteFailed")
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


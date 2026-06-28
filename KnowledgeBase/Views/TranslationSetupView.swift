//
//  TranslationSetupView.swift
//  KnowledgeTree
//
//  spec 042 — 英語記事を保存する際に Apple Translation framework が
//  「en→ja の翻訳モデル」を必要とするため、ユーザーがそれを iOS Settings で
//  ダウンロードする手順をガイドする。
//
//  - 上部に現在の状態 (✓ ダウンロード済 / ⚠ 未ダウンロード / ✕ 非対応 / ? 確認中)
//  - 3 step instructions (Settings > 一般 > 言語と地域 > 翻訳の言語 > 英語 + 日本語)
//  - 「設定アプリを開く」 deeplink button (iOS Settings root へ)
//  - 「状態を再確認する」button (押すと現在の status を再取得)
//  - 「セットアップ完了」(状態 = installed の時のみ表示) → needsSetup flag リセット
//

import SwiftUI

struct TranslationSetupView: View {
    @Environment(ServiceContainer.self) private var services

    @State private var status: TranslationPairStatus = .unknown
    @State private var isChecking: Bool = false

    private var availability: TranslationAvailabilityProtocol? {
        services.translationAvailability
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                statusCard

                Text("settings.translationSetup.description")
                    .font(.body)
                    .foregroundStyle(.secondary)

                stepCard(
                    number: 1,
                    titleKey: "settings.translationSetup.step1.title",
                    descriptionKey: "settings.translationSetup.step1.description",
                    actionButton: AnyView(openSettingsButton)
                )
                stepCard(
                    number: 2,
                    titleKey: "settings.translationSetup.step2.title",
                    descriptionKey: "settings.translationSetup.step2.description",
                    actionButton: nil
                )
                stepCard(
                    number: 3,
                    titleKey: "settings.translationSetup.step3.title",
                    descriptionKey: "settings.translationSetup.step3.description",
                    actionButton: nil
                )

                recheckButton

                if status == .installed {
                    completeButton
                }
            }
            .padding(DS.Spacing.xxl)
        }
        .navigationTitle("settings.translationSetup.title")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshStatus()
        }
        .accessibilityIdentifier("settings.translationSetup.root")
    }

    // MARK: - Status Card

    private var statusCard: some View {
        HStack(spacing: DS.Spacing.lg) {
            Image(systemName: statusIcon)
                .font(.title)
                .foregroundStyle(statusColor)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(statusTitleKey)
                    .font(DS.Typography.sectionTitle)
                Text(statusSubtitleKey)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(DS.Spacing.xxl)
        .dsCardBackground()
    }

    private var statusIcon: String {
        switch status {
        case .installed: return "checkmark.circle.fill"
        case .supported: return "exclamationmark.triangle.fill"
        case .unsupported: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch status {
        case .installed: return DS.Color.sumiInk
        case .supported: return DS.Color.sumiInk
        case .unsupported, .unknown: return .secondary
        }
    }

    private var statusTitleKey: LocalizedStringKey {
        switch status {
        case .installed: return "settings.translationSetup.status.installed"
        case .supported: return "settings.translationSetup.status.supported"
        case .unsupported: return "settings.translationSetup.status.unsupported"
        case .unknown: return "settings.translationSetup.status.unknown"
        }
    }

    private var statusSubtitleKey: LocalizedStringKey {
        switch status {
        case .installed: return "settings.translationSetup.status.installed.subtitle"
        case .supported: return "settings.translationSetup.status.supported.subtitle"
        case .unsupported: return "settings.translationSetup.status.unsupported.subtitle"
        case .unknown: return "settings.translationSetup.status.unknown.subtitle"
        }
    }

    // MARK: - Buttons

    private var openSettingsButton: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            Label("settings.translationSetup.openSettingsButton", systemImage: "arrow.up.forward.app")
        }
        .buttonStyle(.bordered)
    }

    private var recheckButton: some View {
        Button {
            Task { await refreshStatus() }
        } label: {
            HStack {
                if isChecking {
                    ProgressView()
                        .controlSize(.small)
                }
                Text("settings.translationSetup.recheckButton")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(isChecking)
        .accessibilityIdentifier("settings.translationSetup.recheck")
    }

    @ViewBuilder
    private var completeButton: some View {
        Button {
            availability?.clearNeedsSetup()
        } label: {
            Label("settings.translationSetup.completeButton", systemImage: "checkmark")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(DS.Color.sumiInk)
        .accessibilityIdentifier("settings.translationSetup.complete")
    }

    // MARK: - Step Card

    @ViewBuilder
    private func stepCard(number: Int, titleKey: LocalizedStringKey, descriptionKey: LocalizedStringKey, actionButton: AnyView?) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(DS.Color.sumiInk)
                    .frame(width: 32, height: 32)
                Text("\(number)")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(titleKey)
                    .font(DS.Typography.sectionTitle)
                Text(descriptionKey)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionButton {
                    actionButton.padding(.top, DS.Spacing.sm)
                }
            }
        }
        .padding(DS.Spacing.xxl)
        .dsCardBackground()
    }

    // MARK: - Async

    private func refreshStatus() async {
        guard let availability else { return }
        isChecking = true
        let newStatus = await availability.currentStatus()
        status = newStatus
        // installed になったら flag を自動クリア
        if newStatus == .installed {
            availability.clearNeedsSetup()
        }
        isChecking = false
    }
}

/// SettingsView から TranslationSetupView に push 遷移する Hashable destination。
struct TranslationSetupDestination: Hashable {}

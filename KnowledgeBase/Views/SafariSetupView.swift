//
//  SafariSetupView.swift
//  KnowledgeTree
//
//  spec 020 — Safari 拡張機能の Setup Guide。
//  3 ステップ Step Card + 自動保存トグル + 遅延 Picker + 「iOS 設定を開く」deeplink。
//
//  自動保存設定は App Group UserDefaults に同期、Safari Extension content.js から参照される。
//

import SwiftUI
import UIKit

struct SafariSetupView: View {
    @AppStorage("settings.safariSetupCompleted") private var setupCompleted: Bool = false
    @AppStorage("settings.safari.autoSaveEnabled") private var autoSaveEnabled: Bool = false
    @AppStorage("settings.safari.autoSaveDelaySeconds") private var autoSaveDelaySeconds: Int = 10

    @State private var showAutoSaveConfirm: Bool = false

    private let delayOptions: [(seconds: Int, labelKey: LocalizedStringKey)] = [
        (0, "settings.safariSetup.delay.immediate"),
        (5, "settings.safariSetup.delay.5sec"),
        (10, "settings.safariSetup.delay.10sec"),
        (30, "settings.safariSetup.delay.30sec"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                // 説明文
                Text("settings.safariSetup.description")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Step 1: iOS 設定を開く
                stepCard(
                    number: 1,
                    titleKey: "settings.safariSetup.step1.title",
                    descriptionKey: "settings.safariSetup.step1.description",
                    actionButton: AnyView(openSettingsButton)
                )

                // Step 2: 拡張機能を ON
                stepCard(
                    number: 2,
                    titleKey: "settings.safariSetup.step2.title",
                    descriptionKey: "settings.safariSetup.step2.description",
                    actionButton: nil
                )

                // Step 3: 保存方法 (トグル + Picker)
                stepCard(
                    number: 3,
                    titleKey: "settings.safariSetup.step3.title",
                    descriptionKey: "settings.safariSetup.step3.description",
                    actionButton: AnyView(autoSaveControls)
                )

                // 完了 / リセット ボタン
                if setupCompleted {
                    Button("settings.chromeSetup.resetLink") {
                        setupCompleted = false
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, DS.Spacing.md)
                    .accessibilityIdentifier("settings.safariSetup.resetButton")
                } else {
                    Button {
                        setupCompleted = true
                    } label: {
                        Text("settings.chromeSetup.completeButton")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.Color.sumiInk)
                    .padding(.top, DS.Spacing.md)
                    .accessibilityIdentifier("settings.safariSetup.completeButton")
                }
            }
            .padding(DS.Spacing.xxl)
        }
        .navigationTitle("settings.safariSetup.title")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.safariSetup.root")
        .alert("settings.safariSetup.confirmAutoSave.title", isPresented: $showAutoSaveConfirm) {
            Button("settings.safariSetup.confirmAutoSave.enable", role: .none) {
                autoSaveEnabled = true
                syncAutoSaveToAppGroup()
            }
            Button("settings.safariSetup.confirmAutoSave.cancel", role: .cancel) {
                // トグルは戻す
                autoSaveEnabled = false
                syncAutoSaveToAppGroup()
            }
        } message: {
            Text("settings.safariSetup.confirmAutoSave.message")
        }
        .onChange(of: autoSaveDelaySeconds) { _, _ in
            syncAutoSaveToAppGroup()
        }
    }

    // MARK: - Subviews

    private var openSettingsButton: some View {
        Button {
            // iOS 設定アプリの Safari Extension 画面 deeplink
            if let url = URL(string: "App-prefs:SAFARI&path=WEB_EXTENSIONS") {
                UIApplication.shared.open(url) { success in
                    if !success {
                        // fallback: 設定アプリ root
                        if let rootURL = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(rootURL)
                        }
                    }
                }
            }
        } label: {
            Label("settings.safariSetup.openSettingsButton", systemImage: "arrow.up.forward.app")
        }
        .buttonStyle(.bordered)
        .tint(DS.Color.sumiInk)
        .accessibilityIdentifier("settings.safariSetup.openSettingsButton")
    }

    private var autoSaveControls: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Toggle(isOn: Binding(
                get: { autoSaveEnabled },
                set: { newValue in
                    if newValue && !autoSaveEnabled {
                        // OFF → ON: 確認 alert
                        showAutoSaveConfirm = true
                    } else {
                        autoSaveEnabled = newValue
                        syncAutoSaveToAppGroup()
                    }
                }
            )) {
                Text("settings.safariSetup.autoSaveToggle")
            }
            .tint(DS.Color.sumiInk)
            .accessibilityIdentifier("settings.safariSetup.autoSaveToggle")

            Text("settings.safariSetup.autoSaveExplain")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Picker 「保存までの遅延」
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("settings.safariSetup.delayPicker.title")
                    .font(.callout)
                    .foregroundStyle(autoSaveEnabled ? .primary : .secondary)

                Picker("settings.safariSetup.delayPicker.title", selection: $autoSaveDelaySeconds) {
                    ForEach(delayOptions, id: \.seconds) { option in
                        Text(option.labelKey).tag(option.seconds)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!autoSaveEnabled)
                .accessibilityIdentifier("settings.safariSetup.delayPicker")
            }
            .padding(.top, DS.Spacing.sm)
        }
    }

    @ViewBuilder
    private func stepCard(
        number: Int,
        titleKey: LocalizedStringKey,
        descriptionKey: LocalizedStringKey,
        actionButton: AnyView?
    ) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(DS.Color.sumiInk)
                    .frame(width: 32, height: 32)
                Text("\(number)")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(titleKey)
                    .font(DS.Typography.sectionTitle)
                Text(descriptionKey)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let actionButton {
                    actionButton.padding(.top, DS.Spacing.sm)
                }
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCardBackground()
    }

    // MARK: - App Group sync

    /// @AppStorage は UserDefaults.standard を使う、Safari Extension は App Group UserDefaults を使う。
    /// 値変更時に明示的に App Group に sync する。
    private func syncAutoSaveToAppGroup() {
        let group = UserDefaults(suiteName: AppGroup.identifier)
        group?.set(autoSaveEnabled, forKey: "settings.safari.autoSaveEnabled")
        group?.set(autoSaveDelaySeconds, forKey: "settings.safari.autoSaveDelaySeconds")
    }
}

/// SettingsView から SafariSetupView に遷移するための Hashable destination。
struct SafariSetupDestination: Hashable {}

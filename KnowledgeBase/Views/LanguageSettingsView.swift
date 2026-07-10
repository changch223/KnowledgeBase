//
//  LanguageSettingsView.swift
//  KnowledgeTree
//
//  多言語対応 Phase A — 設定画面から「AI が生成する知識の言語」(PipelineLanguage) を
//  確認・変更するサブ画面。変更は再起動が必要 (TranslationSetupView / SettingsView の
//  iCloud toggle 「再起動バナー」パターンと同じ考え方)。
//

import SwiftUI

struct LanguageSettingsView: View {
    private let store: LanguageSettingsStore

    @State private var currentLanguage: PipelineLanguage
    @State private var pendingLanguage: PipelineLanguage?
    @State private var showConfirm: Bool = false
    @State private var showRestartBanner: Bool = false

    init(store: LanguageSettingsStore = UserDefaultsLanguageSettingsStore()) {
        self.store = store
        _currentLanguage = State(initialValue: store.currentLanguage())
    }

    var body: some View {
        Form {
            Section {
                if showRestartBanner {
                    HStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundStyle(.orange)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings.languageSettings.restartBanner.title")
                                .font(.callout.weight(.medium))
                            Text("settings.languageSettings.restartBanner.body")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("settings.languageSettings.restartBanner")
                }
                Picker(
                    selection: Binding(
                        get: { pendingLanguage ?? currentLanguage },
                        set: { newValue in
                            guard newValue != currentLanguage else { return }
                            pendingLanguage = newValue
                            showConfirm = true
                        }
                    )
                ) {
                    ForEach(PipelineLanguage.allCases, id: \.self) { language in
                        Text(language.endonym).tag(language)
                    }
                } label: {
                    Text("settings.languageSettings.picker.label")
                }
                .pickerStyle(.inline)
                .accessibilityIdentifier("settings.languageSettings.picker")
            } header: {
                Text("settings.languageSettings.header")
            } footer: {
                Text("settings.languageSettings.footer")
            }
        }
        .navigationTitle("settings.languageSettings.title")
        .navigationBarTitleDisplayMode(.inline)
        .alert("settings.languageSettings.confirmTitle", isPresented: $showConfirm) {
            Button("settings.languageSettings.confirmAction") {
                if let pendingLanguage {
                    store.change(to: pendingLanguage)
                    currentLanguage = pendingLanguage
                    showRestartBanner = true
                }
                self.pendingLanguage = nil
            }
            Button("common.cancel", role: .cancel) {
                pendingLanguage = nil
            }
        } message: {
            Text("settings.languageSettings.confirmMessage")
        }
        .accessibilityIdentifier("settings.languageSettings.root")
    }
}

/// SettingsView から LanguageSettingsView に push 遷移する Hashable destination。
struct LanguageSettingsDestination: Hashable {}

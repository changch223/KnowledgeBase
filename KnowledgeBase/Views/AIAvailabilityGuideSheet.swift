//
//  AIAvailabilityGuideSheet.swift
//  KnowledgeTree
//
//  AIAvailabilityBanner タップ / 設定の Apple Intelligence ステータス行タップの遷移先。
//  理由別に「なぜ使えないか」「どうすれば直るか」を番号付き手順で示す。
//  デザインは LanguageSettingsView / CategoryEditSheet と同じ NavigationStack + Form 慣習。
//

import SwiftUI

struct AIAvailabilityGuideSheet: View {
    let reason: AppleIntelligenceUnavailabilityReason

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: DS.Spacing.lg) {
                        Image(systemName: iconName)
                            .font(.title2)
                            .foregroundStyle(.orange)
                            .frame(width: 32)
                        Text(LocalizedStringKey(titleKey))
                            .font(DS.Typography.sectionTitle)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                reasonContent

                Section {
                    Text("aiAvailability.guide.reassurance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("aiAvailability.guide.navTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                }
            }
            .accessibilityIdentifier("aiAvailability.guideSheet.root")
        }
    }

    @ViewBuilder
    private var reasonContent: some View {
        switch reason {
        case .appleIntelligenceNotEnabled:
            notEnabledSection
        case .modelNotReady:
            modelNotReadySection
        case .deviceNotEligible:
            deviceNotEligibleSection
        case .unknown:
            unknownSection
        }
    }

    // spec: 「リンクと手順の併記」— App-prefs リンクが効かない端末でも手順で迷わないように、
    // Link と番号手順を常に両方表示する。
    private var notEnabledSection: some View {
        Section {
            stepRow(number: 1, textKey: "aiAvailability.guide.notEnabled.step1")
            stepRow(number: 2, textKey: "aiAvailability.guide.notEnabled.step2")
            stepRow(number: 3, textKey: "aiAvailability.guide.notEnabled.step3")
            if let url = URL(string: AIAvailabilityCopy.settingsURLString) {
                Link(destination: url) {
                    Label("aiAvailability.guide.openSettings", systemImage: "arrow.up.forward.app")
                }
                .accessibilityIdentifier("aiAvailability.guideSheet.openSettingsLink")
            }
        } header: {
            Text("aiAvailability.guide.notEnabled.header")
        }
    }

    private var modelNotReadySection: some View {
        Section {
            stepRow(number: 1, textKey: "aiAvailability.guide.modelNotReady.step1")
            stepRow(number: 2, textKey: "aiAvailability.guide.modelNotReady.step2")
        } header: {
            Text("aiAvailability.guide.modelNotReady.header")
        } footer: {
            Text("aiAvailability.guide.modelNotReady.footer")
        }
    }

    private var deviceNotEligibleSection: some View {
        Section {
            Text("aiAvailability.guide.deviceNotEligible.body")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var unknownSection: some View {
        Section {
            Text("aiAvailability.guide.unknown.body")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func stepRow(number: Int, textKey: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.lg) {
            Text(verbatim: "\(number).")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(LocalizedStringKey(textKey))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var iconName: String {
        switch reason {
        case .deviceNotEligible:           return "iphone.slash"
        case .appleIntelligenceNotEnabled: return "sparkles.slash"
        case .modelNotReady:               return "arrow.down.circle"
        case .unknown:                     return "exclamationmark.bubble"
        }
    }

    private var titleKey: String {
        AIAvailabilityCopy.titleKey(for: reason)
    }
}

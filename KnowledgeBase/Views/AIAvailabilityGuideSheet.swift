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

    // spec: 「アイコン付き手順 + 設定 App だけを開く」— App-prefs の私用スキームは iOS 18+ で
    // 正しいペインに飛ばせないため、リンクで正確なペインへの着地を約束することはやめ、
    // 素の設定 App を開く導線 (openAISettings、1 行目) + アイコン付き番号手順で説明を主役にする。
    private var notEnabledSection: some View {
        Section {
            Button {
                AIAvailabilityCopy.openAISettings()
            } label: {
                iconStepRow(number: 1, icon: "gearshape", textKey: "aiAvailability.guide.notEnabled.step1")
            }
            .accessibilityIdentifier("aiAvailability.guideSheet.openSettingsLink")

            iconStepRow(number: 2, icon: "sparkles", textKey: "aiAvailability.guide.notEnabled.step2", emphasized: true)
            iconStepRow(number: 3, icon: "switch.2", textKey: "aiAvailability.guide.notEnabled.step3")

            Text("aiAvailability.guide.openSettings.hint")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("aiAvailability.guide.notEnabled.header")
        }
    }

    private var modelNotReadySection: some View {
        Section {
            iconStepRow(number: 1, icon: "wifi", textKey: "aiAvailability.guide.modelNotReady.step1")
            iconStepRow(number: 2, icon: "gearshape", textKey: "aiAvailability.guide.modelNotReady.step2")
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

    /// アイコン付き番号ステップ行。emphasized で強調 (太字) にできる (「Apple Intelligence と
    /// Siri」を選ぶ、のように選択を誤りやすい手順を目立たせるため)。
    private func iconStepRow(number: Int, icon: String, textKey: String, emphasized: Bool = false) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Text(verbatim: "\(number).")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(DS.Color.actionBlue)
                .frame(width: 20)
            Text(LocalizedStringKey(textKey))
                .font(emphasized ? .body.weight(.semibold) : .body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// internal (private でなく): AIAvailabilitySymbolTests から SF Symbol 実在検証で参照するため。
    var iconName: String {
        switch reason {
        case .deviceNotEligible:           return "iphone.slash"
        case .appleIntelligenceNotEnabled: return "sparkles"
        case .modelNotReady:               return "arrow.down.circle"
        case .unknown:                     return "exclamationmark.bubble"
        }
    }

    private var titleKey: String {
        AIAvailabilityCopy.titleKey(for: reason)
    }
}

//
//  AppleIntelligenceBanner.swift
//  KnowledgeTree
//
//  spec 048 — Apple Intelligence 非対応 / 未有効 / モデル未準備 端末向けの説明 banner。
//
//  AI 機能 (要約 / Chat / 家庭教師) を使えない理由を明示し、無音 fallback による
//  「分かりません」連発で「壊れている感」を防ぐ。calm UX、設定 deep link 経由で誘導。
//

import SwiftUI

struct AppleIntelligenceBanner: View {
    let reason: AppleIntelligenceUnavailabilityReason
    let compact: Bool

    init(reason: AppleIntelligenceUnavailabilityReason, compact: Bool = false) {
        self.reason = reason
        self.compact = compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: iconName)
                    .foregroundStyle(.orange)
                Text(LocalizedStringKey(reason.titleKey))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            if !compact {
                Text(LocalizedStringKey(reason.bodyKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                if reason == .appleIntelligenceNotEnabled {
                    Button {
                        AIAvailabilityCopy.openAISettings()
                    } label: {
                        Text("aiAvailability.guide.openSettings")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DS.Color.sumiInk)
                    }
                    .padding(.top, DS.Spacing.xs)
                    Text("aiAvailability.guide.openSettings.hint")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        .accessibilityIdentifier("appleIntelligence.banner.\(identifierSuffix)")
        .accessibilityElement(children: .combine)
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

    private var identifierSuffix: String {
        switch reason {
        case .deviceNotEligible:           return "deviceNotEligible"
        case .appleIntelligenceNotEnabled: return "notEnabled"
        case .modelNotReady:               return "modelNotReady"
        case .unknown:                     return "unknown"
        }
    }
}

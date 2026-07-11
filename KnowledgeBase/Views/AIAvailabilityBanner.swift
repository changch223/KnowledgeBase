//
//  AIAvailabilityBanner.swift
//  KnowledgeTree
//
//  全タブ共通のトップバナー。AIAvailabilityMonitor が unavailable を検知している間、
//  どのタブ/画面に居ても気づけるようにする (実機で数日 unavailable に気づけなかった
//  事故の再発防止)。タップで詳細ガイド (AIAvailabilityGuideSheet) を開く。
//
//  spec 048 の AppleIntelligenceBanner (ChatTabView compact 表示) とは独立、無改修で残す。
//

import SwiftUI

struct AIAvailabilityBanner: View {
    let reason: AppleIntelligenceUnavailabilityReason
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: iconName)
                .foregroundStyle(.orange)
                .frame(width: 20)
            Text(LocalizedStringKey(titleKey))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: DS.Spacing.sm)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(Text("common.close"))
            .accessibilityIdentifier("aiAvailability.topBanner.dismiss")
        }
        .padding(.horizontal, DS.Spacing.xxl)
        .padding(.vertical, DS.Spacing.lg)
        .background(.regularMaterial)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityIdentifier("aiAvailability.topBanner")
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

/// アプリルートの safeAreaInset に置く AIAvailabilityBanner のホスト View。
/// 独立 View にすることで monitor の @Observable 変化を確実に観測する
/// (Scene body 直書きだと再評価されない bug の回避、ReviewCompletionBannerHost と同パターン)。
struct AIAvailabilityBannerHost: View {
    let monitor: AIAvailabilityMonitor

    @State private var showGuide: Bool = false

    var body: some View {
        if monitor.isBannerVisible, let reason = monitor.unavailabilityReason {
            AIAvailabilityBanner(
                reason: reason,
                onTap: { showGuide = true },
                onDismiss: { monitor.dismiss() }
            )
            .sheet(isPresented: $showGuide) {
                AIAvailabilityGuideSheet(reason: reason)
            }
        }
    }
}

/// banner / 設定ステータス行 / ガイドシートで共有する理由別タイトル key。
enum AIAvailabilityCopy {
    static func titleKey(for reason: AppleIntelligenceUnavailabilityReason) -> String {
        switch reason {
        case .deviceNotEligible:           return "aiAvailability.title.deviceNotEligible"
        case .appleIntelligenceNotEnabled: return "aiAvailability.title.notEnabled"
        case .modelNotReady:               return "aiAvailability.title.modelNotReady"
        case .unknown:                     return "aiAvailability.title.unknown"
        }
    }

    /// 設定 App の「Apple Intelligence と Siri」ペインへの private URL scheme。
    /// 私用スキームゆえ将来 OS 更新で解決されなくなる可能性はあるが、実機検証済みの root キー。
    static let settingsURLString = "App-prefs:root=SIRI"
}

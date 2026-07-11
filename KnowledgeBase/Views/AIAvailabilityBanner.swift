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
import UIKit

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

    /// 設定 App への deep link。iOS 18+ で「Apple Intelligence と Siri」ペインへの private URL
    /// サブパス (root=SIRI 等) は軒並み解決されなくなった (Apple Developer Forums thread 759900)。
    /// 正しいペインへ確実に飛ばせる公開 API は存在しないため、素の "App-prefs:" (パスなし) で
    /// 設定 App のトップページへの着地だけを狙う。正しいペインへの案内は UI 側の番号手順
    /// (aiAvailability.guide.notEnabled.step2 等) と footnote (aiAvailability.guide.openSettings.hint)
    /// で行う。
    static let settingsURLString = "App-prefs:"

    /// 設定 App を開く。素の App-prefs が失敗 (success==false) したら openSettingsURLString
    /// (公開 API、必ず設定 App 内には着地する) へ fallback する。
    @MainActor
    static func openAISettings() {
        guard let url = URL(string: settingsURLString) else {
            openSettingsAppRoot()
            return
        }
        UIApplication.shared.open(url) { success in
            if !success {
                openSettingsAppRoot()
            }
        }
    }

    @MainActor
    private static func openSettingsAppRoot() {
        if let fallback = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(fallback)
        }
    }
}

//
//  AIAvailabilitySymbolTests.swift
//  KnowledgeTreeTests
//
//  実機ログで "No symbol named 'sparkles.slash' found" が発生した再発防止。
//  AIAvailabilityBanner / AppleIntelligenceBanner / AIAvailabilityGuideSheet が使う
//  全 SF Symbol 名が実在することを UIImage(systemName:) で検証する。将来 iconName の
//  switch に存在しないシンボル名が混入したら、このテストが落ちる。
//
//  合わせて設定 App 遷移の URL (AIAvailabilityCopy.settingsURLString) の内容も検証する
//  (openAISettings 本体は UIApplication.shared.open 依存のため実機/UI テストでしか
//  動作確認できない)。
//

import Testing
import UIKit
@testable import KnowledgeBase

@MainActor
struct AIAvailabilitySymbolTests {

    // (1) AIAvailabilityBanner.iconName: 全 reason で実在する SF Symbol
    @Test func aiAvailabilityBannerIconNamesExist() {
        for reason in AppleIntelligenceUnavailabilityReason.allCases {
            let banner = AIAvailabilityBanner(reason: reason, onTap: {}, onDismiss: {})
            #expect(UIImage(systemName: banner.iconName) != nil, "missing symbol: \(banner.iconName) for \(reason)")
        }
    }

    // (2) AppleIntelligenceBanner.iconName: 全 reason で実在する SF Symbol
    @Test func appleIntelligenceBannerIconNamesExist() {
        for reason in AppleIntelligenceUnavailabilityReason.allCases {
            let banner = AppleIntelligenceBanner(reason: reason)
            #expect(UIImage(systemName: banner.iconName) != nil, "missing symbol: \(banner.iconName) for \(reason)")
        }
    }

    // (3) AIAvailabilityGuideSheet.iconName: 全 reason で実在する SF Symbol
    @Test func guideSheetIconNamesExist() {
        for reason in AppleIntelligenceUnavailabilityReason.allCases {
            let sheet = AIAvailabilityGuideSheet(reason: reason)
            #expect(UIImage(systemName: sheet.iconName) != nil, "missing symbol: \(sheet.iconName) for \(reason)")
        }
    }

    // (4) 3 view で使う reason 非依存の固定 SF Symbol も実在する
    // (chevron.right / xmark.circle.fill = AIAvailabilityBanner、gearshape / switch.2 / wifi =
    // AIAvailabilityGuideSheet の iconStepRow)
    @Test func fixedMiscSymbolsExist() {
        let fixedSymbols = ["chevron.right", "xmark.circle.fill", "gearshape", "switch.2", "wifi"]
        for symbol in fixedSymbols {
            #expect(UIImage(systemName: symbol) != nil, "missing symbol: \(symbol)")
        }
    }

    // (5) 設定遷移は素の "App-prefs:" (パスなし、正しいペインへの着地は狙わず設定 App の
    // トップだけを狙う) — iOS 18+ で私用サブパスが軒並み解決されなくなった問題への対処
    // (Apple Developer Forums thread 759900)。UIApplication.shared.open 本体・fallback 経路は
    // 実機/UI テスト任せ。
    @Test func settingsURLStringIsBarePrefsRoot() {
        #expect(AIAvailabilityCopy.settingsURLString == "App-prefs:")
    }

    // (6) 設定 URL は URL として parse できる (typo による即死を防ぐ)
    @Test func settingsURLStringIsValidURL() {
        #expect(URL(string: AIAvailabilityCopy.settingsURLString) != nil)
    }
}

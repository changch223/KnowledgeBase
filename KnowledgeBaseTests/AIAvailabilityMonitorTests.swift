//
//  AIAvailabilityMonitorTests.swift
//  KnowledgeTreeTests
//
//  Apple Intelligence が使えない状態をユーザーに気づかせる monitor の検証。
//  Timer は直接テストしない (refresh() の純粋な状態遷移のみを検証)。
//

import Testing
import Foundation
@testable import KnowledgeBase

@MainActor
struct AIAvailabilityMonitorTests {

    /// reason を自由に差し替えられる mutable mock。
    private final class MutableAvailabilityChecker: AvailabilityChecker, @unchecked Sendable {
        var reason: AppleIntelligenceUnavailabilityReason?

        init(reason: AppleIntelligenceUnavailabilityReason? = nil) {
            self.reason = reason
        }

        var isAvailable: Bool { reason == nil }
        var unavailabilityReason: AppleIntelligenceUnavailabilityReason? { reason }
    }

    // (1) unavailable → reason が公開され banner も表示される
    @Test func unavailableExposesReasonAndShowsBanner() {
        let checker = MutableAvailabilityChecker(reason: .modelNotReady)
        let monitor = AIAvailabilityMonitor(checker: checker, dismissStore: InMemoryAIAvailabilityDismissStore())

        #expect(monitor.unavailabilityReason == .modelNotReady)
        #expect(monitor.isBannerVisible == true)
    }

    // (2) available → banner 非表示
    @Test func availableHidesBanner() {
        let checker = MutableAvailabilityChecker(reason: nil)
        let monitor = AIAvailabilityMonitor(checker: checker, dismissStore: InMemoryAIAvailabilityDismissStore())

        #expect(monitor.unavailabilityReason == nil)
        #expect(monitor.isBannerVisible == false)
    }

    // (3) dismiss はメモリ内のみ (deviceNotEligible 以外) → 次回起動相当の新インスタンスでは再表示
    @Test func dismissForNonDeviceReasonIsNotPersisted() {
        let checker = MutableAvailabilityChecker(reason: .appleIntelligenceNotEnabled)
        let dismissStore = InMemoryAIAvailabilityDismissStore()
        let monitor = AIAvailabilityMonitor(checker: checker, dismissStore: dismissStore)

        monitor.dismiss()
        #expect(monitor.isBannerVisible == false)

        // 次回起動相当: 新しい monitor インスタンス (同じ dismissStore を共有しても notEnabled は永続しない)
        let relaunched = AIAvailabilityMonitor(checker: checker, dismissStore: dismissStore)
        #expect(relaunched.isBannerVisible == true)
    }

    // (4) deviceNotEligible のみ UserDefaults (dismissStore) に永続化 → 次回起動相当でも非表示のまま
    @Test func dismissForDeviceNotEligibleIsPersisted() {
        let checker = MutableAvailabilityChecker(reason: .deviceNotEligible)
        let dismissStore = InMemoryAIAvailabilityDismissStore()
        let monitor = AIAvailabilityMonitor(checker: checker, dismissStore: dismissStore)

        monitor.dismiss()
        #expect(monitor.isBannerVisible == false)
        #expect(dismissStore.isDeviceNotEligibleDismissed() == true)

        // 次回起動相当: 新しい monitor インスタンスでも dismissStore が永続化を覚えている
        let relaunched = AIAvailabilityMonitor(checker: checker, dismissStore: dismissStore)
        #expect(relaunched.isBannerVisible == false)
        #expect(relaunched.unavailabilityReason == .deviceNotEligible)
    }

    // (5) reason が変化した場合は dismiss をリセットして再表示する
    @Test func reasonChangeResetsDismiss() {
        let checker = MutableAvailabilityChecker(reason: .modelNotReady)
        let monitor = AIAvailabilityMonitor(checker: checker, dismissStore: InMemoryAIAvailabilityDismissStore())

        monitor.dismiss()
        #expect(monitor.isBannerVisible == false)

        // 理由が変化 (modelNotReady → appleIntelligenceNotEnabled)
        checker.reason = .appleIntelligenceNotEnabled
        monitor.refresh()

        #expect(monitor.unavailabilityReason == .appleIntelligenceNotEnabled)
        #expect(monitor.isBannerVisible == true)
    }

    // (6) 解消 (available) への遷移で banner が自動的に非表示になる
    @Test func availableTransitionAutoHidesBanner() {
        let checker = MutableAvailabilityChecker(reason: .modelNotReady)
        let monitor = AIAvailabilityMonitor(checker: checker, dismissStore: InMemoryAIAvailabilityDismissStore())
        #expect(monitor.isBannerVisible == true)

        checker.reason = nil
        monitor.refresh()

        #expect(monitor.unavailabilityReason == nil)
        #expect(monitor.isBannerVisible == false)
    }

    // (7) 解消 → 再発 (nil → reason) でも dismiss がリセットされ再表示される
    @Test func resolvedThenRecurredShowsBannerAgain() {
        let checker = MutableAvailabilityChecker(reason: .modelNotReady)
        let dismissStore = InMemoryAIAvailabilityDismissStore()
        let monitor = AIAvailabilityMonitor(checker: checker, dismissStore: dismissStore)

        monitor.dismiss()
        checker.reason = nil
        monitor.refresh()
        #expect(monitor.isBannerVisible == false)

        // 再発
        checker.reason = .modelNotReady
        monitor.refresh()
        #expect(monitor.unavailabilityReason == .modelNotReady)
        #expect(monitor.isBannerVisible == true)
    }

    // AI 復旧機能: (8) unavailable → available 遷移で onBecameAvailable が 1 回だけ呼ばれる。
    // init 時 (最初から available) や、available → available (変化なし) では呼ばれない。
    @Test func onBecameAvailableFiresOnlyOnUnavailableToAvailableTransition() {
        let checker = MutableAvailabilityChecker(reason: .modelNotReady)
        let monitor = AIAvailabilityMonitor(checker: checker, dismissStore: InMemoryAIAvailabilityDismissStore())
        var fireCount = 0
        monitor.onBecameAvailable = { fireCount += 1 }

        // 変化なし (reason 同じ) → 発火しない
        monitor.refresh()
        #expect(fireCount == 0)

        // unavailable → available への遷移 → 発火
        checker.reason = nil
        monitor.refresh()
        #expect(fireCount == 1)

        // available → available (変化なし) → 発火しない
        monitor.refresh()
        #expect(fireCount == 1)

        // available → unavailable (再発) → 発火しない
        checker.reason = .modelNotReady
        monitor.refresh()
        #expect(fireCount == 1)
    }
}

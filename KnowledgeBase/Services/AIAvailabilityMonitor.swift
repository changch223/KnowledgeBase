//
//  AIAvailabilityMonitor.swift
//  KnowledgeTree
//
//  Apple Intelligence が数日にわたって unavailable でもユーザーが気づけなかった実機事故の
//  再発防止。AvailabilityChecker (spec 048) を定期的に見張り、全タブ共通トップバナー +
//  設定画面の常設ステータス行が観測する。
//
//  再チェック契機:
//   (a) init 時
//   (b) 外部から呼べる refresh() (scenePhase .active 復帰で KnowledgeTreeApp から呼ぶ)
//   (c) unavailable の間だけ 60 秒間隔の Timer で自動再チェック
//      (available になったら Timer を止め、banner も自動で消える)
//
//  dismiss 挙動: deviceNotEligible のみ端末の状態が変わらないため UserDefaults に永続化。
//  それ以外 (notEnabled / modelNotReady / unknown) はメモリ内のみ (翌起動で未解消なら再表示)。
//  理由が変化した場合 (解消→再発を含む) は dismiss をリセットして再表示する。
//

import Foundation
import Observation

@MainActor
@Observable
final class AIAvailabilityMonitor {
    private let checker: AvailabilityChecker
    private let dismissStore: AIAvailabilityDismissStore
    // deinit は nonisolated (MainActor-isolated deinit は不可) のため、そこから安全に
    // invalidate できるよう nonisolated(unsafe) にする。実際の読み書きは常に MainActor
    // 経由 (init / refresh / startTimerIfNeeded / stopTimer) で、deinit の invalidate のみ例外。
    private nonisolated(unsafe) var timer: Timer?

    private static let pollInterval: TimeInterval = 60

    /// nil = Apple Intelligence が使用可能。
    private(set) var unavailabilityReason: AppleIntelligenceUnavailabilityReason?
    private var isDismissed: Bool = false

    init(
        checker: AvailabilityChecker = SystemLanguageModelAvailabilityChecker(),
        dismissStore: AIAvailabilityDismissStore = UserDefaultsAIAvailabilityDismissStore()
    ) {
        self.checker = checker
        self.dismissStore = dismissStore
        let reason = checker.unavailabilityReason
        self.unavailabilityReason = reason
        applyDismissState(for: reason)
        startTimerIfNeeded()
    }

    /// banner を表示すべきか (unavailable かつ dismiss されていない)。
    var isBannerVisible: Bool {
        unavailabilityReason != nil && !isDismissed
    }

    /// scenePhase .active 復帰など、外部トリガーで再チェックする。
    func refresh() {
        let newReason = checker.unavailabilityReason
        guard newReason != unavailabilityReason else { return }
        unavailabilityReason = newReason
        applyDismissState(for: newReason)
        if newReason == nil {
            stopTimer()
        } else {
            startTimerIfNeeded()
        }
    }

    /// banner を閉じる。deviceNotEligible のみ永続化 (端末側の状態が変わらないため毎起動出さない)。
    func dismiss() {
        isDismissed = true
        if unavailabilityReason == .deviceNotEligible {
            dismissStore.markDeviceNotEligibleDismissed()
        }
    }

    /// 解消→再発 / 理由変化のときの dismiss 状態を確定する。
    private func applyDismissState(for reason: AppleIntelligenceUnavailabilityReason?) {
        switch reason {
        case nil:
            isDismissed = false
        case .deviceNotEligible:
            isDismissed = dismissStore.isDeviceNotEligibleDismissed()
        case .appleIntelligenceNotEnabled, .modelNotReady, .unknown:
            isDismissed = false
        }
    }

    private func startTimerIfNeeded() {
        guard unavailabilityReason != nil, timer == nil else { return }
        let newTimer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - Dismiss Store

/// deviceNotEligible の dismiss だけを永続化する最小 protocol。
/// BackfillFlagStore (spec 013) と同じ形: production は UserDefaults、test は in-memory。
protocol AIAvailabilityDismissStore {
    func isDeviceNotEligibleDismissed() -> Bool
    func markDeviceNotEligibleDismissed()
}

/// production 用。UserDefaults.standard に Bool フラグを保存。
final class UserDefaultsAIAvailabilityDismissStore: AIAvailabilityDismissStore {
    private let key: String
    private let defaults: UserDefaults

    init(
        key: String = "aiAvailability.dismissed.deviceNotEligible",
        defaults: UserDefaults = .standard
    ) {
        self.key = key
        self.defaults = defaults
    }

    func isDeviceNotEligibleDismissed() -> Bool {
        defaults.bool(forKey: key)
    }

    func markDeviceNotEligibleDismissed() {
        defaults.set(true, forKey: key)
    }
}

/// test 用。プロセス state を汚染しない in-memory 実装。
final class InMemoryAIAvailabilityDismissStore: AIAvailabilityDismissStore {
    private var dismissed: Bool

    init(initial: Bool = false) {
        self.dismissed = initial
    }

    func isDeviceNotEligibleDismissed() -> Bool { dismissed }
    func markDeviceNotEligibleDismissed() { dismissed = true }
}

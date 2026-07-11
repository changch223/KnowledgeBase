//
//  LanguageMismatchDetector.swift
//  KnowledgeTree
//
//  多言語対応 — 端末の言語設定と AI 生成言語 (PipelineLanguage) がズレたときに、
//  起動時に 1 回だけ気づかせるバナー (LanguageMismatchBanner) の判定ロジック。
//  純粋関数 (LanguageMismatchDetector) + 「案内済みの組」を記録する protocol
//  (BackfillFlagStore / LintLoopMarkerStoring と同パターン: production は UserDefaults、test は in-memory)。
//
//  「ズレ」の定義: 「今初回起動したら選ばれる言語」(= `PipelineLanguage.fromPreferredLanguages`
//  で端末の優先言語から解決した値、初回固定 `lockIfFirstLaunch` と同じ解決ロジック) ≠
//  「現在の生成言語」(= 保存済み `PipelineLanguage`)。未対応言語の端末で fallback (ja) が
//  現在の生成言語と一致する場合はズレなしとみなす (出さない)。
//

import Foundation

enum LanguageMismatchDetector {
    /// 端末言語と生成言語の組を、記録・比較用の文字列キーにする。例: "en|zh-Hant"
    static func comboKey(device: PipelineLanguage, pipeline: PipelineLanguage) -> String {
        "\(device.rawValue)|\(pipeline.rawValue)"
    }

    /// 起動時にバナーを表示すべきか判定する純関数。
    /// - Parameters:
    ///   - devicePreferred: `Locale.preferredLanguages` 形式の端末優先言語リスト。
    ///   - pipeline: 現在の生成言語 (`PipelineLanguage.current` 相当)。
    ///   - lastNotifiedCombo: 直近で案内済みの組 (`comboKey` 形式)、未案内なら nil。
    static func shouldShowBanner(
        devicePreferred: [String],
        pipeline: PipelineLanguage,
        lastNotifiedCombo: String?
    ) -> Bool {
        let device = PipelineLanguage.fromPreferredLanguages(devicePreferred)
        guard device != pipeline else { return false }
        return comboKey(device: device, pipeline: pipeline) != lastNotifiedCombo
    }

    /// 意図的な言語変更 (`LanguageSettingsStore.change(to:)`、設定画面・バナーシートどちらの
    /// 経路でも) が起きたら、変更後の組み合わせを「案内済み」として記録する。
    /// バナーの本来の対象は「端末言語を変えたが生成言語設定を知らない/忘れているユーザー」だけで、
    /// 今まさに生成言語を選んだ本人には次回起動時に出す必要がない (false-positive 抑止)。
    /// `LanguageSettingsView` (設定画面からの変更) と `LanguageMismatchBannerHost`
    /// (バナーシートを閉じた時の書き込み時点再計算) の両方から呼ばれる共有ロジック。
    static func markResolved(
        devicePreferred: [String],
        pipeline: PipelineLanguage,
        store: LanguageMismatchNotificationStore
    ) {
        let device = PipelineLanguage.fromPreferredLanguages(devicePreferred)
        store.lastNotifiedCombo = comboKey(device: device, pipeline: pipeline)
    }
}

/// 「案内済みの組」のみを扱う最小 protocol。標準 UserDefaults で可 (拡張と共有不要)。
/// `AnyObject` 制約: 参照型に限定することで、`let` で保持した store の property を
/// 呼び出し側 (LanguageMismatchBannerHost 等) を mutating にせず更新できる
/// (LintLoopMarkerStoring と同じ規約)。
protocol LanguageMismatchNotificationStore: AnyObject {
    var lastNotifiedCombo: String? { get set }
}

/// production 用。UserDefaults.standard に文字列を保存。
final class UserDefaultsLanguageMismatchNotificationStore: LanguageMismatchNotificationStore {
    private let key = "langMismatch.lastNotifiedCombo"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastNotifiedCombo: String? {
        get { defaults.string(forKey: key) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }
}

/// テスト用。プロセス state (UserDefaults) を汚染しない in-memory 実装。
final class InMemoryLanguageMismatchNotificationStore: LanguageMismatchNotificationStore {
    var lastNotifiedCombo: String?

    init(lastNotifiedCombo: String? = nil) {
        self.lastNotifiedCombo = lastNotifiedCombo
    }
}

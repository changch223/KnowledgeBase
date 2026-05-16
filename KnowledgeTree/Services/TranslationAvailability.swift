//
//  TranslationAvailability.swift
//  KnowledgeTree
//
//  spec 042 — Apple Translation framework の en→ja 翻訳ペアの可用性を扱う。
//
//  - `currentStatus()` で `.installed` / `.supported` / `.unsupported` を非同期取得
//    (`.installed` = ダウンロード済 / `.supported` = 未ダウンロードだが対応 / `.unsupported` = 非対応)
//  - 翻訳失敗を `markNeedsSetup()` で UserDefaults に記録、SettingsView が badge 表示に使う
//  - ユーザーが Setup を確認したら `clearNeedsSetup()` で flag リセット
//
//  KnowledgeExtractor は本 service を optional inject、translate throws 時に
//  markNeedsSetup を呼ぶ (constitution V: silent fallback、UI 喚起は SettingsView 経由のみ)。
//

import Foundation
import Translation

@MainActor
protocol TranslationAvailabilityProtocol: AnyObject {
    /// 現在の en→ja 翻訳ペアの状態を返す
    func currentStatus() async -> TranslationPairStatus
    /// 翻訳失敗を検知 → SettingsView の badge 表示用 flag を立てる
    func markNeedsSetup()
    /// ユーザーが SettingsView でセットアップ確認 → flag リセット
    func clearNeedsSetup()
    /// 現在 flag が立っているか (SettingsView の badge 判定用)
    var needsSetup: Bool { get }
}

/// LanguageAvailability.Status の薄ラッパ (テスト容易化 + import 隠蔽)
enum TranslationPairStatus: Equatable {
    case installed       // 翻訳モデル DL 済、即使用可能
    case supported       // 対応言語ペアだが未 DL (Settings からダウンロード必要)
    case unsupported     // この iOS では非対応
    case unknown         // 判定不能 (フレームワーク不在 / エラー)
}

@MainActor
final class TranslationAvailability: TranslationAvailabilityProtocol {

    private let defaults: UserDefaults
    private static let needsSetupKey = "spec042.translationNeedsSetup"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func currentStatus() async -> TranslationPairStatus {
        let source = Locale.Language(identifier: "en")
        let target = Locale.Language(identifier: "ja")
        let availability = LanguageAvailability()
        let raw = await availability.status(from: source, to: target)
        switch raw {
        case .installed: return .installed
        case .supported: return .supported
        case .unsupported: return .unsupported
        @unknown default: return .unknown
        }
    }

    func markNeedsSetup() {
        defaults.set(true, forKey: Self.needsSetupKey)
    }

    func clearNeedsSetup() {
        defaults.set(false, forKey: Self.needsSetupKey)
    }

    var needsSetup: Bool {
        defaults.bool(forKey: Self.needsSetupKey)
    }
}

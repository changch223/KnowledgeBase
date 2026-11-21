//
//  DirectReadPolicy.swift
//  KnowledgeTree
//
//  spec 106 — 記事を「翻訳してから抽出」するか「原文を直接読ませるか」の判定 (純関数)。
//  Foundation Models が読める言語の記事は翻訳せず、プロンプトで生成言語を指示して直接抽出する
//  (翻訳は chunk あたり ~10 秒 + translationd クラッシュの原因だった)。
//

import Foundation

enum DirectReadPolicy {

    /// Foundation Models が入力として読める言語コード (BCP-47 の言語部)。
    /// 出典: Apple Intelligence 対応言語 (iOS 26 Foundation Models)。対応言語が増えたらここに足す。
    static let modelReadableLanguageCodes: Set<String> = ["ja", "en", "zh", "ko", "es", "de", "fr", "it", "pt"]

    /// 設定キー (Bool、既定 false = 直接読む新方式)。App Group UserDefaults に保存。
    static let translateBeforeExtractionKey = "settings.translateBeforeExtraction"

    /// 検知言語が Foundation Models で直接読めるか。.unknown は従来も翻訳しないので true。
    static func canReadDirectly(_ detected: DetectedLanguage) -> Bool {
        switch detected {
        case .japanese, .english, .unknown:
            return true
        case .other(let raw):
            let code = raw.lowercased().split(separator: "-").first.map(String.init) ?? raw.lowercased()
            return modelReadableLanguageCodes.contains(code)
        }
    }

    /// 抽出前に翻訳すべきか。
    /// - パイプライン言語と一致 → 翻訳しない
    /// - preferTranslate (従来方式スイッチ ON) → 一致しなければ翻訳する
    /// - それ以外 → 直接読めない言語だけ翻訳する
    static func shouldTranslateFirst(
        detected: DetectedLanguage,
        pipeline: PipelineLanguage,
        preferTranslate: Bool
    ) -> Bool {
        if detected == .unknown { return false }  // 判定不能は従来も翻訳しない
        if pipeline.matches(detected: detected) { return false }
        // 日本語パイプラインは従来どおり「翻訳してから抽出」を維持する (v1.0 からの主要利用者。
        // 日本語プロンプト + 日本語入力という実績のある組み合わせを変えない。設定の Toggle も ja では出さない)。
        if pipeline == .ja { return true }
        if preferTranslate { return true }
        return !canReadDirectly(detected)
    }

    /// 設定の読み出し (1 か所)。未設定は false。
    static func prefersTranslateFirst() -> Bool {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        return defaults.bool(forKey: translateBeforeExtractionKey)
    }
}

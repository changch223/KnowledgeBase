//
//  TokenBudgetProbe.swift
//  KnowledgeTree
//
//  spec 071 (コア品質ブラッシュアップ 第1段階) — token 実測診断ツール。
//  SystemLanguageModel.tokenCount(for:) で代表 prompt / @Generable schema の実 token を
//  測り Logger 出力。生成 (respond) は一切呼ばない = AI 呼び出し回数ゼロ・副作用ゼロ。
//
//  目的: これまで「勘 + overflow ログ」で 400 字まで削られてきた入力 truncate を、
//  実測値ベースで安全に緩和する (spec 073) ための数値根拠を作る。デバッグ専用。
//

import Foundation
import FoundationModels
import os

@MainActor
enum TokenBudgetProbe {
    private static let logger = Logger(subsystem: "app.KnowledgeTree", category: "tokenProbe")

    /// 代表 prompt + @Generable schema の実 token を測ってログ出力する (デバッグ診断)。
    /// tokenCount は async throws。生成 (respond) は呼ばない。
    static func runDiagnostics() async {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            logger.notice("TokenBudgetProbe: skipped (model not available)")
            return
        }

        logger.notice("TokenBudgetProbe: contextSize=\(model.contextSize)")

        // --- 代表 prompt の実 token ---
        let sampleBody = String(repeating: "これはトークン計測用のサンプル本文です。", count: 30) // ~600 字級
        await measurePrompt("知識抽出 prompt (本文 ~600字)", KnowledgeExtractor.buildPrompt(text: sampleBody))

        let categoryPrompt = """
            次のタグはどのカテゴリーに属しますか? 候補から 1 つだけ完全一致で返してください。
            候補: \(CategorySeed.promptCandidatesString)
            タグ: Claude
            """
        await measurePrompt("カテゴリ分類 prompt", categoryPrompt)

        let sampleSummary = String(repeating: "概念の要約サンプル。", count: 20)
        await measurePrompt("Wiki 本文 prompt (summary ~200字)", "「Claude」についての Wiki ページ本文を Markdown で書いてください。\n\n# 現在の要約\n\(sampleSummary)")

        // --- @Generable schema の実 token (これまで ~1500 と推定していた値の確定) ---
        await measureSchema("ExtractedKnowledgeOutput schema", ExtractedKnowledgeOutput.self)
        await measureSchema("ConceptSynthesisOutput schema", ConceptSynthesisOutput.self)
        await measureSchema("GraphTripleOutput schema", GraphTripleOutput.self)
    }

    /// prompt 文字列の token を測り、所要時間 + 残余 budget と共にログ。
    private static func measurePrompt(_ label: String, _ promptText: String) async {
        let model = SystemLanguageModel.default
        let start = Date()
        do {
            let tokens = try await model.tokenCount(for: promptText)
            let ms = Date().timeIntervalSince(start) * 1000
            let remaining = model.contextSize - tokens
            logger.notice("TokenBudgetProbe: \(label, privacy: .public) = \(tokens) tokens (\(promptText.count) 字, \(String(format: "%.0f", ms)) ms, 残余 \(remaining))")
        } catch {
            logger.error("TokenBudgetProbe: \(label, privacy: .public) failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// @Generable schema の token を測る (出力スキーマが入力 budget をどれだけ食うか)。
    private static func measureSchema<T: Generable>(_ label: String, _ type: T.Type) async {
        let model = SystemLanguageModel.default
        do {
            let tokens = try await model.tokenCount(for: type.generationSchema)
            logger.notice("TokenBudgetProbe: \(label, privacy: .public) = \(tokens) tokens (schema コスト)")
        } catch {
            logger.error("TokenBudgetProbe: \(label, privacy: .public) failed: \(String(describing: error), privacy: .public)")
        }
    }
}

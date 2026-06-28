//
//  TokenBudgetProbe.swift
//  KnowledgeTree
//
//  spec 071 (token 実測基盤、072 ブランチに前倒し) — DEBUG 専用の診断ツール。
//
//  目的: 「概念合成等が 4090 tokens で overflow する真因は @Generable スキーマか？」を
//  数値で確定する。AI 生成 (respond) は一切呼ばず、`tokenCount(for:)` で各 @Generable
//  スキーマと代表プロンプトの実トークンだけを測ってログに出す (無料・安全・副作用なし)。
//
//  起動時に 1 回だけ走らせ、Xcode コンソールで:
//    [TokenProbe] schema ConceptSynthesisOutput = NNNN tokens (残り PPPP)
//  を読んで、スキーマが窓 (contextSize) のどれだけを食っているかを把握する。
//
//  これを根拠に plain-string 化 (spec 063 パターン) の要否を判断する。
//

#if DEBUG
import Foundation
import FoundationModels
import os

enum TokenBudgetProbe {
    private static let logger = Logger(subsystem: "app.KnowledgeTree", category: "token-probe")

    /// 起動時 (bootstrap) から fire-and-forget で 1 回呼ぶ。
    static func runDiagnostics() async {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            logger.notice("[TokenProbe] skip: Foundation Models unavailable")
            return
        }

        let context = model.contextSize
        logger.notice("[TokenProbe] ========== Foundation Models token 実測 ==========")
        logger.notice("[TokenProbe] contextSize (窓) = \(context, privacy: .public) tokens")
        logger.notice("[TokenProbe] --- @Generable スキーマ単体のコスト (respond(generating:) で毎回入力に同梱される) ---")

        // respond(generating:) で実際に渡している top-level スキーマを全部測る。
        await measureSchema("ExtractedKnowledgeOutput (知識抽出)", ExtractedKnowledgeOutput.generationSchema, context: context, model: model)
        await measureSchema("ConceptSynthesisOutput (概念合成★)", ConceptSynthesisOutput.generationSchema, context: context, model: model)
        await measureSchema("ConceptSummaryChunk (概念chunk)", ConceptSummaryChunk.generationSchema, context: context, model: model)
        await measureSchema("ConceptHierarchyOutput (概念階層,spec074)", ConceptHierarchyOutput.generationSchema, context: context, model: model)
        await measureSchema("DigestOutput (Categoryダイジェスト)", DigestOutput.generationSchema, context: context, model: model)
        await measureSchema("ChatAnswerOutput (AIチャット)", ChatAnswerOutput.generationSchema, context: context, model: model)
        await measureSchema("RecentDigestOutput (最近のあなた)", RecentDigestOutput.generationSchema, context: context, model: model)
        await measureSchema("ConflictDetectionOutput (矛盾検出)", ConflictDetectionOutput.generationSchema, context: context, model: model)
        await measureSchema("GraphTripleOutput (グラフ抽出)", GraphTripleOutput.generationSchema, context: context, model: model)
        await measureSchema("TopicNameOutput (トピック命名)", TopicNameOutput.generationSchema, context: context, model: model)
        await measureSchema("CategoryClassificationOutput (分類)", CategoryClassificationOutput.generationSchema, context: context, model: model)

        logger.notice("[TokenProbe] --- 代表プロンプトの素地 (本文なしの定型部分のみ) ---")
        // スキーマと比較するための、プロンプト側のおおよその baseline。
        // 実データ依存の本文は含めず、各 builder の固定文ぐらいの長さの合成テキストで測る。
        await measurePrompt("日本語 ~100字", String(repeating: "これはトークン計測用の日本語サンプル文です。", count: 5), model: model)
        await measurePrompt("日本語 ~300字", String(repeating: "これはトークン計測用の日本語サンプル文です。", count: 15), model: model)
        await measurePrompt("日本語 ~600字", String(repeating: "これはトークン計測用の日本語サンプル文です。", count: 30), model: model)

        logger.notice("[TokenProbe] ========== 完了 ==========")
        logger.notice("[TokenProbe] 読み方: respond(generating: X) の入力 ≒ schema(X) + プロンプト本文 + (出力予約)。schema が大きいほど overflow しやすい。")
    }

    private static func measureSchema(
        _ label: String,
        _ schema: GenerationSchema,
        context: Int,
        model: SystemLanguageModel
    ) async {
        do {
            let n = try await model.tokenCount(for: schema)
            let pct = context > 0 ? Int(Double(n) / Double(context) * 100) : 0
            logger.notice("[TokenProbe] schema \(label, privacy: .public) = \(n, privacy: .public) tokens (窓の \(pct, privacy: .public)% / 残り \(context - n, privacy: .public))")
        } catch {
            logger.error("[TokenProbe] schema \(label, privacy: .public) 計測失敗: \(String(describing: error), privacy: .public)")
        }
    }

    private static func measurePrompt(
        _ label: String,
        _ prompt: String,
        model: SystemLanguageModel
    ) async {
        do {
            let n = try await model.tokenCount(for: prompt)
            logger.notice("[TokenProbe] prompt \(label, privacy: .public) (\(prompt.count, privacy: .public)字) = \(n, privacy: .public) tokens")
        } catch {
            logger.error("[TokenProbe] prompt \(label, privacy: .public) 計測失敗: \(String(describing: error), privacy: .public)")
        }
    }
}
#endif

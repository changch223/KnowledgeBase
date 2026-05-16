//
//  KnowledgeExtractor.swift
//  KnowledgeTree
//
//  spec 004 — contracts/knowledge-extractor.md
//
//  ExtractedText から prompt を組み立てて LanguageModelSession で生成する純粋ラッパ。
//  availability チェックは呼び出し側 (Service) の責務。
//  ハルシネーション抑止の strict instructions を prompt に埋め込む (research.md / R3)。
//

import Foundation

@MainActor
struct KnowledgeExtractor {
    let session: LanguageModelSessionProtocol

    /// 単発パス (本文 ≤ defaultMaxBodyChars) で使う上限。
    /// spec 006 で 1,200 → 1,000 に変更し、超過時は chunked パスに振り分ける。
    /// 1,000 chars × 1.7 token/char ≒ 1,700 token + prompt overhead ~500 token = 2,200 token、
    /// margin 約 1,900 token (4,096 - 2,200)。
    static let defaultMaxBodyChars = 1_000

    func extract(
        extractedText: String,
        maxBodyChars: Int = KnowledgeExtractor.defaultMaxBodyChars
    ) async throws -> ExtractedKnowledgeOutput {
        let truncated = Self.truncate(text: extractedText, maxChars: maxBodyChars)
        let prepared = await prepareForExtraction(truncated)
        let prompt = Self.buildPrompt(text: prepared)
        return try await session.generateKnowledge(prompt: prompt)
    }

    /// spec 006: 1 chunk を Foundation Models に渡して結果を ChunkResult として返す。
    /// throw しない (失敗は ChunkResult.error に格納)。
    func extractFromChunk(_ chunk: Chunk) async -> ChunkResult {
        let prepared = await prepareForExtraction(chunk.text)
        let prompt = Self.buildPrompt(text: prepared)
        do {
            let output = try await session.generateKnowledge(prompt: prompt)
            return ChunkResult(chunkIndex: chunk.index, output: output, error: nil)
        } catch {
            return ChunkResult(chunkIndex: chunk.index, output: nil, error: error)
        }
    }

    /// spec 042: 言語判定 + 英語なら翻訳して日本語化、それ以外はそのまま返す。
    /// 翻訳失敗 / 空 / 極端に短い結果は raw text を返して silent fallback (constitution V)。
    func prepareForExtraction(_ text: String) async -> String {
        guard LanguageDetector.detect(text) == .english else { return text }
        do {
            let prompt = Self.buildTranslationPrompt(text: text)
            let translated = try await session.generateTranslation(prompt: prompt)
            let trimmed = translated.trimmingCharacters(in: .whitespacesAndNewlines)
            // 翻訳結果が極端に短い (元の 1/4 未満) → 失敗扱いで raw を返す
            guard trimmed.count >= max(20, text.count / 4) else { return text }
            return trimmed
        } catch {
            return text
        }
    }

    /// spec 042: 英語 → 日本語の翻訳 prompt。固有名詞は原文維持を指示。
    static func buildTranslationPrompt(text: String) -> String {
        """
        次の英文を日本語に訳してください。

        # ルール
        - 固有名詞 (会社名・人名・技術名・製品名・地名) は英語のまま残してください
        - 訳文のみを出力し、説明や前置きは書かないでください
        - 元の段落構造を保ってください

        # 本文
        \(text)
        """
    }

    /// spec 006: 全 chunk の essence を統合して 1 つの essence + summary を生成。
    /// 入力空 / 失敗時は nil を返す (Aggregator で fallback 処理)。
    func extractMetaSummary(chunkEssences: [String]) async -> ExtractedKnowledgeOutput? {
        let nonEmpty = chunkEssences.filter { !$0.isEmpty }
        guard !nonEmpty.isEmpty else { return nil }
        let prompt = Self.buildMetaSummaryPrompt(chunkEssences: nonEmpty)
        do {
            return try await session.generateKnowledge(prompt: prompt)
        } catch {
            return nil
        }
    }

    /// 本文が長すぎる場合は冒頭から maxChars 文字に切り詰める。
    /// 末尾を捨てるのは情報損失だが、context window を超えると一切生成できないため
    /// MVP では先頭優先で運用する (記事の主題は冒頭に集中する傾向)。
    static func truncate(text: String, maxChars: Int) -> String {
        guard text.count > maxChars else { return text }
        let prefix = text.prefix(maxChars)
        // 単語/文の途中で切れないよう、最後の句点 / 改行までトリミング
        if let lastPeriod = prefix.lastIndex(where: { "。．\n".contains($0) }) {
            return String(prefix[..<lastPeriod]) + "。"
        }
        return String(prefix)
    }

    /// research.md / R3 のハルシネーション抑止 strict instructions を含む日本語 prompt。
    /// FR-020 (元記事に明示されている内容のみ + 推測禁止 + 整合性) を必ず含める。
    static func buildPrompt(text: String) -> String {
        """
        以下の記事本文から構造化された知識を抽出してください。

        # 抽出ルール (厳守)
        - 元記事に明示されている内容のみを抽出してください
        - 推測・補完・常識による補強は行わないでください
        - 該当する事実が見つからない場合は空配列を返してください
        - essence と summary と key facts は互いに矛盾しないでください
        - すべて日本語で出力してください

        # 元記事本文
        \(text)
        """
    }

    /// spec 006: meta-summary 専用 prompt。本文ではなく chunk 別 essence を入力に取る。
    static func buildMetaSummaryPrompt(chunkEssences: [String]) -> String {
        let numbered = chunkEssences.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        return """
        以下は記事の各部分から抽出した要点です。これらを統合して、記事全体の essence と summary を作ってください。

        # 統合ルール (厳守)
        - 各部分の要点に明示されている内容のみを使ってください
        - 推測・補完・常識による情報の追加は行わないでください
        - essence と summary は互いに矛盾しないでください
        - keyFacts と entities は空配列で返してください (本 prompt では生成しません)
        - すべて日本語で出力してください

        # 各部分の要点
        \(numbered)
        """
    }
}

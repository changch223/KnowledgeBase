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

    /// Foundation Models on-device の context window 上限 (~4096 tokens)。
    /// 実測 (zenn.dev/icare): 1,800 chars でも 4,096 token を超えるケース有 (記事末尾構造による)。
    /// 1,200 chars × 1.7 ≒ 2,040 token + prompt overhead ~500 + safety margin で 4,096 内に確実に収まる。
    /// 情報量は減るが、context window エラーで一切生成できないより冒頭優先で確実に走らせる方を優先。
    /// 末尾を含む全文要約には将来 chunked summarization (spec 006 候補) で対応。
    static let defaultMaxBodyChars = 1_200

    func extract(
        extractedText: String,
        maxBodyChars: Int = KnowledgeExtractor.defaultMaxBodyChars
    ) async throws -> ExtractedKnowledgeOutput {
        let truncated = Self.truncate(text: extractedText, maxChars: maxBodyChars)
        let prompt = Self.buildPrompt(text: truncated)
        return try await session.generateKnowledge(prompt: prompt)
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
}

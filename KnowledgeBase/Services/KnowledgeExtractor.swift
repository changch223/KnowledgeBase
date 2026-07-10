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
import os

@MainActor
struct KnowledgeExtractor {
    let session: LanguageModelSessionProtocol

    /// spec 042: 翻訳失敗時に SettingsView の誘導 flag を立てるための optional 依存。
    /// nil なら failure tracking ゼロ (テスト経路)。
    let translationAvailability: TranslationAvailabilityProtocol?

    /// spec 096 (perf): 翻訳結果のセッションキャッシュ (nil なら毎回翻訳)。
    let translationCache: TranslationCache?

    init(
        session: LanguageModelSessionProtocol,
        translationAvailability: TranslationAvailabilityProtocol? = nil,
        translationCache: TranslationCache? = nil
    ) {
        self.session = session
        self.translationAvailability = translationAvailability
        self.translationCache = translationCache
    }

    /// spec 042: 翻訳前処理の挙動を実機 (Console.app) で diagnose するための logger。
    /// subsystem は他 service と統一、category は "extractor"。
    private static let logger = Logger(subsystem: "app.KnowledgeTree", category: "extractor")

    /// 単発パス (本文 ≤ defaultMaxBodyChars) で使う上限。
    /// spec 006: 1,200 → 1,000 / spec 051 spike: 1,000 → 600 / V3.0 polish: 600 → 400。
    /// Foundation Models 4096 token 制限のうち @Generable schema serialization (~1500 tokens) +
    /// FM internal overhead (~1500 tokens) で実質 user 入力余地は ~1000 tokens のみ。
    /// 実機ログで 600 字 chunked でも英語翻訳後 + Generable schema で 4089-4095 tokens 連発 →
    /// 安全のため 400 字 ≈ 600 tokens まで下げる (margin 1.5x)。
    /// 単発パスは full schema (ExtractedKnowledgeOutput、出力予約大) なので短い記事専用。
    /// 案A (2026-06-12): 長文は小型スキーマの chunked パスに回すため、単発の上限は 400 に据える。
    static let defaultMaxBodyChars = 400

    func extract(
        extractedText: String,
        maxBodyChars: Int = KnowledgeExtractor.defaultMaxBodyChars,
        guidance: String? = nil
    ) async throws -> ExtractedKnowledgeOutput {
        let stripped = Self.stripCodeBlocks(from: extractedText)
        let truncated = Self.truncate(text: stripped, maxChars: maxBodyChars)
        let prepared = await prepareForExtraction(truncated)
        let prompt = Self.buildPrompt(text: prepared, guidance: guidance)
        return try await session.generateKnowledge(prompt: prompt)
    }

    /// spec 006: 1 chunk を Foundation Models に渡して結果を ChunkResult として返す。
    /// throw しない (失敗は ChunkResult.error に格納)。
    /// spec 101: sourceLanguage を渡すと chunk ごとの言語再判定をスキップ (記事単位で 1 回判定する経路用)。
    func extractFromChunk(_ chunk: Chunk, guidance: String? = nil, sourceLanguage: DetectedLanguage? = nil) async -> ChunkResult {
        let stripped = Self.stripCodeBlocks(from: chunk.text)
        let prepared = await prepareForExtraction(stripped, override: sourceLanguage)
        // 案A: chunk は小型スキーマ (ChunkKnowledgeOutput) で抽出 → 出力予約が減り chunk を大きくできる。
        let prompt = Self.buildChunkPrompt(text: prepared, guidance: guidance)
        do {
            let slim = try await session.generateChunkKnowledge(prompt: prompt)
            // aggregator は ExtractedKnowledgeOutput を期待するので変換 (summary は per-chunk 不使用 → 空)。
            let output = ExtractedKnowledgeOutput(
                essence: slim.essence,
                summary: "",
                keyFacts: slim.keyFacts,
                entities: slim.entities
            )
            return ChunkResult(chunkIndex: chunk.index, output: output, error: nil)
        } catch {
            return ChunkResult(chunkIndex: chunk.index, output: nil, error: error)
        }
    }

    /// spec 042 / i18n Phase B: 言語判定 + パイプライン言語 (PipelineLanguage.current) と異なる
    /// 言語なら翻訳してパイプライン言語化、一致 (または判定不能) ならそのまま返す。
    /// 翻訳失敗 / 空 / 極端に短い結果は raw text を返して silent fallback (constitution V)。
    /// Console.app (subsystem: app.KnowledgeTree, category: extractor) で挙動を追跡可能。
    /// spec 101: override に記事単位で判定した言語を渡すと、chunk ごとの再判定をスキップする
    /// (長文記事を chunk 分割すると参照・数式・著者名などの断片が id/fr/nl 等に誤検知され、
    ///  無駄で遅い翻訳 + translationd クラッシュを招くため、記事単位 1 回判定に寄せる)。
    func prepareForExtraction(_ text: String, override: DetectedLanguage? = nil) async -> String {
        let detected = override ?? LanguageDetector.detect(text)
        Self.logger.notice("translate prep: detected=\(String(describing: detected), privacy: .public) inputChars=\(text.count) override=\(override != nil)")
        // i18n Phase B: 「パイプライン言語 (PipelineLanguage.current) 以外」を全て翻訳対象に一般化。
        // .unknown (短文・判定不能) はそのまま返す (誤翻訳を避ける)。既定 ja パイプラインでは
        // `matches(detected:)` が .japanese のときのみ true になるため、spec 093 までの挙動と完全一致する。
        let source: String
        switch detected {
        case .japanese:
            source = "ja"
        case .english:
            source = "en"
        case .other(let raw):
            source = raw
        case .unknown:
            return text
        }
        if PipelineLanguage.current.matches(detected: detected) {
            return text
        }
        // spec 101: この言語が notInstalled で失敗済みなら以後スキップ (raw を使う、再試行しない)。
        if translationCache?.isUnavailable(source: source) == true {
            Self.logger.notice("translate skip: source=\(source, privacy: .public) unavailable (notInstalled) → raw")
            return text
        }
        // spec 096 (perf): 同じ本文を再翻訳しない (再抽出/カスタマイズ/backfill で頻発)。
        if let hit = translationCache?.cached(source: source, text: text) {
            Self.logger.notice("translate cache hit: source=\(source, privacy: .public) chars=\(text.count)")
            return hit
        }
        let start = Date()
        do {
            let translated = try await session.translate(text: text, source: source)
            let trimmed = translated.trimmingCharacters(in: .whitespacesAndNewlines)
            let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
            let minRequired = max(20, text.count / 4)
            // 翻訳結果が極端に短い (元の 1/4 未満) → 失敗扱いで raw を返す (キャッシュしない)
            guard trimmed.count >= minRequired else {
                Self.logger.notice("translate fallback: too short translated=\(trimmed.count) required=\(minRequired) elapsedMs=\(elapsedMs)")
                return text
            }
            Self.logger.notice("translate ok: input=\(text.count) translated=\(trimmed.count) elapsedMs=\(elapsedMs)")
            translationCache?.put(source: source, text: text, translated: trimmed)
            return trimmed
        } catch {
            let desc = String(describing: error)
            // spec 101: 翻訳モデル未インストール (notInstalled) はこの言語を以後スキップ
            // (同記事の他 chunk で同じ失敗を繰り返し translationd をクラッシュさせるのを防ぐ)。
            if desc.contains("notInstalled") {
                translationCache?.markUnavailable(source: source)
                Self.logger.error("translate notInstalled for source=\(source, privacy: .public) → mark unavailable, raw を使用")
            } else {
                Self.logger.error("translate failed: \(desc, privacy: .public)")
            }
            // spec 042: 翻訳失敗 → SettingsView の誘導 flag を立てる (calm UX、UI 喚起なし)
            translationAvailability?.markNeedsSetup()
            return text
        }
    }

    /// spec 006: 全 chunk の essence を統合して 1 つの essence + summary を生成。
    /// 入力空 / 失敗時は nil を返す (Aggregator で fallback 処理)。
    func extractMetaSummary(chunkEssences: [String], guidance: String? = nil) async -> ExtractedKnowledgeOutput? {
        let nonEmpty = chunkEssences.filter { !$0.isEmpty }
        guard !nonEmpty.isEmpty else { return nil }
        let prompt = Self.buildMetaSummaryPrompt(chunkEssences: nonEmpty, guidance: guidance)
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

    /// research.md / R3 のハルシネーション抑止 strict instructions を含む prompt。
    /// FR-020 (元記事に明示されている内容のみ + 推測禁止 + 整合性) を必ず含める。
    /// i18n Phase B: 出力言語は `language` (既定 `PipelineLanguage.current`) に追従する。
    static func buildPrompt(text: String, guidance: String? = nil, language: PipelineLanguage = .current) -> String {
        """
        以下の記事本文から構造化された知識を抽出してください。
        出力言語: \(language.endonym)。スキーマの説明文が日本語でも、出力は必ず \(language.endonym) で書くこと。
        \(guidanceClause(guidance))
        # 抽出ルール (厳守)
        - 元記事に明示されている内容のみを抽出してください
        - 推測・補完・常識による補強は行わないでください
        - 該当する事実が見つからない場合は空配列を返してください
        - essence と summary と key facts は互いに矛盾しないでください
        - key facts は重要度が高い順に最大 10 件まで返してください
        - コード片・関数呼び出し・コマンド出力は key facts に含めないでください (自然言語の事実のみ)
        - entities は主題に関わる固有名詞 (人物・組織・製品・具体的な技術/概念) のみ。一般語・代名詞・地名・日付 (男性/ユーザー/企業/東京駅 等) は除外し、表記を統一 (クロード→Claude)
        - \(language.outputInstruction) (固有名詞の原語表記は維持可)

        # 元記事本文
        \(text)
        """
    }

    /// spec 096: ユーザー指定の抽出方向を prompt に注入する句。
    /// 本文にある範囲で観点を寄せるだけ (新情報の捏造はしない)。空なら空文字。
    static func guidanceClause(_ guidance: String?) -> String {
        let g = (guidance ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !g.isEmpty else { return "" }
        let capped = String(g.prefix(200))
        return """

        # 抽出の方向性 (ユーザー指定 — 本文にある範囲でこの観点を重視)
        \(capped)

        """
    }

    /// 案A: chunked 抽出用の簡潔な prompt (小型スキーマ ChunkKnowledgeOutput とペア)。
    /// 定型部を短くして chunk 本文に枠を回す + 出力 ≤4 件を明示。
    /// i18n Phase B: 出力言語は `language` (既定 `PipelineLanguage.current`) に追従する。
    static func buildChunkPrompt(text: String, guidance: String? = nil, language: PipelineLanguage = .current) -> String {
        """
        以下は記事の一部です。この部分から構造化された知識を抽出してください。
        出力言語: \(language.endonym)。スキーマの説明文が日本語でも、出力は必ず \(language.endonym) で書くこと。
        \(guidanceClause(guidance))
        # ルール (厳守)
        - 元記事に明示されている内容のみ。推測・補完は禁止
        - keyFacts は重要な事実を最大 4 件 (自然言語の事実のみ、コード片は除く)
        - entities は主題に関わる固有名詞 (人物・組織・製品・具体的な技術/概念) を最大 4 件。一般語・代名詞・地名・日付は除外
        - \(language.outputInstruction) (固有名詞の原語表記は維持可)

        # 本文の一部
        \(text)
        """
    }

    /// 記事本文からコードブロックを取り除く純粋関数。コード片混入は KeyFact の品質を下げ、
    /// Foundation Models のトークンも食うため、抽出パイプ入口で削る。
    /// 削るもの:
    ///   - ``` fenced code block (3 個以上のバッククォートで囲まれた範囲、改行越え可)
    ///   - ~~~ alternate fence
    ///   - 連続するインデント (4 スペース or タブ始まり) 行ブロック
    ///   - `inline code` (バッククォート 1 個で囲まれた単一行スパン、改行は跨がない)
    /// 残すもの: バッククォートを含まない通常の文章 / 句読点 / 全角文字。
    static func stripCodeBlocks(from text: String) -> String {
        var working = text

        // 1. ``` または ~~~ で囲まれた fenced block を改行越えで削除
        if let regex = try? NSRegularExpression(
            pattern: "(```|~~~)[\\s\\S]*?\\1",
            options: []
        ) {
            let range = NSRange(working.startIndex..., in: working)
            working = regex.stringByReplacingMatches(in: working, options: [], range: range, withTemplate: " ")
        }

        // 2. 行頭 4 スペース or タブで始まる連続行 (indented code block)
        let lines = working.split(separator: "\n", omittingEmptySubsequences: false)
        var keptLines: [String] = []
        for line in lines {
            let isIndentedCode = line.hasPrefix("    ") || line.hasPrefix("\t")
            if isIndentedCode {
                continue
            }
            keptLines.append(String(line))
        }
        working = keptLines.joined(separator: "\n")

        // 3. inline `code` (改行を跨がないシングルバッククォート) は中身ごと削除
        if let regex = try? NSRegularExpression(
            pattern: "`[^`\\n]*`",
            options: []
        ) {
            let range = NSRange(working.startIndex..., in: working)
            working = regex.stringByReplacingMatches(in: working, options: [], range: range, withTemplate: " ")
        }

        // 4. 連続する空白行を 1 行に圧縮
        if let regex = try? NSRegularExpression(pattern: "\\n{3,}", options: []) {
            let range = NSRange(working.startIndex..., in: working)
            working = regex.stringByReplacingMatches(in: working, options: [], range: range, withTemplate: "\n\n")
        }

        return working.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// spec 006: meta-summary 専用 prompt。本文ではなく chunk 別 essence を入力に取る。
    /// i18n Phase B: 出力言語は `language` (既定 `PipelineLanguage.current`) に追従する。
    static func buildMetaSummaryPrompt(chunkEssences: [String], guidance: String? = nil, language: PipelineLanguage = .current) -> String {
        let numbered = chunkEssences.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        return """
        以下は記事の各部分から抽出した要点です。これらを統合して、記事全体の essence と summary を作ってください。
        出力言語: \(language.endonym)。スキーマの説明文が日本語でも、出力は必ず \(language.endonym) で書くこと。
        \(guidanceClause(guidance))
        # 統合ルール (厳守)
        - 各部分の要点に明示されている内容のみを使ってください
        - 推測・補完・常識による情報の追加は行わないでください
        - essence と summary は互いに矛盾しないでください
        - keyFacts と entities は空配列で返してください (本 prompt では生成しません)
        - \(language.outputInstruction)

        # 各部分の要点
        \(numbered)
        """
    }
}

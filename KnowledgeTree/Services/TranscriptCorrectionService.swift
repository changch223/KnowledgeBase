//
//  TranscriptCorrectionService.swift
//  KnowledgeTree
//
//  spec 094 — 音声文字起こしの用語補正。
//  音声認識は固有名詞・専門用語を音で誤る (例: Claude Code → gloadcod / cloadcod)。
//  既知の正しい用語集 (既存の概念ページ名・タグ名 + 内蔵テック用語) をヒントとして
//  LLM に渡し、明らかに対応する誤認識だけを正しい表記に直す再処理を行う。
//  アプリ target 専用 (LLM 依存)。
//

import Foundation
import SwiftData
import os

protocol TranscriptCorrecting: Sendable {
    /// 文字起こしを用語集ヒントで補正。glossary 空 / 失敗時は原文を返す。
    /// spec 096: onWindow(completed, total) で window 進捗を通知する。
    func correct(_ transcript: String, glossary: [String],
                 onWindow: @Sendable (Int, Int) async -> Void) async -> String

    /// spec 095: ユーザーの自然言語の訂正指示を本文に適用 (例:「cloudecod ではなく Claude Code です」)。
    /// 指示空 / 失敗時は原文を返す。
    func applyInstruction(_ text: String, instruction: String,
                          onWindow: @Sendable (Int, Int) async -> Void) async -> String
}

extension TranscriptCorrecting {
    /// 進捗不要な既存呼び出し向けの簡易版 (audio backfill / AddArticleSheet 等)。
    func correct(_ transcript: String, glossary: [String]) async -> String {
        await correct(transcript, glossary: glossary, onWindow: { _, _ in })
    }
    func applyInstruction(_ text: String, instruction: String) async -> String {
        await applyInstruction(text, instruction: instruction, onWindow: { _, _ in })
    }
}

struct LLMTranscriptCorrectionService: TranscriptCorrecting {
    let session: LanguageModelSessionProtocol

    /// 訂正フローの追跡用ログ (Console.app: subsystem app.KnowledgeTree, category correction)。
    private static let logger = Logger(subsystem: "app.KnowledgeTree", category: "correction")

    /// 1 回の LLM 呼び出しで補正する文字数の目安。
    private let windowChars = 800
    /// プロンプトに載せる用語集の上限。
    private let maxGlossaryTerms = 40
    /// 長文の暴走を防ぐ補正 window の上限 (超過分は原文のまま連結)。
    private let maxWindows = 20

    func correct(_ transcript: String, glossary: [String],
                 onWindow: @Sendable (Int, Int) async -> Void) async -> String {
        let terms = Array(glossary.prefix(maxGlossaryTerms))
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !terms.isEmpty, trimmed.count >= 20 else { return transcript }

        let windows = Self.splitIntoWindows(trimmed, size: windowChars)
        await onWindow(0, windows.count)
        var corrected: [String] = []
        for (index, window) in windows.enumerated() {
            if index >= maxWindows {
                corrected.append(window)  // 上限超過分は補正せずそのまま
            } else {
                corrected.append(await correctWindow(window, terms: terms))
            }
            await onWindow(index + 1, windows.count)
        }
        let result = corrected.joined()

        // 防御: 長さが大きく変わったら誤補正の疑い → 原文を返す (constitution V)。
        let ratio = Double(result.count) / Double(max(1, trimmed.count))
        guard !result.isEmpty, ratio >= 0.6, ratio <= 1.6 else { return transcript }
        return result
    }

    func applyInstruction(_ text: String, instruction: String,
                          onWindow: @Sendable (Int, Int) async -> Void) async -> String {
        let inst = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !inst.isEmpty, !trimmed.isEmpty else {
            Self.logger.info("applyInstruction skipped (empty instruction or text)")
            return text
        }

        let windows = Self.splitIntoWindows(trimmed, size: windowChars)
        Self.logger.info("""
            applyInstruction start: instruction=\(inst, privacy: .public) \
            textChars=\(trimmed.count) windows=\(windows.count) maxWindows=\(self.maxWindows)
            """)
        await onWindow(0, windows.count)
        var corrected: [String] = []
        var changedWindows = 0
        for (index, window) in windows.enumerated() {
            if index >= maxWindows {
                Self.logger.info("window[\(index)] skipped (over maxWindows), kept as-is")
                corrected.append(window)
                await onWindow(index + 1, windows.count)
                continue
            }
            let out = await applyInstructionToWindow(window, instruction: inst, index: index)
            if out != window { changedWindows += 1 }
            corrected.append(out)
            await onWindow(index + 1, windows.count)
        }
        let result = corrected.joined()
        let ratio = Double(result.count) / Double(max(1, trimmed.count))
        guard !result.isEmpty, ratio >= 0.6, ratio <= 1.6 else {
            Self.logger.error("""
                applyInstruction REJECTED by length guard: \
                resultChars=\(result.count) ratio=\(String(format: "%.2f", ratio)) → 原文を返す
                """)
            return text
        }
        Self.logger.info("""
            applyInstruction done: changedWindows=\(changedWindows)/\(windows.count) \
            resultChars=\(result.count) ratio=\(String(format: "%.2f", ratio)) changed=\(result != trimmed)
            """)
        return result
    }

    private func applyInstructionToWindow(_ text: String, instruction: String, index: Int) async -> String {
        let prompt = Self.buildInstructionPrompt(text: text, instruction: instruction)
        do {
            let out = try await session.generateTranscriptCorrection(prompt: prompt)
            let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
            // 暴走出力 (用語羅列・極端な短縮/膨張) は採用せず原文を維持。
            guard Self.acceptsWindowOutput(original: text, output: trimmed) else {
                Self.logger.error("window[\(index)] rejected (runaway output) → 原文維持 out=\(trimmed.count)字 in=\(text.count)字")
                return text
            }
            Self.logger.debug("""
                window[\(index)] in=\(text.count)字 out=\(trimmed.count)字 \
                changed=\(trimmed != text)
                before=\(text, privacy: .public)
                after=\(trimmed, privacy: .public)
                """)
            return trimmed
        } catch {
            Self.logger.error("window[\(index)] LLM failed: \(String(describing: error), privacy: .public) → 原文維持")
            return text
        }
    }

    private func correctWindow(_ text: String, terms: [String]) async -> String {
        let prompt = Self.buildPrompt(text: text, terms: terms)
        do {
            let out = try await session.generateTranscriptCorrection(prompt: prompt)
            let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
            // 暴走出力は採用せず原文を維持。
            guard Self.acceptsWindowOutput(original: text, output: trimmed) else { return text }
            return trimmed
        } catch {
            return text  // 失敗は原文維持 (silent fallback)
        }
    }

    /// spec 096: window 補正出力が暴走 (用語羅列・極端な短縮/膨張) していないか判定。
    /// false = 採用せず原文を維持。純関数 (テスト可)。
    static func acceptsWindowOutput(original: String, output: String) -> Bool {
        let o = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !o.isEmpty else { return false }
        // 長さが大きくずれたら誤出力 (補正は語の置換中心なので長さはほぼ不変のはず)。
        let ratio = Double(o.count) / Double(max(1, original.count))
        guard ratio >= 0.5, ratio <= 1.8 else { return false }
        // リスト化暴走: 入力よりずっと多い短い行が並ぶ = 用語羅列の疑い。
        let outLines = o.split(separator: "\n")
        let inLines = original.split(separator: "\n").count
        if outLines.count >= 6, outLines.count > max(inLines * 2, inLines + 4) {
            let shortLines = outLines.filter {
                $0.trimmingCharacters(in: .whitespaces).count <= 24
            }.count
            if Double(shortLines) / Double(outLines.count) > 0.7 { return false }
        }
        return true
    }

    // MARK: - 純関数 (テスト可)

    static func buildPrompt(text: String, terms: [String]) -> String {
        """
        あなたは音声文字起こしの校正者です。次の文字起こしには、固有名詞や専門用語が音で\
        誤って認識された箇所があります。下の「用語集」に明らかに対応すると判断できる誤認識\
        だけを、用語集の正しい表記に置き換えてください。
        - 用語集に対応しない語は変えない。要約・追加・削除・言い換えをしない。語順もそのまま。
        - 確信が持てない箇所は変えない。
        - 校正後の文字起こし本文だけを出力する (説明や見出しを付けない)。
        用語集: \(terms.joined(separator: "、"))
        文字起こし:
        \(text)
        """
    }

    static func buildInstructionPrompt(text: String, instruction: String) -> String {
        """
        次の文章に、ユーザーの訂正指示を適用してください。文字起こしや OCR では、同じ固有名詞・専門用語が\
        一つの文章の中で何通りにも誤って表記されることがあります\
        (例: 「Claude Code」が gloadcode / clodecode / cloudcode、「CLAUDE.md」が clodeMD など)。

        - 指示が示す「正しい表記」を基準にする。指示で例示された誤記だけでなく、\
          **音・つづりが近く、明らかに同じものを指していると判断できる表記ゆれ・誤変換・誤認識をすべて** 正しい表記に直す。
        - 同じ誤りに由来する関連語・派生語・複合語も合わせて直す\
          (例: 指示が「Claude Code」なら、近い綴りの「clodeMD」→「CLAUDE.md」のように、\
          同じ対象を指すと分かるものは判断して直す)。
        - 文章の最初から最後まで通して見て、該当する表記を一箇所も残さず直す。
        - ただし、指示と無関係な語は変えない。要約・追加・削除・言い換えはしない。語順もそのまま。
        - 訂正後の文章本文だけを出力する (説明や見出しを付けない)。
        訂正指示: \(instruction)
        文章:
        \(text)
        """
    }

    /// 文を「。」「！」「？」「改行」優先で区切りつつ size 以内の window に詰める。
    static func splitIntoWindows(_ text: String, size: Int) -> [String] {
        guard text.count > size else { return [text] }
        var windows: [String] = []
        var current = ""
        var sentence = ""
        let breakers: Set<Character> = ["。", "！", "？", "\n", ".", "!", "?"]

        func flushSentence() {
            guard !sentence.isEmpty else { return }
            if current.count + sentence.count > size, !current.isEmpty {
                windows.append(current)
                current = ""
            }
            current += sentence
            sentence = ""
        }

        for char in text {
            sentence.append(char)
            if breakers.contains(char) {
                flushSentence()
            }
            // 1 文が size 超 → 強制分割
            if sentence.count >= size {
                flushSentence()
                if current.count >= size {
                    windows.append(current)
                    current = ""
                }
            }
        }
        flushSentence()
        if !current.isEmpty { windows.append(current) }
        return windows.isEmpty ? [text] : windows
    }
}

// MARK: - 用語集ビルダー

enum TranscriptGlossaryBuilder {
    /// 内蔵テック用語 (新規記事で未登録でも頻出する固有名詞)。
    static let seedTerms: [String] = [
        "Claude", "Claude Code", "Anthropic", "ChatGPT", "OpenAI", "Gemini",
        "GitHub", "Xcode", "Swift", "SwiftUI", "SwiftData", "Foundation Models",
        "Apple Intelligence", "iPhone", "iPad", "macOS", "iOS", "Cursor",
        "Visual Studio Code", "Python", "JavaScript", "TypeScript"
    ]

    /// 既存の概念ページ名 + タグ名 + 内蔵用語から用語集を作る。
    /// 英字を含む固有名詞 (音声で誤りやすい) を優先。
    @MainActor
    static func build(context: ModelContext, limit: Int = 40) -> [String] {
        var names: [String] = []

        let conceptDescriptor = FetchDescriptor<ConceptPage>(
            predicate: #Predicate { $0.isHidden == false }
        )
        if let pages = try? context.fetch(conceptDescriptor) {
            names += pages.map(\.name)
        }
        if let tags = try? context.fetch(FetchDescriptor<Tag>()) {
            names += tags.map(\.name)
        }
        names += seedTerms

        // 正規化 + 重複排除 (大小無視)。
        var seen = Set<String>()
        var result: [String] = []
        for raw in names {
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.count >= 2 else { continue }
            let key = name.lowercased()
            if seen.insert(key).inserted { result.append(name) }
        }

        // 英字を含む語 (音声誤認識の主対象) を前に。
        let hasLatin: (String) -> Bool = { $0.range(of: "[A-Za-z]", options: .regularExpression) != nil }
        let latin = result.filter(hasLatin)
        let nonLatin = result.filter { !hasLatin($0) }
        return Array((latin + nonLatin).prefix(limit))
    }
}

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

protocol TranscriptCorrecting: Sendable {
    /// 文字起こしを用語集ヒントで補正。glossary 空 / 失敗時は原文を返す。
    func correct(_ transcript: String, glossary: [String]) async -> String

    /// spec 095: ユーザーの自然言語の訂正指示を本文に適用 (例:「cloudecod ではなく Claude Code です」)。
    /// 指示空 / 失敗時は原文を返す。
    func applyInstruction(_ text: String, instruction: String) async -> String
}

struct LLMTranscriptCorrectionService: TranscriptCorrecting {
    let session: LanguageModelSessionProtocol

    /// 1 回の LLM 呼び出しで補正する文字数の目安。
    private let windowChars = 800
    /// プロンプトに載せる用語集の上限。
    private let maxGlossaryTerms = 40
    /// 長文の暴走を防ぐ補正 window の上限 (超過分は原文のまま連結)。
    private let maxWindows = 20

    func correct(_ transcript: String, glossary: [String]) async -> String {
        let terms = Array(glossary.prefix(maxGlossaryTerms))
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !terms.isEmpty, trimmed.count >= 20 else { return transcript }

        let windows = Self.splitIntoWindows(trimmed, size: windowChars)
        var corrected: [String] = []
        for (index, window) in windows.enumerated() {
            if index >= maxWindows {
                corrected.append(window)  // 上限超過分は補正せずそのまま
                continue
            }
            corrected.append(await correctWindow(window, terms: terms))
        }
        let result = corrected.joined()

        // 防御: 長さが大きく変わったら誤補正の疑い → 原文を返す (constitution V)。
        let ratio = Double(result.count) / Double(max(1, trimmed.count))
        guard !result.isEmpty, ratio >= 0.6, ratio <= 1.6 else { return transcript }
        return result
    }

    func applyInstruction(_ text: String, instruction: String) async -> String {
        let inst = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !inst.isEmpty, !trimmed.isEmpty else { return text }

        let windows = Self.splitIntoWindows(trimmed, size: windowChars)
        var corrected: [String] = []
        for (index, window) in windows.enumerated() {
            if index >= maxWindows {
                corrected.append(window)
                continue
            }
            corrected.append(await applyInstructionToWindow(window, instruction: inst))
        }
        let result = corrected.joined()
        let ratio = Double(result.count) / Double(max(1, trimmed.count))
        guard !result.isEmpty, ratio >= 0.6, ratio <= 1.6 else { return text }
        return result
    }

    private func applyInstructionToWindow(_ text: String, instruction: String) async -> String {
        let prompt = Self.buildInstructionPrompt(text: text, instruction: instruction)
        do {
            let out = try await session.generateTranscriptCorrection(prompt: prompt)
            let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? text : trimmed
        } catch {
            return text
        }
    }

    private func correctWindow(_ text: String, terms: [String]) async -> String {
        let prompt = Self.buildPrompt(text: text, terms: terms)
        do {
            let out = try await session.generateTranscriptCorrection(prompt: prompt)
            let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? text : trimmed
        } catch {
            return text  // 失敗は原文維持 (silent fallback)
        }
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
        次の文章に、ユーザーの訂正指示を適用してください。
        - 指示に該当する箇所だけを直す。それ以外は一切変えない。要約・追加・削除・言い換えをしない。語順もそのまま。
        - 指示と無関係な箇所はそのまま残す。
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

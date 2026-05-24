//
//  AgentAction.swift
//  KnowledgeTree
//
//  spec 057 — Agentic Chat の中核 Generable struct。
//  LLM が agent loop の毎 turn で返す、Swift 側で switch 分岐して状態遷移する。
//  Apple Foundation Models の Tool Use 不在の代替パターン (spec 044 同思想)。
//
//  Generable enum は @Guide 制約 + UUID 型非対応のため struct + actionType String 化:
//  - actionType: "immediate" / "askClarification" / "searchArticles" / "finalAnswer"
//  - text: 各 case の主要 text (answer / question / query / finalAnswer text)
//  - suggestions: askClarification の 3 候補、それ以外は空
//  - citedArticleIDs: finalAnswer の引用記事 ID (UUID 文字列)、それ以外は空
//

import Foundation
import FoundationModels

@Generable
struct AgentActionOutput: Sendable {
    @Guide(description: "アクション種別。'immediate' (即答可能) / 'askClarification' (聞き返し必要) / 'searchArticles' (記事検索必要) / 'finalAnswer' (検索結果統合後の最終答え) のいずれか。")
    var actionType: String

    @Guide(description: "主要テキスト。immediate なら answer 本文、askClarification なら聞き返し question、searchArticles なら検索 query、finalAnswer なら answer 本文。")
    var text: String

    @Guide(description: "askClarification の場合の 3 候補 (各 30 字以内)、それ以外は空配列。")
    var suggestions: [String]

    @Guide(description: "finalAnswer の引用記事 ID (UUID 文字列) 配列 (max 5 件)、それ以外は空配列。")
    var citedArticleIDs: [String]
}

// MARK: - AgentAction (Swift 側の type-safe enum)

/// LLM 出力 (AgentActionOutput) を Swift 側で switch 分岐用 enum に変換した型。
enum AgentAction: Sendable, Equatable {
    case immediate(answer: String)
    case askClarification(question: String, suggestions: [String])
    case searchArticles(query: String)
    case finalAnswer(text: String, citedArticleIDs: [UUID])

    /// LLM 出力 (AgentActionOutput) を解析して enum に変換。
    /// actionType が不正 / 必須 field が空のときは .immediate(text) で fallback。
    init(from output: AgentActionOutput) {
        switch output.actionType.lowercased() {
        case "immediate":
            self = .immediate(answer: output.text)

        case "askclarification", "ask_clarification", "clarification":
            // 3 候補 (足りなければ空文字埋め、超過すれば切る)
            var suggestions = output.suggestions
            while suggestions.count < 3 { suggestions.append("") }
            self = .askClarification(question: output.text, suggestions: Array(suggestions.prefix(3)))

        case "searcharticles", "search_articles", "search":
            self = .searchArticles(query: output.text)

        case "finalanswer", "final_answer", "final":
            // citedArticleIDs (String) → UUID 変換、不正な ID は skip
            let uuids = output.citedArticleIDs.compactMap { UUID(uuidString: $0) }
            self = .finalAnswer(text: output.text, citedArticleIDs: Array(uuids.prefix(5)))

        default:
            // 不明な actionType → text を answer として fallback (「分かりません」回避)
            self = .immediate(answer: output.text)
        }
    }
}

// MARK: - Convenience

extension AgentAction {
    /// 表示用主 text。
    var displayText: String {
        switch self {
        case .immediate(let a): return a
        case .askClarification(let q, _): return q
        case .searchArticles(let q): return "保存記事を検索: \(q)"
        case .finalAnswer(let t, _): return t
        }
    }

    /// clarification の場合の chip suggestions、それ以外は []。
    var suggestions: [String] {
        if case .askClarification(_, let suggestions) = self {
            return suggestions.filter { !$0.isEmpty }
        }
        return []
    }

    /// finalAnswer の引用記事 ID 配列、それ以外は []。
    var citedArticleIDs: [UUID] {
        if case .finalAnswer(_, let ids) = self {
            return ids
        }
        return []
    }
}

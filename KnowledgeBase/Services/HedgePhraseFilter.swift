//
//  HedgePhraseFilter.swift
//  KnowledgeTree
//
//  spec 057 — agent loop の最終出力に対して、「分かりません」「答えられません」等の
//  banned phrase を hedge phrase (「私の理解では」「一般的には」) に置換する純粋関数。
//  prompt 制約 + post-process filter の二段構えで「分かりません」廃止を保証。
//

import Foundation

enum HedgePhraseFilter {
    /// 排除対象キーワード (これらが含まれていたら hedge に置換)。
    static let bannedPhrases: [String] = [
        "分かりません",
        "わかりません",
        "分かりかねます",
        "答えられません",
        "回答できません",
        "情報がありません",
        "情報を持っていません",
        "知りません",
        "不明です",
        "お答えできません"
    ]

    /// 置換用 hedge phrase (ランダム選択、deterministic test 用に seed 指定可能)。
    static let hedgeReplacements: [String] = [
        "私の理解では",
        "一般的には",
        "あくまで概要として",
        "確実ではありませんが"
    ]

    /// banned phrase が含まれていれば hedge に置換、そうでなければ原文を返す。
    /// - Parameter randomSource: テスト用に random 制御可能 (default: SystemRandomNumberGenerator)
    static func replace(_ text: String, randomSource: () -> Int = { Int.random(in: 0..<hedgeReplacements.count) }) -> String {
        var result = text
        for banned in bannedPhrases {
            while result.contains(banned) {
                let hedgeIndex = randomSource() % hedgeReplacements.count
                let hedge = hedgeReplacements[hedgeIndex]
                guard let range = result.range(of: banned) else { break }
                result.replaceSubrange(range, with: hedge)
            }
        }
        return result
    }

    /// 文字列に banned phrase が含まれているか判定 (test 用)。
    static func containsBanned(_ text: String) -> Bool {
        bannedPhrases.contains { text.contains($0) }
    }
}

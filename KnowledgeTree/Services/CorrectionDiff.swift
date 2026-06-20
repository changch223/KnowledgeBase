//
//  CorrectionDiff.swift
//  KnowledgeTree
//
//  spec 096 — 訂正/レビュー/手動編集で本文がどう変わったかを before→after の差分にする。
//  ① 文単位 LCS で原文と訂正後を位置合わせ
//  ② 変わった文ペアをトークン単位 LCS で精密化し「gloadcode → Claude Code」級の語句差分を抽出
//  ③ 同じ差分が複数回あればまとめて件数表示
//  巨大本文 (音声長文等) はコストガードで詳細を省略する。純関数のみ (テスト可)。
//

import Foundation

/// 訂正の種類 (ログ・表示用)。
enum CorrectionKind: String, Sendable {
    case review        // AI レビュー (用語集)
    case instruction   // 自然言語の指示訂正
    case manualEdit    // 本文の直接編集
}

/// 1 件の変更 (重複はまとめ、count に回数)。
struct CorrectionChange: Identifiable, Hashable, Sendable {
    let id: Int
    let before: String
    let after: String
    let count: Int
}

/// 差分の解析結果。
struct CorrectionDiffResult: Sendable {
    /// 変更箇所の総数 (重複含む)。
    let total: Int
    /// 重複をまとめた変更一覧。
    let changes: [CorrectionChange]
    /// false = 本文が大きすぎて詳細を省略した。
    let detailAvailable: Bool

    static let none = CorrectionDiffResult(total: 0, changes: [], detailAvailable: true)
}

/// 訂正処理中の進捗 (画面で見せる)。
struct CorrectionProgress: Sendable {
    enum Phase: Sendable {
        case correcting    // 本文を window 単位で見直し中
        case reExtracting  // 本文変更後の知識 (概念・タグ・要点) を作り直し中
    }
    let kind: CorrectionKind
    let phase: Phase
    /// correcting フェーズの完了 window 数 (reExtracting では 0)。
    let current: Int
    /// correcting フェーズの総 window 数 (reExtracting では 0 = 不定)。
    let total: Int
}

/// 見直し完了後、ユーザー確認待ちの候補本文 (まだ保存していない)。
struct PendingCorrection: Sendable {
    let original: String
    let candidate: String
    let diff: CorrectionDiffResult
}

/// 1 回の訂正の結果 (完了後に画面で見せる)。
struct CorrectionResult: Sendable {
    let articleID: UUID
    let kind: CorrectionKind
    /// 本文が変わったか (false = 変更なし)。
    let changed: Bool
    let originalCount: Int
    let correctedCount: Int
    /// 詳細差分が出せたか (false = 本文が大きすぎて省略)。
    let detailAvailable: Bool
    /// 変更箇所の総数 (重複含む)。
    let total: Int
    /// 重複をまとめた変更一覧。
    let changes: [CorrectionChange]
}

enum CorrectionDiff {
    /// 文単位 LCS の計算上限 (R*C)。超過時は詳細省略。
    private static let sentencePairBudget = 1_500_000
    /// 文ペア精密化のトークン LCS 上限。
    private static let tokenPairBudget = 200_000

    /// 原文 → 訂正後の差分を解析する。
    static func analyze(from original: String, to corrected: String, limit: Int = 50) -> CorrectionDiffResult {
        guard original != corrected else { return .none }

        let a = splitSentences(original)
        let b = splitSentences(corrected)
        if a.count * b.count > sentencePairBudget {
            return CorrectionDiffResult(total: 0, changes: [], detailAvailable: false)
        }

        let pairs = lcsPairs(a, b)
        var fragments: [(before: String, after: String)] = []
        var ai = 0, bi = 0, pi = 0
        while pi <= pairs.count {
            let nextA = pi < pairs.count ? pairs[pi].0 : a.count
            let nextB = pi < pairs.count ? pairs[pi].1 : b.count
            let removed = Array(a[ai..<nextA])
            let added = Array(b[bi..<nextB])
            fragments.append(contentsOf: blockFragments(removed: removed, added: added))
            if pi < pairs.count { ai = pairs[pi].0 + 1; bi = pairs[pi].1 + 1 }
            pi += 1
        }

        let total = fragments.count
        // 同じ (before, after) をまとめて件数化 (初出順を維持)。
        var order: [String] = []
        var counts: [String: Int] = [:]
        var pairOf: [String: (String, String)] = [:]
        for f in fragments {
            let key = f.before + "\u{0}" + f.after
            if counts[key] == nil { order.append(key); pairOf[key] = (f.before, f.after) }
            counts[key, default: 0] += 1
        }
        let changes = order.prefix(limit).enumerated().map { idx, key -> CorrectionChange in
            let (before, after) = pairOf[key]!
            return CorrectionChange(id: idx, before: before, after: after, count: counts[key] ?? 1)
        }
        return CorrectionDiffResult(total: total, changes: Array(changes), detailAvailable: true)
    }

    // MARK: - 文ブロックの差分

    private static func blockFragments(removed: [String], added: [String]) -> [(before: String, after: String)] {
        if removed.isEmpty && added.isEmpty { return [] }
        if removed.count == added.count {
            // 1:1 で対応 → 各文ペアをトークン単位で精密化。
            var out: [(String, String)] = []
            for k in 0..<removed.count {
                out.append(contentsOf: refine(removed[k], added[k]))
            }
            return out
        }
        // 文数が違う (追加/削除を含む) → 文ブロックごと before→after。
        if let pair = meaningfulPair(removed.joined(), added.joined()) { return [pair] }
        return []
    }

    /// 文ペアをトークン LCS で精密化し、変わった語句だけを取り出す。
    private static func refine(_ before: String, _ after: String) -> [(before: String, after: String)] {
        if before == after { return [] }
        let at = tokenize(before)
        let bt = tokenize(after)
        if at.count * bt.count > tokenPairBudget {
            return meaningfulPair(before, after).map { [$0] } ?? []
        }
        let pairs = lcsPairs(at, bt)
        var out: [(String, String)] = []
        var ai = 0, bi = 0, pi = 0
        while pi <= pairs.count {
            let nextA = pi < pairs.count ? pairs[pi].0 : at.count
            let nextB = pi < pairs.count ? pairs[pi].1 : bt.count
            let rem = at[ai..<nextA].joined()
            let add = bt[bi..<nextB].joined()
            if let pair = meaningfulPair(rem, add) { out.append(pair) }
            if pi < pairs.count { ai = pairs[pi].0 + 1; bi = pairs[pi].1 + 1 }
            pi += 1
        }
        // 精密化で何も取れなかった (空白だけ等) が文は違う → 文全体を見せる。
        if out.isEmpty, let pair = meaningfulPair(before, after) { return [pair] }
        return out
    }

    /// trim 後に意味のある差分だけ残す (空白だけ/同一は無視)。
    private static func meaningfulPair(_ before: String, _ after: String) -> (before: String, after: String)? {
        let b = before.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = after.trimmingCharacters(in: .whitespacesAndNewlines)
        if b == a { return nil }
        if b.isEmpty && a.isEmpty { return nil }
        return (b, a)
    }

    // MARK: - 分割・トークン化

    /// 「。」「！」「？」「.」「!」「?」「改行」で文に分ける (区切り文字は文末に残す)。
    static func splitSentences(_ text: String) -> [String] {
        let breakers: Set<Character> = ["。", "！", "？", "\n", ".", "!", "?"]
        var result: [String] = []
        var cur = ""
        for ch in text {
            cur.append(ch)
            if breakers.contains(ch) { result.append(cur); cur = "" }
        }
        if !cur.isEmpty { result.append(cur) }
        return result
    }

    /// ASCII 英数字を 1 トークンにまとめる。単一スペースで繋がる Latin 語句 (例「Claude Code」) や
    /// `._-/` で繋がる識別子 (例「CLAUDE.md」) も 1 トークン化。空白の連なりは 1 トークン、
    /// CJK・記号は 1 文字 1 トークン。→ 固有名詞を語句単位で diff できる。
    static func tokenize(_ s: String) -> [String] {
        let chars = Array(s)
        func isLatin(_ c: Character) -> Bool { c.isASCII && (c.isLetter || c.isNumber) }
        var tokens: [String] = []
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if isLatin(c) {
                var run = ""
                while i < chars.count {
                    let cc = chars[i]
                    let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
                    if isLatin(cc) {
                        run.append(cc); i += 1
                    } else if !run.isEmpty, let n = next, isLatin(n),
                              cc == " " || "._-/".contains(cc) {
                        // 後ろが Latin の時だけ、繋ぎのスペース/記号を語句に取り込む。
                        run.append(cc); i += 1
                    } else {
                        break
                    }
                }
                tokens.append(run)
            } else if c == " " || c == "\t" {
                var sp = ""
                while i < chars.count, chars[i] == " " || chars[i] == "\t" { sp.append(chars[i]); i += 1 }
                tokens.append(sp)
            } else {
                tokens.append(String(c)); i += 1
            }
        }
        return tokens
    }

    /// LCS の一致 index ペア列を返す (汎用)。
    private static func lcsPairs<T: Equatable>(_ a: [T], _ b: [T]) -> [(Int, Int)] {
        let n = a.count, m = b.count
        if n == 0 || m == 0 { return [] }
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                dp[i][j] = a[i] == b[j] ? dp[i + 1][j + 1] + 1 : max(dp[i + 1][j], dp[i][j + 1])
            }
        }
        var pairs: [(Int, Int)] = []
        var i = 0, j = 0
        while i < n && j < m {
            if a[i] == b[j] { pairs.append((i, j)); i += 1; j += 1 }
            else if dp[i + 1][j] >= dp[i][j + 1] { i += 1 }
            else { j += 1 }
        }
        return pairs
    }
}

//
//  ChatCitationFormatter.swift
//  KnowledgeTree
//
//  spec 081 — AI Chat の引用を ChatGPT/Gemini スタイル (本文 [n] + 末尾「出典」リスト) に整形する純粋関数。
//
//  入力: 回答本文 + citedArticleIDs。本文中の引用マーカーを 2 形式サポート:
//    - 新形式 (裸マーカー): `(article-id://UUID)` を根拠文の直後に置く → 上付き [n] に変換
//    - 旧形式 (spec 033 互換): `[記事タイトル](article-id://UUID)` → タイトルは本文に残しつつ末尾 [n]
//  番号は本文初出順に採番、同一 UUID 再出は同番号。本文に出ない citedArticleIDs は出典末尾に追加。
//
//  View 非依存 (Foundation のみ) でユニットテスト可能。AttributedString 組立は ChatMessageRow 側。
//

import Foundation

enum ChatCitationFormatter {
    /// 本文を構成する 1 要素。
    enum Segment: Equatable {
        case text(String)
        case citation(number: Int, articleID: UUID)
    }

    /// 出典リストの 1 行 (番号 → 記事 ID)。
    struct Source: Equatable {
        let number: Int
        let articleID: UUID
    }

    struct Result: Equatable {
        let segments: [Segment]
        /// 番号昇順の出典リスト (本文初出順 → 本文外 cited を末尾)。
        let sources: [Source]
    }

    /// 引用マーカー: 任意の `[title]` (旧形式) + `(article-id://UUID)`。
    private static let markerPattern =
        #"(?:\[([^\]]*)\])?\(article-id://([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})\)"#

    static func format(body: String, citedArticleIDs: [String]) -> Result {
        var segments: [Segment] = []
        var numberFor: [UUID: Int] = [:]
        var orderedSources: [Source] = []
        var nextNumber = 1

        func assignNumber(_ id: UUID) -> Int {
            if let existing = numberFor[id] { return existing }
            let n = nextNumber
            nextNumber += 1
            numberFor[id] = n
            orderedSources.append(Source(number: n, articleID: id))
            return n
        }

        guard let regex = try? NSRegularExpression(pattern: markerPattern) else {
            return Result(segments: [.text(body)], sources: [])
        }

        let ns = body as NSString
        let matches = regex.matches(in: body, range: NSRange(location: 0, length: ns.length))

        var cursor = body.startIndex
        for match in matches {
            guard let fullRange = Range(match.range, in: body),
                  let uuidRange = Range(match.range(at: 2), in: body),
                  let id = UUID(uuidString: String(body[uuidRange])) else {
                continue
            }

            // マーカー前のプレーンテキスト
            if cursor < fullRange.lowerBound {
                segments.append(.text(String(body[cursor..<fullRange.lowerBound])))
            }

            // 旧形式のタイトルは本文に残す (文章が壊れないように)
            if let titleRange = Range(match.range(at: 1), in: body) {
                let title = String(body[titleRange])
                if !title.isEmpty { segments.append(.text(title)) }
            }

            let n = assignNumber(id)
            segments.append(.citation(number: n, articleID: id))
            cursor = fullRange.upperBound
        }

        // 残りのテキスト
        if cursor < body.endIndex {
            segments.append(.text(String(body[cursor..<body.endIndex])))
        }
        if segments.isEmpty {
            segments.append(.text(body))
        }

        // 本文に出ない citedArticleIDs を出典末尾に追加
        for idString in citedArticleIDs {
            guard let id = UUID(uuidString: idString), numberFor[id] == nil else { continue }
            _ = assignNumber(id)
        }

        return Result(segments: segments, sources: orderedSources)
    }
}

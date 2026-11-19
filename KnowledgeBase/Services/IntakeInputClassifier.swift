//
//  IntakeInputClassifier.swift
//  KnowledgeTree
//
//  spec 103 — 追加画面の単一入力欄を URL / メモに振り分ける純関数。
//

import Foundation

nonisolated enum IntakeInputClassifier {
    enum Result: Equatable {
        case url(URL)
        case note(String)
        case empty
    }

    static func classify(_ text: String) -> Result {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        // 空白・改行を含む場合は URL ではなくメモ
        if trimmed.contains(where: { $0.isWhitespace }) { return .note(trimmed) }

        var candidate = trimmed
        if candidate.lowercased().hasPrefix("www.") { candidate = "https://" + candidate }
        if let url = URL(string: candidate),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https",
           let host = url.host, !host.isEmpty {
            return .url(url)
        }
        return .note(trimmed)
    }
}

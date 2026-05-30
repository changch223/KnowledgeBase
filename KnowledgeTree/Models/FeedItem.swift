//
//  FeedItem.swift
//  KnowledgeTree
//
//  spec 066 (LLM Wiki) — News+ 風フィードの 1 行を表す transient enum。
//  記事カード / Wiki 更新カード / 周期ダイジェストを時系列 merge するための型。
//  @Model ではない (永続化しない、毎回 FeedBuilder が組み立てる)。
//

import Foundation

/// フィードに並ぶカードの種類。sortDate で時系列 merge する。
enum FeedItem: Identifiable, Hashable {
    /// 保存した記事カード。
    case article(Article)
    /// 最近更新された Wiki ページ (ConceptPage) の更新カード。
    case wikiUpdate(ConceptPage)
    /// 周期ダイジェスト (最近更新された Wiki を束ねた「振り返り」カード、P2)。
    case periodicDigest([ConceptPage])

    /// 時系列 merge 用の日時 (新しい順に並べる)。
    var sortDate: Date {
        switch self {
        case .article(let a): return a.savedAt
        case .wikiUpdate(let p): return p.updatedAt
        case .periodicDigest(let pages): return pages.map(\.updatedAt).max() ?? .distantPast
        }
    }

    var id: String {
        switch self {
        case .article(let a): return "a-\(a.id.uuidString)"
        case .wikiUpdate(let p): return "w-\(p.id.uuidString)"
        case .periodicDigest(let pages):
            let key = pages.first?.id.uuidString ?? "empty"
            return "d-\(key)-\(pages.count)"
        }
    }
}

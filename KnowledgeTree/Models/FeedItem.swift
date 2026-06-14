//
//  FeedItem.swift
//  KnowledgeTree
//
//  spec 066 (LLM Wiki) — News+ 風フィードの 1 行を表す transient enum。
//  spec 068 — iKnow タブ: 記事 / Wiki / カテゴリー / タグ の 4 種カードに拡張。
//  @Model ではない (永続化しない、毎回 FeedBuilder が組み立てる)。
//

import Foundation
import SwiftData

/// フィードに並ぶカードの種類。sortDate で時系列 merge する (highlight は挿入式で時系列に乗らない)。
enum FeedItem: Identifiable, Hashable {
    /// 保存した記事カード。
    case article(Article)
    /// 最近更新された Wiki ページ (ConceptPage) の更新カード。
    case wikiUpdate(ConceptPage)
    /// 周期ダイジェスト (最近更新された Wiki を束ねた「振り返り」カード、P2)。
    case periodicDigest([ConceptPage])
    /// spec 068: カテゴリーハイライトカード (例「テクノロジー — 記事24 / Wiki5、今週 +3」)。
    /// recentCount = 直近 7 日に追加された記事数 (0 なら数字非表示)。
    case categoryHighlight(category: Category, articleCount: Int, wikiCount: Int, recentCount: Int)
    /// spec 068: タグハイライトカード (例「#AI 今週 +3」)。recentCount = 直近 7 日の記事増加数。
    case tagHighlight(tag: Tag, totalCount: Int, recentCount: Int)

    /// 時系列 merge 用の日時 (新しい順に並べる)。highlight は時系列に乗らないので distantPast。
    var sortDate: Date {
        switch self {
        case .article(let a): return a.savedAt
        case .wikiUpdate(let p): return p.updatedAt
        case .periodicDigest(let pages): return pages.map(\.updatedAt).max() ?? .distantPast
        case .categoryHighlight, .tagHighlight: return .distantPast
        }
    }

    var id: String {
        switch self {
        case .article(let a): return "a-\(a.id.uuidString)"
        case .wikiUpdate(let p): return "w-\(p.id.uuidString)"
        case .periodicDigest(let pages):
            let key = pages.first?.id.uuidString ?? "empty"
            return "d-\(key)-\(pages.count)"
        case .categoryHighlight(let category, _, _, _): return "cat-\(category.name)"
        case .tagHighlight(let tag, _, _): return "tag-\(tag.name)"
        }
    }
}

/// spec 075 (iKnow 概念中心フィード) — 縦フィードの主役カード 1 枚分のデータ。
/// トップレベル概念 (広い概念 or 孤立 specific) に、その子 specific 概念と記事数を束ねた transient。
/// @Model ではない (毎回 FeedBuilder.topLevelConcepts が組み立てる)。
struct ConceptFeedEntry: Identifiable, Hashable {
    /// 広い概念ページ or 孤立した specific ページ (parentConceptID == nil)。
    let page: ConceptPage
    /// 子 specific 概念 (broad のみ非空、updatedAt 降順)。
    let children: [ConceptPage]
    /// このページの関連記事数。
    let articleCount: Int

    var id: UUID { page.id }
}

//
//  SearchHighlighter.swift
//  KnowledgeTree
//
//  spec 008 — 検索結果の excerpt を AttributedString で生成する純粋関数。
//  優先順位: title > canonicalTitle > essence > summary > keyFact > entity > tag
//

import Foundation
import SwiftUI

struct SearchHighlight: Sendable {
    let fieldName: LocalizedStringKey
    let excerpt: AttributedString
}

enum SearchHighlighter {
    static let defaultExcerptRadius = 30

    /// article から query にマッチするフィールドを 1 つ選び、ハイライト済 excerpt を返す。
    /// 戻り値 nil はマッチ無し or 空クエリ。
    static func highlight(article: Article, query: String) -> SearchHighlight? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return nil }

        // 1. title
        if let excerpt = highlightText(article.title, query: q) {
            return SearchHighlight(fieldName: "search.field.title", excerpt: excerpt)
        }
        // 2. canonicalTitle
        if let canonical = article.enrichment?.canonicalTitle,
           let excerpt = highlightText(canonical, query: q) {
            return SearchHighlight(fieldName: "search.field.canonicalTitle", excerpt: excerpt)
        }
        // 3. essence
        if let essence = article.extractedKnowledge?.essence,
           let excerpt = highlightText(essence, query: q) {
            return SearchHighlight(fieldName: "search.field.essence", excerpt: excerpt)
        }
        // 4. summary (knowledge or enrichment)
        if let summary = article.extractedKnowledge?.summary,
           let excerpt = highlightText(summary, query: q) {
            return SearchHighlight(fieldName: "search.field.summary", excerpt: excerpt)
        }
        if let summary = article.enrichment?.summary,
           let excerpt = highlightText(summary, query: q) {
            return SearchHighlight(fieldName: "search.field.summary", excerpt: excerpt)
        }
        // 5. keyFact
        if let fact = article.extractedKnowledge?.keyFacts?.first(where: {
            $0.statement.localizedStandardContains(q)
        }), let excerpt = highlightText(fact.statement, query: q) {
            return SearchHighlight(fieldName: "search.field.keyFact", excerpt: excerpt)
        }
        // 6. entity
        if let entity = article.extractedKnowledge?.entities?.first(where: {
            $0.name.localizedStandardContains(q)
        }), let excerpt = highlightText(entity.name, query: q) {
            return SearchHighlight(fieldName: "search.field.entity", excerpt: excerpt)
        }
        // 7. tag
        if let tag = (article.tags ?? []).first(where: { $0.name.localizedStandardContains(q) }),
           let excerpt = highlightText(tag.name, query: q) {
            return SearchHighlight(fieldName: "search.field.tag", excerpt: excerpt)
        }
        return nil
    }

    /// テキストの中で query にマッチする箇所を bold にした AttributedString excerpt を返す。
    /// マッチ無しは nil。excerpt は最初のマッチ周辺 ±radius 文字。
    static func highlightText(
        _ text: String,
        query: String,
        excerptRadius: Int = SearchHighlighter.defaultExcerptRadius
    ) -> AttributedString? {
        guard let firstRange = text.range(of: query, options: .caseInsensitive) else { return nil }

        // excerpt 範囲算出
        let start: String.Index
        if let s = text.index(firstRange.lowerBound, offsetBy: -excerptRadius, limitedBy: text.startIndex) {
            start = s
        } else {
            start = text.startIndex
        }
        let end: String.Index
        if let e = text.index(firstRange.upperBound, offsetBy: excerptRadius, limitedBy: text.endIndex) {
            end = e
        } else {
            end = text.endIndex
        }
        let excerpt = String(text[start..<end])

        var attrs = AttributedString(excerpt)
        // AttributedString に対する繰り返しハイライト
        // (`range(of:options:locale:in:)` は in: 引数が SwiftUI 6 で非対応のため、
        //  cursor を進めながら探索する)
        var cursor = attrs.startIndex
        while cursor < attrs.endIndex,
              let r = attrs[cursor..<attrs.endIndex].range(of: query, options: .caseInsensitive)
        {
            attrs[r].font = .body.bold()
            cursor = r.upperBound
        }
        return attrs
    }
}

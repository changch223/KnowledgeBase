//
//  CategoryConsistency.swift
//  KnowledgeTree
//
//  spec 097 Phase 4 — 分類の一貫性チェック (精度可視化用)。
//  概念の構成タグが複数の実カテゴリに割れている = AI が内部で迷っている高優先の確認対象。
//

import Foundation

enum CategoryConsistency {
    /// 概念の構成タグ (relatedArticles のタグ) が 2 つ以上の実カテゴリ (その他 除く) に割れているか。
    static func isSplit(_ concept: ConceptPage) -> Bool {
        distinctRealCategories(of: concept).count > 1
    }

    /// 概念に紐づくタグの実カテゴリ集合 (その他・空を除く)。
    static func distinctRealCategories(of concept: ConceptPage) -> Set<String> {
        let other = CategorySeed.otherCategory.name
        return Set(
            (concept.relatedArticles ?? [])
                .flatMap { ($0.tags ?? []).compactMap(\.categoryRaw) }
                .filter { !$0.isEmpty && $0 != other }
        )
    }
}

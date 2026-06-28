//
//  SearchSuggestionStore.swift
//  KnowledgeTree
//
//  ライブラリ検索バーの「最近の検索」候補を UserDefaults に永続化するストア。
//  タグ・概念ページ候補は ArticleListView が @Query で取得するため本クラスは
//  recent クエリのみ管理する。
//

import Foundation

final class SearchSuggestionStore {
    static let shared = SearchSuggestionStore()
    private let key = "search.recentQueries"
    private let maxCount = 10

    var recent: [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    /// 2 字未満は記録しない。重複は先頭に移動する。
    func record(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return }
        var list = recent.filter { $0.lowercased() != q.lowercased() }
        list.insert(q, at: 0)
        UserDefaults.standard.set(Array(list.prefix(maxCount)), forKey: key)
    }

    func remove(_ query: String) {
        let list = recent.filter { $0 != query }
        UserDefaults.standard.set(list, forKey: key)
    }

    func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

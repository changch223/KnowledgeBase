//
//  RecentArticlesService.swift
//  KnowledgeTree
//
//  spec 056 — 知識 Clip タブ「最近の記事」セクション (差分キャッチアップ) の
//  データソース。LastOpenedStore.lastOpenedAt 以降に保存された新規 Article 上位 3 件を返す。
//  差分ゼロの場合は前回 cache から復元 (画面が空にならない保証)。
//
//  - UserDefaults `spec056_recent_articles_cache` に Article ID 配列 (max 3) を JSON 永続化
//  - 差分あり: 結果を表示 + cache 更新
//  - 差分ゼロ: cache から ID で再 fetch (削除済 ID は compactMap で skip)
//

import Foundation
import SwiftData

@MainActor
protocol RecentArticlesServiceProtocol: AnyObject {
    /// 指定時刻以降に保存された Article を新しい順に返す (max limit 件)。
    /// 結果が 0 件かつ cache が有効なら、cache から ID 配列で Article を再 fetch する。
    func fetchRecentArticles(since: Date, limit: Int, in context: ModelContext) async -> [Article]

    /// 「直近表示した」Article ID 配列。最大 3 件。UserDefaults 永続化。
    var cachedRecentArticleIDs: [UUID] { get set }

    /// cache を空にする (テスト用 / cleanup 用)。
    func clearCache()
}

@MainActor
final class DefaultRecentArticlesService: RecentArticlesServiceProtocol {
    static let cacheKey = "spec056_recent_articles_cache"
    static let maxCacheCount = 3

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var cachedRecentArticleIDs: [UUID] {
        get {
            guard let data = defaults.data(forKey: Self.cacheKey),
                  let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
                return []
            }
            return ids
        }
        set {
            let trimmed = Array(newValue.prefix(Self.maxCacheCount))
            if let data = try? JSONEncoder().encode(trimmed) {
                defaults.set(data, forKey: Self.cacheKey)
            }
        }
    }

    func fetchRecentArticles(
        since: Date,
        limit: Int = 3,
        in context: ModelContext
    ) async -> [Article] {
        // 1. since 以降の新規 Article fetch
        var descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.savedAt >= since },
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let fresh = (try? context.fetch(descriptor)) ?? []

        if !fresh.isEmpty {
            // 差分あり → cache 更新 + 結果返却
            cachedRecentArticleIDs = fresh.map(\.id)
            return fresh
        }

        // 2. 差分ゼロ → cache から復元 (画面を空にしない)
        let cachedIDs = cachedRecentArticleIDs
        guard !cachedIDs.isEmpty else { return [] }

        let cachedSet = Set(cachedIDs)
        let cacheDescriptor = FetchDescriptor<Article>(
            predicate: #Predicate { article in
                cachedSet.contains(article.id)
            }
        )
        let cached = (try? context.fetch(cacheDescriptor)) ?? []
        let cachedByID = Dictionary(uniqueKeysWithValues: cached.map { ($0.id, $0) })
        // cache 配列の順序を保ちつつ、削除済 ID は skip
        return cachedIDs.compactMap { cachedByID[$0] }
    }

    func clearCache() {
        defaults.removeObject(forKey: Self.cacheKey)
    }
}

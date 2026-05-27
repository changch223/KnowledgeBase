# Contract: RecentArticlesService

## Purpose

「最近の記事」セクション (知識 Clip タブ 最上部) のデータソース。LastOpenedStore.lastOpenedAt 以降に保存された新規 Article 上位 3 件を返す。差分ゼロの場合は前回 cache から復元 (画面が空にならない保証)。

## Protocol

```swift
@MainActor
protocol RecentArticlesServiceProtocol: AnyObject {
    /// 指定時刻以降に保存された Article を新しい順に返す。max limit 件。
    /// 結果が 0 件かつ cache が有効なら、cache から ID 配列で Article を再 fetch する。
    func fetchRecentArticles(
        since: Date,
        limit: Int,
        in context: ModelContext
    ) async -> [Article]
    
    /// 「直近表示した」Article ID 配列。最大 3 件。UserDefaults 永続化。
    var cachedRecentArticleIDs: [UUID] { get set }
    
    /// cache を空にする (テスト用 / アンインストール cleanup 用)。
    func clearCache()
}
```

## Default Implementation

```swift
@MainActor
final class DefaultRecentArticlesService: RecentArticlesServiceProtocol {
    private let cacheKey = "spec056_recent_articles_cache"
    
    var cachedRecentArticleIDs: [UUID] {
        get {
            guard let data = UserDefaults.standard.data(forKey: cacheKey),
                  let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
                return []
            }
            return ids
        }
        set {
            let trimmed = Array(newValue.prefix(3))
            if let data = try? JSONEncoder().encode(trimmed) {
                UserDefaults.standard.set(data, forKey: cacheKey)
            }
        }
    }
    
    func fetchRecentArticles(
        since: Date,
        limit: Int = 3,
        in context: ModelContext
    ) async -> [Article] {
        // 1. since 以降の新規 fetch
        var descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.savedAt >= since },
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let fresh = (try? context.fetch(descriptor)) ?? []
        
        if !fresh.isEmpty {
            // 差分あり → cache 更新 + 返却
            cachedRecentArticleIDs = fresh.map(\.id)
            return fresh
        }
        
        // 2. 差分ゼロ → cache から Article 復元
        let cachedIDs = cachedRecentArticleIDs
        guard !cachedIDs.isEmpty else { return [] }
        
        var cacheDescriptor = FetchDescriptor<Article>(
            predicate: #Predicate { article in
                cachedIDs.contains(article.id)
            }
        )
        let cached = (try? context.fetch(cacheDescriptor)) ?? []
        
        // 削除済 ID は skip、id 順を cache 配列順に合わせる
        let cachedByID = Dictionary(uniqueKeysWithValues: cached.map { ($0.id, $0) })
        return cachedIDs.compactMap { cachedByID[$0] }
    }
    
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
}
```

## Behavior

| Case | Input | Output |
|---|---|---|
| 差分あり | since = 1 日前、新規記事 5 件保存済 | 上位 3 件、cache 更新 |
| 差分ゼロ + cache あり | since = 5 分前、新規 0 件、cache 3 件 | cache 3 件 (削除済は skip) |
| 差分ゼロ + cache 空 | since = 5 分前、新規 0 件、cache 空 | 空配列 → UI 側 empty state 表示 |
| 全削除 + cache に削除済 ID | since = 1 日前、cache に 3 件 (全 DB から削除済) | 空配列 (compactMap で nil 除外) |

## UI 結合

```swift
struct RecentArticlesSection: View {
    @Environment(\.modelContext) var context
    @Environment(ServiceContainer.self) var services
    @State private var articles: [Article] = []
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("最近の記事")  // Localizable
            if articles.isEmpty {
                EmptyStateView(...)
            } else {
                ScrollView(.horizontal) {
                    HStack { ForEach(articles) { ... } }
                }
            }
        }
        .task {
            articles = await services.recentArticlesService.fetchRecentArticles(
                since: services.lastOpenedStore.lastOpenedAt,
                limit: 3,
                in: context
            )
        }
    }
}
```

## Test Cases (8 件)

1. **空状態**: fetch 0 件、cache empty → 結果空配列
2. **差分あり**: since = 1 時間前、新規 5 件 → 上位 3 件返却、cache に新 ID
3. **差分ゼロ + cache 復元**: since = 1 分前、新規 0 件、cache に有効 3 件 → cache 3 件返却
4. **cache 永続化**: set([UUID1, UUID2, UUID3]) → get → 同配列返却
5. **max 3 件制限**: set([UUID1, ..., UUID5]) → get → 最初の 3 件のみ
6. **LastOpenedAt 連動**: since = .now → 全部過去扱い → 結果空配列
7. **削除済 ID skip**: cache [A, B, C]、DB に C のみ存在 → 結果 [C]
8. **new install**: cache empty + DB empty → 結果空配列

## DI / Lifecycle

- ServiceContainer に `recentArticlesService: RecentArticlesServiceProtocol` を追加
- KnowledgeTreeApp.bootstrap で DefaultRecentArticlesService 生成 + inject
- RecentArticlesSection の `.task` で fetch 呼出
- アンインストール時は UserDefaults と一緒に cache も削除される (iOS 標準動作)

## Performance

- fetch with predicate + fetchLimit = O(1) DB lookup
- cache load = JSON decode で 1ms 以内 (3 UUID 程度)
- アプリ起動 → セクション表示まで合算で 100ms 以内

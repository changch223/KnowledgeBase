//
//  RecentArticlesServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 056 — DefaultRecentArticlesService (差分判定 + UserDefaults cache) の単体テスト 8 ケース。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

@MainActor
struct RecentArticlesServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    /// isolated UserDefaults を per-test 作成。
    private func makeIsolatedDefaults(for testName: String = #function) -> UserDefaults {
        let suiteName = "spec056.recentArticles.\(testName).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeArticle(savedAt: Date, in context: ModelContext, url: String = "https://example.com/") -> Article {
        let a = Article(url: url + UUID().uuidString, title: "Test", savedAt: savedAt)
        context.insert(a)
        return a
    }

    // MARK: - 1. 空状態 (fetch 0 件、cache empty)

    @Test func testEmptyStateReturnsEmptyArray() async throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = DefaultRecentArticlesService(defaults: defaults)

        let result = await service.fetchRecentArticles(since: .now.addingTimeInterval(-3600), limit: 3, in: container.mainContext)
        #expect(result.isEmpty)
        #expect(service.cachedRecentArticleIDs.isEmpty)
    }

    // MARK: - 2. 差分あり 5 件 → 上位 3 件 + cache 更新

    @Test func testDifferentialFetchReturnsTopLimitAndUpdatesCache() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeIsolatedDefaults()
        let service = DefaultRecentArticlesService(defaults: defaults)

        let now = Date.now
        var articles: [Article] = []
        for i in 0..<5 {
            articles.append(makeArticle(savedAt: now.addingTimeInterval(TimeInterval(-i * 60)), in: context))
        }
        try context.save()

        let result = await service.fetchRecentArticles(since: now.addingTimeInterval(-3600), limit: 3, in: context)
        #expect(result.count == 3)
        // cache に新 ID 配列
        #expect(service.cachedRecentArticleIDs.count == 3)
        #expect(service.cachedRecentArticleIDs == result.map(\.id))
    }

    // MARK: - 3. 差分ゼロ + cache 3 件 → cache 復元

    @Test func testZeroDifferentialFallsBackToCache() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeIsolatedDefaults()
        let service = DefaultRecentArticlesService(defaults: defaults)

        // cache に 3 件の ID を入れる + DB に対応 Article を作る
        let articles = (0..<3).map { _ in makeArticle(savedAt: Date.now.addingTimeInterval(-3600), in: context) }
        try context.save()
        service.cachedRecentArticleIDs = articles.map(\.id)

        // since = 1 分前 (差分ゼロ)
        let result = await service.fetchRecentArticles(since: Date.now.addingTimeInterval(-60), limit: 3, in: context)
        #expect(result.count == 3)
        #expect(Set(result.map(\.id)) == Set(articles.map(\.id)))
    }

    // MARK: - 4. cache 永続化 (set → get round-trip)

    @Test func testCachePersistRoundTrip() {
        let defaults = makeIsolatedDefaults()
        let service = DefaultRecentArticlesService(defaults: defaults)

        let ids = [UUID(), UUID(), UUID()]
        service.cachedRecentArticleIDs = ids

        // 新 service instance で読み直し
        let service2 = DefaultRecentArticlesService(defaults: defaults)
        #expect(service2.cachedRecentArticleIDs == ids)
    }

    // MARK: - 5. max 3 件制限

    @Test func testCacheMax3Limit() {
        let defaults = makeIsolatedDefaults()
        let service = DefaultRecentArticlesService(defaults: defaults)

        let ids = (0..<5).map { _ in UUID() }
        service.cachedRecentArticleIDs = ids
        #expect(service.cachedRecentArticleIDs.count == 3)
        #expect(service.cachedRecentArticleIDs == Array(ids.prefix(3)))
    }

    // MARK: - 6. since = .now → 全部過去扱い → 結果空

    @Test func testFutureSinceReturnsEmpty() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeIsolatedDefaults()
        let service = DefaultRecentArticlesService(defaults: defaults)

        _ = makeArticle(savedAt: Date.now.addingTimeInterval(-3600), in: context)
        try context.save()

        // since = 1 秒後 → 全部 since より過去
        let result = await service.fetchRecentArticles(since: Date.now.addingTimeInterval(1), limit: 3, in: context)
        // 結果は空 (cache も空)
        #expect(result.isEmpty)
    }

    // MARK: - 7. 削除済 article ID skip

    @Test func testDeletedArticleIDsSkippedInCacheFallback() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeIsolatedDefaults()
        let service = DefaultRecentArticlesService(defaults: defaults)

        // 3 件作成 → cache 登録 → 1 件削除
        let articles = (0..<3).map { _ in makeArticle(savedAt: Date.now.addingTimeInterval(-3600), in: context) }
        try context.save()
        service.cachedRecentArticleIDs = articles.map(\.id)

        context.delete(articles[0])
        try context.save()

        // since = 直前 = 差分ゼロ → cache から restore (削除済 1 件 skip)
        let result = await service.fetchRecentArticles(since: Date.now.addingTimeInterval(-1), limit: 3, in: context)
        #expect(result.count == 2)
        #expect(!result.contains(where: { $0.id == articles[0].id }))
    }

    // MARK: - 8. new install state (cache empty + DB empty)

    @Test func testNewInstallStateReturnsEmpty() async throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = DefaultRecentArticlesService(defaults: defaults)

        let result = await service.fetchRecentArticles(since: Date.distantPast, limit: 3, in: container.mainContext)
        #expect(result.isEmpty)
        #expect(service.cachedRecentArticleIDs.isEmpty)
    }
}

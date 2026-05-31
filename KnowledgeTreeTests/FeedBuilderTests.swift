//
//  FeedBuilderTests.swift
//  KnowledgeTreeTests
//
//  spec 066 (LLM Wiki) — News+ 風フィードの merge / 更新ガード / 時系列の検証。
//  FeedBuilder は AI を呼ばない純粋ロジック (SwiftData fetch + merge)。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

@MainActor
struct FeedBuilderTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)  // 固定 now

    /// spec 068: フィードに出すには AI 処理完了 (succeeded) が必要なので、
    /// デフォルトで succeeded な ExtractedKnowledge を付ける。
    @discardableResult
    private func insertArticle(
        _ ctx: ModelContext,
        title: String,
        savedAt: Date,
        status: ExtractionStatus = .succeeded
    ) -> Article {
        let a = Article(url: "https://example.com/\(UUID().uuidString)", title: title, savedAt: savedAt)
        ctx.insert(a)
        let k = ExtractedKnowledge(article: a, status: status)
        ctx.insert(k)
        a.extractedKnowledge = k
        return a
    }

    @discardableResult
    private func insertWiki(
        _ ctx: ModelContext,
        name: String,
        updatedAt: Date,
        body: String = "本文あり",
        summary: String = "要約",
        isHidden: Bool = false,
        articleCount: Int = 0
    ) -> ConceptPage {
        let p = ConceptPage(name: name, categoryRaw: "tech", summary: summary, updatedAt: updatedAt)
        p.bodyMarkdown = body
        p.isHidden = isHidden
        if articleCount > 0 {
            var arts: [Article] = []
            for i in 0..<articleCount {
                let a = Article(url: "https://example.com/\(name)-\(i)", title: "\(name) 記事\(i)", savedAt: updatedAt)
                ctx.insert(a)
                arts.append(a)
            }
            p.relatedArticles = arts
        }
        ctx.insert(p)
        return p
    }

    private func makeBuilder(_ container: ModelContainer) -> FeedBuilder {
        FeedBuilder(context: container.mainContext, now: { self.fixedNow })
    }

    // MARK: - 空

    @Test func emptyReturnsEmpty() throws {
        let c = try makeContainer()
        #expect(makeBuilder(c).build().isEmpty)
    }

    // MARK: - 記事 + Wiki が時系列 mix

    @Test func mergesArticlesAndWikiByDateDescending() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        insertArticle(ctx, title: "古い記事", savedAt: fixedNow.addingTimeInterval(-86_400))      // -1d
        insertWiki(ctx, name: "新しい Wiki", updatedAt: fixedNow.addingTimeInterval(-3_600))       // -1h
        insertArticle(ctx, title: "最新記事", savedAt: fixedNow.addingTimeInterval(-600))           // -10m

        let items = makeBuilder(c).build()
        #expect(items.count == 3)
        // 降順: 最新記事(-10m) > 新しい Wiki(-1h) > 古い記事(-1d)
        let dates = items.map(\.sortDate)
        #expect(dates == dates.sorted(by: >))
        if case .article(let a) = items[0] { #expect(a.title == "最新記事") } else { Issue.record("先頭は最新記事のはず") }
        if case .wikiUpdate = items[1] {} else { Issue.record("2 番目は Wiki 更新のはず") }
    }

    // MARK: - 更新ガード: 古い Wiki は除外

    @Test func excludesWikiUpdatedBeforeWindow() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        insertWiki(ctx, name: "古すぎ Wiki", updatedAt: fixedNow.addingTimeInterval(-20 * 86_400))  // -20d (>14d)
        insertWiki(ctx, name: "新しい Wiki", updatedAt: fixedNow.addingTimeInterval(-86_400))        // -1d

        let items = makeBuilder(c).build()
        let names = items.compactMap { item -> String? in
            if case .wikiUpdate(let p) = item { return p.name } else { return nil }
        }
        #expect(names.contains("新しい Wiki"))
        #expect(!names.contains("古すぎ Wiki"))
    }

    // MARK: - 更新ガード: 本文も要約も無い Wiki は除外

    @Test func excludesWikiWithoutBodyOrSummary() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        insertWiki(ctx, name: "空 Wiki", updatedAt: fixedNow.addingTimeInterval(-3_600), body: "", summary: "")
        insertWiki(ctx, name: "中身 Wiki", updatedAt: fixedNow.addingTimeInterval(-3_600), body: "本文", summary: "")

        let names = makeBuilder(c).build().compactMap { item -> String? in
            if case .wikiUpdate(let p) = item { return p.name } else { return nil }
        }
        #expect(names.contains("中身 Wiki"))
        #expect(!names.contains("空 Wiki"))
    }

    // MARK: - 更新ガード: 非表示 Wiki は除外

    @Test func excludesHiddenWiki() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        insertWiki(ctx, name: "非表示", updatedAt: fixedNow.addingTimeInterval(-3_600), isHidden: true)
        insertArticle(ctx, title: "記事", savedAt: fixedNow.addingTimeInterval(-3_600))

        let items = makeBuilder(c).build()
        let hasHidden = items.contains { if case .wikiUpdate(let p) = $0 { return p.name == "非表示" } else { return false } }
        #expect(!hasHidden)
        #expect(items.count == 1)  // 記事のみ
    }

    // MARK: - spec 068: AI 処理中の記事は assemble に出ない

    @Test func excludesArticlesStillProcessing() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        insertArticle(ctx, title: "完了記事", savedAt: fixedNow.addingTimeInterval(-600), status: .succeeded)
        insertArticle(ctx, title: "処理中記事", savedAt: fixedNow.addingTimeInterval(-300), status: .pending)
        insertArticle(ctx, title: "抽出中記事", savedAt: fixedNow.addingTimeInterval(-200), status: .extracting)
        insertArticle(ctx, title: "失敗記事", savedAt: fixedNow.addingTimeInterval(-100), status: .failed)
        insertArticle(ctx, title: "部分成功記事", savedAt: fixedNow.addingTimeInterval(-50), status: .partiallySucceeded)

        let titles = makeBuilder(c).build().compactMap { item -> String? in
            if case .article(let a) = item { return a.title } else { return nil }
        }
        #expect(titles.contains("完了記事"))
        #expect(titles.contains("部分成功記事"))
        #expect(!titles.contains("処理中記事"))
        #expect(!titles.contains("抽出中記事"))
        #expect(!titles.contains("失敗記事"))
    }

    // MARK: - spec 068: recommend

    @Test func recommendRanksWikiWithMoreArticlesAndRecencyHigher() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        // 記事多 + 最近更新 → 高スコア
        insertWiki(ctx, name: "人気Wiki", updatedAt: fixedNow.addingTimeInterval(-3_600), articleCount: 8)
        // 記事少 + 古め → 低スコア
        insertWiki(ctx, name: "地味Wiki", updatedAt: fixedNow.addingTimeInterval(-10 * 86_400), articleCount: 1)

        let pages = try ctx.fetch(FetchDescriptor<ConceptPage>())
        let items = FeedBuilder.recommend(articles: [], wikiPages: pages, now: fixedNow)
        // 先頭が人気Wiki
        if case .wikiUpdate(let p) = items.first { #expect(p.name == "人気Wiki") } else { Issue.record("先頭は人気Wikiのはず") }
    }

    @Test func recommendCapsAtLimit() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        for i in 0..<10 {
            insertWiki(ctx, name: "W\(i)", updatedAt: fixedNow.addingTimeInterval(-Double(i) * 3_600), articleCount: i + 1)
        }
        let pages = try ctx.fetch(FetchDescriptor<ConceptPage>())
        let items = FeedBuilder.recommend(articles: [], wikiPages: pages, now: fixedNow, limit: 5)
        #expect(items.count == 5)
    }

    @Test func recommendExcludesProcessingArticlesAndHiddenWiki() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        let done = insertArticle(ctx, title: "完了", savedAt: fixedNow, status: .succeeded)
        let processing = insertArticle(ctx, title: "処理中", savedAt: fixedNow, status: .pending)
        insertWiki(ctx, name: "非表示W", updatedAt: fixedNow, isHidden: true, articleCount: 10)

        let pages = try ctx.fetch(FetchDescriptor<ConceptPage>())
        let items = FeedBuilder.recommend(articles: [done, processing], wikiPages: pages, now: fixedNow)
        let articleTitles = items.compactMap { if case .article(let a) = $0 { return a.title } else { return nil } }
        let wikiNames = items.compactMap { if case .wikiUpdate(let p) = $0 { return p.name } else { return nil } }
        #expect(articleTitles.contains("完了"))
        #expect(!articleTitles.contains("処理中"))
        #expect(!wikiNames.contains("非表示W"))
    }
}

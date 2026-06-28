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
@testable import KnowledgeBase

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

    // MARK: - spec 068: highlights (カテゴリー / タグ)

    /// categoryRaw 付き Tag を持つ記事を作る。
    @discardableResult
    private func insertTaggedArticle(
        _ ctx: ModelContext,
        title: String,
        savedAt: Date,
        tagName: String,
        categoryRaw: String,
        status: ExtractionStatus = .succeeded
    ) -> Article {
        let a = insertArticle(ctx, title: title, savedAt: savedAt, status: status)
        let tag = KnowledgeBase.Tag(name: tagName, categoryRaw: categoryRaw)
        ctx.insert(tag)
        a.tags = [tag]
        return a
    }

    @Test func highlightsBuildsCategoryCardWithRecentCount() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        // テクノロジー: 5 件、うち 3 件が直近 7 日
        for i in 0..<3 {
            insertTaggedArticle(ctx, title: "新T\(i)", savedAt: fixedNow.addingTimeInterval(-Double(i) * 86_400),
                                tagName: "AI", categoryRaw: "テクノロジー")
        }
        for i in 0..<2 {
            insertTaggedArticle(ctx, title: "旧T\(i)", savedAt: fixedNow.addingTimeInterval(-30 * 86_400),
                                tagName: "AI", categoryRaw: "テクノロジー")
        }
        let tags = try ctx.fetch(FetchDescriptor<KnowledgeBase.Tag>())
        let arts = try ctx.fetch(FetchDescriptor<Article>())
        let items = FeedBuilder.highlights(articles: arts, tags: tags,
                                           wikiCountByCategory: ["テクノロジー": 4], now: fixedNow)
        let cat = items.compactMap { item -> (String, Int, Int, Int)? in
            if case .categoryHighlight(let c, let a, let w, let r) = item { return (c.name, a, w, r) } else { return nil }
        }.first
        #expect(cat?.0 == "テクノロジー")
        #expect(cat?.1 == 5)   // 総記事数
        #expect(cat?.2 == 4)   // Wiki 数
        #expect(cat?.3 == 3)   // 直近 7 日
    }

    @Test func highlightsSkipsSmallCategory() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        // 2 件のみ (categoryHighlightMinArticles=3 未満) → カード出ない
        insertTaggedArticle(ctx, title: "x", savedAt: fixedNow, tagName: "T", categoryRaw: "経済")
        insertTaggedArticle(ctx, title: "y", savedAt: fixedNow, tagName: "T", categoryRaw: "経済")
        let tags = try ctx.fetch(FetchDescriptor<KnowledgeBase.Tag>())
        let arts = try ctx.fetch(FetchDescriptor<Article>())
        let items = FeedBuilder.highlights(articles: arts, tags: tags, wikiCountByCategory: [:], now: fixedNow)
        let hasEconomy = items.contains { if case .categoryHighlight(let c, _, _, _) = $0 { return c.name == "経済" } else { return false } }
        #expect(!hasEconomy)
    }

    @Test func interleaveInsertsHighlightsEveryN() throws {
        // feed 12 件 + highlight 2 件 → highlightEvery(6) ごとに挿入
        let c = try makeContainer()
        let ctx = c.mainContext
        for i in 0..<12 {
            insertArticle(ctx, title: "A\(i)", savedAt: fixedNow.addingTimeInterval(-Double(i) * 3_600))
        }
        let arts = try ctx.fetch(FetchDescriptor<Article>())
        let feed: [FeedItem] = arts.map { .article($0) }
        let dummyTag = KnowledgeBase.Tag(name: "X", categoryRaw: "テクノロジー")
        ctx.insert(dummyTag)
        let highlights: [FeedItem] = [
            .tagHighlight(tag: dummyTag, totalCount: 5, recentCount: 3),
            .categoryHighlight(category: CategorySeed.category(for: "テクノロジー"), articleCount: 5, wikiCount: 1, recentCount: 2)
        ]
        let merged = FeedBuilder.interleaveHighlights(into: feed, highlights: highlights)
        #expect(merged.count == feed.count + highlights.count)
        // 7 番目 (index 6) が最初の highlight
        if case .tagHighlight = merged[6] {} else { Issue.record("index 6 は最初の highlight のはず") }
    }

    // MARK: - spec 075: 新着棚 (未概念化記事)

    @Test func newArticleShelfShowsOnlyUnfoldedRecentProcessed() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        insertArticle(ctx, title: "新着未分類", savedAt: fixedNow.addingTimeInterval(-3_600), status: .succeeded)
        let folded = insertArticle(ctx, title: "概念化済", savedAt: fixedNow.addingTimeInterval(-3_600), status: .succeeded)
        // folded を Wiki に紐付け → relatedConcepts 非空 = 棚から除外
        let w = insertWiki(ctx, name: "概念", updatedAt: fixedNow)
        w.relatedArticles = [folded]
        insertArticle(ctx, title: "処理中", savedAt: fixedNow, status: .pending)
        insertArticle(ctx, title: "古い未分類", savedAt: fixedNow.addingTimeInterval(-40 * 86_400), status: .succeeded)

        let arts = try ctx.fetch(FetchDescriptor<Article>())
        let titles = FeedBuilder.newArticleShelf(articles: arts, now: fixedNow).map(\.title)
        #expect(titles.contains("新着未分類"))
        #expect(!titles.contains("概念化済"))   // relatedConcepts 非空
        #expect(!titles.contains("処理中"))      // 未処理
        #expect(!titles.contains("古い未分類"))  // 鮮度超過 (>30d)
    }

    // MARK: - spec 075: トップレベル概念フィード

    @Test func topLevelConceptsFoldsChildrenAndIncludesOrphans() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        let broad = insertWiki(ctx, name: "生成AI", updatedAt: fixedNow, summary: "広い概念")
        broad.conceptLevelRaw = "broad"
        let child1 = insertWiki(ctx, name: "Text-to-SQL", updatedAt: fixedNow.addingTimeInterval(-100), summary: "子1")
        child1.parentConceptID = broad.id
        let child2 = insertWiki(ctx, name: "RAG", updatedAt: fixedNow.addingTimeInterval(-200), summary: "子2")
        child2.parentConceptID = broad.id
        // 孤立 specific (parent=nil) も top-level に拾われる
        insertWiki(ctx, name: "孤立概念", updatedAt: fixedNow.addingTimeInterval(-300), summary: "孤立")

        let pages = try ctx.fetch(FetchDescriptor<ConceptPage>())
        let entries = FeedBuilder.topLevelConcepts(pages: pages, now: fixedNow)
        let names = entries.map(\.page.name)
        #expect(names.contains("生成AI"))
        #expect(names.contains("孤立概念"))
        #expect(!names.contains("Text-to-SQL"))  // 子は top-level に出ない
        #expect(!names.contains("RAG"))
        let broadEntry = entries.first { $0.page.name == "生成AI" }
        #expect(broadEntry?.children.count == 2)
        #expect(entries.first?.page.name == "生成AI")  // updatedAt 降順で先頭
    }

    @Test func topLevelConceptsExcludesEmptyAndHidden() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        insertWiki(ctx, name: "空ページ", updatedAt: fixedNow, body: "", summary: "")  // 中身ゼロ
        insertWiki(ctx, name: "非表示", updatedAt: fixedNow, isHidden: true)
        insertWiki(ctx, name: "良ページ", updatedAt: fixedNow, summary: "中身あり")

        let pages = try ctx.fetch(FetchDescriptor<ConceptPage>())
        let names = FeedBuilder.topLevelConcepts(pages: pages, now: fixedNow).map(\.page.name)
        #expect(names.contains("良ページ"))
        #expect(!names.contains("空ページ"))
        #expect(!names.contains("非表示"))
    }

    @Test func recommendConceptsRanksTopLevelByArticlesAndRecency() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        let popular = insertWiki(ctx, name: "人気", updatedAt: fixedNow, articleCount: 8)
        popular.conceptLevelRaw = "broad"
        insertWiki(ctx, name: "地味", updatedAt: fixedNow.addingTimeInterval(-10 * 86_400), articleCount: 1)
        // 子 specific (parent あり) は記事多くても top-level でないので除外
        let child = insertWiki(ctx, name: "子トピック", updatedAt: fixedNow, articleCount: 20)
        child.parentConceptID = popular.id

        let pages = try ctx.fetch(FetchDescriptor<ConceptPage>())
        let recs = FeedBuilder.recommendConcepts(pages: pages, now: fixedNow, limit: 5)
        #expect(recs.first?.name == "人気")
        #expect(!recs.contains { $0.name == "子トピック" })  // top-level でない
    }

    // MARK: - spec 080拡張: topLevelConcepts は fresh-first + 重要(記事数)×最新

    @Test func topLevelConceptsFreshFirstThenImportance() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        // 未読(lastSeenAt nil): 記事 5 / 記事 2。既読(lastSeenAt > updatedAt): 記事 10。
        insertWiki(ctx, name: "未読大", updatedAt: fixedNow, articleCount: 5)
        insertWiki(ctx, name: "未読小", updatedAt: fixedNow, articleCount: 2)
        let seen = insertWiki(ctx, name: "既読大", updatedAt: fixedNow.addingTimeInterval(-3_600), articleCount: 10)
        seen.lastSeenAt = fixedNow  // 最終閲覧 > 更新 → 既読 (下げる)
        try ctx.save()

        let pages = try ctx.fetch(FetchDescriptor<ConceptPage>())
        let names = FeedBuilder.topLevelConcepts(pages: pages, now: fixedNow).map(\.page.name)
        // 未読が先 (記事数降順)、既読は記事 10 でも最後
        #expect(names == ["未読大", "未読小", "既読大"])
    }
}

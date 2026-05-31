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

    @discardableResult
    private func insertArticle(_ ctx: ModelContext, title: String, savedAt: Date) -> Article {
        let a = Article(url: "https://example.com/\(UUID().uuidString)", title: title, savedAt: savedAt)
        ctx.insert(a)
        return a
    }

    @discardableResult
    private func insertWiki(
        _ ctx: ModelContext,
        name: String,
        updatedAt: Date,
        body: String = "本文あり",
        summary: String = "要約",
        isHidden: Bool = false
    ) -> ConceptPage {
        let p = ConceptPage(name: name, categoryRaw: "tech", summary: summary, updatedAt: updatedAt)
        p.bodyMarkdown = body
        p.isHidden = isHidden
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
}

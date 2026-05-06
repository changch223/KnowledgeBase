//
//  SaveURLToKnowledgeTreeIntentTests.swift
//  KnowledgeTreeTests
//
//  spec 019 — ArticleSavingActor.performSave() 静的純関数の 5 ケース検証。
//  in-memory ModelContainer (SharedSchema.all) で隔離、production App Group container
//  には触らない。AppIntent struct の perform() 自体は AppIntents framework mock 困難
//  なので test 対象外、純関数 performSave() で全分岐を網羅。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

@MainActor
struct SaveURLToKnowledgeTreeIntentTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    /// 1: 正常 URL + title → Article insert される
    @Test func testSaveValidURLCreatesArticle() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let inserted = try ArticleSavingActor.performSave(
            url: "https://example.com/a",
            title: "サンプル記事",
            in: context
        )

        #expect(inserted == true)

        let articles = try context.fetch(FetchDescriptor<Article>())
        #expect(articles.count == 1)
        #expect(articles.first?.url == "https://example.com/a")
        #expect(articles.first?.title == "サンプル記事")
    }

    /// 2: 既存 URL を再投入 → silent skip、Article 数変わらず
    @Test func testSaveDuplicateURLSilentSkip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // 1 回目 insert
        _ = try ArticleSavingActor.performSave(
            url: "https://example.com/dup",
            title: "first",
            in: context
        )

        // 2 回目 (重複)
        let inserted = try ArticleSavingActor.performSave(
            url: "https://example.com/dup",
            title: "second",
            in: context
        )

        #expect(inserted == false)

        let articles = try context.fetch(FetchDescriptor<Article>())
        #expect(articles.count == 1)
        // title は最初の "first" のまま (touch されない)
        #expect(articles.first?.title == "first")
    }

    /// 3: 無効 scheme (javascript:) → silent skip
    @Test func testSaveInvalidURLSilentSkip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let inserted = try ArticleSavingActor.performSave(
            url: "javascript:alert(1)",
            title: "evil",
            in: context
        )

        #expect(inserted == false)

        let articles = try context.fetch(FetchDescriptor<Article>())
        #expect(articles.isEmpty)
    }

    /// 4: title 空 → URL を title に使用
    @Test func testSaveWithoutTitleUsesURLAsTitle() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let inserted = try ArticleSavingActor.performSave(
            url: "https://example.com/notitle",
            title: "",
            in: context
        )

        #expect(inserted == true)

        let articles = try context.fetch(FetchDescriptor<Article>())
        #expect(articles.count == 1)
        #expect(articles.first?.title == "https://example.com/notitle")
    }

    /// 5: title あり → そのまま使用
    @Test func testSaveWithTitleStoresTitle() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let inserted = try ArticleSavingActor.performSave(
            url: "https://example.com/withtitle",
            title: "AI 入門",
            in: context
        )

        #expect(inserted == true)

        let articles = try context.fetch(FetchDescriptor<Article>())
        #expect(articles.count == 1)
        #expect(articles.first?.title == "AI 入門")
    }
}

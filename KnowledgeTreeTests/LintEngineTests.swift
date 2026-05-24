//
//  LintEngineTests.swift
//  KnowledgeTreeTests
//
//  spec 058 — LintEngine 6 step の idempotent + 各 step 単体テスト。
//  Mock LM + in-memory ModelContainer + AutoCategoryClassifier stub。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

@MainActor
struct LintEngineTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    // MARK: - 1. Levenshtein 編集距離 (純関数)

    @Test func testLevenshteinDistance() {
        #expect(DefaultLintEngine.levenshtein("", "") == 0)
        #expect(DefaultLintEngine.levenshtein("a", "") == 1)
        #expect(DefaultLintEngine.levenshtein("", "a") == 1)
        #expect(DefaultLintEngine.levenshtein("OpenAI", "OpenAI") == 0)
        #expect(DefaultLintEngine.levenshtein("OpenAI", "openai") == 3)  // O→o, A→a, I→i
        #expect(DefaultLintEngine.levenshtein("openai", "open ai") == 1)  // space 1 insertion
        #expect(DefaultLintEngine.levenshtein("apple", "ample") == 1)  // p→m substitution
    }

    // MARK: - 2. Step 1: ConceptPage merge (重複統合)

    @Test func testMergeDuplicateConceptPages() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let page1 = ConceptPage(name: "OpenAI", categoryRaw: "テクノロジー", isStale: false)
        page1.updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let page2 = ConceptPage(name: "Open AI", categoryRaw: "テクノロジー", isStale: false)  // 編集距離 1
        page2.updatedAt = Date(timeIntervalSince1970: 1_700_000_100)  // 新しい
        context.insert(page1)
        context.insert(page2)
        try context.save()

        let engine = DefaultLintEngine(context: context)
        let result = await engine.runFullLintLoop()

        // 1 件 merge
        #expect(result.mergedCount == 1)

        // page2 が winner として残る (updatedAt 新)
        let remaining = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
        #expect(remaining.count == 1)
        #expect(remaining[0].name == "Open AI")
        // page1.name が nameAliases に入る
        #expect(remaining[0].nameAliases.contains("OpenAI"))

        // LintLog 記録
        let logs = (try? context.fetch(FetchDescriptor<LintLog>())) ?? []
        #expect(logs.contains { $0.action == .merge })
    }

    // MARK: - 3. Step 1 idempotent (2 回実行で同結果)

    @Test func testMergeIsIdempotent() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let page1 = ConceptPage(name: "OpenAI", categoryRaw: "テクノロジー", isStale: false)
        let page2 = ConceptPage(name: "Open AI", categoryRaw: "テクノロジー", isStale: false)
        page2.updatedAt = page1.updatedAt.addingTimeInterval(10)
        context.insert(page1)
        context.insert(page2)
        try context.save()

        let engine = DefaultLintEngine(context: context)
        _ = await engine.runFullLintLoop()
        let result2 = await engine.runFullLintLoop()

        // 2 回目は merge 候補ゼロ (idempotent)
        #expect(result2.mergedCount == 0)
    }

    // MARK: - 4. Step 1: 異なる category は merge しない

    @Test func testMergeRespectsCategoryBoundary() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let page1 = ConceptPage(name: "Apple", categoryRaw: "テクノロジー", isStale: false)
        let page2 = ConceptPage(name: "Apple", categoryRaw: "食品", isStale: false)  // 同名、異 category
        context.insert(page1)
        context.insert(page2)
        try context.save()

        let engine = DefaultLintEngine(context: context)
        let result = await engine.runFullLintLoop()

        #expect(result.mergedCount == 0)  // category 違いで merge しない
        let remaining = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
        #expect(remaining.count == 2)
    }

    // MARK: - 5. Step 2: ConceptPage 孤立 cleanup

    @Test func testDeleteOrphanedConceptPage() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        // 関連記事 0 件 + 60 日前 + isFollowing=false な ConceptPage
        let orphan = ConceptPage(name: "Old", categoryRaw: "テクノロジー", isFollowing: false, isStale: false)
        orphan.updatedAt = Date.now.addingTimeInterval(-61 * 86400)
        context.insert(orphan)

        // 関連記事 1 件 (1 件ちょうど = 削除候補)
        let article = Article(url: "https://example.com", title: "Test")
        context.insert(article)
        let almostOrphan = ConceptPage(name: "AlmostOrphan", categoryRaw: "テクノロジー", isFollowing: false, isStale: false)
        almostOrphan.relatedArticles = [article]
        almostOrphan.updatedAt = Date.now.addingTimeInterval(-61 * 86400)
        context.insert(almostOrphan)

        // isFollowing=true なら保護
        let protected = ConceptPage(name: "Protected", categoryRaw: "テクノロジー", isFollowing: true, isStale: false)
        protected.updatedAt = Date.now.addingTimeInterval(-61 * 86400)
        context.insert(protected)

        try context.save()

        let engine = DefaultLintEngine(context: context)
        let result = await engine.runFullLintLoop()

        // 2 件削除 (orphan + almostOrphan)、protected は残る
        #expect(result.deletedConceptPageCount == 2)
        let remaining = (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
        #expect(remaining.contains { $0.name == "Protected" })
        #expect(!remaining.contains { $0.name == "Old" })
    }

    // MARK: - 6. Step 3: Tag 孤立 cleanup

    @Test func testDeleteOrphanedTags() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let tag1 = KnowledgeTree.Tag(name: "OrphanTag")
        let tag2 = KnowledgeTree.Tag(name: "ActiveTag")
        let article = Article(url: "https://example.com", title: "Test")
        article.tags = [tag2]
        context.insert(tag1)
        context.insert(tag2)
        context.insert(article)
        try context.save()

        let engine = DefaultLintEngine(context: context)
        let result = await engine.runFullLintLoop()

        #expect(result.deletedTagCount == 1)
        let remaining = (try? context.fetch(FetchDescriptor<KnowledgeTree.Tag>())) ?? []
        #expect(remaining.count == 1)
        #expect(remaining[0].name == "ActiveTag")
    }

    // MARK: - 7. Step 4: link 強化

    @Test func testLinkOrphanedConceptPages() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        // 3 件の同 category ConceptPage、すべて links 0
        // 名前は merge されないよう編集距離 > 2 にする (Alpha / Beta / Gamma)
        let page1 = ConceptPage(name: "Alpha", categoryRaw: "テクノロジー")
        let page2 = ConceptPage(name: "BetaCorp", categoryRaw: "テクノロジー")
        let page3 = ConceptPage(name: "Gamma", categoryRaw: "テクノロジー")
        context.insert(page1)
        context.insert(page2)
        context.insert(page3)
        try context.save()

        let engine = DefaultLintEngine(context: context)
        let result = await engine.runFullLintLoop()

        // 3 件全てに link 追加された
        #expect(result.linkedCount == 3)
    }

    // MARK: - 8. LintLog 永続化 + cap

    @Test func testLintLogIsPersisted() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let page1 = ConceptPage(name: "OpenAI", categoryRaw: "テクノロジー", isStale: false)
        let page2 = ConceptPage(name: "Open AI", categoryRaw: "テクノロジー", isStale: false)
        page2.updatedAt = page1.updatedAt.addingTimeInterval(10)
        context.insert(page1)
        context.insert(page2)
        try context.save()

        let engine = DefaultLintEngine(context: context)
        _ = await engine.runFullLintLoop()

        let logs = (try? context.fetch(FetchDescriptor<LintLog>())) ?? []
        #expect(!logs.isEmpty)
        #expect(logs.contains { $0.action == .merge })
        #expect(logs.first?.targetName == "OpenAI")
    }

    // MARK: - 9. LintLoopResult 集計

    @Test func testFullLoopResultSummary() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        // 何もデータなし
        let engine = DefaultLintEngine(context: context)
        let result = await engine.runFullLintLoop()

        #expect(result.totalOperations == 0)
        #expect(result.elapsedSeconds >= 0)
    }

    // MARK: - 10. inactiveCleanupDays 注入で deterministic

    @Test func testInactiveCleanupDaysIsInjectable() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let page = ConceptPage(name: "Recent", categoryRaw: "テクノロジー", isFollowing: false, isStale: false)
        page.updatedAt = Date.now.addingTimeInterval(-5 * 86400)  // 5 日前
        context.insert(page)
        try context.save()

        // 閾値 3 日 → 削除候補
        let engine = DefaultLintEngine(context: context, inactiveCleanupDays: 3)
        let result = await engine.runFullLintLoop()

        #expect(result.deletedConceptPageCount == 1)
    }
}

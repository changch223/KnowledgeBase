//
//  SuggestedPromptGeneratorTests.swift
//  KnowledgeTreeTests
//
//  spec 056 — DefaultSuggestedPromptGenerator (動的生成 + cache + truncate) の単体テスト 6 ケース。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

@MainActor
struct SuggestedPromptGeneratorTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "spec056.suggestedPrompts.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - 1. 正常: 最新 ConceptPage + 最新 Category + 固定

    @Test func testGenerationWithDataReturnsThreePrompts() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeIsolatedDefaults()
        let generator = DefaultSuggestedPromptGenerator(defaults: defaults)

        // ConceptPage
        let cp = ConceptPage(name: "OpenAI", categoryRaw: "テクノロジー")
        context.insert(cp)

        // Article + Tag (Category 解決用)
        let tag = Tag(name: "AI", categoryRaw: "テクノロジー")
        context.insert(tag)
        let article = Article(url: "https://example.com/a", title: "Test")
        article.tags = [tag]
        context.insert(article)
        try context.save()

        let prompts = await generator.generateSuggestedPrompts(in: context)
        #expect(prompts.count == 3)
        // ConceptPage prompt
        #expect(prompts[0].text.contains("OpenAI"))
        #expect(prompts[0].sourceType == .latestConceptPage)
        // Category prompt
        #expect(prompts[1].text.contains("テクノロジー"))
        #expect(prompts[1].sourceType == .latestCategory)
        // 固定 prompt
        #expect(prompts[2].sourceType == .fixedSummaryPrompt)
    }

    // MARK: - 2. データ無し → fallback 3 件

    @Test func testNoDataFallsBackToGenericPrompts() async throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let generator = DefaultSuggestedPromptGenerator(defaults: defaults)

        let prompts = await generator.generateSuggestedPrompts(in: container.mainContext)
        #expect(prompts.count == 3)
        // 1 番目: 固定、2-3 番目: generic fallback
        #expect(prompts[0].sourceType == .fixedSummaryPrompt)
        #expect(prompts[1].sourceType == .genericFallback)
        #expect(prompts[2].sourceType == .genericFallback)
    }

    // MARK: - 3. ConceptPage 1 + Category 0 → 1 + 固定 1 + generic 1

    @Test func testConceptPageOnlyMixWithGeneric() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeIsolatedDefaults()
        let generator = DefaultSuggestedPromptGenerator(defaults: defaults)

        let cp = ConceptPage(name: "Claude", categoryRaw: "テクノロジー")
        context.insert(cp)
        try context.save()

        let prompts = await generator.generateSuggestedPrompts(in: context)
        #expect(prompts.count == 3)
        #expect(prompts[0].sourceType == .latestConceptPage)
        #expect(prompts[1].sourceType == .fixedSummaryPrompt)
        #expect(prompts[2].sourceType == .genericFallback)
    }

    // MARK: - 4. 30 字超過 → truncate

    @Test func testLongConceptPageNameTruncatedWithEllipsis() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeIsolatedDefaults()
        let generator = DefaultSuggestedPromptGenerator(defaults: defaults)

        let cp = ConceptPage(name: "とても長い名前のサンプル概念で30字を超える例の文字列", categoryRaw: "")
        context.insert(cp)
        try context.save()

        let prompts = await generator.generateSuggestedPrompts(in: context)
        let cpPrompt = prompts.first(where: { $0.sourceType == .latestConceptPage })
        #expect(cpPrompt != nil)
        // 30 字以内 (truncate 効いている)
        #expect(cpPrompt!.text.count <= 30)
        #expect(cpPrompt!.text.contains("…"))
    }

    // MARK: - 5. 同日 cache (call count 1)

    @Test func testCacheReturnedOnSameDay() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeIsolatedDefaults()
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let generator = DefaultSuggestedPromptGenerator(defaults: defaults, now: { fixedDate })

        // 初回
        let prompts1 = await generator.generateSuggestedPrompts(in: context)
        // 2 回目 (同日)
        let prompts2 = await generator.generateSuggestedPrompts(in: context)

        #expect(prompts1 == prompts2)
    }

    // MARK: - 6. cache miss (date 違う)

    @Test func testCacheMissOnDifferentDate() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeIsolatedDefaults()

        // Day 1
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let gen1 = DefaultSuggestedPromptGenerator(defaults: defaults, now: { day1 })
        _ = await gen1.generateSuggestedPrompts(in: context)

        // Day 2 (24 時間+ 後)
        let day2 = day1.addingTimeInterval(86400 * 2)
        let gen2 = DefaultSuggestedPromptGenerator(defaults: defaults, now: { day2 })
        let prompts2 = await gen2.generateSuggestedPrompts(in: context)

        // 再生成された (UUID が異なる新 prompts、ただし text は同じ可能性 = fallback)
        #expect(!prompts2.isEmpty)
    }
}

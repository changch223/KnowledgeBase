//
//  ConceptHierarchyTests.swift
//  KnowledgeTreeTests
//
//  spec 074 — 概念階層 (広い概念 + 具体概念) + 動的カテゴリレジストリの検証。
//

import Testing
import Foundation
import SwiftData
import os
@testable import KnowledgeBase

private typealias Tag = KnowledgeBase.Tag

@MainActor
struct ConceptHierarchyTests {

    private let logger = Logger(subsystem: "app.KnowledgeTree.tests", category: "concept-hierarchy")

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    @discardableResult
    private func makeArticle(
        url: String,
        title: String,
        categoryRaw: String,
        essence: String = "essence text",
        savedAt: Date = .now,
        in context: ModelContext
    ) -> Article {
        let article = Article(url: url, title: title, savedAt: savedAt)
        context.insert(article)
        let tag = Tag(name: "tag-\(url)", categoryRaw: categoryRaw)
        context.insert(tag)
        article.tags?.append(tag)
        let knowledge = ExtractedKnowledge(article: article, status: .succeeded)
        knowledge.essence = essence
        context.insert(knowledge)
        article.extractedKnowledge = knowledge
        return article
    }

    private func makeFoundationService(
        context: ModelContext,
        session: MockLanguageModelSession,
        available: Bool = true
    ) -> FoundationModelsConceptSynthesisService {
        let checker = MockAvailabilityChecker()
        checker.isAvailable = available
        let fallback = FallbackConceptSynthesisService(context: context, refreshTrigger: nil)
        return FoundationModelsConceptSynthesisService(
            session: session,
            availability: checker,
            fallback: fallback,
            embeddingService: nil,
            context: context,
            refreshTrigger: nil
        )
    }

    private func fetchPages(_ context: ModelContext) -> [ConceptPage] {
        (try? context.fetch(FetchDescriptor<ConceptPage>())) ?? []
    }

    // MARK: - 1. processConceptHierarchy: broad + specific を親子付きで作成

    @Test func testProcessConceptHierarchyCreatesBroadAndSpecific() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let article = makeArticle(url: "https://a.com/1", title: "Text-to-SQL の設計", categoryRaw: "テクノロジー", in: context)

        ConceptSynthesisCommon.processConceptHierarchy(
            article: article,
            hierarchy: ConceptHierarchyOutput(
                broadConcept: "生成AI",
                specificConcepts: ["Text-to-SQL", "データエンジニアリング"]
            ),
            context: context,
            refreshTrigger: nil,
            logger: logger
        )

        let pages = fetchPages(context)
        #expect(pages.count == 3)

        let broad = pages.first { $0.name == "生成AI" }
        #expect(broad != nil)
        #expect(broad?.level == .broad)
        #expect(broad?.parentConceptID == nil)
        #expect(broad?.relatedArticles?.contains(where: { $0.id == article.id }) == true)

        let specific = pages.first { $0.name == "Text-to-SQL" }
        #expect(specific != nil)
        #expect(specific?.level == .specific)
        #expect(specific?.parentConceptID == broad?.id)
        #expect(specific?.relatedArticles?.contains(where: { $0.id == article.id }) == true)
    }

    // MARK: - 2. broad と同名の specific は skip + 短すぎる名前 skip

    @Test func testProcessConceptHierarchySkipsDuplicateAndShortNames() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let article = makeArticle(url: "https://a.com/2", title: "t", categoryRaw: "テクノロジー", in: context)

        ConceptSynthesisCommon.processConceptHierarchy(
            article: article,
            hierarchy: ConceptHierarchyOutput(
                broadConcept: "生成AI",
                specificConcepts: ["生成AI", "X", "RAG"]  // 同名 + 1 文字 は除外
            ),
            context: context,
            refreshTrigger: nil,
            logger: logger
        )

        let pages = fetchPages(context)
        // 生成AI (broad) + RAG (specific) のみ
        #expect(pages.count == 2)
        #expect(pages.contains { $0.name == "RAG" && $0.level == .specific })
        #expect(pages.filter { $0.name == "生成AI" }.count == 1)
    }

    // MARK: - 3. 同名 + 同カテゴリは再利用 (dedup)、両記事 link

    @Test func testHierarchyDedupReusesSamePage() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let a1 = makeArticle(url: "https://a.com/3", title: "t1", categoryRaw: "テクノロジー", in: context)
        let a2 = makeArticle(url: "https://a.com/4", title: "t2", categoryRaw: "テクノロジー", in: context)

        let h = ConceptHierarchyOutput(broadConcept: "生成AI", specificConcepts: ["Text-to-SQL"])
        ConceptSynthesisCommon.processConceptHierarchy(article: a1, hierarchy: h, context: context, refreshTrigger: nil, logger: logger)
        ConceptSynthesisCommon.processConceptHierarchy(article: a2, hierarchy: h, context: context, refreshTrigger: nil, logger: logger)

        let pages = fetchPages(context)
        #expect(pages.count == 2)  // broad 1 + specific 1 (重複作成しない)
        let broad = pages.first { $0.name == "生成AI" }
        #expect(broad?.relatedArticles?.count == 2)  // 両記事 link
    }

    // MARK: - 4. ingestArticle: AI 利用可で hierarchy を使う

    @Test func testIngestArticleUsesHierarchy() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = MockLanguageModelSession()
        session.nextConceptHierarchyResult = .success(
            ConceptHierarchyOutput(broadConcept: "生成AI", specificConcepts: ["Text-to-SQL"])
        )
        let service = makeFoundationService(context: context, session: session, available: true)
        let article = makeArticle(url: "https://a.com/5", title: "t", categoryRaw: "テクノロジー", in: context)

        await service.ingestArticle(article)

        #expect(session.conceptHierarchyCallCount == 1)
        let pages = fetchPages(context)
        #expect(pages.contains { $0.name == "生成AI" && $0.level == .broad })
        #expect(pages.contains { $0.name == "Text-to-SQL" && $0.level == .specific })
    }

    // MARK: - 5. ingestArticle: AI 失敗 → entity 共起へ degrade (crash しない)

    @Test func testIngestArticleFallsBackOnError() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = MockLanguageModelSession()
        session.nextConceptHierarchyResult = .failure(MockLanguageModelError.contextExceeded)
        let service = makeFoundationService(context: context, session: session, available: true)
        let article = makeArticle(url: "https://a.com/6", title: "t", categoryRaw: "テクノロジー", in: context)

        await service.ingestArticle(article)

        #expect(session.conceptHierarchyCallCount == 1)
        // hierarchy 由来の broad ページは作られない (entity も 1 件のみで生成されない)
        let pages = fetchPages(context)
        #expect(pages.contains { $0.level == .broad } == false)
    }

    // MARK: - 6. ingestArticle: AI 不可 → entity 共起へ degrade

    @Test func testIngestArticleDegradesWhenUnavailable() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = MockLanguageModelSession()
        let service = makeFoundationService(context: context, session: session, available: false)
        let article = makeArticle(url: "https://a.com/7", title: "t", categoryRaw: "テクノロジー", in: context)

        await service.ingestArticle(article)

        #expect(session.conceptHierarchyCallCount == 0)  // AI 呼ばない
    }

    // MARK: - 7. 広い概念の synth は子トピックを prompt に含める

    @Test func testBroadConceptSynthesisUsesChildren() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let session = MockLanguageModelSession()
        session.nextConceptSynthesisResult = .success(
            ConceptSynthesisOutput(summary: "広い概念のまとめ", crossSourceInsights: [])
        )
        let service = makeFoundationService(context: context, session: session, available: true)
        let article = makeArticle(url: "https://a.com/8", title: "t", categoryRaw: "テクノロジー", essence: "生成AIの記事", in: context)

        // broad + child を作る
        ConceptSynthesisCommon.processConceptHierarchy(
            article: article,
            hierarchy: ConceptHierarchyOutput(broadConcept: "生成AI", specificConcepts: ["Text-to-SQL"]),
            context: context,
            refreshTrigger: nil,
            logger: logger
        )
        let broad = fetchPages(context).first { $0.name == "生成AI" }!

        await service.resynthesize(broad)

        #expect(session.conceptSynthesisCallCount >= 1)
        #expect(session.lastConceptSynthesisPrompt?.contains("Text-to-SQL") == true)
        #expect(session.lastConceptSynthesisPrompt?.contains("広い分野概念") == true)
    }

    // MARK: - 8. CategoryRegistry: 10 シードを idempotent に seed

    @Test func testCategoryRegistrySeedsTenIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let registry = CategoryRegistry(context: context)

        registry.seedIfNeeded()
        registry.seedIfNeeded()  // 2 回呼んでも重複しない

        let defs = (try? context.fetch(FetchDescriptor<CategoryDefinition>())) ?? []
        #expect(defs.count == 10)
        #expect(defs.allSatisfy { $0.isSeed })
        #expect(Set(defs.map { $0.name }) == Set(CategorySeed.allSeeds.map { $0.name }))
    }

    // MARK: - 9. CategoryRegistry: 動的カテゴリが候補・有効名に反映される

    @Test func testCategoryRegistryReflectsDynamicCategory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let registry = CategoryRegistry(context: context)
        registry.seedIfNeeded()

        context.insert(CategoryDefinition(name: "宇宙開発", definition: "ロケット/宇宙探査", isSeed: false, order: 10))
        try? context.save()

        #expect(registry.validNames().contains("宇宙開発"))
        #expect(registry.categoryExists(name: "宇宙開発"))
        #expect(registry.promptCandidatesWithDefinitions().contains("宇宙開発"))
        #expect(registry.validNames().count == 11)
    }
}

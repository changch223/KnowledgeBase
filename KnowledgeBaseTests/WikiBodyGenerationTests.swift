//
//  WikiBodyGenerationTests.swift
//  KnowledgeTreeTests
//
//  spec 063 (LLM Wiki 土台) — ConceptPage.bodyMarkdown 生成 + kind 自動判定の検証。
//  generateWikiBody は plain string (token 超過回避) で、resynthesize の hook 経由で呼ばれる。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeBase

@MainActor
struct WikiBodyGenerationTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    private func makeArticle(essence: String, entityTypes: [String], in context: ModelContext) -> Article {
        let article = Article(url: "https://example.com/\(UUID().uuidString)", title: "記事", savedAt: .now)
        context.insert(article)
        let knowledge = ExtractedKnowledge(article: article, status: .succeeded)
        knowledge.essence = essence
        context.insert(knowledge)
        article.extractedKnowledge = knowledge
        for (idx, t) in entityTypes.enumerated() {
            let e = KnowledgeEntity(knowledge: knowledge, name: "E_\(t)", typeRaw: t, salience: 3, order: idx)
            context.insert(e)
            knowledge.entities?.append(e)
        }
        return article
    }

    private func makeService(session: MockLanguageModelSession, availability: MockAvailabilityChecker, context: ModelContext) -> FoundationModelsConceptSynthesisService {
        FoundationModelsConceptSynthesisService(
            session: session,
            availability: availability,
            fallback: FallbackConceptSynthesisService(context: context),
            context: context
        )
    }

    // MARK: - 1. 生成成功 → bodyMarkdown 反映

    @Test func testBodyMarkdownGeneratedOnSuccess() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let article = makeArticle(essence: "OpenAI が新モデルを発表", entityTypes: ["organization"], in: context)
        let page = ConceptPage(name: "OpenAI", categoryRaw: "テクノロジー", summary: "OpenAI の概要", relatedArticles: [article])
        context.insert(page)
        try context.save()

        let session = MockLanguageModelSession()
        session.nextWikiBodyResult = .success("## 概要\nOpenAI は AI 企業。\n\n- GPT を開発")
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        await makeService(session: session, availability: availability, context: context).resynthesize(page)

        #expect(page.bodyMarkdown.contains("OpenAI は AI 企業"))
        #expect(session.wikiBodyCallCount == 1)
    }

    // MARK: - 2. availability なし → summary を fallback

    @Test func testFallsBackToSummaryWhenUnavailable() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let article = makeArticle(essence: "概要テキスト", entityTypes: ["concept"], in: context)
        let page = ConceptPage(name: "概念X", categoryRaw: "テクノロジー", summary: "これは概念 X の要約です", relatedArticles: [article])
        context.insert(page)
        try context.save()

        let session = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = false

        await makeService(session: session, availability: availability, context: context).resynthesize(page)

        // availability=false なら fallback service 経由 (本文は summary 流用 or fallback 生成)
        #expect(session.wikiBodyCallCount == 0)
    }

    // MARK: - 3. bodyEditedByUser=true → 生成スキップ

    @Test func testSkipsGenerationWhenUserEdited() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let article = makeArticle(essence: "essence", entityTypes: ["concept"], in: context)
        let page = ConceptPage(name: "概念Y", categoryRaw: "テクノロジー", summary: "要約", relatedArticles: [article])
        page.bodyMarkdown = "ユーザーが手で書いた本文"
        page.bodyEditedByUser = true
        context.insert(page)
        try context.save()

        let session = MockLanguageModelSession()
        session.nextWikiBodyResult = .success("AI が上書きしようとした本文")
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        await makeService(session: session, availability: availability, context: context).resynthesize(page)

        // ユーザー訂正は保護され、AI 生成は呼ばれない
        #expect(page.bodyMarkdown == "ユーザーが手で書いた本文")
        #expect(session.wikiBodyCallCount == 0)
    }

    // MARK: - 4. kind 判定

    @Test func testInferKindPerson() {
        let container = try! makeContainer()
        let context = container.mainContext
        let article = makeArticle(essence: "e", entityTypes: ["person", "person", "concept"], in: context)
        #expect(FoundationModelsConceptSynthesisService.inferKind(from: [article]) == .person)
    }

    @Test func testInferKindConcept() {
        let container = try! makeContainer()
        let context = container.mainContext
        let article = makeArticle(essence: "e", entityTypes: ["concept", "product", "location"], in: context)
        #expect(FoundationModelsConceptSynthesisService.inferKind(from: [article]) == .concept)
    }

    @Test func testInferKindNilWhenNoEntities() {
        let container = try! makeContainer()
        let context = container.mainContext
        let article = makeArticle(essence: "e", entityTypes: [], in: context)
        #expect(FoundationModelsConceptSynthesisService.inferKind(from: [article]) == nil)
    }

    // MARK: - 5. 空 AI 出力 → 既存 bodyMarkdown 保持

    @Test func testKeepsExistingBodyWhenAIReturnsEmpty() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let article = makeArticle(essence: "essence", entityTypes: ["concept"], in: context)
        let page = ConceptPage(name: "概念Z", categoryRaw: "テクノロジー", summary: "要約", relatedArticles: [article])
        page.bodyMarkdown = "既存の本文"
        context.insert(page)
        try context.save()

        let session = MockLanguageModelSession()
        session.nextWikiBodyResult = .success("   ")  // 空白のみ
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        await makeService(session: session, availability: availability, context: context).resynthesize(page)

        #expect(page.bodyMarkdown == "既存の本文")
    }

    // MARK: - 6. AI 復旧機能: generateWikiBody が throw + call 中に AI が本当に落ちた (availability が
    //    false になった) → synthesizedWithoutAI = true (復旧対象としてマークされる)

    @Test func testCatchBranchFlagsSynthesizedWithoutAIWhenAvailabilityDropsMidCall() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let article = makeArticle(essence: "OpenAI が新モデルを発表", entityTypes: ["organization"], in: context)
        let page = ConceptPage(name: "OpenAI", categoryRaw: "テクノロジー", summary: "OpenAI の概要", relatedArticles: [article])
        context.insert(page)
        try context.save()

        let session = MockLanguageModelSession()
        session.nextWikiBodyResult = .failure(MockLanguageModelError.timeout)
        // 呼び出し順: ① _resynthesize 冒頭 guard、② generateBodyMarkdown 冒頭 guard、
        // ③ 新設の catch 内チェック。① ② は通過させ、③ で落ちている状態を再現する。
        let availability = SequencedAvailabilityChecker([true, true, false])

        let service = FoundationModelsConceptSynthesisService(
            session: session,
            availability: availability,
            fallback: FallbackConceptSynthesisService(context: context),
            context: context
        )

        await service.resynthesize(page)

        #expect(page.synthesizedWithoutAI == true)
    }

    // MARK: - 7. AI 復旧機能: generateWikiBody が throw しても availability が true のまま
    //    (overflow 等の別要因を模倣) → synthesizedWithoutAI は false のまま (futile 再試行ループ回避)

    @Test func testCatchBranchDoesNotFlagWhenAvailabilityStaysTrue() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let article = makeArticle(essence: "OpenAI が新モデルを発表", entityTypes: ["organization"], in: context)
        let page = ConceptPage(name: "OpenAI", categoryRaw: "テクノロジー", summary: "OpenAI の概要", relatedArticles: [article])
        context.insert(page)
        try context.save()

        let session = MockLanguageModelSession()
        session.nextWikiBodyResult = .failure(MockLanguageModelError.contextExceeded)
        let availability = MockAvailabilityChecker()
        availability.isAvailable = true

        let service = FoundationModelsConceptSynthesisService(
            session: session,
            availability: availability,
            fallback: FallbackConceptSynthesisService(context: context),
            context: context
        )

        await service.resynthesize(page)

        #expect(page.synthesizedWithoutAI == false)
    }
}

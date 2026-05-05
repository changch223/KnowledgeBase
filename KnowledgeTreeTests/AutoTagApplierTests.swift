//
//  AutoTagApplierTests.swift
//  KnowledgeTreeTests
//
//  spec 012 — contracts/auto-tag-applier.md 7 ケース。
//  in-memory ModelContainer を使い Article / ExtractedKnowledge / KnowledgeEntity /
//  Tag をリアル組み立てて純粋関数 AutoTagApplier.apply の挙動を網羅検証。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

// SwiftUI も `Tag` 型 (Picker/TabView 用) を持つため、
// `@testable import KnowledgeTree` 経由で曖昧化する。明示 typealias で解決 (spec 011 と同パターン)。
private typealias Tag = KnowledgeTree.Tag

@MainActor
struct AutoTagApplierTests {

    // MARK: - Test fixture

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Article.self, ArticleEnrichment.self, ArticleBody.self,
                ExtractedKnowledge.self, KeyFact.self, KnowledgeEntity.self,
                Tag.self, KnowledgeChunkProgress.self,
                BackgroundExtractionQueueEntry.self,
            configurations: configuration
        )
    }

    /// salience リストから entities を生成し、Article + ExtractedKnowledge にリンク。
    /// status は引数で制御 (default .succeeded)。
    /// entityNames を渡せば custom name を使い、無ければ "entity-{salience}-{index}" を自動生成。
    @discardableResult
    private func makeArticleWithEntities(
        salienceList: [Int],
        status: ExtractionStatus = .succeeded,
        url: String = "https://example.com/test",
        entityNames: [String]? = nil,
        in context: ModelContext
    ) -> Article {
        let article = Article(url: url, title: "Test")
        context.insert(article)
        let knowledge = ExtractedKnowledge(article: article, status: status)
        context.insert(knowledge)
        article.extractedKnowledge = knowledge
        for (index, salience) in salienceList.enumerated() {
            let name = entityNames?[index] ?? "entity-\(salience)-\(index)"
            let entity = KnowledgeEntity(
                knowledge: knowledge,
                name: name,
                typeRaw: "concept",
                salience: salience,
                order: index
            )
            context.insert(entity)
            knowledge.entities.append(entity)
        }
        return article
    }

    // MARK: - Tests

    @Test func testAppliesTopFiveWhenNoExistingTags() throws {
        // salience [5,5,4,4,4,3] → 上位 5 (salience>=4) が付与、salience=3 entity は除外
        let container = try makeContainer()
        let context = container.mainContext
        let article = makeArticleWithEntities(
            salienceList: [5, 5, 4, 4, 4, 3],
            entityNames: ["alpha", "beta", "gamma", "delta", "epsilon", "zeta"],
            in: context
        )
        let tagStore = TagStore(context: context)

        AutoTagApplier.apply(to: article, using: tagStore)

        #expect(article.tags.count == 5)
        let tagNames = Set(article.tags.map(\.name))
        #expect(tagNames == Set(["alpha", "beta", "gamma", "delta", "epsilon"]))
        #expect(!tagNames.contains("zeta"))  // salience=3 は除外
    }

    @Test func testSkipsWhenArticleHasManualTag() throws {
        // 既に手動タグ 1 件 → apply 後も tag count 不変 (US2)
        let container = try makeContainer()
        let context = container.mainContext
        let article = makeArticleWithEntities(
            salienceList: [5, 5, 4, 4, 4],
            entityNames: ["alpha", "beta", "gamma", "delta", "epsilon"],
            in: context
        )
        let tagStore = TagStore(context: context)

        // 手動タグを 1 件先に付与
        _ = try tagStore.addTag(rawName: "manual-tag", to: article)
        #expect(article.tags.count == 1)

        AutoTagApplier.apply(to: article, using: tagStore)

        #expect(article.tags.count == 1, "auto-apply should skip when manual tags exist")
        #expect(article.tags.first?.name == "manual-tag")
    }

    @Test func testSkipsWhenKnowledgeStatusIsFailed() throws {
        // status = .failed → tag 0 (FR-004 / US4)
        let container = try makeContainer()
        let context = container.mainContext
        let article = makeArticleWithEntities(
            salienceList: [5, 5, 4],
            status: .failed,
            in: context
        )
        let tagStore = TagStore(context: context)

        AutoTagApplier.apply(to: article, using: tagStore)

        #expect(article.tags.count == 0)
    }

    @Test func testSkipsWhenKnowledgeStatusIsPending() throws {
        // status = .pending → tag 0 (Edge case)
        let container = try makeContainer()
        let context = container.mainContext
        let article = makeArticleWithEntities(
            salienceList: [5, 5, 4],
            status: .pending,
            in: context
        )
        let tagStore = TagStore(context: context)

        AutoTagApplier.apply(to: article, using: tagStore)

        #expect(article.tags.count == 0)
    }

    @Test func testIdempotentOnDoubleInvocation() throws {
        // apply 2 回連続 → 結果同じ (1 回目で付与 → 2 回目は tags.count >= 1 で early return)
        let container = try makeContainer()
        let context = container.mainContext
        let article = makeArticleWithEntities(
            salienceList: [5, 5, 4, 4, 4],
            entityNames: ["alpha", "beta", "gamma", "delta", "epsilon"],
            in: context
        )
        let tagStore = TagStore(context: context)

        AutoTagApplier.apply(to: article, using: tagStore)
        let firstCount = article.tags.count
        let firstNames = Set(article.tags.map(\.name))

        AutoTagApplier.apply(to: article, using: tagStore)

        #expect(article.tags.count == firstCount)
        #expect(Set(article.tags.map(\.name)) == firstNames)
    }

    @Test func testReappliesAfterAllTagsRemoved() throws {
        // apply → 全削除 → 再 apply で同じ 5 件復活 (US3)
        let container = try makeContainer()
        let context = container.mainContext
        let article = makeArticleWithEntities(
            salienceList: [5, 5, 4, 4, 4],
            entityNames: ["alpha", "beta", "gamma", "delta", "epsilon"],
            in: context
        )
        let tagStore = TagStore(context: context)

        AutoTagApplier.apply(to: article, using: tagStore)
        let firstNames = Set(article.tags.map(\.name))
        #expect(firstNames.count == 5)

        // 全削除
        for name in firstNames {
            try tagStore.removeTag(normalizedName: name, from: article)
        }
        #expect(article.tags.count == 0)

        AutoTagApplier.apply(to: article, using: tagStore)

        #expect(article.tags.count == 5)
        #expect(Set(article.tags.map(\.name)) == firstNames)
    }

    @Test func testEmptyEntitiesNoTagsApplied() throws {
        // entities 0 件 → tag 0 (Edge case、salience>=4 候補なし)
        let container = try makeContainer()
        let context = container.mainContext
        let article = makeArticleWithEntities(
            salienceList: [],
            in: context
        )
        let tagStore = TagStore(context: context)

        AutoTagApplier.apply(to: article, using: tagStore)

        #expect(article.tags.count == 0)
    }
}

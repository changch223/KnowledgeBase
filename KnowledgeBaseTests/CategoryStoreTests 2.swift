//
//  CategoryStoreTests.swift
//  KnowledgeTreeTests
//
//  spec 075 — CategoryStore の rename cascade / merge / hide / 定義編集の検証。
//  ★中心リスク = Tag.categoryRaw / ConceptPage.categoryRaw (名前文字列で紐づく) の cascade。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeBase

@MainActor
struct CategoryStoreTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    private func makeStore(_ container: ModelContainer) -> CategoryStore {
        CategoryStore(context: container.mainContext)
    }

    @discardableResult
    private func insertCategory(_ ctx: ModelContext, name: String, isHidden: Bool = false, order: Int = 0) -> CategoryDefinition {
        let c = CategoryDefinition(name: name, definition: "", isSeed: false, isHidden: isHidden, order: order)
        ctx.insert(c)
        return c
    }

    // MARK: - rename cascade

    @Test func renameCascadesToTagAndConceptCategoryRaw() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        let category = insertCategory(ctx, name: "テクノロジー")
        let tag = KnowledgeBase.Tag(name: "AI", categoryRaw: "テクノロジー")
        ctx.insert(tag)
        let page = ConceptPage(name: "生成AI", categoryRaw: "テクノロジー", summary: "x", updatedAt: .now)
        ctx.insert(page)
        // 別カテゴリの Tag は影響を受けない
        let otherTag = KnowledgeBase.Tag(name: "経済ニュース", categoryRaw: "経済")
        ctx.insert(otherTag)
        try ctx.save()

        try makeStore(c).rename(category, to: "技術")

        #expect(category.name == "技術")
        #expect(tag.categoryRaw == "技術")
        #expect(page.categoryRaw == "技術")
        #expect(otherTag.categoryRaw == "経済")  // 無関係は不変
    }

    @Test func renameToExistingActiveNameThrowsDuplicate() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        let a = insertCategory(ctx, name: "テクノロジー")
        insertCategory(ctx, name: "経済")
        try ctx.save()

        #expect(throws: CategoryStoreError.self) {
            try makeStore(c).rename(a, to: "経済")
        }
    }

    @Test func renameEmptyThrowsInvalidName() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        let a = insertCategory(ctx, name: "テクノロジー")
        try ctx.save()

        #expect(throws: CategoryStoreError.self) {
            try makeStore(c).rename(a, to: "   ")
        }
    }

    // MARK: - merge

    @Test func mergeReassignsCategoryRawAndHidesSource() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        let source = insertCategory(ctx, name: "AI")
        let target = insertCategory(ctx, name: "テクノロジー")
        let tag = KnowledgeBase.Tag(name: "LLM", categoryRaw: "AI")
        ctx.insert(tag)
        let page = ConceptPage(name: "RAG", categoryRaw: "AI", summary: "x", updatedAt: .now)
        ctx.insert(page)
        try ctx.save()

        try makeStore(c).merge(source: source, into: target)

        #expect(tag.categoryRaw == "テクノロジー")
        #expect(page.categoryRaw == "テクノロジー")
        #expect(source.isHidden == true)   // 物理削除でなく非表示
        #expect(target.isHidden == false)
    }

    // MARK: - hide / unhide

    @Test func hideAndUnhideToggle() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        let category = insertCategory(ctx, name: "テクノロジー")
        try ctx.save()

        let store = makeStore(c)
        try store.hide(category)
        #expect(category.isHidden == true)
        try store.unhide(category)
        #expect(category.isHidden == false)
    }

    // MARK: - definition

    @Test func updateDefinitionPersists() throws {
        let c = try makeContainer()
        let ctx = c.mainContext
        let category = insertCategory(ctx, name: "テクノロジー")
        try ctx.save()

        try makeStore(c).updateDefinition(category, to: "AI/プログラミング。例: Claude, RAG")
        #expect(category.definition == "AI/プログラミング。例: Claude, RAG")
    }
}

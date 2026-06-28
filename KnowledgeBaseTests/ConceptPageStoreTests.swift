//
//  ConceptPageStoreTests.swift
//  KnowledgeTreeTests
//
//  spec 042 — ConceptPageStore の 8 ケース。
//  rename / merge / delete / setFollowing の正常系 + 全 error 分岐。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeBase

@MainActor
struct ConceptPageStoreTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    @discardableResult
    private func makePage(
        name: String,
        categoryRaw: String = "テクノロジー",
        aliases: [String] = [],
        followers: Bool = false,
        in context: ModelContext
    ) -> ConceptPage {
        let page = ConceptPage(
            name: name,
            nameAliases: aliases,
            categoryRaw: categoryRaw,
            summary: "既存 summary",
            isFollowing: followers,
            isStale: false
        )
        context.insert(page)
        return page
    }

    // MARK: - 1. rename 正常

    @Test func testRenameNormalUpdatesAndMarksStale() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = makePage(name: "Apple", in: context)
        try context.save()

        let store = ConceptPageStore(context: context)
        let result = try store.rename(page, to: "Apple Inc.")

        #expect(result.name == "Apple Inc.")
        #expect(result.isStale == true)
    }

    // MARK: - 2. rename 空文字 → throw .emptyName

    @Test func testRenameEmptyThrowsEmptyName() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = makePage(name: "Apple", in: context)
        try context.save()

        let store = ConceptPageStore(context: context)
        do {
            _ = try store.rename(page, to: "   ")
            Issue.record("expected .emptyName error")
        } catch let error as ConceptPageStoreError {
            #expect(error == .emptyName)
        }
    }

    // MARK: - 3. rename 30 字超 → throw .nameTooLong

    @Test func testRenameTooLongThrowsNameTooLong() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = makePage(name: "Apple", in: context)
        try context.save()

        let store = ConceptPageStore(context: context)
        let longName = String(repeating: "あ", count: 31)
        do {
            _ = try store.rename(page, to: longName)
            Issue.record("expected .nameTooLong error")
        } catch let error as ConceptPageStoreError {
            #expect(error == .nameTooLong)
        }
    }

    // MARK: - 4. rename 同 category 内重複 → throw .duplicateInCategory

    @Test func testRenameDuplicateInCategoryThrows() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pageA = makePage(name: "Apple", in: context)
        _ = makePage(name: "Microsoft", in: context)
        try context.save()

        let store = ConceptPageStore(context: context)
        // 大文字小文字無視で重複判定
        do {
            _ = try store.rename(pageA, to: "MICROSOFT")
            Issue.record("expected .duplicateInCategory error")
        } catch let error as ConceptPageStoreError {
            #expect(error == .duplicateInCategory)
        }
    }

    // MARK: - 5. merge: target に統合、source 削除、aliases 吸収

    @Test func testMergeUnitesArticlesAndDeletesSource() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article1 = Article(url: "a", title: "A")
        let article2 = Article(url: "b", title: "B")
        let article3 = Article(url: "c", title: "C")
        context.insert(article1)
        context.insert(article2)
        context.insert(article3)

        let source = ConceptPage(
            name: "アップル",
            nameAliases: ["Apple Inc."],
            categoryRaw: "テクノロジー",
            relatedArticles: [article1, article2],
            isFollowing: true,
            isStale: false
        )
        let target = ConceptPage(
            name: "Apple",
            categoryRaw: "テクノロジー",
            relatedArticles: [article2, article3],
            isFollowing: false,
            isStale: false
        )
        context.insert(source)
        context.insert(target)
        try context.save()

        let store = ConceptPageStore(context: context)
        try store.merge(source: source, into: target)

        let pages = try context.fetch(FetchDescriptor<ConceptPage>())
        #expect(pages.count == 1)
        #expect(pages[0].id == target.id)
        #expect((pages[0].relatedArticles ?? []).count == 3)  // article1, article2, article3 (重複除外)
        #expect(pages[0].isStale == true)
        #expect(pages[0].isFollowing == true)  // OR
        #expect(pages[0].nameAliases.contains("アップル"))
        #expect(pages[0].nameAliases.contains("Apple Inc."))
    }

    // MARK: - 6. merge: source == target → throw .sameSourceTarget

    @Test func testMergeSameSourceTargetThrows() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = makePage(name: "Apple", in: context)
        try context.save()

        let store = ConceptPageStore(context: context)
        do {
            try store.merge(source: page, into: page)
            Issue.record("expected .sameSourceTarget error")
        } catch let error as ConceptPageStoreError {
            #expect(error == .sameSourceTarget)
        }
    }

    // MARK: - 7. delete: ConceptPage 削除、関連 Article は残る

    @Test func testDeleteRemovesPageButKeepsArticles() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article1 = Article(url: "a", title: "A")
        let article2 = Article(url: "b", title: "B")
        context.insert(article1)
        context.insert(article2)

        let pageToDelete = ConceptPage(
            name: "Apple", categoryRaw: "テクノロジー",
            relatedArticles: [article1, article2], isStale: false
        )
        let otherPage = ConceptPage(
            name: "Microsoft", categoryRaw: "テクノロジー",
            relatedConceptIDs: [pageToDelete.id], isStale: false
        )
        context.insert(pageToDelete)
        context.insert(otherPage)
        try context.save()

        let store = ConceptPageStore(context: context)
        try store.delete(pageToDelete)

        // ConceptPage 削除
        let pages = try context.fetch(FetchDescriptor<ConceptPage>())
        #expect(pages.count == 1)
        #expect(pages[0].id == otherPage.id)
        // 他 ConceptPage の relatedConceptIDs から削除されている
        #expect(!pages[0].relatedConceptIDs.contains(pageToDelete.id))
        // Article は残る
        let articles = try context.fetch(FetchDescriptor<Article>())
        #expect(articles.count == 2)
    }

    // MARK: - 8. setFollowing: pin toggle が永続化される

    @Test func testSetFollowingTogglesPersisted() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let page = makePage(name: "Apple", in: context)
        try context.save()
        #expect(page.isFollowing == false)

        let store = ConceptPageStore(context: context)
        try store.setFollowing(page, isFollowing: true)
        #expect(page.isFollowing == true)

        try store.setFollowing(page, isFollowing: false)
        #expect(page.isFollowing == false)
    }

    // MARK: - 9. spec 043: merge 時に SavedAnswer.relatedConceptIDs の source→target 置換

    @Test func testMergeReplacesSourceIDInSavedAnswerRelatedConceptIDs() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let source = makePage(name: "Apple Inc.", in: context)
        let target = makePage(name: "Apple", in: context)

        // Article fixture for SavedAnswer.citedArticles (空でも OK だが SavedAnswer 構築は valid な状態にしておく)
        let article1 = Article(url: "a", title: "A")
        let article2 = Article(url: "b", title: "B")
        context.insert(article1)
        context.insert(article2)

        // SavedAnswer 1: relatedConceptIDs に source のみ含む → target.id に置換されるはず
        let ans1 = SavedAnswer(
            question: "Q1?",
            answer: String(repeating: "あ", count: 80),
            citedArticles: [article1, article2],
            relatedConceptIDs: [source.id]
        )
        context.insert(ans1)

        // SavedAnswer 2: relatedConceptIDs に source + 他 ID 含む → source は target に置換、他は維持
        let other = UUID()
        let ans2 = SavedAnswer(
            question: "Q2?",
            answer: String(repeating: "あ", count: 80),
            citedArticles: [article1, article2],
            relatedConceptIDs: [source.id, other]
        )
        context.insert(ans2)

        // SavedAnswer 3: 既に target.id 含む + source.id も → 重複避ける
        let ans3 = SavedAnswer(
            question: "Q3?",
            answer: String(repeating: "あ", count: 80),
            citedArticles: [article1, article2],
            relatedConceptIDs: [target.id, source.id]
        )
        context.insert(ans3)

        try context.save()

        let store = ConceptPageStore(context: context)
        try store.merge(source: source, into: target)

        // ans1: source → target に置換
        #expect(ans1.relatedConceptIDs == [target.id])
        // ans2: source → target、他はそのまま (順序は append 後)
        #expect(Set(ans2.relatedConceptIDs) == Set([target.id, other]))
        // ans3: source 削除、target は既存ですでに含む (重複なし)
        #expect(ans3.relatedConceptIDs == [target.id])
    }
}

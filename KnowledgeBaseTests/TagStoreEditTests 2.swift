//
//  TagStoreEditTests.swift
//  KnowledgeTreeTests
//
//  spec 024 — TagStore.rename / merge / delete の 7 ケース。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeBase

private typealias Tag = KnowledgeBase.Tag

@MainActor
struct TagStoreEditTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    @discardableResult
    private func makeArticle(url: String, in context: ModelContext) -> Article {
        let article = Article(url: url, title: url)
        context.insert(article)
        return article
    }

    private func makeTag(name: String, in context: ModelContext) -> Tag {
        let tag = Tag(name: name)
        context.insert(tag)
        return tag
    }

    // MARK: - 1. rename: 単純名前変更

    @Test func testRenameSimpleChangesName() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let tag = makeTag(name: "swift", in: context)
        let article = makeArticle(url: "a", in: context)
        article.tags?.append(tag)
        try context.save()

        let store = TagStore(context: context)
        let result = try store.rename(tag, to: "Swift 6")

        // TagNormalizer は lowercase なので "swift 6"
        #expect(result.name == "swift 6")
        #expect((article.tags ?? []).contains(where: { $0.id == result.id }))
    }

    // MARK: - 2. rename: 同名既存あれば自動 merge

    @Test func testRenameToExistingNameTriggersMerge() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let oldTag = makeTag(name: "swift-5", in: context)
        let newTag = makeTag(name: "swift-6", in: context)
        let article = makeArticle(url: "a", in: context)
        article.tags?.append(oldTag)
        try context.save()

        let store = TagStore(context: context)
        let result = try store.rename(oldTag, to: "swift-6")

        // result は既存の newTag (id 一致)
        #expect(result.id == newTag.id)
        // article は newTag を持つ、oldTag は消える
        #expect((article.tags ?? []).contains(where: { $0.id == newTag.id }))
        #expect(!(article.tags ?? []).contains(where: { $0.name == "swift-5" }))

        let allTags = try context.fetch(FetchDescriptor<Tag>())
        #expect(allTags.count == 1)
        #expect(allTags.first?.name == "swift-6")
    }

    // MARK: - 3. merge: source の articles が target に移動、source 削除

    @Test func testMergeMovesArticlesAndDeletesSource() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let source = makeTag(name: "old", in: context)
        let target = makeTag(name: "new", in: context)
        let a1 = makeArticle(url: "a1", in: context)
        let a2 = makeArticle(url: "a2", in: context)
        a1.tags?.append(source)
        a2.tags?.append(source)
        try context.save()

        let store = TagStore(context: context)
        try store.merge(source: source, into: target)

        // a1, a2 は target を持つ
        #expect((a1.tags ?? []).contains(where: { $0.id == target.id }))
        #expect((a2.tags ?? []).contains(where: { $0.id == target.id }))
        // source は消える
        let allTags = try context.fetch(FetchDescriptor<Tag>())
        #expect(allTags.count == 1)
        #expect(allTags.first?.name == "new")
    }

    // MARK: - 4. merge: 両方 Tag が同 article に付いている場合の重複回避

    @Test func testMergeAvoidsDuplicateOnSameArticle() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let source = makeTag(name: "old", in: context)
        let target = makeTag(name: "new", in: context)
        let article = makeArticle(url: "a", in: context)
        article.tags?.append(source)
        article.tags?.append(target)
        try context.save()

        let store = TagStore(context: context)
        try store.merge(source: source, into: target)

        // article.tags は target のみ (source 削除、target 重複なし)
        #expect((article.tags ?? []).count == 1)
        #expect((article.tags ?? []).first?.id == target.id)
    }

    // MARK: - 5. merge: 同 Tag 自身は no-op

    @Test func testMergeSelfIsNoop() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let tag = makeTag(name: "x", in: context)
        let article = makeArticle(url: "a", in: context)
        article.tags?.append(tag)
        try context.save()

        let store = TagStore(context: context)
        try store.merge(source: tag, into: tag)

        // 何も起きない
        let allTags = try context.fetch(FetchDescriptor<Tag>())
        #expect(allTags.count == 1)
        #expect((article.tags ?? []).contains(where: { $0.id == tag.id }))
    }

    // MARK: - 6. delete: 全 articles から relationship 解除 + Tag 削除

    @Test func testDeleteUnlinksAllArticlesAndRemovesTag() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let tag = makeTag(name: "x", in: context)
        let other = makeTag(name: "other", in: context)
        let a1 = makeArticle(url: "a1", in: context)
        let a2 = makeArticle(url: "a2", in: context)
        a1.tags?.append(tag)
        a1.tags?.append(other)
        a2.tags?.append(tag)
        try context.save()

        let store = TagStore(context: context)
        try store.delete(tag)

        // tag は消える
        let allTags = try context.fetch(FetchDescriptor<Tag>())
        #expect(allTags.count == 1)
        #expect(allTags.first?.name == "other")
        // a1.tags は other のみ、a2.tags は空
        #expect((a1.tags ?? []).count == 1)
        #expect((a1.tags ?? []).first?.id == other.id)
        #expect((a2.tags ?? []).isEmpty)
    }

    // MARK: - 7. rename: 同名 (no-op)

    @Test func testRenameToSameNameIsNoop() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let tag = makeTag(name: "swift", in: context)
        try context.save()

        let store = TagStore(context: context)
        let result = try store.rename(tag, to: "swift")

        #expect(result.id == tag.id)
        #expect(result.name == "swift")
    }

    // MARK: - 8. rename: 空文字 → throws

    @Test func testRenameToEmptyThrows() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let tag = makeTag(name: "swift", in: context)
        try context.save()

        let store = TagStore(context: context)
        #expect(throws: TagStoreError.self) {
            _ = try store.rename(tag, to: "   ")
        }
    }
}

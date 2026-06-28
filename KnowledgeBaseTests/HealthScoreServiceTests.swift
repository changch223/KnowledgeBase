//
//  HealthScoreServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 058 — HealthScoreService の単体テスト。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeBase

@MainActor
struct HealthScoreServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    @Test func testEmptyStateIsHealthy() async throws {
        let container = try makeContainer()
        let service = DefaultHealthScoreService(context: container.mainContext)
        let score = service.compute()
        #expect(score.orphanedConceptPageCount == 0)
        #expect(score.pendingConflictProposalCount == 0)
        #expect(score.total == 0)
        #expect(score.isHealthy)
    }

    @Test func testOrphanedConceptPageCounted() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        // 孤立: 関連記事 0 件 + isFollowing=false
        let orphan = ConceptPage(name: "Orphan", categoryRaw: "テクノロジー", isFollowing: false, isStale: false)
        context.insert(orphan)

        // 非孤立: isFollowing=true
        let following = ConceptPage(name: "Following", categoryRaw: "テクノロジー", isFollowing: true)
        context.insert(following)
        try context.save()

        let service = DefaultHealthScoreService(context: context)
        let score = service.compute()
        #expect(score.orphanedConceptPageCount == 1)
        #expect(score.total == 1)
        #expect(!score.isHealthy)
    }

    @Test func testPendingConflictsCounted() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article = Article(url: "https://example.com", title: "T")
        context.insert(article)
        let proposal = ConflictProposal(
            newArticle: article,
            oldArticle: nil,
            entityName: "X",
            conflictDescription: "",
            newFact: "",
            oldFact: "",
            status: ConflictStatus.pending.rawValue
        )
        context.insert(proposal)
        try context.save()

        let service = DefaultHealthScoreService(context: context)
        let score = service.compute()
        #expect(score.pendingConflictProposalCount == 1)
    }

    @Test func testAutoResolvedConflictNotCounted() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let article = Article(url: "https://example.com", title: "T")
        context.insert(article)
        let proposal = ConflictProposal(
            newArticle: article,
            oldArticle: nil,
            entityName: "X",
            conflictDescription: "",
            newFact: "",
            oldFact: "",
            status: ConflictStatus.autoResolved.rawValue
        )
        context.insert(proposal)
        try context.save()

        let service = DefaultHealthScoreService(context: context)
        let score = service.compute()
        // spec 058: autoResolved は pending 扱いされない
        #expect(score.pendingConflictProposalCount == 0)
    }
}

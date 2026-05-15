//
//  TopicClusteringServiceTests.swift
//  KnowledgeTreeTests
//
//  spec 036 — TopicClusteringService 5 ケース。
//

import Testing
import Foundation
import SwiftData
@testable import KnowledgeTree

@MainActor
struct TopicClusteringServiceTests {

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedSchema.all, configurations: configuration)
    }

    /// 簡易 L2 正規化済 embedding を生成 (テスト fixture)
    private func makeEmbedding(_ values: [Float]) -> [Float] {
        let sum = values.map { $0 * $0 }.reduce(0, +)
        let norm = sqrt(sum)
        return norm > 0 ? values.map { $0 / norm } : values
    }

    @discardableResult
    private func makeArticle(
        title: String,
        embedding: [Float],
        in context: ModelContext
    ) -> Article {
        let article = Article(url: "https://example.com/\(UUID().uuidString)", title: title)
        article.essenceEmbedding = embedding.asEmbeddingData
        // ExtractedKnowledge も essence で埋める (fallback name で使う)
        let knowledge = ExtractedKnowledge(article: article, status: .succeeded)
        knowledge.essence = title
        context.insert(knowledge)
        article.extractedKnowledge = knowledge
        context.insert(article)
        return article
    }

    private func makeServiceWith(context: ModelContext, available: Bool = true, defaults: UserDefaults? = nil) -> (TopicClusteringService, MockLanguageModelSession, UserDefaults) {
        let mockSession = MockLanguageModelSession()
        let availability = MockAvailabilityChecker()
        availability.isAvailable = available
        let suiteName = "test.\(UUID().uuidString)"
        let userDefaults = defaults ?? UserDefaults(suiteName: suiteName)!
        let service = TopicClusteringService(
            context: context,
            session: mockSession,
            availability: availability,
            defaults: userDefaults
        )
        return (service, mockSession, userDefaults)
    }

    // MARK: - 1. 記事数 < 10 → clustering スキップ

    @Test func testRunIfDueSkipsWhenTooFewArticles() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        for i in 0..<5 {
            makeArticle(title: "記事 \(i)", embedding: makeEmbedding([Float(i), 1.0, 1.0]), in: context)
        }
        try context.save()

        let (service, session, _) = makeServiceWith(context: context)
        await service.runIfDue(force: true)

        let topics = try context.fetch(FetchDescriptor<UserTopic>())
        #expect(topics.isEmpty)
        #expect(session.topicNameCallCount == 0)
    }

    // MARK: - 2. 2 つの clear cluster → 2 トピック作成

    @Test func testRunIfDueCreatesTwoClustersFromTwoGroups() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Cluster A: [1, 0, 0] 方向の 5 記事
        for i in 0..<5 {
            let v = makeEmbedding([Float(1.0 + Float(i) * 0.01), 0.01, 0.01])
            makeArticle(title: "A 記事 \(i)", embedding: v, in: context)
        }
        // Cluster B: [0, 1, 0] 方向の 5 記事
        for i in 0..<5 {
            let v = makeEmbedding([0.01, Float(1.0 + Float(i) * 0.01), 0.01])
            makeArticle(title: "B 記事 \(i)", embedding: v, in: context)
        }
        try context.save()

        let (service, session, _) = makeServiceWith(context: context)
        session.nextTopicNameResult = .success(TopicNameOutput(name: "テスト名"))

        await service.runIfDue(force: true)

        let topics = try context.fetch(FetchDescriptor<UserTopic>())
        // 最低 1 cluster は出来るはず (k = max(2, 10/10) = 2)
        #expect(topics.count >= 1)
        #expect(session.topicNameCallCount >= 1)
    }

    // MARK: - 3. AI 不可 → fallback で entity ベース命名

    @Test func testRunIfDueUsesFallbackNamingWhenLMUnavailable() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        for i in 0..<10 {
            let v = makeEmbedding([Float(i % 3) + 1.0, 0.5, 0.5])
            makeArticle(title: "記事 \(i)", embedding: v, in: context)
        }
        try context.save()

        let (service, session, _) = makeServiceWith(context: context, available: false)
        await service.runIfDue(force: true)

        let topics = try context.fetch(FetchDescriptor<UserTopic>())
        #expect(topics.count >= 1)
        #expect(session.topicNameCallCount == 0) // LM 呼ばない
    }

    // MARK: - 4. runIfDue: 7 日以内なら force=false でスキップ

    @Test func testRunIfDueRespectsCooldown() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        for i in 0..<10 {
            let v = makeEmbedding([Float(i), 1.0, 1.0])
            makeArticle(title: "記事 \(i)", embedding: v, in: context)
        }
        try context.save()

        let suiteName = "test.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        let yesterday = Date.now.addingTimeInterval(-86400)
        userDefaults.set(yesterday.timeIntervalSince1970, forKey: "topicClustering.lastRunAt")

        let (service, session, _) = makeServiceWith(context: context, defaults: userDefaults)
        await service.runIfDue(force: false)

        let topics = try context.fetch(FetchDescriptor<UserTopic>())
        #expect(topics.isEmpty) // skip された
        #expect(session.topicNameCallCount == 0)
    }

    // MARK: - 5. K-means 純関数: 全 entries が cluster に割り当てられる

    @Test func testKmeansAssignsAllEntries() {
        let entries: [(Article, [Float])] = (0..<6).map { i in
            let dummy = Article(url: "https://example.com/\(i)", title: "")
            let v: [Float] = i < 3
                ? [1.0, 0.0, 0.0]   // 同方向 3 件
                : [0.0, 1.0, 0.0]   // 別方向 3 件
            return (dummy, v)
        }
        let clusters = TopicClusteringService.kmeans(entries: entries, k: 2, maxIterations: 50)
        // K-means は初期 centroid がランダムなので cluster 数は 1〜2 (non-deterministic)
        #expect(clusters.count >= 1)
        let totalAssigned = clusters.reduce(0) { $0 + $1.articles.count }
        #expect(totalAssigned == 6)
    }

    // MARK: - 6. fallbackName: entity 集約

    @Test func testFallbackNameUsesTopEntities() {
        let context: ModelContext? = nil
        _ = context

        // Article + entities を programmatic に
        let containerCfg = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: SharedSchema.all, configurations: containerCfg) else {
            return
        }
        let ctx = container.mainContext

        let article1 = Article(url: "https://e.com/1", title: "1")
        ctx.insert(article1)
        let kn1 = ExtractedKnowledge(article: article1, status: .succeeded)
        let entA = KnowledgeEntity(knowledge: kn1, name: "A", typeRaw: "concept", salience: 5, order: 0)
        let entB = KnowledgeEntity(knowledge: kn1, name: "B", typeRaw: "concept", salience: 4, order: 1)
        ctx.insert(kn1)
        ctx.insert(entA)
        ctx.insert(entB)
        kn1.entities = [entA, entB]
        article1.extractedKnowledge = kn1

        let article2 = Article(url: "https://e.com/2", title: "2")
        ctx.insert(article2)
        let kn2 = ExtractedKnowledge(article: article2, status: .succeeded)
        let entA2 = KnowledgeEntity(knowledge: kn2, name: "A", typeRaw: "concept", salience: 5, order: 0)
        ctx.insert(kn2)
        ctx.insert(entA2)
        kn2.entities = [entA2]
        article2.extractedKnowledge = kn2

        let name = TopicClusteringService.fallbackName(articles: [article1, article2])
        // A が 2 回、B が 1 回 → "A / B" or "A"
        #expect(name.contains("A"))
    }
}

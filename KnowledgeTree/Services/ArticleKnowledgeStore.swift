//
//  ArticleKnowledgeStore.swift
//  KnowledgeTree
//
//  spec 004 — contracts/article-knowledge-store.md
//
//  Generable 出力 (transient) → @Model (persistent) のマッピングを集中管理。
//  cascade delete: Article → ExtractedKnowledge → [KeyFact, KnowledgeEntity]
//

import Foundation
import SwiftData

protocol ArticleKnowledgeStoreProtocol {
    func upsertStatus(article: Article, status: ExtractionStatus) throws

    func upsertFailure(article: Article, reason: String) throws

    func upsertSucceeded(
        article: Article,
        status: ExtractionStatus,
        output: ExtractedKnowledgeOutput,
        modelVersion: String?,
        durationMs: Int?,
        chunkProcessedCount: Int,
        chunkTotalCount: Int,
        skippedTailChars: Int
    ) throws

    func fetchPendingArticles() throws -> [Article]
    func deleteAll() throws
}

extension ArticleKnowledgeStoreProtocol {
    /// spec 005 互換: chunked 引数を default で 1/1/0 に固定する単発パス用の便利オーバーロード。
    func upsertSucceeded(
        article: Article,
        status: ExtractionStatus,
        output: ExtractedKnowledgeOutput,
        modelVersion: String?,
        durationMs: Int?
    ) throws {
        try upsertSucceeded(
            article: article,
            status: status,
            output: output,
            modelVersion: modelVersion,
            durationMs: durationMs,
            chunkProcessedCount: 1,
            chunkTotalCount: 1,
            skippedTailChars: 0
        )
    }
}

enum ArticleKnowledgeStoreError: Error {
    case persistenceFailure(underlying: Error)
}

@MainActor
final class SwiftDataArticleKnowledgeStore: ArticleKnowledgeStoreProtocol {
    private let context: ModelContext
    private let refreshTrigger: RefreshTrigger?

    init(context: ModelContext, refreshTrigger: RefreshTrigger? = nil) {
        self.context = context
        self.refreshTrigger = refreshTrigger
    }

    func upsertStatus(article: Article, status: ExtractionStatus) throws {
        if let existing = article.extractedKnowledge {
            existing.status = status
            if status != .failed {
                existing.failureReason = nil
            }
        } else {
            let new = ExtractedKnowledge(article: article, status: status)
            context.insert(new)
            article.extractedKnowledge = new
        }
        try saveContext()
    }

    func upsertFailure(article: Article, reason: String) throws {
        if let existing = article.extractedKnowledge {
            existing.status = .failed
            existing.failureReason = reason
        } else {
            let new = ExtractedKnowledge(
                article: article,
                status: .failed,
                failureReason: reason
            )
            context.insert(new)
            article.extractedKnowledge = new
        }
        try saveContext()
    }

    func upsertSucceeded(
        article: Article,
        status: ExtractionStatus,
        output: ExtractedKnowledgeOutput,
        modelVersion: String?,
        durationMs: Int?,
        chunkProcessedCount: Int,
        chunkTotalCount: Int,
        skippedTailChars: Int
    ) throws {
        let knowledge: ExtractedKnowledge
        if let existing = article.extractedKnowledge {
            knowledge = existing
            // 旧 children を明示削除 (cascade delete だけだと SwiftData の動作が依存性高いため安全側)
            for fact in knowledge.keyFacts {
                context.delete(fact)
            }
            for entity in knowledge.entities {
                context.delete(entity)
            }
            knowledge.keyFacts = []
            knowledge.entities = []
        } else {
            knowledge = ExtractedKnowledge(article: article, status: status)
            context.insert(knowledge)
            article.extractedKnowledge = knowledge
        }

        knowledge.status = status
        knowledge.failureReason = nil
        knowledge.essence = output.essence.isEmpty ? nil : String(output.essence.prefix(150))
        knowledge.summary = output.summary.isEmpty ? nil : String(output.summary.prefix(300))
        knowledge.generatedAt = Date()
        knowledge.modelVersion = modelVersion
        knowledge.generationDurationMs = durationMs
        // spec 006: chunked summarization のメタデータ
        knowledge.chunkProcessedCount = chunkProcessedCount
        knowledge.chunkTotalCount = chunkTotalCount
        knowledge.skippedTailChars = skippedTailChars

        // KeyFacts: order を生成順で付与
        for (idx, factOutput) in output.keyFacts.enumerated() {
            let fact = KeyFact(
                knowledge: knowledge,
                statement: factOutput.statement,
                typeRaw: factOutput.type.storedRawValue,
                order: idx
            )
            context.insert(fact)
            knowledge.keyFacts.append(fact)
        }

        // Entities: order を生成順、salience 順は表示時に sort
        for (idx, entityOutput) in output.entities.enumerated() {
            let entity = KnowledgeEntity(
                knowledge: knowledge,
                name: entityOutput.name,
                typeRaw: entityOutput.type.storedRawValue,
                salience: entityOutput.salience,
                order: idx
            )
            context.insert(entity)
            knowledge.entities.append(entity)
        }

        try saveContext()
    }

    func fetchPendingArticles() throws -> [Article] {
        do {
            // ArticleBody が succeeded 状態 & ExtractedKnowledge 不在 の Article を取得
            var descriptor = FetchDescriptor<Article>(
                predicate: #Predicate<Article> { article in
                    article.extractedKnowledge == nil &&
                    article.body != nil &&
                    article.body?.statusRaw == "succeeded"
                }
            )
            descriptor.fetchLimit = 1000
            return try context.fetch(descriptor)
        } catch {
            throw ArticleKnowledgeStoreError.persistenceFailure(underlying: error)
        }
    }

    func deleteAll() throws {
        do {
            try context.delete(model: ExtractedKnowledge.self)
            try context.save()
        } catch {
            throw ArticleKnowledgeStoreError.persistenceFailure(underlying: error)
        }
    }

    private func saveContext() throws {
        do {
            try context.save()
            refreshTrigger?.bump()
        } catch {
            throw ArticleKnowledgeStoreError.persistenceFailure(underlying: error)
        }
    }
}

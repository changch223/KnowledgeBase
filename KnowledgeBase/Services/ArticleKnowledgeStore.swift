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
            for fact in (knowledge.keyFacts ?? []) {
                context.delete(fact)
            }
            for entity in (knowledge.entities ?? []) {
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

        // KeyFacts: order を生成順で付与、最大 10 件 (AI が指示を無視した場合の defensive truncate)
        for (idx, factOutput) in (output.keyFacts ?? []).prefix(10).enumerated() {
            let fact = KeyFact(
                knowledge: knowledge,
                statement: factOutput.statement,
                typeRaw: factOutput.type.storedRawValue,
                order: idx
            )
            context.insert(fact)
            if knowledge.keyFacts == nil { knowledge.keyFacts = [] }
            knowledge.keyFacts?.append(fact)
        }

        // Entities: order を生成順、salience 順は表示時に sort
        for (idx, entityOutput) in (output.entities ?? []).enumerated() {
            let entity = KnowledgeEntity(
                knowledge: knowledge,
                name: entityOutput.name,
                typeRaw: entityOutput.type.storedRawValue,
                salience: entityOutput.salience,
                order: idx
            )
            context.insert(entity)
            if knowledge.entities == nil { knowledge.entities = [] }
            knowledge.entities?.append(entity)
        }

        try saveContext()
    }

    func fetchPendingArticles() throws -> [Article] {
        do {
            // 1) body が succeeded で knowledge 不在の Article
            var noKnowledgeDescriptor = FetchDescriptor<Article>(
                predicate: #Predicate<Article> { article in
                    article.extractedKnowledge == nil &&
                    article.body != nil &&
                    article.body?.statusRaw == "succeeded"
                }
            )
            noKnowledgeDescriptor.fetchLimit = 1000
            let noKnowledge = try context.fetch(noKnowledgeDescriptor)

            // 2) 中間状態 (extracting / pending) で残骸になった ExtractedKnowledge を持つ Article
            // app crash / device lock 等で stale state に陥った場合の自動回復対象。
            // AI 復旧機能: skipped (Apple Intelligence 不可時に書かれた) も再試行対象に含める。
            // extract() 冒頭の availability guard が再び skipped を書くだけの安全な no-op ループになる
            // (AI 不可のまま) か、AI 復活後は自然に再抽出される。
            var staleDescriptor = FetchDescriptor<ExtractedKnowledge>(
                predicate: #Predicate<ExtractedKnowledge> {
                    $0.statusRaw == "extracting" || $0.statusRaw == "pending" || $0.statusRaw == "skipped"
                }
            )
            staleDescriptor.fetchLimit = 1000
            let staleKnowledges = try context.fetch(staleDescriptor)
            // spec 051 Phase A: ExtractedKnowledge.article は Optional 化、compactMap で nil 除外
            let staleArticles = staleKnowledges
                .compactMap(\.article)
                .filter { $0.body?.status == .succeeded }

            // 重複排除
            var seen: Set<UUID> = []
            var result: [Article] = []
            for article in noKnowledge + staleArticles {
                if seen.insert(article.id).inserted {
                    result.append(article)
                }
            }
            return result
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

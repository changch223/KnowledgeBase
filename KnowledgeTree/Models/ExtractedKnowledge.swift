//
//  ExtractedKnowledge.swift
//  KnowledgeTree
//
//  spec 004 — 知識抽出 + 要約 (Apple Foundation Models)
//
//  3 つの @Model + 2 つの enum + getter/setter extension を 1 ファイルに集約
//  (関連密度が高く、一覧性を優先 — Constitution Principle VI / コード品質)。
//
//  Generable 型 (transient) と @Model 型 (persistent) は完全分離。
//  Generable 型は LanguageModelSessionProtocol.swift で定義。
//

import Foundation
import SwiftData

// MARK: - ExtractedKnowledge

@Model
final class ExtractedKnowledge {
    var id: UUID = UUID()
    var article: Article
    var statusRaw: String = ""
    var essence: String?
    var summary: String?
    var generatedAt: Date?
    var modelVersion: String?
    var extractionVersion: Int = 0
    var generationDurationMs: Int?
    var failureReason: String?

    /// spec 006: chunked summarization で実際に成功した chunk 数 (含 meta-summary)。
    /// 単発パス (本文 ≤ 1000 文字) では 1。chunked パスでは N+1 (chunk N 個 + meta 1 個)。
    var chunkProcessedCount: Int = 0
    /// spec 006: 総 chunk 数 (chunks + meta-summary)。単発パスでは 1。
    var chunkTotalCount: Int = 0
    /// spec 006: 10 chunk 上限超過で要約対象外となった末尾文字数。0 〜 (text.count - 10000)。
    var skippedTailChars: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \KeyFact.knowledge)
    var keyFacts: [KeyFact] = []

    @Relationship(deleteRule: .cascade, inverse: \KnowledgeEntity.knowledge)
    var entities: [KnowledgeEntity] = []

    /// spec 009: chunked summarization の各 chunk 完了結果。完了で cleanup される。
    @Relationship(deleteRule: .cascade, inverse: \KnowledgeChunkProgress.knowledge)
    var chunkProgress: [KnowledgeChunkProgress] = []

    init(
        id: UUID = UUID(),
        article: Article,
        status: ExtractionStatus = .pending,
        essence: String? = nil,
        summary: String? = nil,
        generatedAt: Date? = nil,
        modelVersion: String? = nil,
        extractionVersion: Int = 1,
        generationDurationMs: Int? = nil,
        failureReason: String? = nil,
        chunkProcessedCount: Int = 1,
        chunkTotalCount: Int = 1,
        skippedTailChars: Int = 0
    ) {
        self.id = id
        self.article = article
        self.statusRaw = status.rawValue
        self.essence = essence
        self.summary = summary
        self.generatedAt = generatedAt
        self.modelVersion = modelVersion
        self.extractionVersion = extractionVersion
        self.generationDurationMs = generationDurationMs
        self.failureReason = failureReason
        self.chunkProcessedCount = chunkProcessedCount
        self.chunkTotalCount = chunkTotalCount
        self.skippedTailChars = skippedTailChars
    }
}

enum ExtractionStatus: String, Codable, Sendable {
    case pending
    case extracting
    case succeeded
    case partiallySucceeded
    case failed
    case skipped
}

extension ExtractedKnowledge {
    var status: ExtractionStatus {
        get { ExtractionStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}

// MARK: - KeyFact

@Model
final class KeyFact {
    var id: UUID = UUID()
    var knowledge: ExtractedKnowledge
    var statement: String = ""
    var typeRaw: String = ""
    var order: Int = 0

    init(
        id: UUID = UUID(),
        knowledge: ExtractedKnowledge,
        statement: String,
        typeRaw: String,
        order: Int
    ) {
        self.id = id
        self.knowledge = knowledge
        self.statement = String(statement.prefix(200))
        self.typeRaw = typeRaw
        self.order = order
    }
}

enum FactTypeStored: String, Codable, Sendable {
    case event
    case claim
    case statistic
    case definition
    case quote
}

extension KeyFact {
    var typeStored: FactTypeStored {
        FactTypeStored(rawValue: typeRaw) ?? .claim
    }
}

// MARK: - KnowledgeEntity

@Model
final class KnowledgeEntity {
    var id: UUID = UUID()
    var knowledge: ExtractedKnowledge
    var name: String = ""
    var typeRaw: String = ""
    var salience: Int = 0
    var order: Int = 0

    init(
        id: UUID = UUID(),
        knowledge: ExtractedKnowledge,
        name: String,
        typeRaw: String,
        salience: Int,
        order: Int
    ) {
        self.id = id
        self.knowledge = knowledge
        self.name = String(name.prefix(30))
        self.typeRaw = typeRaw
        self.salience = max(1, min(5, salience))
        self.order = order
    }
}

enum EntityTypeStored: String, Codable, Sendable {
    case person
    case organization
    case location
    case concept
    case product
    case work
}

extension KnowledgeEntity {
    var typeStored: EntityTypeStored {
        EntityTypeStored(rawValue: typeRaw) ?? .concept
    }
}

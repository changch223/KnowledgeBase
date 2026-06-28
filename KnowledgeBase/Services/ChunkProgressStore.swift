//
//  ChunkProgressStore.swift
//  KnowledgeTree
//
//  spec 009 — KnowledgeChunkProgress の CRUD + JSON encode/decode をカプセル化。
//  Service レイヤーから RAW JSON / SwiftData 詳細を扱わなくて済むようにする。
//

import Foundation
import SwiftData

/// ChunkProgressStore の戻り値型 (transient)
struct LoadedChunkProgress: Sendable {
    let chunkIndex: Int
    let output: ExtractedKnowledgeOutput
}

@MainActor
protocol ChunkProgressStoreProtocol {
    func add(
        knowledge: ExtractedKnowledge,
        chunkIndex: Int,
        output: ExtractedKnowledgeOutput
    ) throws

    func fetchAll(knowledge: ExtractedKnowledge) throws -> [LoadedChunkProgress]

    func cleanup(knowledge: ExtractedKnowledge) throws
}

@MainActor
final class SwiftDataChunkProgressStore: ChunkProgressStoreProtocol {
    private let context: ModelContext
    private let refreshTrigger: RefreshTrigger?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(context: ModelContext, refreshTrigger: RefreshTrigger? = nil) {
        self.context = context
        self.refreshTrigger = refreshTrigger
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func add(
        knowledge: ExtractedKnowledge,
        chunkIndex: Int,
        output: ExtractedKnowledgeOutput
    ) throws {
        let json = try encoder.encode(output)
        let jsonString = String(data: json, encoding: .utf8) ?? "{}"

        if let existing = (knowledge.chunkProgress ?? []).first(where: { $0.chunkIndex == chunkIndex }) {
            existing.chunkOutputJSON = jsonString
            existing.savedAt = Date()
        } else {
            let progress = KnowledgeChunkProgress(
                knowledge: knowledge,
                chunkIndex: chunkIndex,
                chunkOutputJSON: jsonString
            )
            context.insert(progress)
            if knowledge.chunkProgress == nil { knowledge.chunkProgress = [] }
            knowledge.chunkProgress?.append(progress)
        }
        try context.save()
        refreshTrigger?.bump()
    }

    func fetchAll(knowledge: ExtractedKnowledge) throws -> [LoadedChunkProgress] {
        (knowledge.chunkProgress ?? [])
            .sorted { $0.chunkIndex < $1.chunkIndex }
            .compactMap { progress in
                guard let data = progress.chunkOutputJSON.data(using: .utf8),
                      let output = try? decoder.decode(ExtractedKnowledgeOutput.self, from: data)
                else { return nil }
                return LoadedChunkProgress(chunkIndex: progress.chunkIndex, output: output)
            }
    }

    func cleanup(knowledge: ExtractedKnowledge) throws {
        for progress in (knowledge.chunkProgress ?? []) {
            context.delete(progress)
        }
        knowledge.chunkProgress = []
        try context.save()
        refreshTrigger?.bump()
    }
}

/// テスト / spec 006 既存テスト互換用の no-op 実装。
@MainActor
final class NoopChunkProgressStore: ChunkProgressStoreProtocol {
    func add(knowledge: ExtractedKnowledge, chunkIndex: Int, output: ExtractedKnowledgeOutput) throws {}
    func fetchAll(knowledge: ExtractedKnowledge) throws -> [LoadedChunkProgress] { [] }
    func cleanup(knowledge: ExtractedKnowledge) throws {}
}

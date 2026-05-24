//
//  KnowledgeChunkProgress.swift
//  KnowledgeTree
//
//  spec 009 — chunked summarization の各 chunk 完了時に 1 行 insert する incremental
//  永続化 entity。リジューム時は既完了 chunkIndex を skip してリトライ可能化。
//

import Foundation
import SwiftData

@Model
final class KnowledgeChunkProgress {
    var id: UUID = UUID()
    var knowledge: ExtractedKnowledge
    var chunkIndex: Int = 0
    /// ExtractedKnowledgeOutput を Codable で encode した JSON 文字列
    var chunkOutputJSON: String = ""
    var savedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        knowledge: ExtractedKnowledge,
        chunkIndex: Int,
        chunkOutputJSON: String,
        savedAt: Date = Date()
    ) {
        self.id = id
        self.knowledge = knowledge
        self.chunkIndex = chunkIndex
        self.chunkOutputJSON = chunkOutputJSON
        self.savedAt = savedAt
    }
}

//
//  BackgroundExtractionQueueEntry.swift
//  KnowledgeTree
//
//  spec 009 — BGTask が起動した時に処理する article の queue。FIFO (queuedAt 昇順)。
//  Article への soft reference (UUID のみ、relationship 無し) で、Article 削除時の
//  検出は queue dequeue で fetch して 0 件なら skip + entry 削除する。
//

import Foundation
import SwiftData

@Model
final class BackgroundExtractionQueueEntry {
    var id: UUID = UUID()
    var articleID: UUID = UUID()
    var queuedAt: Date = Date.now

    init(id: UUID = UUID(), articleID: UUID, queuedAt: Date = Date()) {
        self.id = id
        self.articleID = articleID
        self.queuedAt = queuedAt
    }
}

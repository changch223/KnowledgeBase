//
//  BackgroundExtractionQueue.swift
//  KnowledgeTree
//
//  spec 009 — BGTask が処理する article の永続化 queue (FIFO)。
//  enqueue 時に重複 articleID は無視。BGTask 起動時に dequeueOldest で 1 件取り出す。
//  Article の削除検出は呼び出し側 (BackgroundExtractionRunner) で実施。
//

import Foundation
import SwiftData

@MainActor
protocol BackgroundExtractionQueueProtocol {
    func enqueue(articleID: UUID) throws
    func dequeueOldest() throws -> UUID?
    func fetchOldestArticleID() throws -> UUID?
    func remove(articleID: UUID) throws
    func contains(articleID: UUID) throws -> Bool
}

@MainActor
final class BackgroundExtractionQueue: BackgroundExtractionQueueProtocol {
    private let context: ModelContext
    private let refreshTrigger: RefreshTrigger?

    init(context: ModelContext, refreshTrigger: RefreshTrigger? = nil) {
        self.context = context
        self.refreshTrigger = refreshTrigger
    }

    func enqueue(articleID: UUID) throws {
        // 重複防止
        if try contains(articleID: articleID) {
            return
        }
        let entry = BackgroundExtractionQueueEntry(articleID: articleID)
        context.insert(entry)
        try context.save()
        refreshTrigger?.bump()
    }

    /// 最古エントリを取り出して削除 + articleID を返す。queue 空なら nil。
    func dequeueOldest() throws -> UUID? {
        guard let oldest = try fetchOldestEntry() else { return nil }
        let articleID = oldest.articleID
        context.delete(oldest)
        try context.save()
        refreshTrigger?.bump()
        return articleID
    }

    /// peek (削除しない、最古 articleID のみ取得)
    func fetchOldestArticleID() throws -> UUID? {
        try fetchOldestEntry()?.articleID
    }

    func remove(articleID: UUID) throws {
        var descriptor = FetchDescriptor<BackgroundExtractionQueueEntry>(
            predicate: #Predicate<BackgroundExtractionQueueEntry> { $0.articleID == articleID }
        )
        descriptor.fetchLimit = 100  // 重複あっても全部削除
        let entries = try context.fetch(descriptor)
        guard !entries.isEmpty else { return }
        for entry in entries {
            context.delete(entry)
        }
        try context.save()
        refreshTrigger?.bump()
    }

    func contains(articleID: UUID) throws -> Bool {
        var descriptor = FetchDescriptor<BackgroundExtractionQueueEntry>(
            predicate: #Predicate<BackgroundExtractionQueueEntry> { $0.articleID == articleID }
        )
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }

    // MARK: - Private

    private func fetchOldestEntry() throws -> BackgroundExtractionQueueEntry? {
        var descriptor = FetchDescriptor<BackgroundExtractionQueueEntry>(
            sortBy: [SortDescriptor(\.queuedAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

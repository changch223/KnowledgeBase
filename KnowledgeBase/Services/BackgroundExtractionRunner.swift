//
//  BackgroundExtractionRunner.swift
//  KnowledgeTree
//
//  spec 009 — BGTask 実行コンテキストで 1 article の chunked extraction を進める。
//  knowledgeService.extract を経由することで spec 005 重複抑止 + spec 008 stale
//  recovery + spec 009 incremental save / resume が連動する。
//

import Foundation
import os

@MainActor
final class BackgroundExtractionRunner {
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "background")
    private let knowledgeService: KnowledgeExtractionServiceProtocol
    private let articleStore: ArticleStoreProtocol
    private let queue: BackgroundExtractionQueueProtocol

    private var currentTask: Task<Void, Never>?

    init(
        knowledgeService: KnowledgeExtractionServiceProtocol,
        articleStore: ArticleStoreProtocol,
        queue: BackgroundExtractionQueueProtocol
    ) {
        self.knowledgeService = knowledgeService
        self.articleStore = articleStore
        self.queue = queue
    }

    /// queue から取り出した articleID で chunked extraction を実行。
    /// - Returns: success (.succeeded / .partiallySucceeded / .skipped で完了) なら true
    @discardableResult
    func run(articleID: UUID) async -> Bool {
        // article fetch
        guard let article = try? articleStore.fetchByID(articleID) else {
            logger.notice("BG runner: article \(articleID, privacy: .public) not found, skipping")
            try? queue.remove(articleID: articleID)
            return true  // skip 扱い (success)
        }

        logger.notice("BG runner: starting extraction for \(article.url, privacy: .public)")

        let task: Task<Void, Never> = Task { [weak self] in
            guard let self else { return }
            await self.knowledgeService.extract(article: article)
        }
        currentTask = task
        defer { currentTask = nil }

        await task.value

        // 完了状態を確認
        let finalStatus = article.extractedKnowledge?.status
        let isComplete = finalStatus == .succeeded
            || finalStatus == .partiallySucceeded
            || finalStatus == .skipped

        if isComplete {
            try? queue.remove(articleID: articleID)
            logger.notice("BG runner: completed for \(article.url, privacy: .public): status=\(String(describing: finalStatus), privacy: .public)")
        } else {
            // 中断された場合は queue に残しておく (時間切れ等で次回 BGTask が継続)
            logger.notice("BG runner: interrupted for \(article.url, privacy: .public): status=\(String(describing: finalStatus), privacy: .public), retaining in queue")
        }

        return isComplete
    }

    func cancelCurrent() {
        currentTask?.cancel()
        currentTask = nil
    }
}

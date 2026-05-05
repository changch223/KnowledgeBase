//
//  AutoTagBackfillRunner.swift
//  KnowledgeTree
//
//  spec 013 — bootstrap で 1 回だけ既存全 article を走査し、
//  spec 012 の AutoTagApplier.apply() を順次適用する backfill runner。
//
//  contracts/auto-tag-backfill-runner.md 準拠。
//
//  Algorithm:
//    1. flagStore.isCompleted() ガード → early return
//    2. Article 全件 fetch (savedAt desc)
//    3. 候補 filter (tags.isEmpty + knowledge.status .succeeded/.partiallySucceeded)
//    4. ProcessingMonitor で進捗開始
//    5. 各候補に AutoTagApplier.apply() を順次呼ぶ + updateProgress
//    6. ProcessingMonitor 完了
//    7. flagStore.markCompleted()
//

import Foundation
import SwiftData
import os

@MainActor
final class AutoTagBackfillRunner {
    private let logger = Logger(subsystem: "app.KnowledgeTree", category: "auto-tag-backfill")

    private let context: ModelContext
    private let tagStore: TagStore
    private let processingMonitor: ProcessingMonitor?
    private let flagStore: BackfillFlagStore

    /// backfill 中の ProcessingMonitor key として使う固定 UUID。
    /// 通常の Article.id (UUID) と衝突しないよう上位 8 桁を全 0 に固定。
    static let backfillProcessingID = UUID(
        uuidString: "00000000-0000-0000-0000-AB13BACFB13F"
    )!

    init(
        context: ModelContext,
        tagStore: TagStore,
        processingMonitor: ProcessingMonitor? = nil,
        flagStore: BackfillFlagStore = UserDefaultsBackfillFlagStore()
    ) {
        self.context = context
        self.tagStore = tagStore
        self.processingMonitor = processingMonitor
        self.flagStore = flagStore
    }

    /// bootstrap で 1 回呼ばれる。フラグが既に true なら early return。
    /// 全候補 article を AutoTagApplier.apply で処理 → 完了でフラグ true セット。
    func run() async {
        // 1. フラグ early return
        guard !flagStore.isCompleted() else {
            logger.debug("auto-tag backfill skipped: already completed")
            return
        }

        // 2. 全 Article を savedAt desc で取得 (最新優先)
        let descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        let allArticles: [Article] = (try? context.fetch(descriptor)) ?? []

        // 3. 候補 filter (tags 空 + knowledge succeeded/partiallySucceeded)
        let candidates: [Article] = allArticles.filter { article in
            guard article.tags.isEmpty else { return false }
            guard let knowledge = article.extractedKnowledge else { return false }
            return knowledge.status == .succeeded
                || knowledge.status == .partiallySucceeded
        }

        logger.notice(
            "auto-tag backfill starting: \(candidates.count)/\(allArticles.count) candidates"
        )

        // 候補 0 件でもフラグだけは true にする (再実行ループ防止)
        guard !candidates.isEmpty else {
            flagStore.markCompleted()
            logger.notice("auto-tag backfill completed: 0 articles processed (no candidates)")
            return
        }

        // 4. ProcessingMonitor で進捗表示開始
        let backfillID = Self.backfillProcessingID
        processingMonitor?.start(
            .tagBackfilling,
            articleID: backfillID,
            title: "全タグ整理中",
            progressIndex: 0,
            progressTotal: candidates.count
        )

        // 5. 各候補に AutoTagApplier.apply
        var processedIndex = 0
        for article in candidates {
            AutoTagApplier.apply(to: article, using: tagStore)
            processedIndex += 1
            processingMonitor?.updateProgress(
                articleID: backfillID,
                index: processedIndex
            )
        }

        // 6. ProcessingMonitor 終了
        processingMonitor?.finish(articleID: backfillID)

        // 7. フラグ true セット
        flagStore.markCompleted()

        logger.notice(
            "auto-tag backfill completed: processed \(processedIndex) articles"
        )
    }
}
